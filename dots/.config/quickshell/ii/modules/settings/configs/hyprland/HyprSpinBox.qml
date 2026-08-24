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
    /// See HyprSlider: arming before Hyprland has answered turns the first real value into an
    /// edit, because this control clamps it into its own range on the way in.
    property bool armed: false
    property real reported: NaN

    enabled: root.optionState.shellOwnedBy === ""
    value: root.optionValue

    function clamped(value: real): real {
        return Math.min(root.to, Math.max(root.from, value));
    }

    onValueChanged: {
        if (!root.armed || !root.optionState.known) return;
        if (root.value === root.optionValue) return;
        if (isFinite(root.reported) && root.value === root.clamped(root.reported)) return;
        HyprlandGui.setKey(root.optionKey, root.value);
    }
    onOptionValueChanged: {
        root.reported = root.optionValue;
        root.value = root.optionValue;
    }

    Component.onCompleted: {
        HyprlandGui.watch([root.optionKey]);
        if (root.optionState.known) {
            root.reported = root.optionValue;
            Qt.callLater(() => root.armed = true);
        }
    }

    onOptionStateChanged: {
        if (root.armed || !root.optionState.known) return;
        root.reported = root.optionValue;
        Qt.callLater(() => root.armed = true);
    }
}
