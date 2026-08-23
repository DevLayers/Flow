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
                ConfigSwitch { buttonIcon: "calendar_month"; text: Translation.tr("Calendar"); checked: Config.options.search.modules.calendar.enable; onCheckedChanged: Config.options.search.modules.calendar.enable = checked }
                ConfigSelectionArray {
                    visible: Config.options.search.modules.calendar.enable
                    Layout.fillWidth: true
                    currentValue: Config.options.search.modules.calendar.source
                    options: [{ displayName: Translation.tr("khal"), value: "khal" }, { displayName: Translation.tr("Google"), value: "google" }, { displayName: Translation.tr("Both"), value: "both" }]
                    onSelected: value => Config.options.search.modules.calendar.source = value
                }
                ConfigSwitch { buttonIcon: "task_alt"; text: Translation.tr("Tasks"); checked: Config.options.search.modules.tasks.enable; onCheckedChanged: Config.options.search.modules.tasks.enable = checked }
                ConfigSwitch { buttonIcon: "timer"; text: Translation.tr("Timers"); checked: Config.options.search.modules.timers.enable; onCheckedChanged: Config.options.search.modules.timers.enable = checked }
                ConfigSwitch { buttonIcon: "splitscreen"; text: Translation.tr("Window management"); checked: Config.options.search.modules.windowManagement.enable; onCheckedChanged: Config.options.search.modules.windowManagement.enable = checked }
                ConfigSwitch { buttonIcon: "screenshot"; text: Translation.tr("Screenshots"); checked: Config.options.search.modules.screenshots.enable; onCheckedChanged: Config.options.search.modules.screenshots.enable = checked }
                ConfigSwitch { buttonIcon: "mood"; text: Translation.tr("Emojis"); checked: Config.options.search.modules.emojis.enable; onCheckedChanged: Config.options.search.modules.emojis.enable = checked }
                ConfigSwitch { buttonIcon: "settings"; text: Translation.tr("Settings in Search"); checked: Config.options.search.modules.settingsToggles.enable; onCheckedChanged: Config.options.search.modules.settingsToggles.enable = checked }
                ConfigSwitch { buttonIcon: "keyboard"; text: Translation.tr("Keybinds"); checked: Config.options.search.modules.keybinds.enable; onCheckedChanged: Config.options.search.modules.keybinds.enable = checked }
                ConfigSwitch { buttonIcon: "toggle_on"; text: Translation.tr("Quick toggles"); checked: Config.options.search.modules.quickToggles.enable; onCheckedChanged: Config.options.search.modules.quickToggles.enable = checked }
            }
        }

        ContentSection {
            icon: "database"
            title: Translation.tr("Data-backed modules")
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2
                ConfigSwitch { buttonIcon: "terminal"; text: Translation.tr("Commands"); checked: Config.options.search.modules.cheatsheet.commandsPanel; onCheckedChanged: Config.options.search.modules.cheatsheet.commandsPanel = checked }
                ConfigSwitch { buttonIcon: "mail"; text: Translation.tr("Gmail"); checked: Config.options.search.modules.cheatsheet.gmailPanel; onCheckedChanged: Config.options.search.modules.cheatsheet.gmailPanel = checked }
                ConfigSwitch { buttonIcon: "sports_soccer"; text: Translation.tr("Upcoming games"); checked: Config.options.search.modules.sports.enable; onCheckedChanged: Config.options.search.modules.sports.enable = checked }
                ConfigSwitch { buttonIcon: "devices"; text: Translation.tr("Bluetooth devices by name"); checked: Config.options.search.modules.bluetooth; onCheckedChanged: Config.options.search.modules.bluetooth = checked }
                ConfigSwitch { buttonIcon: "cancel"; text: Translation.tr("Quit process"); checked: Config.options.search.modules.processes.enable; onCheckedChanged: Config.options.search.modules.processes.enable = checked }
                ConfigSwitch { buttonIcon: "routine"; text: Translation.tr("Modes & routines"); checked: Config.options.modes.enable; onCheckedChanged: Config.options.modes.enable = checked }
                ConfigSwitch { buttonIcon: "code"; text: Translation.tr("Generators"); checked: Config.options.search.modules.generators.enable; onCheckedChanged: Config.options.search.modules.generators.enable = checked }
            }
        }
    }
}
