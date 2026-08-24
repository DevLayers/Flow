import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * A labelled row of choices, bound to a Hyprland option key or driven by hand.
 *
 * With `optionKey` set it reads and writes that key. With `currentOverride` set instead it just
 * reports what was chosen, which is what the per-device cards need - a device override is one
 * Lua table, not a set of independent keys.
 */
ContentSubsection {
    id: root

    property string optionKey: ""
    property var defaultValue: ""
    /// Used in place of an option key. Ignored when `optionKey` is set.
    property var currentOverride: undefined
    property alias options: choices.options

    signal selected(var newValue)

    readonly property var optionState: root.optionKey === ""
        ? null : HyprlandGui.resolve(root.optionKey)
    readonly property var optionValue: root.optionKey === ""
        ? root.currentOverride : HyprlandGui.displayValue(root.optionKey, root.defaultValue)

    Layout.fillWidth: true

    ConfigSelectionArray {
        id: choices
        enabled: root.optionState === null || root.optionState.shellOwnedBy === ""
        currentValue: root.optionValue
        onSelected: newValue => {
            if (root.optionKey !== "") HyprlandGui.setKey(root.optionKey, newValue);
            root.selected(newValue);
        }
    }

    Component.onCompleted: {
        if (root.optionKey !== "") HyprlandGui.watch([root.optionKey]);
    }
}
