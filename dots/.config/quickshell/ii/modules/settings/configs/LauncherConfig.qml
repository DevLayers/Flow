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
            tooltip: Translation.tr("Controls how the normal result list is ranked, positioned and sized. Panel-specific options are under Search modules.")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2

                ConfigSwitch {
                    buttonIcon: "trending_up"
                    text: Translation.tr("Frequency-based ranking")
                    description: Translation.tr("Learns from launches and moves frequently used results closer to the top. Data stays on this device.")
                    checked: Config.options.search.frecency
                    onCheckedChanged: Config.options.search.frecency = checked
                }
                ConfigSwitch {
                    buttonIcon: "apps"
                    text: Translation.tr("Always list apps on empty query")
                    description: Translation.tr("Shows applications before you type instead of keeping Search as a compact empty field.")
                    checked: Config.options.search.alwaysListApps
                    onCheckedChanged: Config.options.search.alwaysListApps = checked
                }
                ConfigSwitch {
                    buttonIcon: "center_focus_strong"
                    text: Translation.tr("Center Search on Screen")
                    description: Translation.tr("Places Search at the screen center; disable it to keep the Overview-aligned position.")
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
            id: resultPrioritySection
            icon: "low_priority"
            title: Translation.tr("Result priority")
            tooltip: Translation.tr("Order the groups results are shown in, and choose which ones appear at all.")

            // ContentSection reparents its children into an inner layout, so
            // the list below reaches this by id rather than through `parent`.
            readonly property var orderedIds: Array.from(Config.options.search.sectionOrder ?? [])
                .map(entry => String(entry?.id ?? entry ?? ""))
                .filter(id => id.length > 0)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2

                NoticeBox {
                    Layout.fillWidth: true
                    materialIcon: "reorder"
                    text: Translation.tr("Drag a group to change where its results appear. Removing one hides its results entirely — add it back from the selector below.")
                }

                ConfigListView {
                    // Not a bar layout: no group owns a "centered" slot here.
                    barSection: -1
                    listModel: Config.options.search.sectionOrder
                    availableComponents: SearchResultSectionRegistry.getAvailableComponents(resultPrioritySection.orderedIds)
                    addButtonText: Translation.tr("Add group")
                    infoProvider: id => SearchResultSectionRegistry.getComponent(id)
                    // A result group is only ever an id and a position, so that
                    // is all the stored entry carries. Taking the bar's
                    // per-entry shape would write fields into config.json that
                    // mean nothing here.
                    normalizeEntry: entry => ({
                            id: entry.id
                        })
                    onUpdated: newList => {
                        Config.options.search.sectionOrder = newList;
                    }
                }
            }
        }

        ContentSection {
            icon: "extension"
            title: Translation.tr("Search workspace")
            tooltip: Translation.tr("Configure every searchable panel and see the words or prefixes that open it.")

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
            tooltip: Translation.tr("Customize explicit triggers, aliases and empty-query suggestions.")

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
