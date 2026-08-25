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

    /**
     * What the row needs, split by what it depends on.
     *
     * `resolve()` bundles all five layers into one object, so a control bound to it was rebuilt
     * whenever anything anywhere in the config changed - and with six tabs open that is every
     * control on the page, on every edit. Ownership never changes at all, and "has Hyprland
     * answered yet" changes once; only the value really moves.
     */
    readonly property bool locked: root.optionKey !== ""
        && HyprlandGui.shellOwned(root.optionKey) !== ""
    readonly property var optionValue: root.optionKey === ""
        ? root.currentOverride : HyprlandGui.displayValue(root.optionKey, root.defaultValue)

    Layout.fillWidth: true

    ConfigSelectionArray {
        id: choices
        enabled: !root.locked
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
