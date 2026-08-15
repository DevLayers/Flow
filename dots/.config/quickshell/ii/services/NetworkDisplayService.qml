pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

Singleton {
    id: root

    // ── Public Properties ───────────────────────────────────────────────────
    readonly property string bridgePath: Directories.networkDisplayBridgePath
    property bool bridgeAvailable: false
    property bool backendInstalled: false
    property bool managerAvailable: false
    property bool backendOwnedByShell: false
    readonly property bool discoveryActive: managerWatchProcess.running

    property var displays: []
    readonly property var filteredDisplays: {
        if (!displays || displays.length === 0)
            return [];
        return displays.filter(d => root.protocolEnabled(d.protocol));
    }

    // Session states: "Idle", "Selecting", "Starting", "SessionActive", "Stopping", "Error"
    property string sessionState: "Idle"
    property string activeSinkUuid: ""
    property string activeSinkName: ""
    property string activeStreamUnit: ""
    property string lastError: ""

    property var diagnostics: null

    // ── Helper protocol label & filter ──────────────────────────────────────
    function protocolLabel(protocol) {
        switch (protocol) {
        case "miracastP2p":
            return Translation.tr("Miracast · Wi-Fi Direct");
        case "miracastMice":
            return Translation.tr("Miracast · Network");
        case "chromecast":
            return Translation.tr("Chromecast");
        default:
            return Translation.tr("Wireless display");
        }
    }

    function protocolEnabled(protocol) {
        if (!Config.ready || !Config.options.displayCast)
            return true;
        switch (protocol) {
        case "miracastP2p":
            return Config.options.displayCast.showMiracastP2p ?? true;
        case "miracastMice":
            return Config.options.displayCast.showMiracastMice ?? true;
        case "chromecast":
            return Config.options.displayCast.showChromecast ?? true;
        default:
            return true;
        }
    }

    // ── Lifecycle & Backend Management ──────────────────────────────────────
    Component.onCompleted: {
        checkBridgeAndBackend();
    }

    Component.onDestruction: {
        if (root.activeStreamUnit !== "") {
            root.disconnect();
        }
        if (root.backendOwnedByShell && daemonProcess.running) {
            daemonProcess.running = false;
        }
    }

    property bool isCompiling: compileBridgeProcess.running

    function checkBridgeAndBackend() {
        runDiagnostics();
    }

    function ensureBackend() {
        idleTimer.stop();
        if (!managerWatchProcess.running) {
            startDiscovery();
        }
        if (!root.managerAvailable && root.backendInstalled && !daemonProcess.running) {
            console.log("[NetworkDisplayService] Spawning GNOME Network Displays background service");
            root.backendOwnedByShell = true;
            if (root.diagnostics && root.diagnostics.backend && root.diagnostics.backend.daemonPath && root.diagnostics.backend.daemonPath.startsWith("flatpak:")) {
                daemonProcess.command = ["flatpak", "run", "org.gnome.NetworkDisplays", "--gapplication-service"];
            } else if (root.diagnostics && root.diagnostics.backend && root.diagnostics.backend.daemonPath) {
                if (root.diagnostics.backend.daemonPath.indexOf("daemon") !== -1) {
                    daemonProcess.command = [root.diagnostics.backend.daemonPath];
                } else {
                    daemonProcess.command = [root.diagnostics.backend.daemonPath, "--gapplication-service"];
                }
            } else {
                daemonProcess.command = ["gnome-network-displays-daemon"];
            }
            daemonProcess.running = true;
        }
    }

    function deleteBridge() {
        deleteBridgeProcess.running = true;
    }

    function compileBridge() {
        const srcPath = Directories.scriptPath + "/networkDisplays/network_display_bridge_src";
        compileBridgeProcess.command = [
            "bash", "-c",
            "cargo build --release --manifest-path \"" + srcPath + "/Cargo.toml\" && install -m 755 \"" + srcPath + "/target/release/network_display_bridge\" \"" + root.bridgePath + "\""
        ];
        compileBridgeProcess.running = true;
    }

    function launchBackendApp() {
        if (root.diagnostics && root.diagnostics.backend && root.diagnostics.backend.daemonPath && root.diagnostics.backend.daemonPath.startsWith("flatpak:")) {
            launchAppProcess.command = ["flatpak", "run", "org.gnome.NetworkDisplays"];
        } else if (root.diagnostics && root.diagnostics.backend && root.diagnostics.backend.daemonPath) {
            launchAppProcess.command = [root.diagnostics.backend.daemonPath];
        } else {
            launchAppProcess.command = ["gnome-network-displays"];
        }
        launchAppProcess.running = true;
    }

    function startDiscovery() {
        idleTimer.stop();
        if (!managerWatchProcess.running) {
            managerWatchProcess.command = [root.bridgePath, "manager-watch"];
            managerWatchProcess.running = true;
        }
    }

    function stopDiscovery() {
        if (managerWatchProcess.running) {
            managerWatchProcess.running = false;
        }
    }

    Timer {
        id: idleTimer
        interval: 10000 // 10s grace period
        repeat: false
        onTriggered: {
            if (!GlobalStates.displayCastOpen && root.activeStreamUnit === "" && root.sessionState === "Idle") {
                console.log("[NetworkDisplayService] Idle grace expired, shutting down discovery/daemon");
                root.stopDiscovery();
                if (root.backendOwnedByShell && daemonProcess.running) {
                    daemonProcess.running = false;
                    root.backendOwnedByShell = false;
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onDisplayCastOpenChanged() {
            if (GlobalStates.displayCastOpen) {
                root.ensureBackend();
            } else {
                if (root.activeStreamUnit === "" && (!Config.options.displayCast || Config.options.displayCast.stopBackendWhenIdle !== false)) {
                    idleTimer.restart();
                }
            }
        }
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked && GlobalStates.displayCastOpen) {
                GlobalStates.displayCastOpen = false;
            }
        }
    }

    // ── Connect & Disconnect Actions ────────────────────────────────────────
    function connectTo(uuid) {
        if (root.sessionState !== "Idle" && root.sessionState !== "Error") {
            console.log("[NetworkDisplayService] Cannot connect: session busy (state:", root.sessionState, ")");
            return;
        }

        const sink = root.displays.find(d => d.uuid === uuid);
        root.activeSinkUuid = uuid;
        root.activeSinkName = sink ? sink.name : uuid;
        root.lastError = "";
        root.sessionState = "Selecting";

        startStreamProcess.command = [root.bridgePath, "start", uuid];
        startStreamProcess.running = true;
    }

    function disconnect() {
        if (root.activeStreamUnit === "") {
            root.sessionState = "Idle";
            root.activeSinkUuid = "";
            root.activeSinkName = "";
            return;
        }

        root.sessionState = "Stopping";
        stopStreamProcess.command = [root.bridgePath, "stop", root.activeStreamUnit];
        stopStreamProcess.running = true;
    }

    function resetError() {
        root.lastError = "";
        if (root.sessionState === "Error" && root.activeStreamUnit === "") {
            root.sessionState = "Idle";
            root.activeSinkUuid = "";
            root.activeSinkName = "";
        }
    }

    function runDiagnostics() {
        diagnoseProcess.command = [root.bridgePath, "diagnose"];
        diagnoseProcess.running = true;
    }

    // ── Event Handlers ──────────────────────────────────────────────────────
    function handleManagerEvent(line) {
        let text = line.trim();
        if (!text || text.length === 0)
            return;

        try {
            let msg = JSON.parse(text);
            switch (msg.type) {
            case "bridgeReady":
                root.bridgeAvailable = true;
                break;
            case "managerAvailable":
                root.managerAvailable = true;
                break;
            case "managerUnavailable":
                root.managerAvailable = false;
                root.displays = [];
                break;
            case "displaysSnapshot":
                root.displays = (msg.displays || []).map(d => ({
                    uuid: d.uuid,
                    name: d.name,
                    protocol: d.protocol,
                    protocolLabel: root.protocolLabel(d.protocol),
                    priority: d.priority,
                    backendState: d.state,
                    isActive: (d.uuid === root.activeSinkUuid && (root.sessionState === "SessionActive" || root.sessionState === "Starting")),
                    isStarting: (d.uuid === root.activeSinkUuid && (root.sessionState === "Selecting" || root.sessionState === "Starting"))
                }));
                break;
            default:
                break;
            }
        } catch (e) {
            console.log("[NetworkDisplayService] Error parsing manager event JSON:", e, "Line:", text);
        }
    }

    function handleUnitEvent(line) {
        let text = line.trim();
        if (!text || text.length === 0)
            return;

        try {
            let msg = JSON.parse(text);
            if (msg.type === "unitState") {
                let act = (msg.activeState || "").toLowerCase();
                let sub = (msg.subState || "").toLowerCase();

                if (act === "active" || sub === "running") {
                    root.sessionState = "SessionActive";
                } else if (act === "activating" || sub === "start") {
                    root.sessionState = "Starting";
                } else if (act === "failed" || sub === "failed") {
                    root.sessionState = "Error";
                    root.lastError = Translation.tr("Stream unit failed: %1").arg(sub);
                    root.activeStreamUnit = "";
                    root.activeSinkUuid = "";
                } else if (act === "inactive" || act === "deactivating" || sub === "dead") {
                    if (root.sessionState === "Stopping" || root.sessionState === "SessionActive" || root.sessionState === "Starting") {
                        root.sessionState = "Idle";
                        root.activeStreamUnit = "";
                        root.activeSinkUuid = "";
                        root.activeSinkName = "";
                    }
                }
            }
        } catch (e) {
            console.log("[NetworkDisplayService] Error parsing unit event JSON:", e, "Line:", text);
        }
    }

    // ── Processes ───────────────────────────────────────────────────────────
    Process {
        id: daemonProcess
        command: ["gnome-network-displays-daemon"]
        onExited: (code, status) => {
            console.log("[NetworkDisplayService] Daemon exited with code:", code);
            root.backendOwnedByShell = false;
        }
    }

    Process {
        id: managerWatchProcess
        stdout: SplitParser {
            onRead: line => root.handleManagerEvent(line)
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.trim().length > 0)
                    console.log("[NetworkDisplayService bridge stderr]", line);
            }
        }
        onExited: (code, status) => {
            root.managerAvailable = false;
        }
    }

    Process {
        id: startStreamProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let res = JSON.parse(text.trim());
                    if (res.ok && res.streamUnit) {
                        root.activeStreamUnit = res.streamUnit;
                        root.sessionState = "SessionActive";

                        if (res.streamUnit.indexOf(".service") !== -1 || res.streamUnit.indexOf(".scope") !== -1) {
                            unitWatchProcess.command = [root.bridgePath, "unit-watch", res.streamUnit];
                            unitWatchProcess.running = true;
                        }
                    } else {
                        root.sessionState = "Error";
                        root.lastError = res.message || res.error || Translation.tr("Could not start cast");
                        root.activeStreamUnit = "";
                        root.activeSinkUuid = "";
                    }
                } catch (e) {
                    console.log("[NetworkDisplayService] Error parsing startStream response:", e, "Text:", text);
                    root.sessionState = "Error";
                    root.lastError = Translation.tr("Invalid response from bridge");
                }
            }
        }
    }

    Process {
        id: stopStreamProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.sessionState = "Idle";
                root.activeStreamUnit = "";
                root.activeSinkUuid = "";
                root.activeSinkName = "";
            }
        }
        onExited: {
            root.sessionState = "Idle";
            root.activeStreamUnit = "";
            root.activeSinkUuid = "";
            root.activeSinkName = "";
        }
    }

    Process {
        id: unitWatchProcess
        stdout: SplitParser {
            onRead: line => root.handleUnitEvent(line)
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.trim().length > 0)
                    console.log("[NetworkDisplayService unit-watch stderr]", line);
            }
        }
    }

    Process {
        id: diagnoseProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let rep = JSON.parse(text.trim());
                    root.diagnostics = rep;
                    root.bridgeAvailable = rep.bridge ? rep.bridge.ok : false;
                    root.backendInstalled = rep.backend ? rep.backend.daemonBinary : false;
                    if (rep.backend && rep.backend.managerBus) {
                        root.managerAvailable = true;
                    }
                } catch (e) {
                    console.log("[NetworkDisplayService] Error parsing diagnose JSON:", e);
                }
            }
        }
    }

    Process {
        id: launchAppProcess
    }

    Process {
        id: compileBridgeProcess
        onRunningChanged: if (!running) {
            root.runDiagnostics();
        }
    }

    Process {
        id: deleteBridgeProcess
        command: ["rm", "-f", root.bridgePath]
        onRunningChanged: if (!running) {
            root.runDiagnostics();
        }
    }
}
