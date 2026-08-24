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
    // A GridView virtualizes delegates, but handing it thousands of plain
    // JavaScript objects still stalls its model reset. The full corpus stays
    // searchable; the browse view uses a responsive, bounded window.
    readonly property int maxVisibleEntries: 240
    readonly property real gridSpacing: Appearance.sizes.elevationMargin / 2
    readonly property var categories: {
        const rows = [
            { id: "all", label: Translation.tr("All categories"), icon: "category" },
            { id: "people", label: Translation.tr("People"), icon: "face" },
            { id: "nature", label: Translation.tr("Nature"), icon: "nature" },
            { id: "food", label: Translation.tr("Food"), icon: "restaurant" },
            { id: "objects", label: Translation.tr("Objects"), icon: "lightbulb" },
            { id: "symbols", label: Translation.tr("Symbols"), icon: "tag" }
        ];
        if (Config.options.search.modules.emojis.showRecents
                && (Persistent.states.search.recentEmojis?.length ?? 0) > 0)
            rows.splice(1, 0, { id: "recent", label: Translation.tr("Recent"), icon: "history" });
        return rows;
    }
    readonly property var filteredEntries: root.filteredEmojiEntries()
    readonly property var selectedEntry: root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length
        ? root.filteredEntries[root.selectedIndex]
        : null
    readonly property string selectedCategoryLabel: root.categories.find(category => category.id === root.selectedCategory)?.label
        ?? Translation.tr("All categories")
    implicitWidth: 720
    implicitHeight: scaffold.implicitHeight

    function filterByCategory(entries) {
        if (root.selectedCategory === "all")
            return entries;
        if (root.selectedCategory === "recent") {
            const available = new Set(entries.map(entry => entry.raw));
            return Array.from(Persistent.states.search.recentEmojis ?? [])
                .filter(raw => available.has(raw))
                .map(raw => Emojis.entryFor(raw))
                .filter(Boolean);
        }
        return entries.filter(entry => entry.category === root.selectedCategory);
    }

    function filteredEmojiEntries() {
        const query = root.searchQuery.trim();
        const allEntries = Emojis.entries ?? [];
        if (query.length > 0) {
            const matchingRawEntries = new Set(Emojis.fuzzyQuery(query));
            return root.filterByCategory(allEntries.filter(entry => matchingRawEntries.has(entry.raw)))
                .slice(0, root.maxVisibleEntries);
        }

        return root.filterByCategory(allEntries).slice(0, root.maxVisibleEntries);
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
        showStatus: true
        statusText: Emojis.loading
            ? Translation.tr("Loading emojis…")
            : root.selectedEntry
            ? root.skinToneEmoji(root.selectedEntry) + "  " + String(root.selectedEntry.name ?? "")
            : Translation.tr("No emojis found")
        primaryHint: ({ label: Translation.tr("Copy"), keys: ["↵"] })
        hints: [{ label: Translation.tr("Navigate"), keys: ["↑", "↓", "←", "→"] }]

        ColumnLayout {
            width: parent.width
            height: parent.height
            spacing: Appearance.sizes.elevationMargin

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.filteredEntries.length >= root.maxVisibleEntries
                        ? Translation.tr("Results  %1+").arg(String(root.filteredEntries.length))
                        : Translation.tr("Results  %1").arg(String(root.filteredEntries.length))
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledComboBox {
                    id: categoryPicker
                    Layout.preferredWidth: Appearance.sizes.elevationMargin * 20
                    Layout.fillWidth: false
                    model: root.categories
                    textRole: "label"
                    valueRole: "id"
                    buttonIcon: "category"
                    currentIndex: Math.max(0, root.categories.findIndex(category => category.id === root.selectedCategory))
                    onActivated: index => root.selectCategory(root.categories[index].id)
                }
            }

            GridView {
                id: emojiGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                reuseItems: true
                cacheBuffer: cellHeight * 2
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
                    text: Emojis.loading ? Translation.tr("Loading emojis…") : Translation.tr("No emojis found")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
