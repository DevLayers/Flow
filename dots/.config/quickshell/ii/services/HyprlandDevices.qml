pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * The input devices Hyprland can see, split into the ones a person owns and the ones software
 * invented.
 *
 * `hyprctl devices` on this laptop lists eleven keyboards and eight mice for a machine with one
 * of each: keyd, ydotool and logiops each register a virtual device, ACPI lids and power buttons
 * show up as keyboards, and a single USB receiver appears three times. A per-device settings list
 * that shows all of them is unusable, so the phantoms are filtered out - and counted, because
 * hiding them silently would be its own kind of lie.
 */
Singleton {
    id: root

    property var mice: []
    property var keyboards: []
    property var tablets: []
    property var touch: []
    property bool ready: false

    /// Names that belong to software, not hardware.
    readonly property var virtualPatterns: [
        /virtual/i, /^video-bus$/, /^power-button$/, /^sleep-button$/, /^lid-switch$/,
        /hid-events$/, /button-array$/, /consumer-control/, /system-control/, /^ydotool/, /^keyd/,
        /^logiops/, /^wlr/, /^wayland/
    ]

    function isVirtual(name: string): bool {
        return root.virtualPatterns.some(pattern => pattern.test(String(name ?? "")));
    }

    function real(list: var): var {
        return Array.from(list ?? []).filter(device => !root.isVirtual(device.name));
    }

    readonly property int hiddenCount:
        (root.mice.length - root.real(root.mice).length)
        + (root.keyboards.length - root.real(root.keyboards).length)
        + (root.tablets.length - root.real(root.tablets).length)
        + (root.touch.length - root.real(root.touch).length)

    /// A touchpad is a mouse as far as Hyprland is concerned, and the only thing that says
    /// otherwise is its name.
    function isTouchpad(device: var): bool {
        return /touchpad|trackpad|synaptics|glidepoint/i.test(String(device?.name ?? ""));
    }

    function refresh() {
        root.stale = false;
        if (devicesProc.running) return;
        devicesProc.running = true;
    }

    /// Nothing outside Settings -> Hyprland reads this list, so it is only kept current while
    /// that page is on screen. What happened while it was closed is caught up on the way back.
    property bool stale: false

    function ensureFresh() {
        if (root.stale || !root.ready) root.refresh();
    }

    Connections {
        target: HyprlandGui
        function onWatchingChanged() {
            if (HyprlandGui.watching) root.ensureFresh();
        }
    }

    Process {
        id: devicesProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed;
                try {
                    parsed = JSON.parse(text);
                } catch (error) {
                    console.warn("[HyprlandDevices] cannot parse hyprctl devices:", error);
                    return;
                }
                root.mice = parsed.mice ?? [];
                root.keyboards = parsed.keyboards ?? [];
                root.tablets = parsed.tablets ?? [];
                root.touch = parsed.touch ?? [];
                root.ready = true;
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // Plugging a mouse in does not reload the config, so the list has to follow the
            // compositor's own device events instead.
            if (event.name !== "configreloaded" && event.name !== "activelayout") return;
            root.stale = true;
            if (HyprlandGui.watching) rescan.restart();
        }
    }

    Timer {
        id: rescan
        interval: 400
        onTriggered: root.refresh()
    }
}
