pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings -> Hyprland -> Input -> Advanced cursor.
 *
 * Zoom, warping and hardware-cursor overrides: niche behaviour past "hide when idle" that
 * almost nobody needs to reach for. The cursor's theme and size live in the Environment tab,
 * since those are environment variables rather than compositor options.
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
                    text: Translation.tr("Advanced cursor")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Zoom, warping and hardware overrides")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }

        ContentSection {
            title: Translation.tr("Hiding & warping")
            icon: "my_location"

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
        }

        ContentSection {
            title: Translation.tr("Zoom & hardware")
            icon: "zoom_in"

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

            HyprOptionNote {
                keys: ["cursor:hide_on_key_press", "cursor:hide_on_touch", "cursor:no_warps",
                    "cursor:persistent_warps", "cursor:warp_on_change_workspace",
                    "cursor:zoom_rigid", "cursor:zoom_factor", "cursor:no_hardware_cursors"]
            }
        }
    }
}
