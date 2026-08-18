import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    ContentPage {
        id: page
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
                text: Translation.tr("Suggestions Panel")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            icon: "auto_awesome"
            title: Translation.tr("Empty Query Suggestions")

            ConfigSwitch {
                buttonIcon: "auto_awesome"
                text: Translation.tr("Enable suggestions panel")
                checked: Config.options.search.suggestions.enable
                onCheckedChanged: {
                    Config.options.search.suggestions.enable = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Displays quick action and app suggestions when search is opened without any query")
                }
            }

            ConfigSwitch {
                visible: Config.options.search.suggestions.enable
                buttonIcon: "trending_up"
                text: Translation.tr("Show frecency suggestions")
                checked: Config.options.search.suggestions.showFrecency
                onCheckedChanged: Config.options.search.suggestions.showFrecency = checked
                StyledToolTip {
                    text: Translation.tr("Suggests apps based on frequency and recency of use")
                }
            }

            ConfigSwitch {
                visible: Config.options.search.suggestions.enable
                buttonIcon: "apps"
                text: Translation.tr("Show applications section")
                checked: Config.options.search.suggestions.showApps
                onCheckedChanged: Config.options.search.suggestions.showApps = checked
            }

            ConfigSwitch {
                visible: Config.options.search.suggestions.enable
                buttonIcon: "terminal"
                text: Translation.tr("Show system commands section")
                checked: Config.options.search.suggestions.showCommands
                onCheckedChanged: Config.options.search.suggestions.showCommands = checked
            }

            ConfigSwitch {
                visible: Config.options.search.suggestions.enable
                buttonIcon: "keyboard_command_key"
                text: Translation.tr("Show aliases section")
                checked: Config.options.search.suggestions.showAliases
                onCheckedChanged: Config.options.search.suggestions.showAliases = checked
            }

            ConfigSpinBox {
                visible: Config.options.search.suggestions.enable
                icon: "format_list_numbered"
                text: Translation.tr("Max suggestions per section")
                value: Config.options.search.suggestions.maxSuggestionsPerSection
                from: 2
                to: 10
                stepSize: 1
                onValueChanged: Config.options.search.suggestions.maxSuggestionsPerSection = value
            }
        }
    }
}
