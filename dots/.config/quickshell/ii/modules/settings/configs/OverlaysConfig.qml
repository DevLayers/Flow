import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: overlaysConfigRoot

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page

        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress
        visible: opacity > 0

        ContentSection {
            title: Translation.tr("Game Overlays")
            icon: "sports_esports"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RippleButton {
                    id: gameOverlayRipple

                    Layout.fillWidth: true
                    implicitHeight: gameOverlayRow.implicitHeight + 32
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colTertiaryContainer
                    colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                    colRipple: Appearance.colors.colTertiaryContainerActive
                    onClicked: {
                        overlaysConfigRoot.activeSubPage = Qt.resolvedUrl("widgets/GameOverlayConfig.qml");
                    }

                    contentItem: RowLayout {
                        id: gameOverlayRow

                        spacing: 12
                        anchors.fill: parent
                        anchors.margins: 16

                        MaterialShapeWrappedMaterialSymbol {
                            text: "settings"
                            shape: MaterialShape.Shape.Circle
                            iconSize: 18
                            padding: 6
                            fill: 1
                            color: Appearance.colors.colTertiary
                            colSymbol: Appearance.colors.colOnTertiary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Game Overlay Options")
                            font.pixelSize: Appearance.font.pixelSize.medium
                            color: Appearance.colors.colOnTertiaryContainer
                        }

                        MaterialSymbol {
                            text: "arrow_forward"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnTertiaryContainer
                        }

                    }

                }

            }

        }

        ContentSection {
            title: Translation.tr("Media Overlay")
            icon: "play_circle"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSwitch {
                    buttonIcon: "linear_scale"
                    text: Translation.tr("Show slider")
                    checked: Config.options.overlay.media.showSlider
                    onCheckedChanged: {
                        Config.options.overlay.media.showSlider = checked;
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Background opacity (%)")
                    value: Config.options.overlay.media.backgroundOpacityPercentage
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.overlay.media.backgroundOpacityPercentage = value;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "gradient"
                    text: Translation.tr("Use lyrics gradient masking")
                    checked: Config.options.overlay.media.useGradientMask
                    onCheckedChanged: {
                        Config.options.overlay.media.useGradientMask = checked;
                    }
                }

                ConfigSpinBox {
                    icon: "format_size"
                    text: Translation.tr("Lyrics font size")
                    value: Config.options.overlay.media.lyricSize
                    from: 10
                    to: 100
                    stepSize: 1
                    onValueChanged: {
                        Config.options.overlay.media.lyricSize = value;
                    }
                }

            }

        }

        ContentSection {
            title: Translation.tr("On-screen Keyboard")
            icon: "keyboard"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSwitch {
                    buttonIcon: "touch_app"
                    text: Translation.tr("Show automatically on touch")
                    checked: Config.options.osk.autoShow.enable
                    onCheckedChanged: {
                        Config.options.osk.autoShow.enable = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "pan_tool"
                    text: Translation.tr("Trigger with finger")
                    enabled: Config.options.osk.autoShow.enable
                    checked: Config.options.osk.autoShow.allowTouch
                    onCheckedChanged: {
                        Config.options.osk.autoShow.allowTouch = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "stylus"
                    text: Translation.tr("Trigger with pen")
                    enabled: Config.options.osk.autoShow.enable
                    checked: Config.options.osk.autoShow.allowPen
                    onCheckedChanged: {
                        Config.options.osk.autoShow.allowPen = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "keyboard_hide"
                    text: Translation.tr("Hide when typing on a real keyboard")
                    enabled: Config.options.osk.autoShow.enable
                    checked: Config.options.osk.autoShow.hideOnPhysicalKey
                    onCheckedChanged: {
                        Config.options.osk.autoShow.hideOnPhysicalKey = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "gesture"
                    text: Translation.tr("Hide when tapping outside")
                    enabled: Config.options.osk.autoShow.enable
                    checked: Config.options.osk.autoShow.hideOnTouchOutside
                    onCheckedChanged: {
                        Config.options.osk.autoShow.hideOnTouchOutside = checked;
                    }
                }

                ConfigSpinBox {
                    icon: "timer"
                    text: Translation.tr("Touch window (ms)")
                    enabled: Config.options.osk.autoShow.enable
                    value: Config.options.osk.autoShow.touchWindowMs
                    from: 200
                    to: 5000
                    stepSize: 100
                    onValueChanged: {
                        Config.options.osk.autoShow.touchWindowMs = value;
                    }
                }

            }

        }

    }

    ConfigSubPageHost {
        id: subPageOverlay

        anchors.fill: parent
        z: 10
    }

}
