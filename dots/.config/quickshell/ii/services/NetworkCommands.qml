pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Every NetworkManager write the shell makes, through one serialised nmcli queue.
 *
 * Quickshell's native backend covers state but cannot build a settings
 * dictionary from QML, so profile creation, 802.1X, hidden SSIDs, addressing and
 * the hotspot all have to go through nmcli. Commands are argument vectors rather
 * than assembled shell strings; the handful that carry a secret run a fixed
 * script that reads it out of the environment, because /proc/<pid>/cmdline is
 * world readable and /proc/<pid>/environ is not.
 */
Singleton {
    id: root

    readonly property string kConnectPsk: 'nmcli device wifi connect "$1" password "$PASSWORD" "${@:2}"'
    readonly property string kSetPsk: 'nmcli connection modify "$1" wifi-sec.psk "$PASSWORD"'
    readonly property string kAddEnterprise: 'nmcli connection add type wifi con-name "$1" ifname "$2" ssid "$3" wifi-sec.key-mgmt wpa-eap 802-1x.password "$PASSWORD" "${@:4}"'

    readonly property bool busy: root.active !== null
    property var active: null
    property var pending: []

    signal commandFinished(string tag, int exitCode, string output, string error)

    function run(argv: var, tag = "", callback = null, env = null): void {
        root.pending = [...root.pending, {
            argv: argv,
            tag: tag,
            callback: callback,
            env: env
        }];
        root.pump();
    }

    function runScript(script: string, args: var, tag = "", callback = null, env = null): void {
        root.run(["bash", "-c", script, "--", ...args], tag, callback, env);
    }

    function pump(): void {
        if (root.active || root.pending.length === 0)
            return;
        const job = root.pending[0];
        root.pending = root.pending.slice(1);
        root.active = job;
        runner.running = false;
        runner.environment = Object.assign({
            LANG: "C",
            LC_ALL: "C"
        }, job.env ?? {});
        runner.command = job.argv;
        runner.running = true;
    }

    // ---- Radio ------------------------------------------------------------
    function setWifiRadio(enabled: bool, callback = null): void {
        root.run(["nmcli", "radio", "wifi", enabled ? "on" : "off"], "radio", callback);
    }

    // Blocks until the scan results are in, which is what makes it usable as a
    // "scanning finished" signal.
    function rescanWifi(callback = null): void {
        root.run(["nmcli", "device", "wifi", "list", "--rescan", "yes"], "rescan", callback);
    }

    // ---- Wi-Fi connections ------------------------------------------------
    function connectToSsid(ssid: string, ifname = "", callback = null): void {
        const argv = ["nmcli", "device", "wifi", "connect", ssid];
        if (ifname.length > 0)
            argv.push("ifname", ifname);
        root.run(argv, "connect", callback);
    }

    function activateProfile(name: string, callback = null): void {
        root.run(["nmcli", "connection", "up", "id", name], "activate", callback);
    }

    function connectWithPsk(ssid: string, psk: string, options = ({}), callback = null): void {
        const extra = [];
        if (options.ifname)
            extra.push("ifname", options.ifname);
        if (options.hidden)
            extra.push("hidden", "yes");
        root.runScript(root.kConnectPsk, [ssid, ...extra], "connect", callback, {
            PASSWORD: psk
        });
    }

    function setProfilePsk(profile: string, psk: string, callback = null): void {
        root.runScript(root.kSetPsk, [profile], "modify", callback, {
            PASSWORD: psk
        });
    }

    /**
     * Creates an 802.1X profile and brings it up. `options` takes eap ("peap",
     * "ttls", "tls", "pwd"), identity, anonymousIdentity, phase2, caCert,
     * domainSuffix, clientCert, privateKey, profile, ifname and hidden.
     */
    function connectWithEnterprise(ssid: string, password: string, options = ({}), callback = null): void {
        const profile = options.profile ?? ssid;
        const extra = ["802-1x.eap", options.eap ?? "peap"];
        if (options.identity)
            extra.push("802-1x.identity", options.identity);
        if (options.anonymousIdentity)
            extra.push("802-1x.anonymous-identity", options.anonymousIdentity);
        if (options.phase2)
            extra.push("802-1x.phase2-auth", options.phase2);
        if (options.caCert)
            extra.push("802-1x.ca-cert", options.caCert);
        if (options.domainSuffix)
            extra.push("802-1x.domain-suffix-match", options.domainSuffix);
        if (options.clientCert)
            extra.push("802-1x.client-cert", options.clientCert);
        if (options.privateKey)
            extra.push("802-1x.private-key", options.privateKey);
        if (options.hidden)
            extra.push("802-11-wireless.hidden", "yes");
        root.runScript(root.kAddEnterprise, [profile, options.ifname ?? "", ssid, ...extra], "enterprise", (code, out, err) => {
            if (code !== 0) {
                if (callback)
                    callback(code, out, err);
                return;
            }
            root.activateProfile(profile, callback);
        }, {
            PASSWORD: password
        });
    }

    function connectToHidden(ssid: string, psk: string, options = ({}), callback = null): void {
        root.connectWithPsk(ssid, psk, Object.assign({}, options, {
            hidden: true
        }), callback);
    }

    function disconnectProfile(name: string, callback = null): void {
        root.run(["nmcli", "connection", "down", "id", name], "down", callback);
    }

    function disconnectDevice(ifname: string, callback = null): void {
        root.run(["nmcli", "device", "disconnect", ifname], "down", callback);
    }

    function forgetProfile(name: string, callback = null): void {
        root.run(["nmcli", "connection", "delete", "id", name], "forget", callback);
    }

    function setAutoconnect(name: string, enabled: bool, callback = null): void {
        root.run(["nmcli", "connection", "modify", "id", name, "connection.autoconnect", enabled ? "yes" : "no"], "modify", callback);
    }

    // ---- Reads nmcli still owns -------------------------------------------
    // nmcli --escape writes a literal colon inside a field as a backslash pair,
    // so the separator can only be found by walking the line.
    function splitEscaped(line: string): var {
        const fields = [];
        let current = "";
        for (let i = 0; i < line.length; i++) {
            const c = line.charAt(i);
            if (c === "\\" && i + 1 < line.length) {
                current += line.charAt(++i);
            } else if (c === ":") {
                fields.push(current);
                current = "";
            } else {
                current += c;
            }
        }
        fields.push(current);
        return fields;
    }

    /**
     * Per access point extras the D-Bus backend doesn't expose: BSSID, frequency
     * and NetworkManager's own security string. Keyed by SSID.
     */
    function readWifiDetails(callback): void {
        root.run(["nmcli", "-t", "-e", "yes", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY,NAME", "device", "wifi"], "details", (code, out) => {
            callback(code === 0 ? root.parseWifiDetails(out) : ({}));
        });
    }

    function parseWifiDetails(text: string): var {
        const bySsid = ({});
        text.trim().split("\n").forEach(line => {
            if (line.length === 0)
                return;
            const parts = root.splitEscaped(line);
            const ssid = parts[3] ?? "";
            if (ssid.length === 0)
                return;
            const entry = {
                active: parts[0] === "yes",
                strength: parseInt(parts[1]) || 0,
                frequency: parseInt(parts[2]) || 0,
                ssid: ssid,
                bssid: parts[4] ?? "",
                security: parts[5] ?? "",
                profile: parts[6] ?? ""
            };
            // Several radios can advertise the same SSID; keep the connected one,
            // then the strongest, so these extras describe the same access point
            // the backend collapsed them into.
            const existing = bySsid[ssid];
            if (!existing || (entry.active && !existing.active) || (!existing.active && entry.strength > existing.strength))
                bySsid[ssid] = entry;
        });
        return bySsid;
    }

    function readSavedConnections(callback): void {
        root.run(["nmcli", "-t", "-e", "yes", "-g", "NAME,UUID,TYPE,DEVICE,AUTOCONNECT,TIMESTAMP", "connection", "show"], "saved", (code, out) => {
            callback(code === 0 ? root.parseSavedConnections(out) : []);
        });
    }

    function parseSavedConnections(text: string): var {
        const rows = [];
        text.trim().split("\n").forEach(line => {
            if (line.length === 0)
                return;
            const parts = root.splitEscaped(line);
            if (!parts[0] || parts[0].length === 0)
                return;
            rows.push({
                name: parts[0],
                uuid: parts[1] ?? "",
                type: parts[2] ?? "",
                device: parts[3] ?? "",
                autoconnect: parts[4] === "yes",
                timestamp: parseInt(parts[5]) || 0
            });
        });
        return rows;
    }

    function readIpConfig(ifname: string, callback): void {
        if (ifname.length === 0) {
            callback({});
            return;
        }
        root.run(["nmcli", "-t", "-e", "yes", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS", "device", "show", ifname], "ipconfig", (code, out) => {
            callback(code === 0 ? root.parseIpConfig(out) : ({}));
        });
    }

    function parseIpConfig(text: string): var {
        const result = {
            address: "",
            prefix: 0,
            gateway: "",
            dns: [],
            address6: ""
        };
        text.trim().split("\n").forEach(line => {
            const parts = root.splitEscaped(line);
            if (parts.length < 2)
                return;
            const key = parts[0];
            const value = parts.slice(1).join(":");
            if (key.startsWith("IP4.ADDRESS") && result.address.length === 0) {
                const bits = value.split("/");
                result.address = bits[0] ?? "";
                result.prefix = parseInt(bits[1]) || 0;
            } else if (key.startsWith("IP4.GATEWAY")) {
                result.gateway = value === "--" ? "" : value;
            } else if (key.startsWith("IP4.DNS")) {
                result.dns.push(value);
            } else if (key.startsWith("IP6.ADDRESS") && result.address6.length === 0) {
                result.address6 = value.split("/")[0] ?? "";
            }
        });
        return result;
    }

    function prefixToMask(prefix: int): string {
        if (prefix <= 0 || prefix > 32)
            return "";
        const bits = (0xFFFFFFFF << (32 - prefix)) >>> 0;
        return [bits >>> 24, (bits >>> 16) & 255, (bits >>> 8) & 255, bits & 255].join(".");
    }

    Process {
        id: runner
        stdout: StdioCollector {
            id: outCollector
        }
        stderr: StdioCollector {
            id: errCollector
        }
        onExited: exitCode => {
            const job = root.active;
            root.active = null;
            const out = outCollector.text ?? "";
            const err = errCollector.text ?? "";
            if (job) {
                if (job.callback)
                    job.callback(exitCode, out, err);
                root.commandFinished(job.tag ?? "", exitCode, out, err);
            }
            Qt.callLater(root.pump);
        }
    }
}
