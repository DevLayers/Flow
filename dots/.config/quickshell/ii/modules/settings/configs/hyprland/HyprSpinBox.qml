import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/// A spin box bound to one Hyprland option. Same write rule as HyprSlider: the option pushes
/// into the box, the box writes back only when the user has moved it off that value.
ConfigSpinBox {
    id: root

    required property string optionKey
    property int defaultValue: 0

    readonly property var optionState: HyprlandGui.resolve(root.optionKey)
    readonly property int optionValue: {
        const value = Number(HyprlandGui.displayValue(root.optionKey, root.defaultValue));
        return isNaN(value) ? root.defaultValue : Math.round(value);
    }
    property bool armed: false

    enabled: root.optionState.shellOwnedBy === ""
    value: root.optionValue

    onValueChanged: {
        if (!root.armed || root.value === root.optionValue) return;
        HyprlandGui.setKey(root.optionKey, root.value);
    }
    onOptionValueChanged: root.value = root.optionValue

    Component.onCompleted: {
        HyprlandGui.watch([root.optionKey]);
        Qt.callLater(() => root.armed = true);
    }
}
