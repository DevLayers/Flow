import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal openSettingsPage(string pageId)

    readonly property int barPosition: (Config.options.bar.bottom ? 1 : 0)
        | (Config.options.bar.vertical ? 2 : 0)

    ContentPage {
        anchors.fill: parent
        bottomContentPadding: 28

        ContentSection {
            Layout.fillWidth: true
            icon: "dashboard_customize"
            title: Translation.tr("Shell mode")

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: ShellModePolicy.connectModeActive ? "phone_android" : "view_sidebar"
                text: ShellModePolicy.connectModeActive
                    ? Translation.tr("Connect joins shell surfaces into a more mobile, unified experience.")
                    : Translation.tr("Default keeps the classic II layout with independent panels and OSD.")
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 720 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12

                WelcomeActionCard {
                    Layout.fillWidth: true
                    implicitHeight: 132
                    materialIcon: "view_sidebar"
                    title: Translation.tr("Default mode")
                    description: Translation.tr("Classic bar, panels and configurable OSD")
                    statusText: !ShellModePolicy.canSelectDefault
                        ? Translation.tr(ShellModePolicy.defaultBlockedReasonKey)
                        : ""
                    selected: ShellModePolicy.effectiveMode === "default"
                    enabled: ShellModePolicy.canSelectDefault
                    showChevron: false
                    onClicked: ShellModePolicy.setMode("default")
                }

                WelcomeActionCard {
                    Layout.fillWidth: true
                    implicitHeight: 132
                    materialIcon: "phone_android"
                    title: Translation.tr("Connect mode")
                    description: Translation.tr("Unified surfaces with mobile-style drop overlays")
                    statusText: !ShellModePolicy.canSelectConnect
                        ? Translation.tr(ShellModePolicy.connectBlockedReasonKey)
                        : ""
                    selected: ShellModePolicy.effectiveMode === "connect"
                    enabled: ShellModePolicy.canSelectConnect
                    showChevron: false
                    onClicked: ShellModePolicy.setMode("connect")
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "dock"
            title: Translation.tr("Bar position")

            NoticeBox {
                Layout.fillWidth: true
                visible: ShellModePolicy.barPositionLocked
                materialIcon: "lock"
                text: Translation.tr(ShellModePolicy.barPositionBlockedReasonKey)
            }

            ConfigSelectionArray {
                Layout.fillWidth: true
                currentValue: root.barPosition
                onSelected: newValue => ShellModePolicy.setBarPosition(newValue)
                options: [{
                    "displayName": Translation.tr("Top"),
                    "icon": "arrow_upward",
                    "value": 0
                }, {
                    "displayName": Translation.tr("Left"),
                    "icon": "arrow_back",
                    "value": 2,
                    "enabled": !ShellModePolicy.barPositionLocked
                }, {
                    "displayName": Translation.tr("Bottom"),
                    "icon": "arrow_downward",
                    "value": 1,
                    "enabled": !ShellModePolicy.barPositionLocked
                }, {
                    "displayName": Translation.tr("Right"),
                    "icon": "arrow_forward",
                    "value": 3,
                    "enabled": !ShellModePolicy.barPositionLocked
                }]
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "instant_mix"
            title: Translation.tr("Quick preferences")

            NoticeBox {
                Layout.fillWidth: true
                visible: !ShellModePolicy.osdStyleEditable
                materialIcon: "phone_android"
                text: Translation.tr("Connect uses its own native OSD styling.")
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 800 ? 2 : 1
                columnSpacing: 14
                rowSpacing: 14

                ContentSubsection {
                    Layout.fillWidth: true
                    title: Translation.tr("OSD style")
                    icon: "desktop_windows"
                    enabled: ShellModePolicy.osdStyleEditable
                    opacity: enabled ? 1 : 0.4

                    ConfigSelectionArray {
                        enabled: parent.enabled
                        currentValue: Config.options.osd.style ?? "default"
                        onSelected: newValue => Config.options.osd.style = newValue
                        options: [{
                            "displayName": Translation.tr("Android"),
                            "icon": "smartphone",
                            "value": "default"
                        }, {
                            "displayName": Translation.tr("Minimal"),
                            "icon": "horizontal_rule",
                            "value": "minimalist"
                        }]
                    }
                }

                ContentSubsection {
                    Layout.fillWidth: true
                    title: Translation.tr("Dashboard controls")
                    icon: "toggle_on"

                    ConfigSelectionArray {
                        currentValue: Config.options.sidebar.quickToggles.style
                        onSelected: newValue => Config.options.sidebar.quickToggles.style = newValue
                        options: [{
                            "displayName": Translation.tr("Classic"),
                            "icon": "grid_view",
                            "value": "classic"
                        }, {
                            "displayName": Translation.tr("Android"),
                            "icon": "view_comfy_alt",
                            "value": "android"
                        }]
                    }
                }
            }
        }

        RippleButtonWithIcon {
            Layout.fillWidth: true
            materialIcon: "settings"
            mainText: Translation.tr("Open full Bar settings")
            onClicked: root.openSettingsPage("bar")
        }
    }
}
