pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings -> Hyprland -> Input -> Advanced mouse.
 *
 * Everything about the mouse past sensitivity and natural scrolling: focus-follows-pointer
 * tuning, scroll method, button swap. Left off the Input tab itself because almost nobody
 * changes these after the first time they get the pointer feeling right.
 */
Item {
    id: subPageRoot
    anchors.fill: parent

    signal goBack
    property bool showBackButton: false

    ContentPage {
        anchors.fill: parent
        forceWidth: false

        RowLayout {
            visible: subPageRoot.showBackButton
            Layout.fillWidth: true
            spacing: 12

            RippleButton {
                implicitWidth: implicitHeight
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: subPageRoot.goBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: Translation.tr("Advanced mouse")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Focus, scrolling and button behaviour")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }

        ContentSection {
            title: Translation.tr("Buttons & scrolling")
            icon: "mouse"

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
        }

        ContentSection {
            title: Translation.tr("Focus")
            icon: "ads_click"

            HyprSwitch {
                optionKey: "input:mouse_refocus"
                defaultValue: true
                buttonIcon: "center_focus_weak"
                text: Translation.tr("Moving the mouse can change focus")
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
                keys: ["input:left_handed", "input:force_no_accel", "input:scroll_factor",
                    "input:scroll_button_lock", "input:scroll_method", "input:mouse_refocus",
                    "input:follow_mouse", "input:follow_mouse_threshold", "input:focus_on_close"]
            }
        }
    }
}
