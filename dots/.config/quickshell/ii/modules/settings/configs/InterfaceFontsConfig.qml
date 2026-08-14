pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: interfaceFontsRoot

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

        ContentSection {
            title: Translation.tr("System Rounding")
            icon: "rounded_corner"

            ConfigSlider {
                buttonIcon: "rounded_corner"
                text: Translation.tr("Corner radius")
                usePercentTooltip: false
                stopIndicatorValues: [24]
                tooltipContent: `${value}px`
                from: 0
                to: 48
                stepSize: 1
                value: Config.options.appearance.roundingValue >= 0 ? Config.options.appearance.roundingValue : 24
                onValueChanged: {
                    Config.options.appearance.roundingValue = value;
                    Config.options.appearance.sharpMode = (value === 0);
                }
            }
        }

        ContentSection {
            title: Translation.tr("Animations")
            icon: "motion_photos_on"

            ConfigSlider {
                buttonIcon: "speed"
                text: Translation.tr("Animation speed multiplier")
                usePercentTooltip: false
                stopIndicatorValues: [1.0]
                tooltipContent: `${value.toFixed(2)}x`
                from: 0.25
                to: 2.5
                stepSize: 0.05
                value: Config.options.appearance.animationMultiplier ?? 1.0
                onValueChanged: {
                    Config.options.appearance.animationMultiplier = value;
                }
            }

            ConfigSwitch {
                buttonIcon: "speed"
                text: Translation.tr("Performance mode")
                checked: Config.options.appearance.settingsPerformanceMode
                onCheckedChanged: {
                    Config.options.appearance.settingsPerformanceMode = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Disables animations and expensive effects inside Settings.")
                }
            }
        }

        ContentSection {
            title: Translation.tr("Icons")
            icon: "category"

            ConfigSwitch {
                buttonIcon: "magic_button"
                text: Translation.tr("Themed icons (Experimental)")
                checked: Config.options.appearance.icons.enableThemed
                onCheckedChanged: {
                    Config.options.appearance.icons.enableThemed = checked;
                }

                StyledToolTip {
                    text: Translation.tr("When enabled, uses the dynamic Matugen generated icon pack. Fallbacks to Tint Icons.")
                }
            }

            ContentSubsection {
                visible: Config.options.appearance.icons.enableThemed
                title: Translation.tr("Base icon theme")
                icon: "palette"
                Layout.fillWidth: true
                tooltip: Translation.tr("Select the base icon theme to be recolored by Matugen.\nRequires generating colors again to apply.")

                ConfigSelectionArray {
                    currentValue: Config.options.appearance.iconTheme
                    onSelected: (newValue) => {
                        Config.options.appearance.iconTheme = newValue;
                    }
                    options: IconThemes.availableThemes.map((theme) => {
                        return ({
                            "displayName": theme,
                            "value": theme,
                            "icon": "category"
                        });
                    })
                }
            }

            RippleButtonWithIcon {
                visible: Config.options.appearance.icons.enableThemed
                materialIcon: "magic_button"
                mainText: Translation.tr("Apply Theme")
                useDynamicRadius: true
                implicitHeight: 48
                Layout.fillWidth: true
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                colText: Appearance.colors.colOnPrimaryContainer
                onClicked: {
                    IconThemes.applyTheme(false);
                }
            }

            ConfigSwitch {
                buttonIcon: "restart_alt"
                text: Translation.tr("Auto restart Quickshell on theme change")
                checked: Config.options.appearance.wallpaperTheming.autoRestartQuickshell
                onCheckedChanged: {
                    Config.options.appearance.wallpaperTheming.autoRestartQuickshell = checked;
                }
            }
        }

        ContentSection {
            title: Translation.tr("Details")
            icon: "auto_awesome"

            ConfigSwitch {
                buttonIcon: "colors"
                text: Translation.tr("Colorful scrollbar")
                checked: Config.options.appearance.colorfulScrollbar
                onCheckedChanged: {
                    Config.options.appearance.colorfulScrollbar = checked;
                }
            }

        }

        ContentSection {
            title: Translation.tr("Fonts Management")
            icon: "text_format"

            ConfigSwitch {
                buttonIcon: "custom_typography"
                text: Translation.tr("Enable custom fonts")
                checked: Config.options.appearance.fonts.enableCustom
                configPage: Qt.resolvedUrl("widgets/CustomFontsConfig.qml")
                onCheckedChanged: {
                    Config.options.appearance.fonts.enableCustom = checked;
                    if (checked) {
                        Config.options.appearance.fonts.main = Persistent.states.settings.fonts.main;
                        Config.options.appearance.fonts.numbers = Persistent.states.settings.fonts.numbers;
                        Config.options.appearance.fonts.title = Persistent.states.settings.fonts.title;
                        Config.options.appearance.fonts.monospace = Persistent.states.settings.fonts.monospace;
                        Config.options.appearance.fonts.iconNerd = Persistent.states.settings.fonts.iconNerd;
                        Config.options.appearance.fonts.reading = Persistent.states.settings.fonts.reading;
                        Config.options.appearance.fonts.expressive = Persistent.states.settings.fonts.expressive;
                    } else {
                        Config.options.appearance.fonts.main = "Google Sans Flex";
                        Config.options.appearance.fonts.numbers = "Google Sans Flex";
                        Config.options.appearance.fonts.title = "Google Sans Flex";
                        Config.options.appearance.fonts.iconNerd = "JetBrainsMono Nerd Font";
                        Config.options.appearance.fonts.monospace = "JetBrainsMono Nerd Font";
                        Config.options.appearance.fonts.reading = "Readex Pro";
                        Config.options.appearance.fonts.expressive = "Space Grotesk";
                    }
                }

                StyledToolTip {
                    text: Translation.tr("Toggle custom fonts. Click on the button text to configure individual font family overrides.")
                }
            }

            ConfigSwitch {
                buttonIcon: "rounded_corner"
                text: Translation.tr("Full font roundness")
                checked: Config.options.appearance.fonts.roundnessFull
                onCheckedChanged: {
                    Config.options.appearance.fonts.roundnessFull = checked;
                    Persistent.states.settings.fonts.roundnessFull = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Use rounded font variant (ROND: 100) for variable fonts like Google Sans Flex")
                }
            }
        }
    }

    // Sub-page overlay
    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }
}
