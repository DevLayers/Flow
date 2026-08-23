pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Singleton {
    id: root

    // This registry is intentionally declarative: the Search surface, aliases and
    // prefix handling consume this data instead of maintaining parallel lists.
    readonly property var panels: [
        { id: "clipboard", source: "ClipboardPanel.qml", prefixKey: "clipboard", keywords: ["clipboard", "clip", "paste", "copiar", "area de transferencia"], label: qsTr("Clipboard"), icon: "content_paste", width: () => Config.options.search.clipboard.panelWidth ?? 860, enabled: () => Config.options.search.modules.clipboard, accent: false, focusMode: "list", queryProperty: "searchQuery" },
        { id: "bluetooth", source: "BluetoothPanel.qml", prefixKey: "bluetooth", keywords: ["bluetooth", "bt", "fone"], label: qsTr("Bluetooth"), icon: "bluetooth", width: () => Config.options.search.clipboard.panelWidth ?? 860, enabled: () => Config.options.search.modules.bluetooth, accent: false, focusMode: "list", queryProperty: "searchQuery" },
        { id: "translator", source: "TranslatorPanel.qml", prefixKey: "translator", keywords: ["translator", "translate", "tradutor", "traduzir"], label: qsTr("Translator"), icon: "translate", width: () => Config.options.search.clipboard.panelWidth ?? 860, enabled: () => Config.options.search.modules.translator, accent: false, focusMode: "input", queryProperty: "searchQuery" },
        { id: "mediaDownloader", source: "MediaDownloaderPanel.qml", prefixKey: "mediaDownloader", keywords: ["download", "video", "media"], label: qsTr("Media Downloader"), icon: "download", width: () => Config.options.search.clipboard.panelWidth ?? 860, enabled: () => Config.options.search.modules.mediaDownloader && Config.options.mediaDownloader.enabled, accent: false, focusMode: "input", queryProperty: "searchQuery" },
        { id: "materialSymbols", source: "MaterialSymbolsPanel.qml", prefixKey: "materialSymbols", keywords: ["material", "symbols", "icons"], label: qsTr("Material Symbols"), icon: "font_download", width: () => 380, enabled: () => Config.options.search.modules.materialSymbols, accent: false, focusMode: "grid", queryProperty: "searchQuery" },
        { id: "ai", source: "AiChatPanel.qml", prefixKey: "ai", keywords: ["ai", "chat", "assistant"], label: qsTr("AI Chat"), icon: "auto_awesome", width: () => 720, enabled: () => Ai.enabled, accent: false, focusMode: "input", queryProperty: "" },

        // Future panels are registered now so aliases and configuration have one
        // stable namespace. Their source is activated only when its feature lands.
        { id: "calendar", source: "CalendarPanel.qml", prefixKey: "", keywords: ["calendar", "agenda", "event", "evento", "schedule", "meeting"], label: qsTr("Calendar"), icon: "calendar_month", width: () => 720, enabled: () => Config.options.search.modules.calendar.enable, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "tasks", source: "TasksPanel.qml", prefixKey: "", keywords: ["tasks", "task", "tarefas", "todo"], label: qsTr("Tasks"), icon: "task_alt", width: () => 720, enabled: () => Config.options.search.modules.tasks.enable, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "timers", source: "TimersPanel.qml", prefixKey: "", keywords: ["timer", "timers", "pomodoro", "alarm"], label: qsTr("Timers"), icon: "timer", width: () => 720, enabled: () => Config.options.search.modules.timers.enable, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "emojis", source: "EmojiPanel.qml", prefixKey: "emojis", keywords: ["emoji", "emojis", "emoticon", "smiley", "símbolo"], label: qsTr("Emojis"), icon: "mood", width: () => 720, enabled: () => Config.options.search.modules.emojis.enable, accent: true, focusMode: "grid", queryProperty: "searchQuery", hosted: true },
        { id: "screenshots", source: "ScreenshotsPanel.qml", prefixKey: "", keywords: ["screenshot", "screenshots", "print", "captura", "imagem"], label: qsTr("Screenshots"), icon: "screenshot", width: () => 720, enabled: () => Config.options.search.modules.screenshots.enable, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "windows", source: "WindowManagementPanel.qml", prefixKey: "", keywords: ["window", "windows", "tiling", "move", "janela", "mover"], label: qsTr("Window Management"), icon: "splitscreen", width: () => 720, enabled: () => Config.options.search.modules.windowManagement.enable, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "settings", source: "SettingsTogglesPanel.qml", prefixKey: "", keywords: ["settings", "config", "configurar", "dotfiles"], label: qsTr("Settings"), icon: "settings", width: () => 720, enabled: () => Config.options.search.modules.settingsToggles.enable, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "keybinds", source: "KeybindsPanel.qml", prefixKey: "", keywords: ["keybind", "keybinds", "atalho", "shortcut", "bind"], label: qsTr("Keybinds"), icon: "keyboard", width: () => 720, enabled: () => Config.options.search.modules.keybinds.enable, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "commands", source: "CommandsPanel.qml", prefixKey: "", keywords: ["command", "commands", "comando", "comandos", "cmd", "terminal"], label: qsTr("Commands"), icon: "terminal", width: () => 720, enabled: () => Config.options.search.modules.cheatsheet.enable && Config.options.search.modules.cheatsheet.commandsPanel, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "gmail", source: "GmailPanel.qml", prefixKey: "", keywords: ["gmail", "email", "mail", "inbox", "unread"], label: qsTr("Email"), icon: "mail", width: () => 720, enabled: () => Config.options.search.modules.cheatsheet.enable && Config.options.search.modules.cheatsheet.gmailPanel, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true },
        { id: "sports", source: "SportsPanel.qml", prefixKey: "", keywords: ["sports", "jogos", "game", "games", "football", "futebol"], label: qsTr("Upcoming games"), icon: "sports_soccer", width: () => 720, enabled: () => Config.options.search.modules.sports.enable, accent: true, focusMode: "list", queryProperty: "searchQuery", hosted: true }
    ]

    readonly property var enabledPanels: root.panels.filter(panel => panel.enabled())
    readonly property var activePrefixes: root.enabledPanels.map(panel => root.prefixOf(panel)).filter(prefix => prefix.length > 0)
    readonly property var aliasTargets: root.enabledPanels.filter(panel => panel.aliasable !== false).map(panel => ({ id: panel.id, name: panel.label, icon: panel.icon }))

    function byId(panelId) {
        return root.panels.find(panel => panel.id === panelId) ?? null;
    }

    function prefixOf(panel) {
        if (!panel?.prefixKey)
            return "";
        return String(Config.options.search.prefix[panel.prefixKey] ?? "");
    }

    function resolve(query) {
        const text = String(query ?? "");
        for (const panel of root.enabledPanels) {
            const prefix = root.prefixOf(panel);
            if (prefix.length > 0 && text.startsWith(prefix))
                return panel;
        }
        return null;
    }
}
