pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/emojiHues.js" as EmojiHues

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: 0
    property string selectedCategory: Config.options.search.modules.emojis.defaultCategory
    property string noticeText: ""

    readonly property bool supportsSectionToggle: true
    readonly property int gridColumns: Math.max(5, Math.min(8, Config.options.search.modules.emojis.gridColumns))
    readonly property int maxVisibleEntries: 180
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
        if (Config.options.search.modules.emojis.showRecents && (Persistent.states.search.recentEmojis?.length ?? 0) > 0)
            rows.splice(1, 0, { id: "recent", label: Translation.tr("Recent"), icon: "history" });
        return rows;
    }
    readonly property var filteredEntries: root.filteredEmojiEntries()
    readonly property var selectedEntry: root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length
        ? root.filteredEntries[root.selectedIndex]
        : null
    readonly property string selectedCategoryLabel: root.categories.find(category => category.id === root.selectedCategory)?.label
        ?? Translation.tr("All categories")
    readonly property string statusText: root.noticeText.length > 0
        ? root.noticeText
        : (root.selectedEntry
            ? root.skinToneEmoji(root.selectedEntry) + "  " + String(root.selectedEntry.name ?? "")
            : (Emojis.loading ? Translation.tr("Preparing emoji library…") : Translation.tr("No emojis found")))

    implicitWidth: Config.options.search.appearance.panelWidth
    implicitHeight: scaffold.implicitHeight

    function filterByCategory(entries) {
        if (root.selectedCategory === "all")
            return entries;
        if (root.selectedCategory === "recent") {
            const available = new Set(entries.map(entry => entry.raw));
            return Array.from(Persistent.states.search.recentEmojis ?? [])
                .filter(raw => available.has(raw)).map(raw => Emojis.entryFor(raw)).filter(Boolean);
        }
        return entries.filter(entry => entry.category === root.selectedCategory);
    }

    function filteredEmojiEntries() {
        const query = root.searchQuery.trim();
        const allEntries = Array.from(Emojis.entries ?? []);
        if (query.length > 0) {
            const matchingRawEntries = new Set(Emojis.fuzzyQuery(query));
            return root.filterByCategory(allEntries.filter(entry => matchingRawEntries.has(entry.raw))).slice(0, root.maxVisibleEntries);
        }
        return root.filterByCategory(allEntries).slice(0, root.maxVisibleEntries);
    }

    function skinToneEmoji(entry) {
        const emoji = String(entry?.emoji ?? "");
        const tone = String(Config.options.search.modules.emojis.skinTone ?? "none");
        const modifiers = { light: "🏻", mediumLight: "🏼", medium: "🏽", mediumDark: "🏾", dark: "🏿" };
        if (tone === "none" || !modifiers[tone] || entry?.category !== "people" || /[🏻-🏿]/.test(emoji))
            return emoji;
        return emoji + modifiers[tone];
    }

    function toneLabel() {
        const labels = {
            none: Translation.tr("Default tone"), light: Translation.tr("Light tone"),
            mediumLight: Translation.tr("Medium-light tone"), medium: Translation.tr("Medium tone"),
            mediumDark: Translation.tr("Medium-dark tone"), dark: Translation.tr("Dark tone")
        };
        return labels[String(Config.options.search.modules.emojis.skinTone ?? "none")] ?? labels.none;
    }

    function cycleTone() {
        const tones = ["none", "light", "mediumLight", "medium", "mediumDark", "dark"];
        const current = String(Config.options.search.modules.emojis.skinTone ?? "none");
        Config.options.search.modules.emojis.skinTone = tones[(tones.indexOf(current) + 1) % tones.length];
        root.showNotice(root.toneLabel());
    }

    function remember(entry) {
        if (!entry)
            return;
        const previous = Array.from(Persistent.states.search.recentEmojis ?? []).filter(raw => raw !== entry.raw);
        Persistent.states.search.recentEmojis = [entry.raw].concat(previous).slice(0, 32);
    }
    function clampSelection() {
        root.selectedIndex = root.filteredEntries.length === 0 ? -1 : Math.max(0, Math.min(root.selectedIndex, root.filteredEntries.length - 1));
    }
    function ensureVisible() {
        if (root.selectedIndex >= 0)
            emojiGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
    }
    function navigateUp(): bool {
        if (root.selectedIndex >= root.gridColumns)
            root.selectedIndex -= root.gridColumns;
        root.ensureVisible();
        return true;
    }
    function navigateDown(): bool {
        if (root.selectedIndex >= 0 && root.selectedIndex + root.gridColumns < root.filteredEntries.length)
            root.selectedIndex += root.gridColumns;
        root.ensureVisible();
        return true;
    }
    function navigateLeft(): bool {
        if (root.selectedIndex > 0)
            root.selectedIndex--;
        root.ensureVisible();
        return true;
    }
    function navigateRight(): bool {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length - 1)
            root.selectedIndex++;
        root.ensureVisible();
        return true;
    }
    function activateSelected(): bool {
        if (!root.selectedEntry)
            return false;
        const emoji = root.skinToneEmoji(root.selectedEntry);
        Quickshell.clipboardText = emoji;
        root.remember(root.selectedEntry);
        root.showNotice(Translation.tr("%1 copied to clipboard").arg(emoji));
        return true;
    }
    function copySelected(): bool { return root.activateSelected(); }
    function focusInput(): bool { return false; }
    function toggleSection(): bool {
        const current = root.categories.findIndex(category => category.id === root.selectedCategory);
        root.selectCategory(root.categories[(current + 1) % root.categories.length].id);
        return true;
    }
    function selectCategory(category) {
        root.selectedCategory = category;
        Config.options.search.modules.emojis.defaultCategory = category;
        root.selectedIndex = 0;
    }
    function showNotice(message) {
        root.noticeText = String(message ?? "");
        noticeTimer.restart();
    }

    onSearchQueryChanged: root.selectedIndex = 0
    onFilteredEntriesChanged: root.clampSelection()
    Component.onCompleted: { Emojis.load(); root.clampSelection(); }

    Timer { id: noticeTimer; interval: 3200; onTriggered: root.noticeText = "" }

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Emojis")
        icon: "mood"
        accent: true
        showStatus: true
        statusText: root.statusText
        primaryHint: ({ label: Translation.tr("Copy"), keys: ["↵"] })
        hints: [
            { label: Translation.tr("Category"), keys: ["Tab"] },
            { label: Translation.tr("Navigate"), keys: ["↑", "↓", "←", "→"] }
        ]

        ColumnLayout {
            width: parent.width
            height: parent.height
            spacing: Appearance.sizes.elevationMargin

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2
                StyledText {
                    Layout.fillWidth: true
                    text: root.filteredEntries.length >= root.maxVisibleEntries
                        ? Translation.tr("%1+ results").arg(String(root.filteredEntries.length))
                        : Translation.tr("%1 results").arg(String(root.filteredEntries.length))
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }
                RippleButton {
                    implicitWidth: toneContent.implicitWidth + Appearance.sizes.elevationMargin * 2
                    implicitHeight: Appearance.sizes.elevationMargin * 3
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSurfaceContainerHigh
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                    colRipple: Appearance.colors.colSurfaceContainerHighestActive
                    onClicked: root.cycleTone()
                    RowLayout {
                        id: toneContent
                        anchors.centerIn: parent
                        spacing: Appearance.sizes.elevationMargin / 2
                        StyledText { text: root.skinToneEmoji({ emoji: "👋", category: "people" }); font.pixelSize: Appearance.font.pixelSize.normal }
                        StyledText { text: root.toneLabel(); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colOnSurface }
                    }
                }
                StyledComboBox {
                    Layout.preferredWidth: Appearance.sizes.elevationMargin * 18
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
                visible: root.filteredEntries.length > 0
                clip: true
                reuseItems: true
                cacheBuffer: cellHeight
                model: root.filteredEntries
                cellWidth: width / root.gridColumns
                cellHeight: cellWidth

                delegate: Item {
                    required property int index
                    required property var modelData
                    width: emojiGrid.cellWidth
                    height: emojiGrid.cellHeight
                    RippleButton {
                        anchors.fill: parent
                        anchors.margins: root.gridSpacing / 2
                        buttonRadius: root.selectedIndex === index ? Appearance.rounding.large : Appearance.rounding.normal
                        colBackground: root.selectedIndex === index
                            ? ColorUtils.categoryAccent(EmojiHues.hueForCategory(modelData.category), 1, Appearance.m3colors.m3primary)
                            : Appearance.colors.colSurfaceContainerHigh
                        colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                        colRipple: Appearance.colors.colPrimaryContainerActive
                        onClicked: root.selectedIndex = index
                        onDoubleClicked: root.activateSelected()
                        StyledText {
                            anchors.centerIn: parent
                            text: root.skinToneEmoji(modelData)
                            font.pixelSize: Appearance.font.pixelSize.huge
                            color: Appearance.colors.colOnSurface
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.filteredEntries.length === 0
                spacing: Appearance.sizes.elevationMargin / 2
                MaterialLoadingIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Appearance.sizes.elevationMargin * 4
                    implicitHeight: implicitWidth
                    visible: Emojis.loading
                }
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !Emojis.loading
                    text: "sentiment_dissatisfied"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Emojis.loading ? Translation.tr("Preparing emoji library…") : Translation.tr("No emojis found")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
