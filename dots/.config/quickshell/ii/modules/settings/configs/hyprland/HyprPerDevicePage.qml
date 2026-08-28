pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings -> Hyprland -> Input -> Per device.
 *
 * One card per real keyboard, mouse, tablet or touch device Hyprland can see, each able to
 * override the global input settings for just that device. Split off the Input tab itself: a
 * machine with several peripherals - or one with several HID interfaces per peripheral, which
 * is common on gaming keyboards and mice - can report a dozen or more real devices, and each
 * card is a small settings page of its own.
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
                    text: Translation.tr("Per device")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Overrides for one keyboard, mouse, tablet or touch device")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }

        ContentSection {
            title: Translation.tr("Devices")
            icon: "devices"

            StyledText {
                Layout.fillWidth: true
                text: HyprlandDevices.ready
                    ? Translation.tr("Settings on the Input tab apply to everything. These override them for one device only.")
                    : Translation.tr("Asking Hyprland what is plugged in…")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: HyprlandDevices.realKeyboards

                delegate: HyprDeviceCard {
                    required property var modelData

                    device: modelData
                    kind: "keyboard"
                }
            }

            Repeater {
                model: HyprlandDevices.realMice

                delegate: HyprDeviceCard {
                    required property var modelData

                    device: modelData
                    kind: "pointer"
                }
            }

            Repeater {
                model: HyprlandDevices.realTablets

                delegate: HyprDeviceCard {
                    required property var modelData

                    device: modelData
                    kind: "tablet"
                }
            }

            Repeater {
                model: HyprlandDevices.realTouch

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
}
