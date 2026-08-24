import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * A slider bound to one Hyprland option, with a live preview while dragging.
 *
 * The value is not bound to the option: the option is pushed into the slider whenever it
 * changes from elsewhere, and the slider writes back only when its own value stops matching.
 * Binding both ways would make every refresh look like a fresh edit.
 */
ConfigSlider {
    id: root

    required property string optionKey
    property real defaultValue: 0
    /// Hyprland types its options; writing 0.5 into an int key is rejected on reload.
    property bool integer: false
    property int decimals: 2

    readonly property var optionState: HyprlandGui.resolve(root.optionKey)
    readonly property real optionValue: {
        const value = Number(HyprlandGui.displayValue(root.optionKey, root.defaultValue));
        return isNaN(value) ? root.defaultValue : value;
    }
    /// Nothing is written before the first real value has arrived and been shown.
    property bool armed: false

    usePercentTooltip: false
    enabled: root.optionState.shellOwnedBy === ""
    // A real binding, so the slider follows the option until the first drag replaces it; from
    // then on onOptionValueChanged keeps the two in step by hand.
    value: root.optionValue

    function committedValue(): real {
        return root.integer ? Math.round(root.value) : Number(root.value.toFixed(root.decimals));
    }

    function push() {
        if (!root.armed || root.committedValue() === root.optionValue) return;
        HyprlandGui.setKey(root.optionKey, root.committedValue());
    }

    onValueChanged: root.push()
    onOptionValueChanged: {
        if (root.pressed) return;
        root.value = root.optionValue;
    }

    Component.onCompleted: {
        HyprlandGui.watch([root.optionKey]);
        Qt.callLater(() => root.armed = true);
    }
}
