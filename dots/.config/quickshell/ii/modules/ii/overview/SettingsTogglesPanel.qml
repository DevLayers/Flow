pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.services.ai
import qs.services.ai.blocks
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string searchQuery: ""
    property int activeSection: 0
    property int selectedIndex: 0

    readonly property string normalizedQuery: root.searchQuery.trim()
    readonly property var settingRows: {
        if (!Ai.settingsIntegration.ready)
            return [];
        return Ai.settingsIntegration.search(root.normalizedQuery, 100);
    }
    readonly property var pageRows: {
        if (!Config.options.search.modules.settingsToggles.showPages)
            return [];
        const tokens = root.normalizedQuery.toLocaleLowerCase().split(/\s+/).filter(token => token.length > 0);
        const output = [];
        for (const page of SettingsPageRegistry.pages) {
            const candidates = [Object.assign({}, page, { displayName: Translation.tr(page.name), subPage: "", parentName: "" })];
            for (const subPage of page.subPages ?? []) {
                const fileName = String(subPage).split("/").pop().replace(/Config\.qml$/, "");
                candidates.push({
                    id: page.id,
                    icon: page.icon,
                    displayName: fileName,
                    subPage,
                    parentName: Translation.tr(page.name),
                    aliases: []
                });
            }
            for (const candidate of candidates) {
                const haystack = [candidate.displayName, candidate.parentName, ...(candidate.aliases ?? []), candidate.id]
                    .join(" ").toLocaleLowerCase();
                if (tokens.length === 0 || tokens.every(token => haystack.includes(token)))
                    output.push(candidate);
            }
        }
        return output;
    }
    readonly property var activeRows: root.activeSection === 0 ? root.settingRows : root.pageRows
    readonly property bool indexing: !Ai.settingsIntegration.ready
    readonly property string statusText: root.indexing
        ? Translation.tr("Indexing settings…")
        : root.activeSection === 0
            ? Translation.tr("%1 controls").arg(String(root.settingRows.length))
            : Translation.tr("%1 pages").arg(String(root.pageRows.length))

    implicitWidth: 720
    implicitHeight: scaffold.implicitHeight

    function focusInput(): bool {
        // The Overview search bar is the panel's filter input and should keep
        // receiving text while this panel owns the result surface.
        return false;
    }

    function clampSelection() {
        if (root.activeRows.length === 0) {
            root.selectedIndex = -1;
            return;
        }
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.activeRows.length - 1));
    }

    function selectedDelegate() {
        return panelList.itemAtIndex(root.selectedIndex)?.item ?? null;
    }

    function navigateUp(): bool {
        if (root.activeRows.length === 0)
            return false;
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        panelList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateDown(): bool {
        if (root.activeRows.length === 0)
            return false;
        root.selectedIndex = Math.min(root.activeRows.length - 1, root.selectedIndex + 1);
        panelList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateLeft(): bool {
        const row = root.selectedDelegate();
        return row && typeof row.navigateLeft === "function" ? row.navigateLeft() : false;
    }

    function navigateRight(): bool {
        const row = root.selectedDelegate();
        return row && typeof row.navigateRight === "function" ? row.navigateRight() : false;
    }

    function activateSelected(): bool {
        const row = root.selectedDelegate();
        return row && typeof row.activate === "function" ? row.activate() : false;
    }

    function toggleSection(): bool {
        if (root.pageRows.length === 0)
            return false;
        root.activeSection = root.activeSection === 0 ? 1 : 0;
        root.selectedIndex = 0;
        return true;
    }

    onActiveRowsChanged: root.clampSelection()
    onActiveSectionChanged: root.clampSelection()

    Component.onCompleted: {
        if (!Ai.settingsIntegration.ready)
            Ai.settingsIntegration.ensureIndex();
    }

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Settings")
        icon: "settings"
        accent: true
        statusText: root.statusText
        primaryHint: ({ label: Translation.tr("Open"), keys: ["↵"] })
        hints: [
            { label: Translation.tr("Adjust"), keys: ["←", "→"] },
            { label: Translation.tr("Section"), keys: ["Tab"] }
        ]

        ColumnLayout {
            width: parent.width
            spacing: Appearance.sizes.elevationMargin

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2

                Repeater {
                    model: [
                        { label: Translation.tr("Controls"), section: 0 },
                        { label: Translation.tr("Pages"), section: 1 }
                    ]

                    delegate: RippleButton {
                        required property var modelData
                        visible: modelData.section === 0 || Config.options.search.modules.settingsToggles.showPages
                        implicitHeight: Appearance.font.pixelSize.large + Appearance.sizes.elevationMargin
                        implicitWidth: tabLabel.implicitWidth + Appearance.sizes.elevationMargin * 2
                        buttonRadius: Appearance.rounding.full
                        colBackground: root.activeSection === modelData.section
                            ? Appearance.colors.colPrimaryContainer
                            : Appearance.colors.colSurfaceContainerHigh
                        colBackgroundHover: root.activeSection === modelData.section
                            ? Appearance.colors.colPrimaryContainerHover
                            : Appearance.colors.colSurfaceContainerHighHover
                        colRipple: root.activeSection === modelData.section
                            ? Appearance.colors.colPrimaryContainerActive
                            : Appearance.colors.colSurfaceContainerHighActive
                        onClicked: {
                            root.activeSection = modelData.section;
                            root.selectedIndex = 0;
                        }

                        StyledText {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.activeSection === modelData.section
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            ListView {
                id: panelList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 460)
                Layout.minimumHeight: emptyState.implicitHeight
                clip: true
                spacing: Appearance.sizes.elevationMargin / 2
                model: root.activeRows
                visible: root.activeRows.length > 0

                delegate: Loader {
                    id: rowLoader
                    required property int index
                    required property var modelData
                    width: panelList.width
                    sourceComponent: root.activeSection === 0 ? settingRow : pageRow

                    Component {
                        id: settingRow

                        AiSettingResultCard {
                            width: rowLoader.width
                            setting: rowLoader.modelData
                            compact: false
                            launcherStyle: false
                            listIndex: rowLoader.index
                            listCount: panelList.count
                            listCurrentIndex: root.selectedIndex
                        }
                    }

                    Component {
                        id: pageRow

                        RippleButton {
                            implicitWidth: rowLoader.width
                            implicitHeight: pageRowContent.implicitHeight + Appearance.sizes.elevationMargin * 2
                            buttonRadius: Appearance.rounding.normal
                            colBackground: root.selectedIndex === rowLoader.index
                                ? Appearance.colors.colPrimaryContainer
                                : Appearance.colors.colSurfaceContainerHigh
                            colBackgroundHover: root.selectedIndex === rowLoader.index
                                ? Appearance.colors.colPrimaryContainerHover
                                : Appearance.colors.colSurfaceContainerHighHover
                            colRipple: root.selectedIndex === rowLoader.index
                                ? Appearance.colors.colPrimaryContainerActive
                                : Appearance.colors.colSurfaceContainerHighActive
                            onClicked: GlobalStates.openSettingsPage(rowLoader.modelData.id, rowLoader.modelData.subPage)

                            function activate(): bool {
                                GlobalStates.openSettingsPage(rowLoader.modelData.id, rowLoader.modelData.subPage);
                                return true;
                            }

                            RowLayout {
                                id: pageRowContent
                                anchors.fill: parent
                                anchors.margins: Appearance.sizes.elevationMargin
                                spacing: Appearance.sizes.elevationMargin

                                MaterialSymbol {
                                    text: rowLoader.modelData.icon
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: root.selectedIndex === rowLoader.index
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : Appearance.colors.colOnSurface
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: rowLoader.modelData.displayName
                                        elide: Text.ElideRight
                                        color: root.selectedIndex === rowLoader.index
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colOnSurface
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: rowLoader.modelData.parentName.length > 0
                                        text: rowLoader.modelData.parentName
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: root.selectedIndex === rowLoader.index
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colSubtext
                                    }
                                }

                                MaterialSymbol {
                                    text: "arrow_outward"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: root.selectedIndex === rowLoader.index
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : Appearance.colors.colOnSurfaceVariant
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                id: emptyState
                Layout.fillWidth: true
                visible: root.activeRows.length === 0
                text: root.indexing
                    ? Translation.tr("Preparing the settings index…")
                    : Translation.tr("No matches for \"%1\"").arg(root.normalizedQuery)
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
