import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root
    anchors.fill: parent
    property bool showBackButton: false
    signal goBack()

    ContentPage {
        anchors.fill: parent
        forceWidth: false

        RowLayout {
            visible: root.showBackButton
            spacing: Appearance.sizes.elevationMargin
            RippleButton {
                implicitWidth: Appearance.sizes.elevationMargin * 4
                implicitHeight: implicitWidth
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: root.goBack()
                MaterialSymbol { anchors.centerIn: parent; text: "arrow_back"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnSecondaryContainer }
            }
            StyledText { text: Translation.tr("Search modules"); font.pixelSize: Appearance.font.pixelSize.large; font.family: Appearance.font.family.title; color: Appearance.colors.colOnLayer0 }
        }

        ContentSection {
            icon: "dashboard_customize"
            title: Translation.tr("Search panels")
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2
                ConfigSwitch { buttonIcon: "content_paste"; text: Translation.tr("Clipboard"); description: Translation.tr("Search for ‘clipboard’, ‘clip’, ‘paste’, or type prefix ‘%1’.").arg(String(Config.options.search.prefix.clipboard)); checked: Config.options.search.modules.clipboard; onCheckedChanged: Config.options.search.modules.clipboard = checked }
                ConfigSwitch { buttonIcon: "bluetooth"; text: Translation.tr("Bluetooth"); description: Translation.tr("Search for ‘bluetooth’ or type prefix ‘%1’; device names also appear as results.").arg(String(Config.options.search.prefix.bluetooth)); checked: Config.options.search.modules.bluetooth; onCheckedChanged: Config.options.search.modules.bluetooth = checked }
                ConfigSwitch { buttonIcon: "translate"; text: Translation.tr("Translator"); description: Translation.tr("Search for ‘translator’, ‘translate’, ‘tradutor’, or type prefix ‘%1’.").arg(String(Config.options.search.prefix.translator)); checked: Config.options.search.modules.translator; onCheckedChanged: Config.options.search.modules.translator = checked }
                ConfigSwitch { buttonIcon: "download"; text: Translation.tr("Media downloader"); description: Translation.tr("Search for ‘download’, ‘video’, ‘media’, or type prefix ‘%1’. Requires Media Downloader to be enabled.").arg(String(Config.options.search.prefix.mediaDownloader)); checked: Config.options.search.modules.mediaDownloader; onCheckedChanged: Config.options.search.modules.mediaDownloader = checked }
                ConfigSwitch { buttonIcon: "font_download"; text: Translation.tr("Material Symbols"); description: Translation.tr("Search for ‘material’, ‘symbols’, ‘icons’, or type prefix ‘%1’.").arg(String(Config.options.search.prefix.materialSymbols)); checked: Config.options.search.modules.materialSymbols; onCheckedChanged: Config.options.search.modules.materialSymbols = checked }
                ConfigSwitch { buttonIcon: "calendar_month"; text: Translation.tr("Calendar"); description: Translation.tr("Search for ‘calendar’, ‘agenda’, ‘event’, or ‘meeting’ to open it."); checked: Config.options.search.modules.calendar.enable; onCheckedChanged: Config.options.search.modules.calendar.enable = checked }
                ConfigSelectionArray {
                    visible: Config.options.search.modules.calendar.enable
                    Layout.fillWidth: true
                    currentValue: Config.options.search.modules.calendar.source
                    options: [{ displayName: Translation.tr("khal"), value: "khal" }, { displayName: Translation.tr("Google"), value: "google" }, { displayName: Translation.tr("Both"), value: "both" }]
                    onSelected: value => Config.options.search.modules.calendar.source = value
                }
                ConfigSwitch { buttonIcon: "task_alt"; text: Translation.tr("Tasks"); description: Translation.tr("Search for ‘tasks’, ‘task’, ‘tarefas’, or ‘todo’. Type a task and press Ctrl+N to create it."); checked: Config.options.search.modules.tasks.enable; onCheckedChanged: Config.options.search.modules.tasks.enable = checked }
                ConfigSwitch { buttonIcon: "timer"; text: Translation.tr("Timers"); description: Translation.tr("Search for ‘timer’, ‘timers’, ‘pomodoro’, or ‘alarm’. Use arrows and Enter inside the panel."); checked: Config.options.search.modules.timers.enable; onCheckedChanged: Config.options.search.modules.timers.enable = checked }
                ConfigSwitch { buttonIcon: "splitscreen"; text: Translation.tr("Window management"); description: Translation.tr("Search for ‘window’, ‘tiling’, ‘move’, ‘janela’, or ‘mover’ to act on the window that opened Search."); checked: Config.options.search.modules.windowManagement.enable; onCheckedChanged: Config.options.search.modules.windowManagement.enable = checked }
                ConfigSwitch { buttonIcon: "screenshot"; text: Translation.tr("Screenshots"); description: Translation.tr("Search for ‘screenshot’, ‘print’, ‘captura’, or ‘imagem’ to browse clipboard images."); checked: Config.options.search.modules.screenshots.enable; onCheckedChanged: Config.options.search.modules.screenshots.enable = checked }
                ConfigSwitch { buttonIcon: "mood"; text: Translation.tr("Emojis"); description: Translation.tr("Search for ‘emoji’ or type the configured emoji prefix to open the grid."); checked: Config.options.search.modules.emojis.enable; onCheckedChanged: Config.options.search.modules.emojis.enable = checked }
                ConfigSwitch { buttonIcon: "settings"; text: Translation.tr("Settings in Search"); description: Translation.tr("Type the name of a setting, such as ‘dark mode’, ‘night light’, or ‘Wi-Fi’, to change it from Search."); checked: Config.options.search.modules.settingsToggles.enable; onCheckedChanged: Config.options.search.modules.settingsToggles.enable = checked }
                ConfigSwitch { buttonIcon: "keyboard"; text: Translation.tr("Keybinds"); description: Translation.tr("Search for ‘keybind’, ‘shortcut’, ‘atalho’, or the action name."); checked: Config.options.search.modules.keybinds.enable; onCheckedChanged: Config.options.search.modules.keybinds.enable = checked }
                ConfigSwitch { buttonIcon: "toggle_on"; text: Translation.tr("Quick toggles"); description: Translation.tr("Shows matching system toggles directly among regular Search results."); checked: Config.options.search.modules.quickToggles.enable; onCheckedChanged: Config.options.search.modules.quickToggles.enable = checked }
            }
        }

        ContentSection {
            icon: "manage_search"
            title: Translation.tr("Search providers")
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2
                ConfigSwitch { buttonIcon: "select_window"; text: Translation.tr("Window search"); description: Translation.tr("Type prefix ‘%1’ followed by a window title or app class.").arg(String(Config.options.search.prefix.windowSearch)); checked: Config.options.search.modules.windowSearch; onCheckedChanged: Config.options.search.modules.windowSearch = checked }
                ConfigSwitch { buttonIcon: "folder_open"; text: Translation.tr("File browser"); description: Translation.tr("Type prefix ‘%1’ followed by a path to browse folders.").arg(String(Config.options.search.prefix.fileBrowser)); checked: Config.options.search.modules.fileBrowser; onCheckedChanged: Config.options.search.modules.fileBrowser = checked }
                ConfigSwitch { buttonIcon: "find_in_page"; text: Translation.tr("File search"); description: Translation.tr("Type prefix ‘%1’ followed by at least two characters to find files.").arg(String(Config.options.search.prefix.fileSearch)); checked: Config.options.search.modules.fileSearch; onCheckedChanged: Config.options.search.modules.fileSearch = checked }
                ConfigSwitch { buttonIcon: "calculate"; text: Translation.tr("Calculator"); description: Translation.tr("Type an expression directly or use prefix ‘%1’.").arg(String(Config.options.search.prefix.math)); checked: Config.options.search.modules.math; onCheckedChanged: Config.options.search.modules.math = checked }
                ConfigSwitch { buttonIcon: "travel_explore"; text: Translation.tr("Web search"); description: Translation.tr("Type prefix ‘%1’ followed by the search terms, or use the fallback result.").arg(String(Config.options.search.prefix.webSearch)); checked: Config.options.search.modules.webSearch; onCheckedChanged: Config.options.search.modules.webSearch = checked }
                ConfigSwitch { buttonIcon: "terminal"; text: Translation.tr("Shell commands"); description: Translation.tr("Type prefix ‘%1’ followed by a command. Commands run only after pressing Enter.").arg(String(Config.options.search.prefix.shellCommand)); checked: Config.options.search.modules.shellCommand; onCheckedChanged: Config.options.search.modules.shellCommand = checked }
                ConfigSwitch { buttonIcon: "power_settings_new"; text: Translation.tr("System controls"); description: Translation.tr("Search for ‘lock’, ‘poweroff’, ‘reboot’, ‘suspend’, or ‘restart’; destructive controls require confirmation."); checked: Config.options.search.modules.systemControls; onCheckedChanged: Config.options.search.modules.systemControls = checked }
                ConfigSwitch { buttonIcon: "widgets"; text: Translation.tr("Shell actions"); description: Translation.tr("Makes shell tools such as color picker, wallpaper, OCR, recording, and overlays searchable by name."); checked: Config.options.search.modules.shellActions; onCheckedChanged: Config.options.search.modules.shellActions = checked }
            }
        }

        ContentSection {
            icon: "database"
            title: Translation.tr("Data-backed modules")
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2
                ConfigSwitch { buttonIcon: "menu_book"; text: Translation.tr("Cheat Sheet shortcuts"); description: Translation.tr("Lets Search open Cheat Sheet pages such as timetable, elements, amino acids, workspaces, Gmail, and commands."); checked: Config.options.search.modules.cheatsheet.enable; onCheckedChanged: Config.options.search.modules.cheatsheet.enable = checked }
                ConfigSwitch { buttonIcon: "terminal"; text: Translation.tr("Commands"); description: Translation.tr("Search for ‘commands’, ‘command’, ‘comando’, ‘cmd’, or the command name."); checked: Config.options.search.modules.cheatsheet.commandsPanel; onCheckedChanged: Config.options.search.modules.cheatsheet.commandsPanel = checked }
                ConfigSwitch { buttonIcon: "mail"; text: Translation.tr("Gmail"); description: Translation.tr("Search for ‘gmail’, ‘email’, ‘mail’, ‘inbox’, or ‘unread’."); checked: Config.options.search.modules.cheatsheet.gmailPanel; onCheckedChanged: Config.options.search.modules.cheatsheet.gmailPanel = checked }
                ConfigSwitch { buttonIcon: "sports_soccer"; text: Translation.tr("Today’s games"); description: Translation.tr("Search for ‘sports’, ‘games’, ‘jogos’, ‘football’, or ‘futebol’ to see every monitored game today."); checked: Config.options.search.modules.sports.enable; onCheckedChanged: Config.options.search.modules.sports.enable = checked }
                ConfigSwitch { buttonIcon: "cancel"; text: Translation.tr("Quit process"); description: Translation.tr("Search for ‘process’, ‘kill’, ‘quit’, ‘fechar’, or a running process name. Enter requires confirmation."); checked: Config.options.search.modules.processes.enable; onCheckedChanged: Config.options.search.modules.processes.enable = checked }
                ConfigSwitch { buttonIcon: "routine"; text: Translation.tr("Modes & routines"); description: Translation.tr("Type a mode or routine name to activate or deactivate it."); checked: Config.options.modes.enable; onCheckedChanged: Config.options.modes.enable = checked }
                ConfigSwitch { buttonIcon: "code"; text: Translation.tr("Generators"); description: Translation.tr("Search for ‘generator’ to browse all, or type ‘uuid’, ‘password’, or ‘lorem’. Enter generates and copies locally."); checked: Config.options.search.modules.generators.enable; onCheckedChanged: Config.options.search.modules.generators.enable = checked }
            }
        }
    }
}
