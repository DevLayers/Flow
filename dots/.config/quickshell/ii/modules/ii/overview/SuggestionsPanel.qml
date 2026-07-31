import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Qt5Compat.GraphicalEffects

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    readonly property int calculatedContentHeight: {
        let totalH = 16;
        for (let s = 0; s < suggestionsList.length; s++) {
            let sec = suggestionsList[s];
            totalH += (s === 0 ? 24 : 32);
            totalH += sec.items.length * 52;
        }
        return Math.max(160, totalH);
    }

    implicitHeight: Math.min(Config.options.search.baseHeight ?? 500, Math.max(calculatedContentHeight, contentLayout.implicitHeight + 20))

    readonly property var suggestionsList: {
        if (!Config.ready) return [];
        
        let suggestions = [];
        const maxN = Config.options.search.suggestions.maxSuggestionsPerSection;
        
        // 1. SUGGESTIONS: Apps + Commands unified by frecency
        if (Config.options.search.suggestions.showFrecency && Config.options.search.frecency) {
            let list = AppSearch.frecencyQuery("").filter(item => item && item.id);
            let scoredApps = list.map(app => {
                let rawApp = AppSearch.list.find(x => x.id === app.id);
                return {
                    name: app.name,
                    comment: app.comment || "",
                    type: Translation.tr("App"),
                    iconName: app.id,
                    appEntry: rawApp,
                    execute: () => {
                        AppUsage.recordLaunch(app.id);
                        rawApp?.launch();
                    },
                    score: AppUsage.getScore(app.id)
                };
            });
            
            // Filter items with score > 0 and sort descending
            let filtered = scoredApps.filter(item => item.score > 0).sort((a, b) => b.score - a.score);
            if (filtered.length >= 2) {
                suggestions.push({
                    title: Translation.tr("Suggestions"),
                    items: filtered.slice(0, maxN)
                });
            }
        }
        
        // 2. ALIASES: From config
        if (Config.options.search.suggestions.showAliases) {
            let aliasesConfig = Config.options.search.aliases || [];
            let mappedAliases = aliasesConfig.map(alias => ({
                name: alias.alias || "",
                comment: alias.command || "",
                type: Translation.tr("Alias"),
                iconName: "keyboard_command_key",
                iconType: 2, // Material icon
                execute: () => {
                    Quickshell.execDetached(["bash", "-c", alias.command]);
                }
            }));
            if (mappedAliases.length >= 2) {
                suggestions.push({
                    title: Translation.tr("Aliases"),
                    items: mappedAliases.slice(0, maxN)
                });
            }
        }

        // 3. APPS: All applications in alphabetical order or default frecency
        if (Config.options.search.suggestions.showApps) {
            let rawApps = AppSearch.list || [];
            let mappedApps = rawApps.map(app => ({
                name: app.name,
                comment: app.comment || "",
                type: Translation.tr("App"),
                iconName: app.id,
                appEntry: app, // Expose raw app entry for more actions
                execute: () => {
                    AppUsage.recordLaunch(app.id);
                    app.launch();
                }
            }));
            if (mappedApps.length >= 2) {
                suggestions.push({
                    title: Translation.tr("Applications"),
                    items: mappedApps.slice(0, maxN)
                });
            }
        }

        // 4. COMMANDS: Comandos fixos do sistema
        if (Config.options.search.suggestions.showCommands) {
            let fixedCommands = [
                { name: ":lock", comment: Translation.tr("Lock session"), icon: "lock", execute: () => Quickshell.execDetached(["hyprlock"]) },
                { name: ":reboot", comment: Translation.tr("Reboot system"), icon: "restart_alt", execute: () => Quickshell.execDetached(["systemctl", "reboot"]) },
                { name: ":shutdown", comment: Translation.tr("Shutdown system"), icon: "power_settings_new", execute: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
                { name: ":logout", comment: Translation.tr("Exit Hyprland"), icon: "logout", execute: () => Quickshell.execDetached(["hyprctl", "dispatch", "exit"]) }
            ];
            let mappedCommands = fixedCommands.map(cmd => ({
                name: cmd.name,
                comment: cmd.comment,
                type: Translation.tr("Command"),
                iconName: cmd.icon,
                iconType: 2, // Material icon
                execute: cmd.execute
            }));
            if (mappedCommands.length >= 2) {
                suggestions.push({
                    title: Translation.tr("Commands"),
                    items: mappedCommands.slice(0, maxN)
                });
            }
        }

        return suggestions;
    }

    readonly property var flatItems: {
        let list = [];
        let sectionOffset = 0;
        for (let s = 0; s < root.suggestionsList.length; s++) {
            let sec = root.suggestionsList[s];
            for (let i = 0; i < sec.items.length; i++) {
                list.push({
                    sectionIndex: s,
                    itemIndex: i,
                    flatIndex: list.length,
                    data: sec.items[i]
                });
            }
        }
        return list;
    }

    property int activeFlatIndex: 0

    function focusFirst() {
        activeFlatIndex = 0;
    }

    function navigateUp() {
        if (root.flatItems.length === 0) return;
        if (activeFlatIndex > 0) {
            activeFlatIndex--;
            ensureVisible();
        }
    }

    function navigateDown() {
        if (root.flatItems.length === 0) return;
        if (activeFlatIndex < root.flatItems.length - 1) {
            activeFlatIndex++;
            ensureVisible();
        }
    }

    function ensureVisible() {
        // Calculate scroll bounds for the selected item button
        // Standard item height is 48, with margins and spacing. Let's compute approx layout height.
        let itemIndexInGroup = activeFlatIndex;
        let itemY = 0;
        
        // Approximate Y offset calculation based on items
        let currentFlatIndex = 0;
        for (let s = 0; s < root.suggestionsList.length; s++) {
            let sec = root.suggestionsList[s];
            if (activeFlatIndex >= currentFlatIndex && activeFlatIndex < currentFlatIndex + sec.items.length) {
                // Section header y-offset estimate (24px) + items offset (48px + spacing)
                itemY += 24 + (activeFlatIndex - currentFlatIndex) * 50;
                break;
            } else {
                itemY += 24 + sec.items.length * 50 + 12; // Add section spacing
                currentFlatIndex += sec.items.length;
            }
        }

        const itemHeight = 48;
        const viewTop = suggestionsFlickable.contentY;
        const viewBottom = viewTop + suggestionsFlickable.height;

        if (itemY < viewTop + 10) {
            suggestionsFlickable.contentY = Math.max(0, itemY - 10);
        } else if (itemY + itemHeight > viewBottom - 10) {
            // Include an extra 40px buffer for bottom margins/spacing to prevent clipping the last element
            suggestionsFlickable.contentY = Math.min(suggestionsFlickable.contentHeight - suggestionsFlickable.height, itemY + itemHeight - suggestionsFlickable.height + 40);
        }
    }

    function activateSelected() {
        if (root.flatItems.length > 0 && activeFlatIndex >= 0 && activeFlatIndex < root.flatItems.length) {
            let selectedItem = root.flatItems[activeFlatIndex];
            if (selectedItem && selectedItem.data && selectedItem.data.execute) {
                selectedItem.data.execute();
            }
        }
        GlobalStates.overviewOpen = false;
    }

    Flickable {
        id: suggestionsFlickable
        anchors.fill: parent
        clip: true
        layer.enabled: suggestionsFlickable.height < contentHeight
        layer.effect: OpacityMask {
            maskSource: Item {
                id: maskRoot
                width: suggestionsFlickable.width
                height: suggestionsFlickable.height

                property color topFadeColor: suggestionsFlickable.atYBeginning ? "white" : "transparent"
                property color bottomFadeColor: suggestionsFlickable.atYEnd ? "white" : "transparent"

                Behavior on topFadeColor {
                    ColorAnimation { duration: 100 }
                }
                Behavior on bottomFadeColor {
                    ColorAnimation { duration: 100 }
                }

                Column {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        width: parent.width
                        height: 36
                        color: "transparent"
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: maskRoot.topFadeColor }
                            GradientStop { position: 1.0; color: "white" }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.max(0, parent.height - 72)
                        color: "white"
                    }

                    Rectangle {
                        width: parent.width
                        height: 36
                        color: "transparent"
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "white" }
                            GradientStop { position: 1.0; color: maskRoot.bottomFadeColor }
                        }
                    }
                }
            }
        }

        contentWidth: width
        contentHeight: contentLayout.height

        ColumnLayout {
            id: contentLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 0
            anchors.bottomMargin: 8
            spacing: 8

            Repeater {
                model: root.suggestionsList

                delegate: ColumnLayout {
                    id: sectionColumn
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    // Section header
                    StyledText {
                        text: sectionColumn.modelData.title
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.topMargin: index === 0 ? 0 : 8
                    }

                    // Section items
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: sectionColumn.modelData.items

                            delegate: SearchItem {
                                id: itemButton
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                // Calculate flat/sequential linear index
                                readonly property int linearIndex: {
                                    let offset = 0;
                                    for (let s = 0; s < sectionColumn.index; s++) {
                                        offset += root.suggestionsList[s].items.length;
                                    }
                                    return offset + index;
                                }

                                listIndex: linearIndex
                                listCount: root.flatItems.length
                                listCurrentIndex: root.activeFlatIndex
                                isFirst: index === 0
                                isLast: index === sectionColumn.modelData.items.length - 1

                                entry: itemButton.modelData.appEntry || { comment: itemButton.modelData.comment }
                                itemType: itemButton.modelData.type
                                itemName: itemButton.modelData.name
                                iconName: itemButton.modelData.iconName
                                iconType: itemButton.modelData.iconType === 2 ? 0 : (itemButton.modelData.iconName ? 2 : 3)
                                materialSymbol: itemButton.modelData.iconType === 2 ? itemButton.modelData.iconName : ""

                                itemClickActionName: Translation.tr("Open")
                                itemExecute: () => {
                                    itemButton.modelData.execute();
                                    GlobalStates.overviewOpen = false;
                                }

                                Connections {
                                    target: root.parent?.parent?.parent?.parent // SearchWidget root
                                    ignoreUnknownSignals: true
                                    function onRequestToggleActions() {
                                        if (itemButton.linearIndex === root.activeFlatIndex) {
                                            itemButton.actionPanelOpen = !itemButton.actionPanelOpen;
                                            itemButton.actionSelectedIndex = 0;
                                            if (itemButton.actionPanelOpen) {
                                                itemButton.forceActiveFocus();
                                            } else {
                                                // Focus text input via SearchWidget
                                                root.parent?.parent?.parent?.parent?.focusSearchInput();
                                            }
                                        }
                                    }
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
                                        itemButton.actionPanelOpen = !itemButton.actionPanelOpen;
                                        itemButton.actionSelectedIndex = 0;
                                        if (itemButton.actionPanelOpen) {
                                            itemButton.forceActiveFocus();
                                        } else {
                                            root.parent?.parent?.parent?.parent?.focusSearchInput();
                                        }
                                        event.accepted = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
