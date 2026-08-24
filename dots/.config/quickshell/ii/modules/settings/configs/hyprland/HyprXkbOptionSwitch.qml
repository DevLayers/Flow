import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * One XKB option, as a switch.
 *
 * `input:kb_options` is a single comma-separated string, so a switch here is really "is this
 * word in that list" - and toggling it has to rewrite the whole list without disturbing
 * anything else that happens to be in it, including options this page does not offer.
 */
ConfigSwitch {
    id: root

    /// An XKB option code, e.g. "caps:escape".
    required property string option

    readonly property var current: String(HyprlandGui.displayValue("input:kb_options", "") ?? "")
        .split(",").filter(entry => entry.trim().length > 0)

    checked: root.current.indexOf(root.option) >= 0
    onClicked: {
        const next = root.checked
            ? root.current.filter(entry => entry !== root.option)
            : root.current.concat([root.option]);
        HyprlandGui.setKey("input:kb_options", next.join(","));
    }

    Component.onCompleted: HyprlandGui.watch(["input:kb_options"])
}
