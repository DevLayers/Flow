pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string canonicalUnit: "app-dev.lizardbyte.app.Sunshine.service"
    readonly property string webUiUrl: "https://localhost:47990"
    readonly property string configPath: FileUtils.trimFileProtocol(`${Directories.home}/.config/sunshine/sunshine.conf`)
    readonly property string defaultStatePath: FileUtils.trimFileProtocol(`${Directories.home}/.config/sunshine/sunshine_state.json`)

    property string serviceUnit: canonicalUnit
    property bool serviceAvailable: false
    property bool binaryAvailable: false
    readonly property bool installed: serviceAvailable || binaryAvailable
    property bool running: false
    property bool enabledOnLogin: false
    property bool refreshing: false
    readonly property bool actionRunning: actionProcess.running || configWriteProcess.running

    property string hostName: ""
    property string hostAddress: ""
    property string lastError: ""

    property string encoder: "auto"
    property bool keyboardEnabled: true
    property bool mouseEnabled: true
    property bool controllerEnabled: true
    property bool nativePenTouchEnabled: true
    property string stateFilePath: defaultStatePath
    property var pairedClients: []
    readonly property int pairedClientCount: pairedClients.length

    Component.onCompleted: refresh()

    function refresh() {
        if (!statusProcess.running) {
            root.refreshing = true;
            statusProcess.running = true;
        }
        if (!addressProcess.running)
            addressProcess.running = true;
        if (!configReadProcess.running)
            configReadProcess.running = true;
        refreshClients();
    }

    function refreshClients() {
        if (clientsReadProcess.running || root.stateFilePath.length === 0)
            return;
        clientsReadProcess.command = ["bash", "-lc", "[ -f \"$1\" ] && cat \"$1\" || true", "bash", root.stateFilePath];
        clientsReadProcess.running = true;
    }

    function setRunning(enabled) {
        if (!root.serviceAvailable || actionProcess.running || configWriteProcess.running)
            return;
        root.lastError = "";
        actionProcess.command = ["systemctl", "--user", enabled ? "start" : "stop", root.serviceUnit];
        actionProcess.running = true;
    }

    function setEnabledOnLogin(enabled) {
        if (!root.serviceAvailable || actionProcess.running || configWriteProcess.running)
            return;
        root.lastError = "";
        actionProcess.command = ["systemctl", "--user", enabled ? "enable" : "disable", root.serviceUnit];
        actionProcess.running = true;
    }

    function restart() {
        if (!root.serviceAvailable || actionProcess.running || configWriteProcess.running)
            return;
        root.lastError = "";
        actionProcess.command = ["systemctl", "--user", "restart", root.serviceUnit];
        actionProcess.running = true;
    }

    function openWebUi() {
        Quickshell.execDetached(["xdg-open", root.webUiUrl]);
    }

    function parseStatus(text) {
        const values = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const separator = lines[i].indexOf("=");
            if (separator <= 0)
                continue;
            values[lines[i].slice(0, separator)] = lines[i].slice(separator + 1);
        }

        root.serviceUnit = values.unit || root.canonicalUnit;
        root.serviceAvailable = Boolean(values.load && values.load !== "not-found");
        root.binaryAvailable = Boolean(values.binary && values.binary.length > 0);
        root.running = values.active === "active" || values.active === "activating";
        root.enabledOnLogin = values.enabled === "enabled" || values.enabled === "enabled-runtime";
        root.refreshing = false;
    }

    function parseAddress(text) {
        const values = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const separator = lines[i].indexOf("=");
            if (separator <= 0)
                continue;
            values[lines[i].slice(0, separator)] = lines[i].slice(separator + 1);
        }
        root.hostName = values.host || "";
        root.hostAddress = values.address || "";
    }

    function parseBool(value, fallback) {
        if (value === undefined || value === null || value === "")
            return fallback;
        const normalized = String(value).trim().toLowerCase();
        return normalized === "enabled" || normalized === "on" || normalized === "true" || normalized === "1" || normalized === "yes";
    }

    function resolveConfigPath(value) {
        if (!value || value.length === 0)
            return root.defaultStatePath;
        if (value.startsWith("/"))
            return value;
        const slash = root.configPath.lastIndexOf("/");
        const base = slash >= 0 ? root.configPath.slice(0, slash) : "";
        return `${base}/${value}`;
    }

    function parseConfig(text) {
        const values = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim();
            if (line.length === 0 || line.startsWith("#"))
                continue;
            const separator = line.indexOf("=");
            if (separator <= 0)
                continue;
            const key = line.slice(0, separator).trim();
            const value = line.slice(separator + 1).trim();
            values[key] = value;
        }

        root.keyboardEnabled = root.parseBool(values.keyboard, true);
        root.mouseEnabled = root.parseBool(values.mouse, true);
        root.controllerEnabled = root.parseBool(values.controller, true);
        root.nativePenTouchEnabled = root.parseBool(values.native_pen_touch, true);
        root.encoder = values.encoder && values.encoder.length > 0 ? values.encoder : "auto";

        const nextStatePath = root.resolveConfigPath(values.file_state || "sunshine_state.json");
        if (nextStatePath !== root.stateFilePath) {
            root.stateFilePath = nextStatePath;
            Qt.callLater(root.refreshClients);
        }
    }

    function parseClients(text) {
        if (!text || text.trim().length === 0) {
            root.pairedClients = [];
            return;
        }

        try {
            const state = JSON.parse(text);
            const devices = state?.root?.named_devices;
            if (!Array.isArray(devices)) {
                root.pairedClients = [];
                return;
            }

            root.pairedClients = devices.map(device => ({
                name: device.name || "Moonlight device",
                uuid: device.uuid || "",
                enabled: device.enabled !== false
            }));
        } catch (error) {
            console.warn("[SunshineService] Could not parse paired clients:", error);
            root.pairedClients = [];
        }
    }

    function setInputOption(key, enabled) {
        const allowed = ["keyboard", "mouse", "controller", "native_pen_touch"];
        if (allowed.indexOf(key) < 0)
            return;
        setConfigOption(key, enabled ? "enabled" : "disabled");
    }

    function setEncoder(value) {
        const allowed = ["auto", "nvenc", "quicksync", "amdvce", "vaapi", "vulkan", "software"];
        if (allowed.indexOf(value) < 0)
            return;
        setConfigOption("encoder", value === "auto" ? "__DELETE__" : value);
    }

    function setConfigOption(key, value) {
        const allowedKeys = ["keyboard", "mouse", "controller", "native_pen_touch", "encoder"];
        if (allowedKeys.indexOf(key) < 0 || configWriteProcess.running || actionProcess.running)
            return;

        root.lastError = "";
        configWriteProcess.command = [
            "bash", "-lc",
            "set -eu; file=\"$1\"; key=\"$2\"; value=\"$3\"; restart=\"$4\"; unit=\"$5\"; mkdir -p \"$(dirname \"$file\")\"; touch \"$file\"; tmp=$(mktemp \"${file}.ii.XXXXXX\"); awk -v key=\"$key\" -v value=\"$value\" 'BEGIN { written=0 } { if ($0 ~ \"^[[:space:]]*\" key \"[[:space:]]*=\") { if (!written && value != \"__DELETE__\") print key \" = \" value; written=1; next } print } END { if (!written && value != \"__DELETE__\") print key \" = \" value }' \"$file\" > \"$tmp\"; cp -a \"$file\" \"${file}.ii-backup\" 2>/dev/null || true; chmod --reference=\"$file\" \"$tmp\" 2>/dev/null || true; mv \"$tmp\" \"$file\"; if [ \"$restart\" = 1 ]; then systemctl --user restart \"$unit\"; fi",
            "bash",
            root.configPath,
            key,
            value,
            root.running ? "1" : "0",
            root.serviceUnit
        ];
        configWriteProcess.running = true;
    }

    Process {
        id: statusProcess
        command: ["bash", "-lc", "unit='app-dev.lizardbyte.app.Sunshine.service'; load=$(systemctl --user show \"$unit\" -p LoadState --value 2>/dev/null || true); if [ -z \"$load\" ] || [ \"$load\" = 'not-found' ]; then unit='sunshine.service'; load=$(systemctl --user show \"$unit\" -p LoadState --value 2>/dev/null || true); fi; active=$(systemctl --user show \"$unit\" -p ActiveState --value 2>/dev/null || true); enabled=$(systemctl --user is-enabled \"$unit\" 2>/dev/null || true); binary=$(command -v sunshine 2>/dev/null || true); printf 'unit=%s\\nload=%s\\nactive=%s\\nenabled=%s\\nbinary=%s\\n' \"$unit\" \"$load\" \"$active\" \"$enabled\" \"$binary\""]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.refreshing = false;
        }
    }

    Process {
        id: addressProcess
        command: ["bash", "-lc", "addr=$(hostname -I 2>/dev/null | tr ' ' '\\n' | grep -E '^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$' | grep -v '^127\\.' | head -n1); printf 'host=%s\\naddress=%s\\n' \"$(hostname 2>/dev/null || true)\" \"$addr\""]
        stdout: StdioCollector {
            onStreamFinished: root.parseAddress(text)
        }
    }

    Process {
        id: configReadProcess
        command: ["bash", "-lc", "[ -f \"$1\" ] && cat \"$1\" || true", "bash", root.configPath]
        stdout: StdioCollector {
            onStreamFinished: root.parseConfig(text)
        }
    }

    Process {
        id: clientsReadProcess
        stdout: StdioCollector {
            onStreamFinished: root.parseClients(text)
        }
    }

    Process {
        id: configWriteProcess
        stderr: SplitParser {
            onRead: line => {
                if (line.trim().length > 0)
                    root.lastError = line.trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.lastError = "";
            Qt.callLater(root.refresh);
        }
    }

    Process {
        id: actionProcess
        stderr: SplitParser {
            onRead: line => {
                if (line.trim().length > 0)
                    root.lastError = line.trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.lastError = "";
            Qt.callLater(root.refresh);
        }
    }
}
