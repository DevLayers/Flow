import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.configs.widgets
import qs.services

Item {
    id: launcherRoot
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

        ContentSection {
            icon: "tune"
            title: Translation.tr("Search Behavior & Positioning")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2

                ConfigSwitch {
                    buttonIcon: "trending_up"
                    text: Translation.tr("Frequency-based ranking")
                    checked: Config.options.search.frecency
                    onCheckedChanged: Config.options.search.frecency = checked
                }
                ConfigSwitch {
                    buttonIcon: "apps"
                    text: Translation.tr("Always list apps on empty query")
                    checked: Config.options.search.alwaysListApps
                    onCheckedChanged: Config.options.search.alwaysListApps = checked
                }
                ConfigSwitch {
                    buttonIcon: "center_focus_strong"
                    text: Translation.tr("Center Search on Screen")
                    checked: Config.options.search.positionStyle === "center"
                    onCheckedChanged: Config.options.search.positionStyle = checked ? "center" : "default"
                }
                ConfigSlider {
                    buttonIcon: "search"
                    text: Translation.tr("Search base width (px)")
                    value: Config.options.search.baseWidth
                    from: 360
                    to: 1000
                    stepSize: 10
                    usePercentTooltip: false
                    onValueChanged: Config.options.search.baseWidth = value
                }
            }
        }

        ContentSection {
            icon: "extension"
            title: Translation.tr("Search workspace")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2

                SubPageEntryButton {
                    entryIcon: "dashboard_customize"
                    entryTitle: Translation.tr("Search modules")
                    entryDescription: Translation.tr("Enable panels and tune their data sources")
                    onClicked: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherModulesConfig.qml"))
                }
                SubPageEntryButton {
                    entryIcon: "link"
                    entryTitle: Translation.tr("Quicklinks")
                    entryDescription: Translation.tr("Aliases that open or copy URLs")
                    onClicked: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherQuicklinksConfig.qml"))
                }
                SubPageEntryButton {
                    entryIcon: "content_cut"
                    entryTitle: Translation.tr("Text snippets")
                    entryDescription: Translation.tr("Reusable text with clipboard and date tokens")
                    onClicked: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherSnippetsConfig.qml"))
                }
                SubPageEntryButton {
                    entryIcon: "keyboard"
                    entryTitle: Translation.tr("Search shortcuts")
                    entryDescription: Translation.tr("Keyboard reference and conflict-safe defaults")
                    onClicked: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherShortcutsConfig.qml"))
                }
                SubPageEntryButton {
                    entryIcon: "palette"
                    entryTitle: Translation.tr("Panel appearance")
                    entryDescription: Translation.tr("Accent surfaces, hints and dimensions")
                    onClicked: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherAppearanceConfig.qml"))
                }
                SubPageEntryButton {
                    entryIcon: "privacy_tip"
                    entryTitle: Translation.tr("Data & privacy")
                    entryDescription: Translation.tr("Frequency, histories, favorites and recent content")
                    onClicked: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherDataConfig.qml"))
                }
            }
        }

        ContentSection {
            icon: "construction"
            title: Translation.tr("Advanced")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2

                SubPageEntryButton {
                    entryIcon: "tune"
                    entryTitle: Translation.tr("Prefixes")
                    entryDescription: Translation.tr("Prefix triggers and search engine behavior")
                    onClicked: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherPrefixesConfig.qml"))
                }
                SubPageEntryButton {
                    entryIcon: "shortcut"
                    entryTitle: Translation.tr("Aliases")
                    entryDescription: Translation.tr("Applications, commands and Search panels")
                    onClicked: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherAliasesConfig.qml"))
                }
                SubPageEntryButton {
                    entryIcon: "auto_awesome"
                    entryTitle: Translation.tr("Suggestions")
                    entryDescription: Translation.tr("Empty-query content and app suggestions")
                    onClicked: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherSuggestionsConfig.qml"))
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
