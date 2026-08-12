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
                            font.pixelSize: Appearance.font.pixelSize.normal
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
            title: Translation.tr("On-Screen Display (OSD)")
            icon: "desktop_windows"

            ConfigSwitch {
                buttonIcon: "visibility"
                text: Translation.tr("Enable OSD")
                checked: Config.options.osd.enable
                onCheckedChanged: {
                    Config.options.osd.enable = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "fullscreen"
                text: Translation.tr("Hide OSD when fullscreen")
                checked: Config.options.osd.hideWhenFullscreen
                onCheckedChanged: {
                    Config.options.osd.hideWhenFullscreen = checked;
                }
            }

            NoticeBox {
                Layout.fillWidth: true
                visible: Config.options.sidebar.sidebarStyle === "connect"
                materialIcon: "phone_android"
                text: Translation.tr("OSD customization is only available in Default shell mode. The Connect mode uses its own native OSD.")

                ShortcutBox {
                    targetPageId: "bar"
                    targetSectionTitle: Translation.tr("Shell mode")
                    materialIcon: "arrow_forward"
                    text: Translation.tr("Go to Shell mode settings")
                    linkText: Translation.tr("Go there")
                }
            }

            ContentSubsection {
                title: Translation.tr("OSD Style")
                icon: "tune"
                Layout.fillWidth: true
                enabled: Config.options.sidebar.sidebarStyle !== "connect"
                opacity: Config.options.sidebar.sidebarStyle !== "connect" ? 1.0 : 0.4

                ConfigSelectionArray {
                    enabled: Config.options.sidebar.sidebarStyle !== "connect"
                    currentValue: Config.options.osd.style ?? "default"
                    onSelected: (newValue) => {
                        Config.options.osd.style = newValue;
                    }
                    options: [{
                        "displayName": Translation.tr("Android"),
                        "icon": "smartphone",
                        "value": "default"
                    }, {
                        "displayName": Translation.tr("Minimal"),
                        "icon": "horizontal_rule",
                        "value": "minimalist"
                    }]
                }
            }

            ContentSubsection {
                title: Translation.tr("OSD Position")
                icon: "align_horizontal_right"
                Layout.fillWidth: true
                enabled: Config.options.sidebar.sidebarStyle !== "connect"
                opacity: Config.options.sidebar.sidebarStyle !== "connect" ? 1.0 : 0.4

                ConfigSelectionArray {
                    enabled: Config.options.sidebar.sidebarStyle !== "connect"
                    currentValue: Config.options.osd.position ?? "right"
                    onSelected: (newValue) => {
                        Config.options.osd.position = newValue;
                    }
                    options: [{
                        "displayName": Translation.tr("Left"),
                        "icon": "align_horizontal_left",
                        "value": "left"
                    }, {
                        "displayName": Translation.tr("Right"),
                        "icon": "align_horizontal_right",
                        "value": "right"
                    }]
                }
            }

            ConfigSlider {
                enabled: Config.options.sidebar.sidebarStyle !== "connect"
                opacity: Config.options.sidebar.sidebarStyle !== "connect" ? 1.0 : 0.4
                buttonIcon: "schedule"
                text: Translation.tr("OSD Timeout")
                usePercentTooltip: false
                tooltipContent: `${(value / 1000).toFixed(1)}s`
                from: 1000
                to: 5000
                stepSize: 500
                value: Config.options.osd.timeout ?? 3000
                onValueChanged: {
                    Config.options.osd.timeout = value;
                }
            }

            ConfigSlider {
                enabled: Config.options.sidebar.sidebarStyle !== "connect"
                opacity: Config.options.sidebar.sidebarStyle !== "connect" ? 1.0 : 0.4
                buttonIcon: "height"
                text: Translation.tr("OSD Height")
                usePercentTooltip: false
                stopIndicatorValues: [500]
                tooltipContent: `${value}px`
                from: 300
                to: 800
                stepSize: 10
                value: Config.options.osd.height ?? 500
                onValueChanged: {
                    Config.options.osd.height = value;
                }
            }

            ConfigSwitch {
                enabled: Config.options.sidebar.sidebarStyle !== "connect"
                buttonIcon: "tag"
                text: Translation.tr("Show OSD value number")
                checked: Config.options.osd.showValues
                onCheckedChanged: {
                    Config.options.osd.showValues = checked;
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

            ContentSubsection {
                title: Translation.tr("Keyboard Style")
                icon: "keyboard"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.osk.style ?? "deck"
                    onSelected: (newValue) => {
                        Config.options.osk.style = newValue;
                    }
                    options: [{
                        "displayName": Translation.tr("Deck"),
                        "icon": "keyboard",
                        "tooltip": Translation.tr("Spans the bottom of the screen"),
                        "value": "deck"
                    }, {
                        "displayName": Translation.tr("Classic"),
                        "icon": "keyboard_alt",
                        "tooltip": Translation.tr("Floats above the screen edge"),
                        "value": "classic"
                    }]
                }
            }

            ContentSubsection {
                title: Translation.tr("Layout")
                icon: "language"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.osk.layout ?? "auto"
                    onSelected: (newValue) => {
                        Config.options.osk.layout = newValue;
                    }
                    options: [{
                        "displayName": Translation.tr("Auto"),
                        "icon": "autorenew",
                        "tooltip": Translation.tr("Follows the keyboard layout you are typing in"),
                        "value": "auto"
                    }, {
                        "displayName": Translation.tr("French"),
                        "value": "French"
                    }, {
                        "displayName": Translation.tr("English"),
                        "value": "English (US)"
                    }, {
                        "displayName": Translation.tr("German"),
                        "value": "German"
                    }, {
                        "displayName": Translation.tr("Russian"),
                        "value": "Russian"
                    }]
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                enabled: (Config.options.osk.style ?? "deck") === "deck"
                opacity: enabled ? 1.0 : 0.4

                ConfigSpinBox {
                    icon: "height"
                    text: Translation.tr("Height (% of the screen)")
                    value: Config.options.osk.heightPercent
                    from: 15
                    to: 60
                    stepSize: 1
                    onValueChanged: {
                        Config.options.osk.heightPercent = value;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "text_fields"
                    text: Translation.tr("Show shift and AltGr glyphs")
                    checked: Config.options.osk.secondaryGlyphs
                    onCheckedChanged: {
                        Config.options.osk.secondaryGlyphs = checked;
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSwitch {
                    buttonIcon: "touch_app"
                    text: Translation.tr("Show automatically on touch")
                    checked: Config.options.osk.autoShow.enable
                    configPage: Qt.resolvedUrl("widgets/OnScreenKeyboardConfig.qml")
                    onCheckedChanged: {
                        Config.options.osk.autoShow.enable = checked;
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
