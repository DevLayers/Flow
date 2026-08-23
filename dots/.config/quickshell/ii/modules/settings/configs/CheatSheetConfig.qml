import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    function openSubPage(url) {
        subPageOverlay.open(Qt.resolvedUrl(url));
    }

    anchors.fill: parent

    ContentPage {
        id: page

        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress
        visible: opacity > 0

        KeyboardShortcutBox {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            text: Translation.tr("Toggle the Cheatsheet")
            keys: ["Super", "/"]
        }

        ContentSection {
            title: Translation.tr("General Options")
            icon: "keyboard"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ContentSubsection {
                    title: Translation.tr("Super key symbol")
                    icon: "keyboard_command_key"
                    Layout.fillWidth: true

                    ConfigSelectionArray {
                        currentValue: Config.options.cheatsheet.superKey
                        onSelected: (newValue) => {
                            Config.options.cheatsheet.superKey = newValue;
                        }
                        options: (["󰖳", "", "󰨡", "", "󰌽", "󰣇", "", "", "", "", "", "󱄛", "", "", "", "⌘", "󰀲", "󰟍", ""]).map((icon) => {
                            return {
                                "displayName": icon,
                                "value": icon
                            };
                        })
                    }

                }

                ConfigSwitch {
                    buttonIcon: "󰘵"
                    text: Translation.tr("Use macOS-like symbols for mods keys")
                    checked: Config.options.cheatsheet.useMacSymbol
                    onCheckedChanged: {
                        Config.options.cheatsheet.useMacSymbol = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "󱊶"
                    text: Translation.tr("Use symbols for function keys")
                    checked: Config.options.cheatsheet.useFnSymbol
                    onCheckedChanged: {
                        Config.options.cheatsheet.useFnSymbol = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "󰍽"
                    text: Translation.tr("Use symbols for mouse")
                    checked: Config.options.cheatsheet.useMouseSymbol
                    onCheckedChanged: {
                        Config.options.cheatsheet.useMouseSymbol = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "highlight_keyboard_focus"
                    text: Translation.tr("Split buttons")
                    checked: Config.options.cheatsheet.splitButtons
                    onCheckedChanged: {
                        Config.options.cheatsheet.splitButtons = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "filter_alt"
                    text: Translation.tr("Filter unbinds")
                    checked: Config.options.cheatsheet.filterUnbinds
                    onCheckedChanged: {
                        Config.options.cheatsheet.filterUnbinds = checked;
                    }
                }

            }

            Item {
                Layout.preferredHeight: 16
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSpinBox {
                    icon: "format_size"
                    text: Translation.tr("Keybind font size")
                    value: Config.options.cheatsheet.fontSize.key
                    from: 8
                    to: 30
                    stepSize: 1
                    onValueChanged: {
                        Config.options.cheatsheet.fontSize.key = value;
                    }
                }

                ConfigSpinBox {
                    icon: "text_fields"
                    text: Translation.tr("Description font size")
                    value: Config.options.cheatsheet.fontSize.comment
                    from: 8
                    to: 30
                    stepSize: 1
                    onValueChanged: {
                        Config.options.cheatsheet.fontSize.comment = value;
                    }
                }

            }

        }

        ContentSection {
            title: Translation.tr("Toggle Widgets")
            icon: "widgets"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSwitch {
                    buttonIcon: "calendar_month"
                    text: Translation.tr("Enable Timetable")
                    checked: Config.options.cheatsheet.enableTimetable
                    configPage: Qt.resolvedUrl("widgets/TimetableConfig.qml")
                    onCheckedChanged: {
                        Config.options.cheatsheet.enableTimetable = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("Weekly and monthly calendar timetable with event scheduling, alarms, and sports integration.")
                    }
                }

                ConfigSwitch {
                    buttonIcon: "mail"
                    text: Translation.tr("Enable Gmail")
                    checked: Config.options.cheatsheet.enableGmail
                    onCheckedChanged: {
                        Config.options.cheatsheet.enableGmail = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("View and manage unread Gmail messages directly in the Cheatsheet.")
                    }
                }

                ConfigSwitch {
                    buttonIcon: "biotech"
                    text: Translation.tr("Enable Amino acids")
                    checked: Config.options.cheatsheet.enableAminoAcids
                    configPage: Qt.resolvedUrl("widgets/CheatsheetAminoAcidsConfig.qml")
                    onCheckedChanged: {
                        Config.options.cheatsheet.enableAminoAcids = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("Reference guide for amino acids with structural formulas and classification schemes.")
                    }
                }

                ConfigSwitch {
                    buttonIcon: "terminal"
                    text: Translation.tr("Enable Commands")
                    checked: Config.options.cheatsheet.enableCommands
                    configPage: Qt.resolvedUrl("widgets/CheatsheetCommandsConfig.qml")
                    onCheckedChanged: {
                        Config.options.cheatsheet.enableCommands = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("Quick reference cheatsheet for terminal commands and shell workflows.")
                    }
                }

                ConfigSwitch {
                    buttonIcon: "dashboard"
                    text: Translation.tr("Enable Workspaces")
                    checked: Config.options.cheatsheet.enableWorkspaceProfiles
                    onCheckedChanged: {
                        Config.options.cheatsheet.enableWorkspaceProfiles = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("Manage workspace profiles, saved application layouts, and monitor assignments.")
                    }
                }

                ConfigSwitch {
                    buttonIcon: "experiment"
                    text: Translation.tr("Enable Elements")
                    checked: Config.options.cheatsheet.enablePeriodicTable
                    onCheckedChanged: {
                        Config.options.cheatsheet.enablePeriodicTable = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("Interactive periodic table of chemical elements with atomic properties.")
                    }
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
