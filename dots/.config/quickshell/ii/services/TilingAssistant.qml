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
 * On drop the window is floated and given the zone's exact geometry, and the
 * geometry it had before is kept so dragging it back out can undo that. The
 * same thing happens without the mouse through the quick-tile shortcuts below.
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
    // Hyprland reports and accepts window geometry without the border, so zone
    // rects have to lose it. Taken from the shell rather than from Hyprland,
    // because the shell is what pushes the value and Hyprland briefly reports
    // the config file's own number after a reload.
    readonly property int hyprBorderSize: Appearance.borderless ? 0 : (Appearance.borderWidth ?? 0)
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

    // ------------------------------------------------------------ applying

    // "quickTile" | "preview" | "hybrid"
    readonly property string mode: root.options?.mode ?? "quickTile"

    // Where each window we tiled came from, keyed by address. Only windows this
    // service moved are in here, so nothing else can be "restored" out of a
    // position the user put it in themselves.
    property var tileRecords: ({})

    // Which zone each window was last put in. Hyprland emits no event when a
    // floating window is moved or resized, so the shared window list keeps
    // reporting the previous geometry indefinitely after a quick-tile - it is
    // only refreshed by events like a float toggle. Remembering the zone is
    // therefore the only way a second arrow press can resolve from where the
    // window actually is.
    property var zoneMemory: ({})

    // Zone rects as windows rather than as boxes: Hyprland positions and sizes a
    // window inside its border, so the border comes off every side.
    function windowRectForZone(name, index) {
        const monitor = root.monitorByName(name);
        const zones = root.zonesFor(name);
        if (!monitor || index < 0 || index >= zones.length) return null;
        const box = Tiling.zoneRect(zones[index], Tiling.usableArea(monitor), root.gapsFor(name));
        const rect = Tiling.insetRect(box, root.hyprBorderSize);
        return (rect.width > 0 && rect.height > 0) ? rect : null;
    }

    // Whether a geometry sample is already sitting in one of that monitor's
    // zones. Growing it by the border undoes the inset above, putting it back in
    // the same space the zone boxes are measured in.
    function sampleZoneIndex(name, sample) {
        const monitor = root.monitorByName(name);
        if (!monitor || !sample) return -1;
        const rect = Tiling.makeRect(sample.x, sample.y, sample.width, sample.height);
        const grown = Tiling.insetRect(rect, -root.hyprBorderSize);
        const usable = Tiling.usableArea(monitor);
        return Tiling.zoneIndexForRect(root.zonesFor(name), usable, root.gapsFor(name), grown, 4);
    }

    // Hyprland's float dispatcher is a toggle and takes no target state, so the
    // current state decides whether to flip it. Callers pass what they know -
    // the pre-drag sample beats the shared window list, which can be a refresh
    // behind - and an unknown state is left alone rather than guessed at.
    function setFloating(address, floating, current) {
        const known = current ?? HyprlandData.windowByAddress?.[address]?.floating;
        if (known === undefined || known === floating) return;
        root.dispatchWindow(address, "float");
    }

    function dispatchWindow(address, dispatcher, args) {
        const call = [`window = "address:${address}"`].concat(args ?? []).join(", ");
        Hyprland.dispatch(`hl.dsp.window.${dispatcher}({${call}})`);
    }

    function applyZone(address, name, index, before, floating) {
        const rect = root.windowRectForZone(name, index);
        if (!rect) return;

        // A window already floating in a zone is one of ours from before a
        // reload: its geometry says nothing about where it came from, so it goes
        // unrecorded rather than recorded uselessly. One the layout put there is
        // a different matter - restoring it means handing it back to the layout.
        const ours = (before?.floating ?? false) && root.sampleZoneIndex(name, before) >= 0;
        if (!root.tileRecords[address] && before && !ours) {
            root.tileRecords[address] = {
                x: before.x,
                y: before.y,
                width: before.width,
                height: before.height,
                floating: before.floating ?? false
            };
        }

        root.zoneMemory[address] = {
            monitor: name,
            index: index
        };

        root.suppressDetection(500);
        root.setFloating(address, true, floating);
        // Resizing keeps the centre, so the move has to come second.
        root.dispatchWindow(address, "resize", [`x = ${rect.width}`, `y = ${rect.height}`]);
        root.dispatchWindow(address, "move", [`x = ${rect.x}`, `y = ${rect.y}`]);
    }

    function restoreWindow(address, floating) {
        const record = root.tileRecords[address];
        delete root.zoneMemory[address];
        if (!record) return;
        delete root.tileRecords[address];

        root.suppressDetection(500);
        if (!record.floating) {
            // Back into the layout tree, which decides the geometry itself.
            root.setFloating(address, false, floating);
            return;
        }
        root.setFloating(address, true, floating);
        root.dispatchWindow(address, "resize", [`x = ${record.width}`, `y = ${record.height}`]);
        root.dispatchWindow(address, "move", [`x = ${record.x}`, `y = ${record.y}`]);
    }

    // Closed windows would otherwise pile up in the record map for the lifetime
    // of the shell.
    function pruneRecords() {
        const known = HyprlandData.windowByAddress ?? {};
        // An empty list means the window data has not arrived, not that every
        // window closed at once.
        if (Object.keys(known).length === 0) return;
        for (const address in root.tileRecords) {
            if (!known[address]) delete root.tileRecords[address];
        }
        for (const address in root.zoneMemory) {
            if (!known[address]) delete root.zoneMemory[address];
        }
    }

    function handleDrop(kind, zoneIndex) {
        if (kind !== "move" || root.mode === "preview") return;
        const address = root.dragAddress;
        if (!address) return;
        const before = root.dragWindowBefore;
        // Hyprland floats a tiled window for the duration of a drag and puts it
        // back on release, so the sample from *before* the drag is the one that
        // describes the window now that the drag is over.
        const floating = before?.floating;

        // Nothing under the cursor: the window was dragged out of its zone, so
        // put it back the way it was found.
        if (zoneIndex < 0) {
            delete root.zoneMemory[address];
            if (root.options?.restoreOnUntile ?? true) root.restoreWindow(address, floating);
            return;
        }
        // Hybrid leaves windows that live in the layout tree to Hyprland and
        // only quick-tiles ones that were already floating.
        if (root.mode === "hybrid" && !(before?.floating ?? false) && !root.tileRecords[address]) return;

        root.applyZone(address, root.monitorName, zoneIndex, before, floating);
    }

    onDragStarted: root.pruneRecords()
    onDragEnded: (kind, zoneIndex) => root.handleDrop(kind, zoneIndex)

    // ------------------------------------------------------------ keyboard

    readonly property bool keyboardEnabled: root.enabled && (root.options?.keyboardQuickTile ?? true)

    // Hyprland numbers windows by how recently they were focused, so the one at
    // zero is the focused one. Taking it out of the shared list beats asking
    // hyprctl for the active window: no extra process, and the geometry that
    // comes with it is the same snapshot the zone helpers work from.
    function focusedWindow() {
        const windows = HyprlandData.windowList ?? [];
        for (const window of windows) {
            if (window.focusHistoryID === 0) return window;
        }
        return null;
    }

    function monitorById(id) {
        const monitors = HyprlandData.monitors ?? [];
        for (const candidate of monitors) {
            if (candidate.id === id) return candidate;
        }
        return null;
    }

    // A raw hyprctl client in the shape the zone helpers expect.
    function windowSample(window) {
        if (!window) return null;
        return {
            x: window.at?.[0] ?? 0,
            y: window.at?.[1] ?? 0,
            width: window.size?.[0] ?? 0,
            height: window.size?.[1] ?? 0,
            floating: window.floating ?? false
        };
    }

    // Remembered zone first, geometry only as a fallback: see zoneMemory. A
    // window back in the layout tree is in no zone whatever we remember, and
    // float state - unlike geometry - does come with an event.
    function currentZone(address, name, sample) {
        const remembered = root.zoneMemory[address];
        if (remembered) {
            if (!(sample?.floating ?? false)) delete root.zoneMemory[address];
            else if (remembered.monitor === name) return remembered.index;
        }
        return root.sampleZoneIndex(name, sample);
    }

    // Tiles the focused window one zone over. Unlike a drag, this is explicit
    // enough to act on a window living in the layout tree even in hybrid mode,
    // which has no preview of its own to fall back on.
    function quickTile(direction) {
        if (!root.keyboardEnabled || root.mode === "preview") return;
        const window = root.focusedWindow();
        if (!window) return;
        const name = root.monitorById(window.monitor)?.name ?? "";
        const zones = root.zonesFor(name);
        if (!name || zones.length === 0) return;

        const address = window.address;
        const sample = root.windowSample(window);
        const from = root.currentZone(address, name, sample);
        const target = (from < 0) ? Tiling.edgeZoneIndex(zones, direction) : Tiling.resolveDirection(zones, from, direction);
        if (target < 0) return;

        // Nowhere further that way. Down is the way back out: once a window is
        // at the bottom of the layout there is nothing below to want instead.
        if (target === from) {
            if (Tiling.normalizeDirection(direction) === "down" && (root.options?.restoreOnUntile ?? true))
                root.restoreWindow(address, sample.floating);
            return;
        }
        root.applyZone(address, name, target, sample, sample.floating);
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

    // Quick-tile without the mouse. Bound to SUPER + ALT + arrow, which leaves
    // SUPER + SHIFT + arrow to Hyprland's own move-in-direction.
    Loader {
        active: root.keyboardEnabled

        // Instantiator rather than a Repeater inside an Item: a shortcut is not
        // an item and has nothing to be laid out in.
        sourceComponent: Instantiator {
            model: ["Left", "Right", "Up", "Down"]

            delegate: GlobalShortcut {
                required property string modelData
                name: `tilingTile${modelData}`
                description: `Quick-tiles the focused window ${modelData.toLowerCase()}`
                onPressed: root.quickTile(modelData.toLowerCase())
            }
        }
    }
}
