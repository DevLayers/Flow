pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Tracks window move and resize gestures so the tiling overlay knows when to
 * appear, and resolves the cursor into a tiling zone on the monitor it is over.
 *
 * The gesture itself is detected by scripts/hyprland/drag_monitor.py, which
 * watches Hyprland far more tightly than a QML timer could. It knows about a
 * drag only through the companion keybinds below, which report Hyprland's own
 * drag binds - so a client-side titlebar drag, which fires no bind, is not a
 * gesture this reacts to at all. See the script's header for why.
 *
 * On drop the window is floated and given the zone's exact geometry, and the
 * geometry it had before is kept so dragging it back out can undo that. The
 * same thing happens without the mouse through the quick-tile shortcuts below.
 *
 * Resizing a tiled window past its zone drags the divider it shares with its
 * neighbours instead of overlapping them, and they follow.
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
    property string dragAddress: ""
    property var dragWindow: null      // geometry captured when the drag started
    property var dragWindowBefore: null // geometry from just before it started, for restoring later
    property var dragWindowAfter: null  // geometry as it ended, for co-resize
    property int cursorX: 0
    property int cursorY: 0

    signal dragStarted(string kind)
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

    // The shared monitor list comes from `hyprctl monitors all`, so it also
    // carries outputs that are switched off - a closed laptop lid, a display
    // unplugged earlier in the session. Those report an origin of 0,0 and a
    // stale size, which is close enough to a real monitor to win the hit test
    // below and send a whole drop to a screen that is not there. Everywhere
    // else in the shell looks monitors up by name or id and never notices.
    readonly property var liveMonitors: (HyprlandData.monitors ?? []).filter(candidate => candidate && !candidate.disabled)

    // The monitor under the cursor, straight from hyprctl so scale, transform
    // and reserved space are all available.
    readonly property var monitor: {
        const monitors = root.liveMonitors;
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

    // Hyprland announces monitors and workspaces, but not the space a layer
    // surface reserves. A bar that changed side or height therefore leaves the
    // cached monitor list describing the old usable area, and zones would be
    // laid out against a bar that is no longer there. Re-reading the list at the
    // start of a gesture is one cheap hyprctl call and lands long before a drop;
    // a quick-tile is over sooner than that, so the press right after a bar
    // change still uses the previous area and the one after it is correct.
    function refreshMonitors() {
        HyprlandData.updateMonitors();
    }

    function monitorByName(name) {
        for (const candidate of root.liveMonitors) {
            if (candidate.name === name) return candidate;
        }
        return null;
    }

    // Dividers the user has dragged, per monitor name. Runtime only: a resize
    // says where this session's windows go, and rewriting the saved layout from
    // under a mouse drag would be a much bigger promise than the gesture makes.
    property var zoneOverrides: ({})

    // Editing the layout in settings is the more deliberate statement of the
    // two, so it drops whatever the dividers were dragged to.
    readonly property string layoutKey: `${JSON.stringify(Array.from(root.options?.monitors ?? []))}|${root.options?.defaultPreset ?? ""}`
    onLayoutKeyChanged: root.zoneOverrides = ({})

    function zonesFor(name) {
        return root.zoneOverrides[name] ?? Tiling.zonesForMonitor(root.options?.monitors, name, root.options?.defaultPreset ?? "kde");
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

    // Position alone does not put a window on another screen. Hyprland draws a
    // floating window wherever its coordinates say, but it keeps the workspace
    // it came from, so a window dropped across the gap looks right until that
    // workspace changes and takes it away. Handing it to the target monitor
    // first is what makes a cross-monitor drop stick.
    function moveToMonitor(address, name, currentId) {
        if (!name) return;
        const id = (currentId !== undefined && currentId !== null && currentId >= 0) ? currentId : HyprlandData.windowByAddress?.[address]?.monitor;
        const current = root.monitorById(id)?.name ?? "";
        if (!current || current === name) return;
        root.dispatchWindow(address, "move", [`monitor = "${name}"`]);
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
                floating: before.floating ?? false,
                monitor: root.monitorById(before.monitor)?.name ?? ""
            };
        }

        root.zoneMemory[address] = {
            monitor: name,
            index: index
        };

        root.setFloating(address, true, floating);
        root.moveToMonitor(address, name, before?.monitor);
        // Resizing keeps the centre, so the move has to come second.
        root.dispatchWindow(address, "resize", [`x = ${rect.width}`, `y = ${rect.height}`]);
        root.dispatchWindow(address, "move", [`x = ${rect.x}`, `y = ${rect.y}`]);
    }

    function restoreWindow(address, floating) {
        const record = root.tileRecords[address];
        delete root.zoneMemory[address];
        if (!record) return;
        delete root.tileRecords[address];

        // Back to the screen it came from first, or a window tiled across the
        // gap would be handed back to the layout tree of the wrong monitor.
        root.moveToMonitor(address, record.monitor);
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

    onDragStarted: {
        root.refreshMonitors();
        root.pruneRecords();
    }
    onDragEnded: (kind, zoneIndex) => {
        if (kind === "resize") root.handleResize(root.dragAddress, root.dragWindowAfter);
        else root.handleDrop(kind, zoneIndex);
    }

    // ----------------------------------------------------------- co-resize

    readonly property bool coResizeEnabled: root.enabled && root.mode !== "preview" && (root.options?.coResize?.enable ?? true)

    // Every window the assistant put on this monitor moves with the divider,
    // not just the one under the mouse - that is what a shared edge means. The
    // resized one is in here too, so a drag that overshot snaps back onto it.
    function reapplyZones(name) {
        const known = HyprlandData.windowByAddress ?? {};
        const alive = Object.keys(known).length > 0;
        for (const address in root.zoneMemory) {
            const zone = root.zoneMemory[address];
            if (zone.monitor !== name || (alive && !known[address])) continue;
            root.applyZone(address, name, zone.index, null, true);
        }
    }

    // Widening a tiled window past its zone drags the divider it shares with its
    // neighbours, rather than leaving it overlapping them. Only windows the
    // assistant tiled take part: one the user sized by hand is in no zone, so
    // there is no edge to share and nothing else moves.
    function handleResize(address, sample) {
        if (!root.coResizeEnabled || !address || !sample) return;
        const zone = root.zoneMemory[address];
        const monitor = zone ? root.monitorByName(zone.monitor) : null;
        if (!monitor) return;

        let zones = root.zonesFor(zone.monitor);
        if (zone.index < 0 || zone.index >= zones.length) return;
        const usable = Tiling.usableArea(monitor);
        const gaps = root.gapsFor(zone.monitor);
        const before = Tiling.zoneRect(zones[zone.index], usable, gaps);
        // Undoing the border inset puts the window back in the space the zone
        // boxes are measured in.
        const after = Tiling.insetRect(Tiling.makeRect(sample.x, sample.y, sample.width, sample.height), -root.hyprBorderSize);

        // A corner drag moves two edges at once, so every side is considered
        // rather than just the one that moved furthest.
        const tolerance = root.options?.coResize?.edgeTolerancePx ?? 8;
        const sides = [
            {
                side: "left",
                delta: after.x - before.x,
                pixel: after.x
            },
            {
                side: "right",
                delta: (after.x + after.width) - (before.x + before.width),
                pixel: after.x + after.width
            },
            {
                side: "top",
                delta: after.y - before.y,
                pixel: after.y
            },
            {
                side: "bottom",
                delta: (after.y + after.height) - (before.y + before.height),
                pixel: after.y + after.height
            }
        ];

        let moved = false;
        for (const candidate of sides) {
            if (Math.abs(candidate.delta) <= tolerance) continue;
            const fraction = Tiling.edgeFraction(usable, gaps, candidate.side, candidate.pixel);
            const updated = Tiling.moveEdge(zones, zone.index, candidate.side, fraction);
            if (!updated) continue;
            zones = updated;
            moved = true;
        }
        if (!moved) return;

        // A new object rather than a mutated one: the zone bindings only notice
        // the property being reassigned.
        const overrides = Object.assign({}, root.zoneOverrides);
        overrides[zone.monitor] = zones;
        root.zoneOverrides = overrides;
        root.reapplyZones(zone.monitor);
    }

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
        for (const candidate of root.liveMonitors) {
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
    // window in the layout tree counts as being in no zone at all, even where
    // its geometry happens to line up with one - the layout put it there, so a
    // press towards that side should tile it rather than read as "already here,
    // take me out". Float state, unlike geometry, does come with an event.
    function currentZone(address, name, sample) {
        if (!(sample?.floating ?? false)) {
            delete root.zoneMemory[address];
            return -1;
        }
        const remembered = root.zoneMemory[address];
        if (remembered && remembered.monitor === name) return remembered.index;
        return root.sampleZoneIndex(name, sample);
    }

    // Tiles the focused window one zone over. Unlike a drag, this is explicit
    // enough to act on a window living in the layout tree even in hybrid mode,
    // which has no preview of its own to fall back on.
    function quickTile(direction) {
        if (!root.keyboardEnabled || root.mode === "preview") return;
        const window = root.focusedWindow();
        if (!window) return;
        root.refreshMonitors();
        const name = root.monitorById(window.monitor)?.name ?? "";
        const zones = root.zonesFor(name);
        if (!name || zones.length === 0) return;

        const address = window.address;
        const sample = root.windowSample(window);
        const from = root.currentZone(address, name, sample);
        const target = (from < 0) ? Tiling.edgeZoneIndex(zones, direction) : Tiling.resolveDirection(zones, from, direction);
        if (target < 0) return;

        // Nowhere further that way, on any of the four sides: a window already
        // against the edge it is being pushed towards has nothing else to want
        // in that direction, so the press means "out of the layout" instead.
        if (target === from) {
            if (root.options?.restoreOnUntile ?? true) root.restoreWindow(address, sample.floating);
            return;
        }
        root.applyZone(address, name, target, sample, sample.floating);
    }

    function send(message) {
        if (!detector.running) return;
        detector.write(`${JSON.stringify(message)}\n`);
    }

    function sendConfig() {
        const detection = root.options?.detection ?? null;
        root.send({
            cmd: "config",
            idleHz: detection?.idleHz ?? 5,
            activeHz: detection?.activeHz ?? 90,
            tolerance: detection?.trackingTolerancePx ?? 2,
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
            root.dragging = true;
            root.dragStarted(event.kind);
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
            root.dragWindowAfter = event.window ?? null;
            root.dragging = false;
            // Releasing the modifier before the button makes Hyprland drop the
            // gesture and put the window back, which is a cancel and not a drop:
            // the overlay goes away and nothing is tiled.
            if (!event.cancelled) root.dragEnded(event.kind, zone);
            root.dragKind = "";
            break;
        }
    }

    // Reconfiguring is cheap, so the detector is told about setting changes
    // rather than being restarted.
    readonly property string detectionKey: {
        const detection = root.options?.detection ?? null;
        return [detection?.idleHz, detection?.activeHz, detection?.trackingTolerancePx, detection?.useKeybinds].join("|");
    }
    onDetectionKeyChanged: {
        root.sendConfig();
        if (root.enabled) root.checkKeybinds();
    }

    onEnabledChanged: {
        if (root.enabled) {
            root.checkKeybinds();
            return;
        }
        root.dragging = false;
        root.dragKind = "";
    }

    // ------------------------------------------------------- keybind check

    // The drag binds are not part of the shell: they live in the Hyprland
    // config, and the fork's installer only overlays ~/.config/hypr when it is
    // asked to - the update button inside Settings deliberately never does. So
    // a perfectly up-to-date shell can have nothing bound to these shortcuts,
    // and since the binds are now the only thing that detects a drag at all,
    // the whole feature is silently inert rather than merely degraded.
    property bool keybindsChecked: false
    property bool keybindsFound: true
    readonly property bool keybindsMissing: root.enabled && (root.options?.detection?.useKeybinds ?? true) && root.keybindsChecked && !root.keybindsFound

    function checkKeybinds() {
        root.keybindsChecked = false;
        keybindProbe.running = false;
        keybindProbe.running = true;
    }

    Process {
        id: keybindProbe

        // `hyprctl binds` cannot answer this. Under the Lua config every bind
        // reports a dispatcher of "__lua" with an opaque numeric argument, so
        // no shortcut name ever appears in it. The config text can be read
        // instead, which also covers custom/ overrides and the older syntax.
        // -s so a missing directory is simply "not bound" rather than noise.
        command: ["grep", "-rqsF", "quickshell:tilingDragMove", `${FileUtils.trimFileProtocol(Directories.config)}/hypr`]

        onExited: (code, status) => {
            root.keybindsFound = (code === 0);
            root.keybindsChecked = true;
            if (root.keybindsMissing)
                console.log("[TilingAssistant] nothing in ~/.config/hypr binds quickshell:tilingDragMove - Super+drag and Super+Alt+arrow will do nothing until the fork's Hyprland config is installed (setup script, --hypr)");
        }
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
