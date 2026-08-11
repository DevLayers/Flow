import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.welcome

Item {
    id: root

    signal openWifi()
    signal openBluetooth()
    signal openAudioOutput()
    signal openSettingsPage(string pageId)

    ContentPage {
        anchors.fill: parent
        bottomContentPadding: 24

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: heroLayout.implicitHeight + 48
            radius: Appearance.rounding.large
            color: Appearance.colors.colPrimaryContainer

            RowLayout {
                id: heroLayout
                anchors.fill: parent
                anchors.margins: 24
                spacing: 22

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: "waving_hand"
                    shape: MaterialShape.Shape.Cookie9Sided
                    iconSize: Appearance.font.pixelSize.huge
                    padding: 18
                    fill: 1
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Welcome to illogical-impulse")
                        color: Appearance.colors.colOnPrimaryContainer
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.variableAxes: Appearance.font.variableAxes.title
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Take a quick tour, connect the essentials and make II feel like yours. Every step is optional.")
                        color: Appearance.colors.colOnPrimaryContainer
                        font.pixelSize: Appearance.font.pixelSize.normal
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "tune"
            title: Translation.tr("Get connected")

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("These are the same quick controls available in the dashboard.")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 860 ? 3 : 1
                columnSpacing: 12
                rowSpacing: 12

                WelcomeActionCard {
                    Layout.fillWidth: true
                    materialIcon: Network.materialSymbol
                    title: Translation.tr("Wi-Fi")
                    description: Network.wifiStatus === "connected"
                        ? Translation.tr("Connected and ready")
                        : Translation.tr("Choose a wireless network")
                    statusText: Network.wifiStatus === "connected"
                        ? (Network.networkName || Network.active?.ssid || Translation.tr("Connected"))
                        : Translation.tr("Not connected")
                    onClicked: root.openWifi()
                }

                WelcomeActionCard {
                    Layout.fillWidth: true
                    materialIcon: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
                    title: Translation.tr("Bluetooth")
                    description: BluetoothStatus.connected
                        ? Translation.tr("Manage connected devices")
                        : Translation.tr("Pair headphones and accessories")
                    statusText: BluetoothStatus.connected
                        ? (BluetoothStatus.firstActiveDevice?.name || Translation.tr("Device connected"))
                        : (BluetoothStatus.enabled ? Translation.tr("On") : Translation.tr("Off"))
                    onClicked: root.openBluetooth()
                }

                WelcomeActionCard {
                    Layout.fillWidth: true
                    materialIcon: Audio.muted ? "volume_off" : "volume_up"
                    title: Translation.tr("Audio output")
                    description: Translation.tr("Choose speakers and adjust apps")
                    statusText: Audio.sink
                        ? Translation.tr("%1 · %2%").arg(Audio.friendlyDeviceName(Audio.sink)).arg(String(Math.round(Audio.value * 100)))
                        : Translation.tr("No output detected")
                    onClicked: root.openAudioOutput()
                }
            }
        }

        NoticeBox {
            Layout.fillWidth: true
            materialIcon: "info"
            text: Translation.tr("You can revisit every choice later. Super + I opens the complete Settings app.")

            RippleButtonWithIcon {
                materialIcon: "settings"
                mainText: Translation.tr("Open Settings")
                onClicked: root.openSettingsPage("")
            }
        }
    }
}
