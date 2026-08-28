pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings -> Hyprland -> Layout -> Advanced workspace swipe.
 *
 * Direction locking, touchscreen behaviour and the rarer speed/wrap options for the touchpad
 * workspace gesture — left off the Layout tab because the distance, commit threshold and
 * inversion above cover what almost everyone actually tunes.
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
                    text: Translation.tr("Advanced workspace swipe")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Direction lock, touchscreen and wrap-around")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }

        ContentSection {
            title: Translation.tr("Behaviour")
            icon: "swipe"

            HyprSlider {
                optionKey: "gestures:workspace_swipe_min_speed_to_force"
                defaultValue: 30
                integer: true
                buttonIcon: "bolt"
                text: Translation.tr("Speed that commits a swipe regardless")
                tooltipContent: value < 1 ? Translation.tr("Off") : `${Math.round(value)} px`
                from: 0
                to: 200
                stepSize: 1
            }

            HyprSwitch {
                optionKey: "gestures:workspace_swipe_create_new"
                defaultValue: true
                buttonIcon: "add"
                text: Translation.tr("Swiping past the last workspace makes a new one")
            }

            HyprSwitch {
                optionKey: "gestures:workspace_swipe_forever"
                buttonIcon: "all_inclusive"
                text: Translation.tr("Keep going past the next workspace in one swipe")
            }

            HyprSwitch {
                optionKey: "gestures:workspace_swipe_use_r"
                buttonIcon: "tag"
                text: Translation.tr("Swipe within the monitor's own workspaces")

                StyledToolTip {
                    text: Translation.tr("Uses the r workspace prefix instead of m, so a swipe stays inside the workspaces that belong to this monitor.")
                }
            }
        }

        ContentSection {
            title: Translation.tr("Direction lock")
            icon: "lock"

            HyprSwitch {
                optionKey: "gestures:workspace_swipe_direction_lock"
                defaultValue: true
                buttonIcon: "swipe_right"
                text: Translation.tr("Lock to the direction the swipe started in")
            }

            HyprSlider {
                optionKey: "gestures:workspace_swipe_direction_lock_threshold"
                defaultValue: 10
                integer: true
                buttonIcon: "straighten"
                text: Translation.tr("Travel before the lock takes hold")
                tooltipContent: `${Math.round(value)} px`
                from: 0
                to: 200
                stepSize: 1
            }
        }

        ContentSection {
            title: Translation.tr("Touchscreen")
            icon: "touch_app"

            HyprSwitch {
                optionKey: "gestures:workspace_swipe_touch"
                buttonIcon: "swipe"
                text: Translation.tr("Swipe workspaces from the edge of a touchscreen")
            }

            HyprSwitch {
                optionKey: "gestures:workspace_swipe_touch_invert"
                buttonIcon: "swap_horiz"
                text: Translation.tr("Invert the touchscreen direction")
            }

            HyprOptionNote {
                keys: ["gestures:workspace_swipe_min_speed_to_force",
                    "gestures:workspace_swipe_create_new", "gestures:workspace_swipe_forever",
                    "gestures:workspace_swipe_use_r", "gestures:workspace_swipe_direction_lock",
                    "gestures:workspace_swipe_direction_lock_threshold",
                    "gestures:workspace_swipe_touch", "gestures:workspace_swipe_touch_invert"]
                notes: [{
                    "icon": "info",
                    "text": Translation.tr("Turning the swipe on and choosing how many fingers it takes is no longer a setting: since Hyprland 0.55 that is a gesture line, and the ones this config ships live in hyprland/general.lua. Everything here tunes a swipe that is already set up.")
                }]
            }
        }
    }
}
