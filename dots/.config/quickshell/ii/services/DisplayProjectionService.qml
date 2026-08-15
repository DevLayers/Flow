pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.modules.common
import qs.services

Singleton {
    id: root

    // ── Properties ──────────────────────────────────────────────────────────
    property var monitors: []
    readonly property int monitorCount: root.monitors.length
    readonly property bool isMultiMonitor: root.monitors.length > 1

    property bool hasSnapshot: false
    property var layoutSnapshot: null
    property string explicitCurrentMode: ""

    Component.onCompleted: {
        fetchMonitors();
    }

    function fetchMonitors() {
        fetchMonitorsProc.running = true;
    }

    Process {
        id: fetchMonitorsProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => ({
                        id: m.id !== undefined ? m.id : -1,
                        name: m.name,
                        description: m.description || "",
                        make: m.make || "",
                        model: m.model || "",
                        serial: m.serial || "",
                        width: m.width,
                        height: m.height,
                        refreshRate: m.refreshRate,
                        x: m.x,
                        y: m.y,
                        scale: (m.scale !== undefined && m.scale !== null) ? m.scale : 1.0,
                        transform: (m.transform !== undefined && m.transform !== null) ? m.transform : 0,
                        disabled: Boolean(m.disabled),
                        focused: Boolean(m.focused),
                        availableModes: m.availableModes || [],
                        mirrorOf: (m.mirrorOf && m.mirrorOf !== "none") ? m.mirrorOf : ""
                    }));
                    root.explicitCurrentMode = "";
                } catch (e) {
                    console.log("[DisplayProjectionService] Error parsing monitors:", e);
                }
            }
        }
    }

    Timer {
        id: delayedFetchTimer
        interval: 350
        repeat: false
        onTriggered: {
            root.fetchMonitors();
        }
    }

    Timer {
        id: closeTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (Config.options.displayCast && Config.options.displayCast.closeAfterProjectionChange) {
                GlobalStates.closeDisplayCast();
            }
        }
    }

    // ── Primary Monitor Resolution ──────────────────────────────────────────
    readonly property string preferredSetting: (Config.options && Config.options.displayCast && Config.options.displayCast.preferredProjectionMonitor) ? Config.options.displayCast.preferredProjectionMonitor : "auto"

    readonly property var primaryMonitor: {
        if (!root.monitors || root.monitors.length === 0)
            return null;

        if (root.preferredSetting !== "auto" && root.preferredSetting !== "") {
            let found = root.monitors.find(m => m.name === root.preferredSetting);
            if (found)
                return found;
        }

        // Search for laptop/internal displays (eDP, LVDS, DSI)
        let internal = root.monitors.find(m => {
            let n = (m.name || "").toLowerCase();
            return n.startsWith("edp") || n.startsWith("lvds") || n.startsWith("dsi");
        });
        if (internal)
            return internal;

        // Otherwise focused monitor
        let focused = root.monitors.find(m => m.focused);
        if (focused)
            return focused;

        return root.monitors[0];
    }

    readonly property string primaryMonitorName: root.primaryMonitor ? root.primaryMonitor.name : ""

    readonly property var externalMonitors: {
        if (!root.monitors || root.monitors.length <= 1)
            return [];
        return root.monitors.filter(m => m.name !== root.primaryMonitorName);
    }

    readonly property bool hasExternalMonitors: root.externalMonitors.length > 0

    // ── Current Mode Detection ──────────────────────────────────────
    // Modes: "primaryOnly", "duplicate", "extend", "externalOnly", "custom"
    readonly property string computedMode: {
        if (root.monitors.length <= 1)
            return "primaryOnly";

        const primary = root.primaryMonitor;
        const externals = root.externalMonitors;

        const isPrimaryActive = primary && !primary.disabled;
        const activeExternals = externals.filter(m => !m.disabled);

        if (!isPrimaryActive && activeExternals.length > 0)
            return "externalOnly";

        if (isPrimaryActive && activeExternals.length === 0)
            return "primaryOnly";

        // Check if all active externals mirror the primary (by name or by ID)
        const allMirrored = activeExternals.length > 0 && activeExternals.every(m => {
            if (!m.mirrorOf || m.mirrorOf === "none" || m.mirrorOf === "")
                return false;
            if (!primary)
                return true;
            return m.mirrorOf === primary.name || (primary.id !== undefined && m.mirrorOf === String(primary.id)) || (primary.id !== undefined && m.mirrorOf === primary.id);
        });
        if (allMirrored)
            return "duplicate";

        if (isPrimaryActive && activeExternals.length > 0)
            return "extend";

        return "custom";
    }

    readonly property string currentMode: root.explicitCurrentMode !== "" ? root.explicitCurrentMode : root.computedMode

    // ── Snapshot Management ─────────────────────────────────────────────────
    function takeSnapshotIfNeeded() {
        if (!root.hasSnapshot && root.monitors.length > 0) {
            root.layoutSnapshot = JSON.parse(JSON.stringify(root.monitors));
            root.hasSnapshot = true;
            HyprmonService.saveProfile("__ii_display_cast_previous__", root.layoutSnapshot);
        }
    }

    function clearSnapshot() {
        root.hasSnapshot = false;
        root.layoutSnapshot = null;
    }

    function restoreSnapshot() {
        if (root.hasSnapshot && root.layoutSnapshot) {
            root.monitors = JSON.parse(JSON.stringify(root.layoutSnapshot));
            root.explicitCurrentMode = "extend";
            HyprmonService.saveAndApplyProfile("__quickshell_live__", root.layoutSnapshot);
            root.clearSnapshot();
            delayedFetchTimer.restart();
            closeTimer.restart();
            return true;
        }
        if (HyprmonService.profileExists("__ii_display_cast_previous__")) {
            HyprmonService.applyProfile("__ii_display_cast_previous__");
            root.clearSnapshot();
            delayedFetchTimer.restart();
            closeTimer.restart();
            return true;
        }
        return false;
    }

    // ── Projection Actions ──────────────────────────────────────────────────
    function applyPrimaryOnly() {
        if (root.monitors.length === 0)
            return;
        root.takeSnapshotIfNeeded();

        const transformed = root.monitors.map(m => {
            let copy = Object.assign({}, m);
            if (m.name === root.primaryMonitorName) {
                copy.disabled = false;
                copy.mirrorOf = "";
                copy.x = 0;
                copy.y = 0;
            } else {
                copy.disabled = true;
                copy.mirrorOf = "";
            }
            return copy;
        });

        root.monitors = transformed;
        root.explicitCurrentMode = "primaryOnly";
        HyprmonService.saveAndApplyProfile("__quickshell_live__", transformed);
        delayedFetchTimer.restart();
        closeTimer.restart();
    }

    function applyDuplicate() {
        if (root.monitors.length <= 1)
            return;
        root.takeSnapshotIfNeeded();

        const primary = root.primaryMonitor;
        const transformed = root.monitors.map(m => {
            let copy = Object.assign({}, m);
            if (m.name === root.primaryMonitorName) {
                copy.disabled = false;
                copy.mirrorOf = "";
                copy.x = 0;
                copy.y = 0;
            } else {
                copy.disabled = false;
                copy.mirrorOf = primary ? primary.name : "";
                copy.x = 0;
                copy.y = 0;
            }
            return copy;
        });

        root.monitors = transformed;
        root.explicitCurrentMode = "duplicate";
        HyprmonService.saveAndApplyProfile("__quickshell_live__", transformed);
        delayedFetchTimer.restart();
        closeTimer.restart();
    }

    function applyExtend() {
        if (root.monitors.length <= 1)
            return;

        if (root.restoreSnapshot()) {
            return;
        }

        let currentX = 0;
        const transformed = root.monitors.map(m => {
            let copy = Object.assign({}, m);
            copy.disabled = false;
            copy.mirrorOf = "";
            copy.x = currentX;
            copy.y = 0;
            let logW = Math.round(m.width / (m.scale || 1.0));
            currentX += logW;
            return copy;
        });

        root.monitors = transformed;
        root.explicitCurrentMode = "extend";
        HyprmonService.saveAndApplyProfile("__quickshell_live__", transformed);
        delayedFetchTimer.restart();
        closeTimer.restart();
    }

    function applyExternalOnly() {
        if (root.monitors.length <= 1 || !root.hasExternalMonitors)
            return;
        root.takeSnapshotIfNeeded();

        let firstExternal = true;
        const transformed = root.monitors.map(m => {
            let copy = Object.assign({}, m);
            if (m.name === root.primaryMonitorName) {
                copy.disabled = true;
                copy.mirrorOf = "";
            } else {
                if (firstExternal) {
                    copy.disabled = false;
                    copy.mirrorOf = "";
                    copy.x = 0;
                    copy.y = 0;
                    firstExternal = false;
                } else {
                    copy.disabled = false;
                    copy.mirrorOf = "";
                }
            }
            return copy;
        });

        root.monitors = transformed;
        root.explicitCurrentMode = "externalOnly";
        HyprmonService.saveAndApplyProfile("__quickshell_live__", transformed);
        delayedFetchTimer.restart();
        closeTimer.restart();
    }
}
