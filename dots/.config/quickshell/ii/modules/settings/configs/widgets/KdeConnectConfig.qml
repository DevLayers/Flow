import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    ContentPage {
        anchors.fill: parent
        forceWidth: false

        RowLayout {
            visible: subPageRoot.showBackButton
            spacing: 12

            RippleButton {
                implicitWidth: implicitHeight
                implicitHeight: 40
                topLeftRadius: Appearance.rounding.full
                topRightRadius: Appearance.rounding.full
                bottomLeftRadius: Appearance.rounding.full
                bottomRightRadius: Appearance.rounding.full
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

            StyledText {
                text: Translation.tr("KDE Connect Service")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            icon: "sync"
            title: Translation.tr("Connection Settings")

            ConfigSwitch {
                buttonIcon: "wifi"
                text: Translation.tr("Use wireless debugging")
                checked: Config.options.phone.scrcpy.useWireless
                onCheckedChanged: Config.options.phone.scrcpy.useWireless = checked
            }

            ConfigSwitch {
                buttonIcon: "sync_alt"
                text: Translation.tr("Auto-detect IP (KDE Connect)")
                checked: Config.options.phone.scrcpy.autoWirelessIp
                enabled: Config.options.phone.scrcpy.useWireless
                onCheckedChanged: Config.options.phone.scrcpy.autoWirelessIp = checked
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                visible: Config.options.phone.scrcpy.useWireless && Config.options.phone.scrcpy.autoWirelessIp
                text: KdeConnectService.resolvedWirelessHost !== ""
                    ? Translation.tr("Will connect to %1").arg(KdeConnectService.resolvedWirelessHost)
                    : Translation.tr("Waiting for KDE Connect to report the phone's IP…")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }

            ConfigTextField {
                icon: "dns"
                text: Translation.tr("Wireless IP")
                placeholderText: Translation.tr("e.g. 192.168.1.50")
                inputText: Config.options.phone.scrcpy.wirelessIp
                visible: Config.options.phone.scrcpy.useWireless && !Config.options.phone.scrcpy.autoWirelessIp
                enabled: visible
                textField.onTextChanged: Config.options.phone.scrcpy.wirelessIp = textField.text
            }

            ConfigTextField {
                icon: "tag"
                text: Translation.tr("Wireless Port")
                placeholderText: Translation.tr("Default: 5555")
                inputText: Config.options.phone.scrcpy.wirelessPort
                visible: Config.options.phone.scrcpy.useWireless && !Config.options.phone.scrcpy.autoWirelessIp
                enabled: visible
                textField.onTextChanged: Config.options.phone.scrcpy.wirelessPort = textField.text
            }

            ConfigSwitch {
                buttonIcon: "terminal"
                text: Translation.tr("Show terminal window")
                checked: Config.options.phone.scrcpy.showTerminal
                onCheckedChanged: Config.options.phone.scrcpy.showTerminal = checked
            }
        }

        ContentSection {
            icon: "phone_android"
            title: Translation.tr("scrcpy Options")

            ConfigSwitch {
                buttonIcon: "lock"
                text: Translation.tr("Stay awake")
                checked: Config.options.phone.scrcpy.stayAwake
                onCheckedChanged: Config.options.phone.scrcpy.stayAwake = checked
            }
            ConfigSwitch {
                buttonIcon: "phone_android"
                text: Translation.tr("Turn screen off")
                checked: Config.options.phone.scrcpy.turnScreenOff
                onCheckedChanged: Config.options.phone.scrcpy.turnScreenOff = checked
            }
            ConfigSwitch {
                buttonIcon: "power_settings_new"
                text: Translation.tr("No power on device")
                checked: Config.options.phone.scrcpy.noPowerOn
                onCheckedChanged: Config.options.phone.scrcpy.noPowerOn = checked
            }
            ConfigSwitch {
                buttonIcon: "volume_off"
                text: Translation.tr("No audio forwarding")
                checked: Config.options.phone.scrcpy.noAudio
                onCheckedChanged: Config.options.phone.scrcpy.noAudio = checked
            }
            ConfigSwitch {
                buttonIcon: "gesture"
                text: Translation.tr("Show touches")
                checked: Config.options.phone.scrcpy.showTouches
                onCheckedChanged: Config.options.phone.scrcpy.showTouches = checked
            }
            ConfigSwitch {
                buttonIcon: "fullscreen"
                text: Translation.tr("Fullscreen")
                checked: Config.options.phone.scrcpy.fullscreen
                onCheckedChanged: Config.options.phone.scrcpy.fullscreen = checked
            }
            ConfigSwitch {
                buttonIcon: "vertical_align_top"
                text: Translation.tr("Always on top")
                checked: Config.options.phone.scrcpy.alwaysOnTop
                onCheckedChanged: Config.options.phone.scrcpy.alwaysOnTop = checked
            }
            ConfigSlider {
                buttonIcon: "speed"
                text: Translation.tr("Max FPS")
                value: Config.options.phone.scrcpy.maxFps
                from: 0
                to: 120
                stepSize: 5
                usePercentTooltip: false
                onValueChanged: Config.options.phone.scrcpy.maxFps = value
            }
            ConfigTextField {
                icon: "wifi_tethering"
                text: Translation.tr("Bitrate")
                placeholderText: Translation.tr("e.g. 8M, 4M")
                inputText: Config.options.phone.scrcpy.bitRate
                textField.onTextChanged: Config.options.phone.scrcpy.bitRate = textField.text
            }
            ConfigSlider {
                buttonIcon: "aspect_ratio"
                text: Translation.tr("Max Size (0 for unrestricted)")
                value: Config.options.phone.scrcpy.maxSize
                from: 0
                to: 3840
                stepSize: 120
                usePercentTooltip: false
                onValueChanged: Config.options.phone.scrcpy.maxSize = value
            }
            ConfigSlider {
                buttonIcon: "av_timer"
                text: Translation.tr("Video Buffer (ms)")
                value: Config.options.phone.scrcpy.videoBuffer
                from: 0
                to: 1000
                stepSize: 10
                usePercentTooltip: false
                onValueChanged: Config.options.phone.scrcpy.videoBuffer = value
            }
        }
    }
}
