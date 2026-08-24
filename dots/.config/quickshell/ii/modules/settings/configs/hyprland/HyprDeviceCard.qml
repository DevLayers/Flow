pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * One physical input device, and the settings that apply only to it.
 *
 * A device override is all or nothing in Lua - `hl.device{}` either exists for a name or it does
 * not - so the card is off until you turn it on, and turning it off deletes the whole block
 * rather than leaving a stub behind. Fields follow what the device is: a trackpoint has no
 * layout, a keyboard has no pointer acceleration.
 */
ContentSubsection {
    id: card

    required property var device
    /// "pointer", "keyboard", "tablet" or "touch"
    required property string kind

    readonly property string deviceName: String(card.device?.name ?? "")
    readonly property var spec: HyprlandGui.deviceSpec(card.deviceName)
    readonly property bool overridden: card.spec !== null
    readonly property bool isPointer: card.kind === "pointer"
    readonly property bool isKeyboard: card.kind === "keyboard"
    readonly property bool isSurface: card.kind === "tablet" || card.kind === "touch"

    title: card.deviceName
    icon: {
        if (card.isKeyboard) return "keyboard";
        if (card.kind === "tablet") return "stylus";
        if (card.kind === "touch") return "touch_app";
        return HyprlandDevices.isTouchpad(card.device) ? "touchpad_mouse" : "mouse";
    }
    Layout.fillWidth: true

    function put(key: string, value: var) {
        const next = Object.assign({ "name": card.deviceName }, card.spec ?? {});
        next[key] = value;
        HyprlandGui.setDevice(card.deviceName, next);
    }

    function setting(key: string, fallback: var): var {
        const spec = card.spec;
        return spec && spec[key] !== undefined ? spec[key] : fallback;
    }

    HyprToggle {
        buttonIcon: "tune"
        text: Translation.tr("Settings just for this device")
        switchOn: card.overridden
        onRequested: wanted => {
            if (wanted) HyprlandGui.setDevice(card.deviceName, { "name": card.deviceName });
            else HyprlandGui.removeDevice(card.deviceName);
        }

        StyledToolTip {
            text: Translation.tr("Overrides the global input settings for this one device.")
        }
    }

    HyprToggle {
        visible: card.overridden
        buttonIcon: "power_settings_new"
        text: Translation.tr("Device enabled")
        switchOn: card.setting("enabled", true) === true
        onRequested: wanted => card.put("enabled", wanted)
    }

    ConfigSlider {
        id: sensitivity

        readonly property real specValue: Number(card.setting("sensitivity", 0))

        visible: card.overridden && card.isPointer
        buttonIcon: "speed"
        text: Translation.tr("Sensitivity")
        usePercentTooltip: false
        from: -1
        to: 1
        stepSize: 0.05
        value: sensitivity.specValue
        onSpecValueChanged: {
            if (sensitivity.pressed) return;
            sensitivity.value = sensitivity.specValue;
        }
        onPressedChanged: {
            if (sensitivity.pressed) return;
            card.put("sensitivity", Number(sensitivity.value.toFixed(2)));
        }
    }

    HyprSelect {
        visible: card.overridden && card.isPointer
        title: Translation.tr("Pointer acceleration")
        icon: "trending_up"
        currentOverride: String(card.setting("accel_profile", ""))
        options: [
            { "displayName": Translation.tr("Global setting"), "value": "" },
            { "displayName": Translation.tr("Adaptive"), "value": "adaptive" },
            { "displayName": Translation.tr("Flat"), "value": "flat" }
        ]
        onSelected: newValue => card.put("accel_profile", newValue)
    }

    HyprToggle {
        visible: card.overridden && card.isPointer
        buttonIcon: "swap_vert"
        text: Translation.tr("Natural scrolling")
        switchOn: card.setting("natural_scroll", false) === true
        onRequested: wanted => card.put("natural_scroll", wanted)
    }

    HyprToggle {
        visible: card.overridden && card.isPointer
        buttonIcon: "back_hand"
        text: Translation.tr("Left handed")
        switchOn: card.setting("left_handed", false) === true
        onRequested: wanted => card.put("left_handed", wanted)
    }

    ConfigTextField {
        id: deviceLayout

        visible: card.overridden && card.isKeyboard
        icon: "keyboard"
        text: Translation.tr("Layout codes")
        placeholderText: "us,fr"
        inputText: String(card.setting("kb_layout", ""))

        Connections {
            target: deviceLayout.textField

            function onEditingFinished() {
                card.put("kb_layout", deviceLayout.inputText);
            }
        }
    }

    ConfigTextField {
        id: deviceVariant

        visible: card.overridden && card.isKeyboard
        icon: "language"
        text: Translation.tr("Variants")
        placeholderText: ",intl"
        inputText: String(card.setting("kb_variant", ""))

        Connections {
            target: deviceVariant.textField

            function onEditingFinished() {
                card.put("kb_variant", deviceVariant.inputText);
            }
        }
    }

    ConfigSpinBox {
        id: deviceRate

        visible: card.overridden && card.isKeyboard
        icon: "repeat"
        text: Translation.tr("Repeat rate")
        from: 1
        to: 100
        stepSize: 1
        value: Number(card.setting("repeat_rate", 25))
        onValueChanged: {
            if (deviceRate.value === Number(card.setting("repeat_rate", 25))) return;
            card.put("repeat_rate", deviceRate.value);
        }
    }

    ConfigSpinBox {
        id: deviceDelay

        visible: card.overridden && card.isKeyboard
        icon: "timer"
        text: Translation.tr("Repeat delay (ms)")
        from: 100
        to: 2000
        stepSize: 50
        value: Number(card.setting("repeat_delay", 600))
        onValueChanged: {
            if (deviceDelay.value === Number(card.setting("repeat_delay", 600))) return;
            card.put("repeat_delay", deviceDelay.value);
        }
    }

    ConfigTextField {
        id: deviceOutput

        visible: card.overridden && card.isSurface
        icon: "monitor"
        text: Translation.tr("Bind to one screen")
        placeholderText: "eDP-1"
        inputText: String(card.setting("output", ""))

        Connections {
            target: deviceOutput.textField

            function onEditingFinished() {
                card.put("output", deviceOutput.inputText);
            }
        }
    }

    HyprSelect {
        visible: card.overridden && card.isSurface
        title: Translation.tr("Rotation")
        icon: "screen_rotation"
        currentOverride: Number(card.setting("transform", 0))
        options: [
            { "displayName": Translation.tr("None"), "value": 0 },
            { "displayName": "90°", "value": 1 },
            { "displayName": "180°", "value": 2 },
            { "displayName": "270°", "value": 3 }
        ]
        onSelected: newValue => card.put("transform", newValue)
    }
}
