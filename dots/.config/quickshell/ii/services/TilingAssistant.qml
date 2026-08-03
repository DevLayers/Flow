pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Tracks window move and resize gestures so the tiling overlay knows when to
 * appear, and resolves the cursor into a tiling zone on the monitor it is over.
 *
 * The gesture itself is detected by scripts/hyprland/drag_monitor.py, which
 * watches Hyprland far more tightly than a QML timer could. Companion keybinds
 * report Hyprland's own drag binds through the global shortcuts below; the
 * script's motion heuristic covers titlebar drags that never touch a keybind.
 *
 * This phase only observes - nothing is drawn and no window is moved yet.
 */

import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services
import "../modules/common/functions/tiling.js" as Tiling
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var options: Config.options?.tiling ?? null
    readonly property bool enabled: Config.ready && (root.options?.enable ?? false)

    // Gesture state, mirrored from the detector.
    property bool dragging: false
    property string dragKind: ""       // "move" | "resize"
    property string dragSource: ""     // "keybind" | "motion"
    property string dragAddress: ""
    property var dragWindow: null      // geometry captured when the drag started
    property var dragWindowBefore: null // geometry from just before it started, for restoring later
    property int cursorX: 0
    property int cursorY: 0

    signal dragStarted(string kind, string source)
    signal dragMoved(int x, int y)
    signal dragEnded(string kind, int zoneIndex)

    // Hyprland's own gaps, so a tiled window sits exactly where a real one would.
    property int hyprGapsOuter: 5
    property int hyprGapsInner: 4
    readonly property var gaps: {
        const configured = root.options?.gaps ?? null;
        if (configured?.followHyprland ?? true)
            return {
                outer: root.hyprGapsOuter,
                inner: root.hyprGapsInner
            };
        return {
            outer: configured?.outer ?? 8,
            inner: configured?.inner ?? 4
        };
    }

    // The monitor under the cursor, straight from hyprctl so scale, transform
    // and reserved space are all available.
    readonly property var monitor: {
        const monitors = HyprlandData.monitors ?? [];
        for (const candidate of monitors) {
            const rect = Tiling.monitorLogicalRect(candidate);
            if (Tiling.rectContains(rect, root.cursorX, root.cursorY))
                return candidate;
        }
        return monitors.length > 0 ? monitors[0] : null;
    }
    readonly property string monitorName: root.monitor?.name ?? ""
    readonly property var usable: root.monitor ? Tiling.usableArea(root.monitor) : null

    readonly property var zones: root.zonesFor(root.monitorName)
    readonly property var effectiveGaps: root.gapsFor(root.monitorName)
    readonly property var zoneRects: root.usable ? Tiling.zoneRects(root.zones, root.usable, root.effectiveGaps) : []

    readonly property int hoveredZone: {
        if (!root.dragging || !root.usable) return -1;
        return Tiling.zoneIndexAt(root.zones, root.usable, root.cursorX, root.cursorY);
    }

    // The overlay is a move-drag affordance: a resize drag keeps its own
    // neighbours, so painting zone targets over it would only mislead.
    readonly property bool overlayVisible: root.enabled && root.dragging && root.dragKind === "move" && (root.options?.showOnDragStart ?? true)

    function monitorByName(name) {
        const monitors = HyprlandData.monitors ?? [];
        for (const candidate of monitors) {
            if (candidate.name === name) return candidate;
        }
        return null;
    }

    function zonesFor(name) {
        return Tiling.zonesForMonitor(root.options?.monitors, name, root.options?.defaultPreset ?? "kde");
    }

    function gapsFor(name) {
        return Tiling.gapsForMonitor(root.options?.monitors, name, root.gaps);
    }

    // Zones of one monitor as drawable rects, relative to that monitor's own
    // origin. Every coordinate conversion the overlay needs lives here so the
    // overlay itself stays presentational.
    function overlayZonesFor(name) {
        const monitor = root.monitorByName(name);
        if (!monitor) return [];
        const origin = Tiling.monitorLogicalRect(monitor);
        const zones = root.zonesFor(name);
        const rects = Tiling.zoneRects(zones, Tiling.usableArea(monitor), root.gapsFor(name));
        const out = [];
        for (let i = 0; i < rects.length; i++) {
            out.push({
                x: rects[i].x - origin.x,
                y: rects[i].y - origin.y,
                width: rects[i].width,
                height: rects[i].height,
                label: Tiling.labelFor(zones[i])
            });
        }
        return out;
    }

    function zoneLabel(index) {
        if (index < 0 || index >= root.zones.length) return "";
        return Tiling.labelFor(root.zones[index]);
    }

    // Lets a window we move ourselves pass without the heuristic mistaking it
    // for the user dragging it.
    function suppressDetection(milliseconds) {
        root.send({
            cmd: "suppress",
            ms: milliseconds ?? 300
        });
    }

    function send(message) {
        if (!detector.running) return;
        detector.write(`${JSON.stringify(message)}\n`);
    }

    function sendConfig() {
        const detection = root.options?.detection ?? null;
        root.send({
            cmd: "config",
            idleHz: detection?.idleHz ?? 30,
            activeHz: detection?.activeHz ?? 90,
            tolerance: detection?.trackingTolerancePx ?? 2,
            motion: detection?.useMotionHeuristic ?? true,
            keybinds: detection?.useKeybinds ?? true
        });
    }

    function handleEvent(event) {
        switch (event.event) {
        case "ready":
            root.sendConfig();
            break;
        case "gaps":
            root.hyprGapsOuter = event.outer;
            root.hyprGapsInner = event.inner;
            break;
        case "dragStart":
            root.cursorX = event.x;
            root.cursorY = event.y;
            root.dragAddress = event.address ?? "";
            root.dragWindow = event.window ?? null;
            root.dragWindowBefore = event.before ?? event.window ?? null;
            root.dragKind = event.kind;
            root.dragSource = event.source;
            root.dragging = true;
            root.dragStarted(event.kind, event.source);
            break;
        case "dragMove":
            root.cursorX = event.x;
            root.cursorY = event.y;
            root.dragMoved(event.x, event.y);
            break;
        case "dragEnd":
            root.cursorX = event.x;
            root.cursorY = event.y;
            const zone = root.hoveredZone;
            root.dragging = false;
            root.dragEnded(event.kind, zone);
            root.dragKind = "";
            root.dragSource = "";
            break;
        }
    }

    // Reconfiguring is cheap, so the detector is told about setting changes
    // rather than being restarted.
    readonly property string detectionKey: {
        const detection = root.options?.detection ?? null;
        return [detection?.idleHz, detection?.activeHz, detection?.trackingTolerancePx, detection?.useMotionHeuristic, detection?.useKeybinds].join("|");
    }
    onDetectionKeyChanged: root.sendConfig()

    onEnabledChanged: {
        if (root.enabled) return;
        root.dragging = false;
        root.dragKind = "";
        root.dragSource = "";
    }

    Process {
        id: detector
        running: root.enabled
        stdinEnabled: true
        command: ProcUtils.pdeath(["python3", Quickshell.shellPath("scripts/hyprland/drag_monitor.py")])

        stdout: SplitParser {
            onRead: line => {
                if (!line || line.length === 0) return;
                try {
                    root.handleEvent(JSON.parse(line));
                } catch (error) {
                    console.warn("[TilingAssistant] bad event:", error.message);
                }
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line && line.length > 0) console.log("[TilingAssistant]", line);
            }
        }

        // Exiting clears `running` imperatively, which drops the binding above,
        // so a detector that dies would otherwise stay dead until a reload.
        onExited: (code, status) => {
            if (!root.enabled) return;
            console.log("[TilingAssistant] detector exited with", code, "- restarting");
            detectorRestart.restart();
        }
    }

    Timer {
        id: detectorRestart
        interval: 2000
        onTriggered: detector.running = Qt.binding(() => root.enabled)
    }

    // Hyprland's drag binds fire these alongside their own dispatcher, which is
    // the only exact signal for "the user grabbed a window".
    Loader {
        active: root.enabled && (root.options?.detection?.useKeybinds ?? true)

        sourceComponent: Item {
            GlobalShortcut {
                name: "tilingDragMove"
                description: "Reports a window move drag to the tiling assistant"
                onPressed: root.send({
                    cmd: "hint",
                    kind: "move",
                    state: "down"
                })
                onReleased: root.send({
                    cmd: "hint",
                    kind: "move",
                    state: "up"
                })
            }

            GlobalShortcut {
                name: "tilingDragResize"
                description: "Reports a window resize drag to the tiling assistant"
                onPressed: root.send({
                    cmd: "hint",
                    kind: "resize",
                    state: "down"
                })
                onReleased: root.send({
                    cmd: "hint",
                    kind: "resize",
                    state: "up"
                })
            }
        }
    }
}
