import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    ContentPage {
        id: root
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
                text: Translation.tr("Lockscreen Widgets & Layout")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            title: Translation.tr("Widgets & Layout")
            icon: "widgets"

            ConfigSwitch {
                buttonIcon: "timer_off"
                text: Translation.tr("Disable clock animation on lock")
                checked: Config.options.background.widgets.clock_cookie.disableAnimationOnLock
                onCheckedChanged: {
                    Config.options.background.widgets.clock_cookie.disableAnimationOnLock = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Skip loading the clock widget during lock screen for better animation performance.")
                }
            }

            ConfigSpinBox {
                icon: "vertical_align_center"
                text: Translation.tr("Clock center vertical spacing (px)")
                value: Config.options.lock.widgets.clockCenterSpacing ?? 100
                from: 0
                to: 300
                stepSize: 10
                onValueChanged: {
                    Config.options.lock.widgets.clockCenterSpacing = value;
                }
            }

            ContentSubsection {
                title: Translation.tr("Clock Alignment")
                icon: "format_align_center"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.lock.widgets.clockAlignment ?? "center"
                    onSelected: newValue => {
                        Config.options.lock.widgets.clockAlignment = newValue;
                    }
                    options: [
                        { displayName: Translation.tr("Center"), icon: "format_align_center", value: "center" },
                        { displayName: Translation.tr("Left"), icon: "format_align_left", value: "left" },
                        { displayName: Translation.tr("Right"), icon: "format_align_right", value: "right" }
                    ]
                }
            }

            ConfigSwitch {
                buttonIcon: "lock"
                text: Translation.tr("Show locked text indicator")
                checked: Config.options.lock.widgets.showLockedIndicator ?? true
                onCheckedChanged: {
                    Config.options.lock.widgets.showLockedIndicator = checked;
                }
            }

            ContentSubsection {
                title: Translation.tr("Material character shape")
                icon: "shapes"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.lock.widgets.materialCharacterShape ?? "circle"
                    onSelected: newValue => {
                        Config.options.lock.widgets.materialCharacterShape = newValue;
                    }
                    options: (["Circle", "Square", "Slanted", "Arch", "Arrow", "SemiCircle", "Oval", "Pill", "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny", "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided", "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Flower", "Puffy", "PuffyDiamond", "PixelCircle", "Bun", "Heart"]).map(icon => {
                        return {
                            "displayName": "",
                            "shape": icon,
                            "value": icon
                        };
                    })
                }
            }

            ConfigSwitch {
                buttonIcon: "water_drop"
                text: Translation.tr("Enable ripple effect on unlock")
                checked: Config.options.lock.widgets.enableUnlockRipple ?? true
                onCheckedChanged: {
                    Config.options.lock.widgets.enableUnlockRipple = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Show Now Playing widget")
                checked: Config.options.lock.widgets.showNowPlaying ?? true
                onCheckedChanged: {
                    Config.options.lock.widgets.showNowPlaying = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "alarm"
                text: Translation.tr("Show next alarm")
                checked: Config.options.lock.widgets.showNextAlarm ?? true
                onCheckedChanged: {
                    Config.options.lock.widgets.showNextAlarm = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "wb_sunny"
                text: Translation.tr("Show weather icon & temperature")
                checked: Config.options.lock.widgets.showWeather ?? true
                onCheckedChanged: {
                    Config.options.lock.widgets.showWeather = checked;
                }
            }
        }
    }
}
