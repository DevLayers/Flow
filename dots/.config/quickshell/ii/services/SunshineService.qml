pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property string canonicalUnit: "app-dev.lizardbyte.app.Sunshine.service"
    readonly property string webUiUrl: "https://localhost:47990"

    property string serviceUnit: canonicalUnit
    property bool serviceAvailable: false
    property bool binaryAvailable: false
    readonly property bool installed: serviceAvailable || binaryAvailable
    property bool running: false
    property bool enabledOnLogin: false
    property bool refreshing: false
    readonly property bool actionRunning: actionProcess.running
    property string hostAddress: ""
    property string lastError: ""

    Component.onCompleted: refresh()

    function refresh() {
        if (!statusProcess.running) {
            root.refreshing = true;
            statusProcess.running = true;
        }
        if (!addressProcess.running)
            addressProcess.running = true;
    }

    function setRunning(enabled) {
        if (!root.serviceAvailable || actionProcess.running)
            return;
        root.lastError = "";
        actionProcess.command = ["systemctl", "--user", enabled ? "start" : "stop", root.serviceUnit];
        actionProcess.running = true;
    }

    function setEnabledOnLogin(enabled) {
        if (!root.serviceAvailable || actionProcess.running)
            return;
        root.lastError = "";
        actionProcess.command = ["systemctl", "--user", enabled ? "enable" : "disable", root.serviceUnit];
        actionProcess.running = true;
    }

    function restart() {
        if (!root.serviceAvailable || actionProcess.running)
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
        command: ["bash", "-lc", "hostname -I 2>/dev/null | tr ' ' '\\n' | grep -E '^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$' | grep -v '^127\\.' | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.hostAddress = text.trim()
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
