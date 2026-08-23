pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "../../common/functions/emojiHues.js" as EmojiHues

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: 0
    property string selectedCategory: Config.options.search.modules.emojis.defaultCategory

    readonly property int gridColumns: Math.max(4, Config.options.search.modules.emojis.gridColumns)
    readonly property real gridSpacing: Appearance.sizes.elevationMargin / 2
    readonly property var categories: [
        { id: "all", label: Translation.tr("All") },
        { id: "people", label: Translation.tr("People") },
        { id: "nature", label: Translation.tr("Nature") },
        { id: "food", label: Translation.tr("Food") },
        { id: "objects", label: Translation.tr("Objects") },
        { id: "symbols", label: Translation.tr("Symbols") }
    ]
    readonly property var filteredEntries: root.filteredEmojiEntries()
    readonly property var selectedEntry: root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length
        ? root.filteredEntries[root.selectedIndex]
        : null
    readonly property string statusText: root.selectedEntry
        ? root.selectedEntry.name
        : Translation.tr("%1 emojis").arg(String(root.filteredEntries.length))

    implicitWidth: 720
    implicitHeight: scaffold.implicitHeight

    function filterByCategory(entries) {
        if (root.selectedCategory === "all")
            return entries;
        return entries.filter(entry => entry.category === root.selectedCategory);
    }

    function filteredEmojiEntries() {
        const query = root.searchQuery.trim();
        const allEntries = Array.from(Emojis.entries ?? []);
        if (query.length > 0) {
            const matchingRawEntries = new Set(Emojis.fuzzyQuery(query));
            return root.filterByCategory(allEntries.filter(entry => matchingRawEntries.has(entry.raw)));
        }

        if (Config.options.search.modules.emojis.showRecents) {
            const recent = Array.from(Persistent.states.search.recentEmojis ?? []);
            const recentEntries = recent.map(raw => Emojis.entryFor(raw)).filter(Boolean);
            if (recentEntries.length > 0)
                return root.filterByCategory(recentEntries);
        }
        return root.filterByCategory(allEntries);
    }

    function skinToneEmoji(entry) {
        const emoji = String(entry?.emoji ?? "");
        const tone = String(Config.options.search.modules.emojis.skinTone ?? "none");
        const modifiers = {
            light: "\ud83c\udffb",
            mediumLight: "\ud83c\udffc",
            medium: "\ud83c\udffd",
            mediumDark: "\ud83c\udffe",
            dark: "\ud83c\udfff"
        };
        if (tone === "none" || !modifiers[tone] || entry?.category !== "people" || /[\ud83c\udffb-\ud83c\udfff]/.test(emoji))
            return emoji;
        return emoji + modifiers[tone];
    }

    function remember(entry) {
        if (!entry)
            return;
        const previous = Array.from(Persistent.states.search.recentEmojis ?? []).filter(raw => raw !== entry.raw);
        Persistent.states.search.recentEmojis = [entry.raw].concat(previous).slice(0, 32);
    }

    function clampSelection() {
        if (root.filteredEntries.length === 0) {
            root.selectedIndex = -1;
            return;
        }
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.filteredEntries.length - 1));
    }

    function ensureVisible() {
        if (root.selectedIndex >= 0)
            emojiGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
    }

    function navigateUp(): bool {
        if (root.selectedIndex < root.gridColumns)
            return false;
        root.selectedIndex -= root.gridColumns;
        root.ensureVisible();
        return true;
    }

    function navigateDown(): bool {
        if (root.selectedIndex < 0 || root.selectedIndex + root.gridColumns >= root.filteredEntries.length)
            return false;
        root.selectedIndex += root.gridColumns;
        root.ensureVisible();
        return true;
    }

    function navigateLeft(): bool {
        if (root.selectedIndex <= 0)
            return false;
        root.selectedIndex--;
        root.ensureVisible();
        return true;
    }

    function navigateRight(): bool {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.filteredEntries.length - 1)
            return false;
        root.selectedIndex++;
        root.ensureVisible();
        return true;
    }

    function activateSelected(): bool {
        const entry = root.selectedEntry;
        if (!entry)
            return false;
        Quickshell.clipboardText = root.skinToneEmoji(entry);
        root.remember(entry);
        GlobalStates.overviewOpen = false;
        return true;
    }

    function focusInput(): bool {
        return false;
    }

    function selectCategory(category) {
        root.selectedCategory = category;
        Config.options.search.modules.emojis.defaultCategory = category;
        root.selectedIndex = 0;
    }

    onSearchQueryChanged: root.selectedIndex = 0
    onFilteredEntriesChanged: root.clampSelection()

    Component.onCompleted: {
        Emojis.load();
        root.clampSelection();
    }

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Emojis")
        icon: "mood"
        accent: true
        statusText: root.statusText
        primaryHint: ({ label: Translation.tr("Copy"), keys: ["↵"] })
        hints: [{ label: Translation.tr("Navigate"), keys: ["↑", "↓", "←", "→"] }]

        ColumnLayout {
            width: parent.width
            spacing: Appearance.sizes.elevationMargin

            RowLayout {
                Layout.fillWidth: true
                spacing: root.gridSpacing

                Repeater {
                    model: root.categories

                    delegate: RippleButton {
                        required property var modelData
                        implicitWidth: categoryText.implicitWidth + Appearance.sizes.elevationMargin * 2
                        implicitHeight: categoryText.implicitHeight + Appearance.sizes.elevationMargin
                        buttonRadius: Appearance.rounding.full
                        colBackground: root.selectedCategory === modelData.id
                            ? Appearance.colors.colPrimaryContainer
                            : Appearance.colors.colSurfaceContainerHigh
                        colBackgroundHover: root.selectedCategory === modelData.id
                            ? Appearance.colors.colPrimaryContainerHover
                            : Appearance.colors.colSurfaceContainerHighHover
                        colRipple: root.selectedCategory === modelData.id
                            ? Appearance.colors.colPrimaryContainerActive
                            : Appearance.colors.colSurfaceContainerHighActive
                        onClicked: root.selectCategory(modelData.id)

                        StyledText {
                            id: categoryText
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.selectedCategory === modelData.id
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: root.searchQuery.trim().length === 0 && Config.options.search.modules.emojis.showRecents
                        && Persistent.states.search.recentEmojis.length > 0
                        ? Translation.tr("Recent")
                        : root.categories.find(category => category.id === root.selectedCategory)?.label ?? Translation.tr("All")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
                }

                StyledText {
                    text: String(root.filteredEntries.length)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }

            GridView {
                id: emojiGrid
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.sizes.elevationMargin * 32
                clip: true
                model: root.filteredEntries
                cellWidth: (width + root.gridSpacing) / root.gridColumns
                cellHeight: Appearance.sizes.elevationMargin * 5

                delegate: Item {
                    required property int index
                    required property var modelData
                    width: emojiGrid.cellWidth - root.gridSpacing
                    height: emojiGrid.cellHeight - root.gridSpacing

                    RippleButton {
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.normal
                        colBackground: root.selectedIndex === index
                            ? ColorUtils.categoryAccent(EmojiHues.hueForCategory(modelData.category), 1, Appearance.m3colors.m3primary)
                            : Appearance.colors.colSurfaceContainerHigh
                        colBackgroundHover: Appearance.colors.colSurfaceContainerHighHover
                        colRipple: Appearance.colors.colPrimaryContainerActive
                        onClicked: {
                            root.selectedIndex = index;
                            root.activateSelected();
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: root.skinToneEmoji(modelData)
                            font.pixelSize: Appearance.font.pixelSize.huge
                            color: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.filteredEntries.length === 0
                    text: Translation.tr("No emojis found")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
