import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * A switch bound to one Hyprland option.
 *
 * Shows what Hyprland is actually doing until this page sets the key, then shows what this page
 * set. Writing only ever happens on a click, so the value can never write itself back.
 */
ConfigSwitch {
    id: root

    required property string optionKey
    /// Used only until hyprctl has answered, so the row does not flicker on first paint.
    property bool defaultValue: false

    readonly property var optionState: HyprlandGui.resolve(root.optionKey)

    checked: {
        const value = HyprlandGui.displayValue(root.optionKey, root.defaultValue);
        return value === true || value === 1;
    }
    enabled: root.optionState.shellOwnedBy === ""
    onClicked: HyprlandGui.setKey(root.optionKey, !root.checked)

    Component.onCompleted: HyprlandGui.watch([root.optionKey])
}
