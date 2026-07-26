pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    readonly property string _sessionId: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""

    // "never" | "session" | "always" — see Config.options.idle.persistInhibit
    readonly property string persistScope: (Config.options && Config.options.idle && Config.options.idle.persistInhibit) ? Config.options.idle.persistInhibit : "session"

    Timer {
        id: restoreTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (!Persistent.ready || !Config.ready) return;
            if (root.persistScope === "never") {
                root.inhibit = false;
                return;
            }
            const storedId = Persistent.states.idle.sessionId || "";
            if (root.persistScope === "session" && storedId !== root._sessionId) {
                root.inhibit = false;
                return;
            }
            root.inhibit = Persistent.states.idle.inhibit ?? false;
        }
    }

    Connections {
        target: Persistent
        function onReadyChanged() { restoreTimer.restart() }
    }

    Connections {
        target: Config
        function onReadyChanged() { restoreTimer.restart() }
    }

    // Both singletons may already be ready by the time this one loads
    Component.onCompleted: restoreTimer.restart()

    function toggleInhibit(active = null) {
        root.inhibit = active !== null ? active : !root.inhibit
        Persistent.states.idle.inhibit = root.inhibit
        Persistent.states.idle.sessionId = root._sessionId
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            // Inhibitor requires a "visible" surface
            // Actually not lol
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }
}
