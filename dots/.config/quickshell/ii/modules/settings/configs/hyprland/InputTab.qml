pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings -> Hyprland -> Input.
 *
 * Keyboard, key repeat, mouse, touchpad, cursor, and the devices themselves. Nothing here had a
 * page anywhere in the shell before; the only way to change any of it was to edit Lua.
 *
 * Every control shows what Hyprland is actually doing until this page sets the key. The footer
 * of each section is where anything gets undone, and where the page admits that something else
 * - a hand-written line, a Mode, the shell itself - is having the last word.
 */
ContentPage {
    id: tab

    forceWidth: false

    Component.onCompleted: {
        HyprlandDevices.refresh();
        // The Layout row names the layout in words, so the catalogue is needed before the
        // sub-page is ever opened.
        XkbCatalog.load();
    }

    ContentSection {
        title: Translation.tr("Keyboard")
        icon: "keyboard"

        HyprNavRow {
            buttonIcon: "language"
            text: Translation.tr("Layout")
            value: {
                const layout = String(HyprlandGui.displayValue("input:kb_layout", "us") ?? "");
                const variant = String(HyprlandGui.displayValue("input:kb_variant", "") ?? "");
                if (layout.indexOf(",") >= 0)
                    return Translation.tr("%1 layouts").arg(layout.split(",").length);
                const name = XkbCatalog.loaded
                    ? (variant === "" ? XkbCatalog.layoutName(layout)
                        : XkbCatalog.variantName(layout, variant))
                    : layout;
                return variant === "" ? `${name} (${layout})` : `${name} (${layout} ${variant})`;
            }
            configPage: Qt.resolvedUrl("HyprKeyboardLayoutPage.qml")
            onOpenSubPage: XkbCatalog.load()
        }

        HyprSwitch {
            optionKey: "input:numlock_by_default"
            defaultValue: true
            buttonIcon: "pin"
            text: Translation.tr("Num Lock on at startup")
        }

        HyprSwitch {
            optionKey: "input:resolve_binds_by_sym"
            buttonIcon: "abc"
            text: Translation.tr("Match shortcuts by symbol, not position")

            StyledToolTip {
                text: Translation.tr("On an AZERTY layout, SUPER+A then means the key that types A rather than the key where A sits on QWERTY.")
            }
        }

        ContentSubsection {
            title: Translation.tr("Key behaviour")
            icon: "keyboard_option_key"
            Layout.fillWidth: true

            HyprXkbOptionSwitch {
                option: "caps:escape"
                buttonIcon: "keyboard_capslock"
                text: Translation.tr("Caps Lock acts as Escape")
            }

            HyprXkbOptionSwitch {
                option: "caps:swapescape"
                buttonIcon: "swap_horiz"
                text: Translation.tr("Swap Caps Lock and Escape")
            }

            HyprXkbOptionSwitch {
                option: "compose:ralt"
                buttonIcon: "add_circle"
                text: Translation.tr("Right Alt is the Compose key")

                StyledToolTip {
                    text: Translation.tr("Compose then ' then e types é. Works in every app, without a layout that has the letter on it.")
                }
            }

            HyprXkbOptionSwitch {
                option: "terminate:ctrl_alt_bksp"
                buttonIcon: "logout"
                text: Translation.tr("Ctrl+Alt+Backspace kills the session")
            }

            HyprXkbOptionSwitch {
                option: "grp:alt_shift_toggle"
                buttonIcon: "language"
                text: Translation.tr("Alt+Shift switches between layouts")
            }
        }

        ContentSubsection {
            title: Translation.tr("Several layouts at once")
            icon: "list"
            Layout.fillWidth: true

            HyprTextField {
                optionKey: "input:kb_layout"
                defaultValue: "us"
                icon: "language"
                text: Translation.tr("Layout codes")
                placeholderText: "fr,us"
                tooltip: Translation.tr("Comma separated. The first one is active at startup.")
            }

            HyprTextField {
                optionKey: "input:kb_variant"
                icon: "tune"
                text: Translation.tr("Variants")
                placeholderText: ",intl"
                tooltip: Translation.tr("One per layout, in the same order. Leave a slot empty for no variant.")
            }

            HyprTextField {
                optionKey: "input:kb_options"
                icon: "settings"
                text: Translation.tr("XKB options")
                placeholderText: "caps:escape,compose:ralt"
                tooltip: Translation.tr("The raw list. The switches above edit the same string.")
            }

            HyprTextField {
                optionKey: "input:kb_model"
                icon: "keyboard_alt"
                text: Translation.tr("Keyboard model")
                placeholderText: "pc105"
            }
        }

        HyprOptionNote {
            keys: ["input:kb_layout", "input:kb_variant", "input:kb_options", "input:kb_model",
                "input:numlock_by_default", "input:resolve_binds_by_sym"]
        }
    }

    ContentSection {
        title: Translation.tr("Key repeat")
        icon: "repeat"

        HyprSlider {
            optionKey: "input:repeat_delay"
            defaultValue: 600
            integer: true
            buttonIcon: "timer"
            text: Translation.tr("Delay before repeating")
            tooltipContent: `${Math.round(value)} ms`
            from: 100
            to: 1500
            stepSize: 25
        }

        HyprSlider {
            optionKey: "input:repeat_rate"
            defaultValue: 25
            integer: true
            buttonIcon: "speed"
            text: Translation.tr("Repeats per second")
            tooltipContent: `${Math.round(value)}/s`
            from: 1
            to: 80
            stepSize: 1
        }

        ContentSubsection {
            title: Translation.tr("Try it")
            icon: "edit"
            Layout.fillWidth: true

            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Hold a key down here")
            }
        }

        HyprOptionNote {
            keys: ["input:repeat_delay", "input:repeat_rate"]
        }
    }

    ContentSection {
        title: Translation.tr("Mouse")
        icon: "mouse"

        HyprSlider {
            optionKey: "input:sensitivity"
            buttonIcon: "speed"
            text: Translation.tr("Sensitivity")
            tooltipContent: value.toFixed(2)
            from: -1
            to: 1
            stepSize: 0.05
        }

        HyprSwitch {
            optionKey: "input:natural_scroll"
            buttonIcon: "swap_vert"
            text: Translation.tr("Natural scrolling")
        }

        HyprSwitch {
            optionKey: "input:left_handed"
            buttonIcon: "back_hand"
            text: Translation.tr("Swap the mouse buttons")
        }

        HyprSwitch {
            optionKey: "input:force_no_accel"
            buttonIcon: "linear_scale"
            text: Translation.tr("Send raw movement, unaccelerated")

            StyledToolTip {
                text: Translation.tr("Bypasses libinput's pointer acceleration entirely. Useful for games and drawing; heavy-handed for everything else.")
            }
        }

        HyprSlider {
            optionKey: "input:scroll_factor"
            defaultValue: 1
            buttonIcon: "unfold_more"
            text: Translation.tr("Scroll distance")
            tooltipContent: `${value.toFixed(2)}×`
            from: 0.05
            to: 3
            stepSize: 0.05
        }

        HyprSwitch {
            optionKey: "input:scroll_button_lock"
            buttonIcon: "lock"
            text: Translation.tr("Scroll button stays held")
        }

        HyprSwitch {
            optionKey: "input:mouse_refocus"
            defaultValue: true
            buttonIcon: "center_focus_weak"
            text: Translation.tr("Moving the mouse can change focus")
        }

        HyprSelect {
            optionKey: "input:accel_profile"
            title: Translation.tr("Pointer acceleration")
            icon: "trending_up"
            options: [
                { "displayName": Translation.tr("libinput default"), "value": "" },
                { "displayName": Translation.tr("Adaptive"), "value": "adaptive" },
                { "displayName": Translation.tr("Flat"), "value": "flat" }
            ]
        }

        HyprSelect {
            optionKey: "input:scroll_method"
            title: Translation.tr("Scroll method")
            icon: "swipe_vertical"
            options: [
                { "displayName": Translation.tr("libinput default"), "value": "" },
                { "displayName": Translation.tr("Two fingers"), "value": "2fg" },
                { "displayName": Translation.tr("Edge"), "value": "edge" },
                { "displayName": Translation.tr("Hold a button"), "value": "on_button_down" },
                { "displayName": Translation.tr("Off"), "value": "no_scroll" }
            ]
        }

        HyprSelect {
            optionKey: "input:follow_mouse"
            defaultValue: 1
            title: Translation.tr("Focus follows the pointer")
            icon: "ads_click"
            options: [
                { "displayName": Translation.tr("Never"), "value": 0 },
                { "displayName": Translation.tr("Always"), "value": 1 },
                { "displayName": Translation.tr("Detached"), "value": 2 },
                { "displayName": Translation.tr("Click to focus"), "value": 3 }
            ]
        }

        HyprSlider {
            optionKey: "input:follow_mouse_threshold"
            buttonIcon: "straighten"
            text: Translation.tr("Movement needed before focus follows")
            tooltipContent: `${Math.round(value)} px`
            from: 0
            to: 200
            stepSize: 5
        }

        HyprSelect {
            optionKey: "input:focus_on_close"
            title: Translation.tr("When a window closes, focus goes to")
            icon: "close"
            options: [
                { "displayName": Translation.tr("The next window"), "value": 0 },
                { "displayName": Translation.tr("Whatever is under the pointer"), "value": 1 }
            ]
        }

        HyprOptionNote {
            keys: ["input:sensitivity", "input:natural_scroll", "input:left_handed",
                "input:force_no_accel", "input:scroll_factor", "input:scroll_button_lock",
                "input:mouse_refocus", "input:accel_profile", "input:scroll_method",
                "input:follow_mouse", "input:follow_mouse_threshold", "input:focus_on_close"]
        }
    }

    ContentSection {
        title: Translation.tr("Touchpad")
        icon: "touchpad_mouse"

        HyprSwitch {
            optionKey: "input:touchpad:tap-to-click"
            defaultValue: true
            buttonIcon: "touch_app"
            text: Translation.tr("Tap to click")
        }

        HyprSwitch {
            optionKey: "input:touchpad:tap-and-drag"
            defaultValue: true
            buttonIcon: "drag_pan"
            text: Translation.tr("Tap then drag to move things")
        }

        HyprSwitch {
            optionKey: "input:touchpad:natural_scroll"
            buttonIcon: "swap_vert"
            text: Translation.tr("Natural scrolling")
        }

        HyprSwitch {
            optionKey: "input:touchpad:disable_while_typing"
            defaultValue: true
            buttonIcon: "keyboard_hide"
            text: Translation.tr("Ignore the touchpad while typing")
        }

        HyprSwitch {
            optionKey: "input:touchpad:clickfinger_behavior"
            buttonIcon: "pinch"
            text: Translation.tr("Right click with two fingers anywhere")

            StyledToolTip {
                text: Translation.tr("Off, the button areas at the bottom of the pad decide which click you get. On, the number of fingers does.")
            }
        }

        HyprSwitch {
            optionKey: "input:touchpad:middle_button_emulation"
            buttonIcon: "adjust"
            text: Translation.tr("Both buttons at once is a middle click")
        }

        HyprSwitch {
            optionKey: "input:touchpad:flip_x"
            buttonIcon: "flip"
            text: Translation.tr("Flip horizontally")
        }

        HyprSwitch {
            optionKey: "input:touchpad:flip_y"
            buttonIcon: "flip_camera_android"
            text: Translation.tr("Flip vertically")
        }

        HyprSlider {
            optionKey: "input:touchpad:scroll_factor"
            defaultValue: 1
            buttonIcon: "unfold_more"
            text: Translation.tr("Scroll distance")
            tooltipContent: `${value.toFixed(2)}×`
            from: 0.05
            to: 3
            stepSize: 0.05
        }

        HyprSelect {
            optionKey: "input:touchpad:drag_lock"
            defaultValue: 0
            title: Translation.tr("Drag lock")
            icon: "lock_open"
            options: [
                { "displayName": Translation.tr("Off"), "value": 0 },
                { "displayName": Translation.tr("Until a timeout"), "value": 1 },
                { "displayName": Translation.tr("Until the next tap"), "value": 2 }
            ]
        }

        HyprSelect {
            optionKey: "input:touchpad:drag_3fg"
            defaultValue: 0
            title: Translation.tr("Three-finger drag")
            icon: "3d_rotation"
            options: [
                { "displayName": Translation.tr("Off"), "value": 0 },
                { "displayName": Translation.tr("Three fingers"), "value": 1 },
                { "displayName": Translation.tr("Four fingers"), "value": 2 }
            ]
        }

        HyprSelect {
            optionKey: "input:touchpad:tap_button_map"
            title: Translation.tr("Two and three finger taps")
            icon: "touch_app"
            options: [
                { "displayName": Translation.tr("libinput default"), "value": "" },
                { "displayName": Translation.tr("Right, then middle"), "value": "lrm" },
                { "displayName": Translation.tr("Middle, then right"), "value": "lmr" }
            ]
        }

        HyprOptionNote {
            keys: ["input:touchpad:tap-to-click", "input:touchpad:tap-and-drag",
                "input:touchpad:natural_scroll", "input:touchpad:disable_while_typing",
                "input:touchpad:clickfinger_behavior", "input:touchpad:middle_button_emulation",
                "input:touchpad:flip_x", "input:touchpad:flip_y", "input:touchpad:scroll_factor",
                "input:touchpad:drag_lock", "input:touchpad:drag_3fg",
                "input:touchpad:tap_button_map"]
        }
    }

    ContentSection {
        title: Translation.tr("Cursor")
        icon: "mouse"

        HyprSlider {
            optionKey: "cursor:inactive_timeout"
            buttonIcon: "timer_off"
            text: Translation.tr("Hide when idle")
            tooltipContent: value < 0.5 ? Translation.tr("Never") : `${value.toFixed(1)} s`
            from: 0
            to: 30
            stepSize: 0.5
            decimals: 1
        }

        HyprSwitch {
            optionKey: "cursor:hide_on_key_press"
            buttonIcon: "keyboard"
            text: Translation.tr("Hide while typing")
        }

        HyprSwitch {
            optionKey: "cursor:hide_on_touch"
            defaultValue: true
            buttonIcon: "touch_app"
            text: Translation.tr("Hide when the screen is touched")
        }

        HyprSwitch {
            optionKey: "cursor:no_warps"
            buttonIcon: "my_location"
            text: Translation.tr("Never move the cursor by itself")

            StyledToolTip {
                text: Translation.tr("Hyprland normally jumps the cursor to a window it focuses. This stops that everywhere.")
            }
        }

        HyprSwitch {
            optionKey: "cursor:persistent_warps"
            buttonIcon: "history"
            text: Translation.tr("Remember where the cursor was in each window")
        }

        HyprSwitch {
            optionKey: "cursor:enable_hyprcursor"
            defaultValue: true
            buttonIcon: "brush"
            text: Translation.tr("Use hyprcursor themes")
        }

        HyprSwitch {
            optionKey: "cursor:zoom_rigid"
            buttonIcon: "center_focus_strong"
            text: Translation.tr("Zoom stays centred on the screen")
        }

        HyprSlider {
            optionKey: "cursor:zoom_factor"
            defaultValue: 1
            buttonIcon: "zoom_in"
            text: Translation.tr("Screen zoom")
            tooltipContent: `${value.toFixed(1)}×`
            from: 1
            to: 5
            stepSize: 0.1
            decimals: 1
        }

        HyprSelect {
            optionKey: "cursor:no_hardware_cursors"
            defaultValue: 2
            title: Translation.tr("Hardware cursor")
            icon: "memory"
            options: [
                { "displayName": Translation.tr("Use it"), "value": 0 },
                { "displayName": Translation.tr("Never"), "value": 1 },
                { "displayName": Translation.tr("Decide automatically"), "value": 2 }
            ]
        }

        HyprSelect {
            optionKey: "cursor:warp_on_change_workspace"
            defaultValue: 0
            title: Translation.tr("Jump to the focused window when changing workspace")
            icon: "swap_horiz"
            options: [
                { "displayName": Translation.tr("No"), "value": 0 },
                { "displayName": Translation.tr("Yes"), "value": 1 },
                { "displayName": Translation.tr("Force"), "value": 2 }
            ]
        }

        HyprOptionNote {
            keys: ["cursor:inactive_timeout", "cursor:hide_on_key_press", "cursor:hide_on_touch",
                "cursor:no_warps", "cursor:persistent_warps", "cursor:enable_hyprcursor",
                "cursor:zoom_rigid", "cursor:zoom_factor", "cursor:no_hardware_cursors",
                "cursor:warp_on_change_workspace"]
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: Translation.tr("The cursor's theme and size are environment variables, not compositor options, so they live in the Environment tab.")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }
    }

    ContentSection {
        title: Translation.tr("Per device")
        icon: "devices"

        StyledText {
            Layout.fillWidth: true
            text: HyprlandDevices.ready
                ? Translation.tr("Settings above apply to everything. These override them for one device only.")
                : Translation.tr("Asking Hyprland what is plugged in…")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: HyprlandDevices.real(HyprlandDevices.keyboards)

            delegate: HyprDeviceCard {
                required property var modelData

                device: modelData
                kind: "keyboard"
            }
        }

        Repeater {
            model: HyprlandDevices.real(HyprlandDevices.mice)

            delegate: HyprDeviceCard {
                required property var modelData

                device: modelData
                kind: "pointer"
            }
        }

        Repeater {
            model: HyprlandDevices.real(HyprlandDevices.tablets)

            delegate: HyprDeviceCard {
                required property var modelData

                device: modelData
                kind: "tablet"
            }
        }

        Repeater {
            model: HyprlandDevices.real(HyprlandDevices.touch)

            delegate: HyprDeviceCard {
                required property var modelData

                device: modelData
                kind: "touch"
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: HyprlandDevices.hiddenCount > 0
            text: Translation.tr("%1 device(s) Hyprland reports are not hardware — keyd, ydotool, logiops and the lid switch each register one — so they are left out.")
                .arg(HyprlandDevices.hiddenCount)
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }
    }
}
