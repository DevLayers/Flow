import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.welcome

Item {
    id: root

    signal openSettingsPage(string pageId)

    readonly property bool shellModeLockedToDefault: Config.options.bar.floatingNotch.centerInBar
    readonly property bool defaultModeUnavailable: Config.options.bar.floatingNotch.enable && Config.options.sidebar.sidebarStyle === "connect"
    readonly property int barPosition: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)

    function setBarPosition(newValue) {
        if (root.shellModeLockedToDefault)
            return;
        Config.options.bar.bottom = (newValue & 1) !== 0;
        Config.options.bar.vertical = (newValue & 2) !== 0;
    }

    ContentPage {
        anchors.fill: parent
        bottomContentPadding: 28

        ContentSection {
            Layout.fillWidth: true
            icon: "wallpaper"
            title: Translation.tr("Look & feel")

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 900 ? 2 : 1
                columnSpacing: 18
                rowSpacing: 14

                ConfigWallpaperSelector {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(210, width * 0.52)
                    implicitWidth: 360
                    implicitHeight: 220
                    text: Translation.tr("Wallpaper")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    ConfigLightDarkToggle {
                        Layout.fillWidth: true
                        text: Translation.tr("Light / Dark Theme")
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 170
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        clip: true

                        StyledFlickable {
                            anchors.fill: parent
                            anchors.margins: 10
                            contentWidth: width
                            contentHeight: colorGrid.implicitHeight
                            clip: true

                            ColorPreviewGrid {
                                id: colorGrid
                                width: parent.width
                                customTheme: false
                                builtInTheme: false
                            }
                        }
                    }
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "dashboard_customize"
            title: Translation.tr("Shell mode")

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "info"
                text: Config.options.sidebar.sidebarStyle === "connect"
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
                    statusText: root.defaultModeUnavailable ? Translation.tr("Disable Floating Dynamic Island first") : ""
                    selected: Config.options.sidebar.sidebarStyle === "default"
                    enabled: !root.defaultModeUnavailable
                    showChevron: false
                    onClicked: Config.options.sidebar.sidebarStyle = "default"
                }

                WelcomeActionCard {
                    Layout.fillWidth: true
                    implicitHeight: 132
                    materialIcon: "phone_android"
                    title: Translation.tr("Connect mode")
                    description: Translation.tr("Unified surfaces with mobile-style drop overlays")
                    statusText: root.shellModeLockedToDefault ? Translation.tr("Dynamic Island is locked to the bar center") : ""
                    selected: Config.options.sidebar.sidebarStyle === "connect"
                    enabled: !root.shellModeLockedToDefault
                    showChevron: false
                    onClicked: Config.options.sidebar.sidebarStyle = "connect"
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "dock"
            title: Translation.tr("Bar position")

            NoticeBox {
                Layout.fillWidth: true
                visible: root.shellModeLockedToDefault
                materialIcon: "lock"
                text: Translation.tr("The bar stays at the top while Dynamic Island is centered in it.")
            }

            ConfigSelectionArray {
                Layout.fillWidth: true
                currentValue: root.barPosition
                onSelected: newValue => root.setBarPosition(newValue)
                options: [{
                    "displayName": Translation.tr("Top"),
                    "icon": "arrow_upward",
                    "value": 0
                }, {
                    "displayName": Translation.tr("Left"),
                    "icon": "arrow_back",
                    "value": 2,
                    "enabled": !root.shellModeLockedToDefault
                }, {
                    "displayName": Translation.tr("Bottom"),
                    "icon": "arrow_downward",
                    "value": 1,
                    "enabled": !root.shellModeLockedToDefault
                }, {
                    "displayName": Translation.tr("Right"),
                    "icon": "arrow_forward",
                    "value": 3,
                    "enabled": !root.shellModeLockedToDefault
                }]
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "instant_mix"
            title: Translation.tr("Quick preferences")

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 800 ? 2 : 1
                columnSpacing: 14
                rowSpacing: 14

                ContentSubsection {
                    Layout.fillWidth: true
                    title: Translation.tr("OSD style")
                    icon: "desktop_windows"
                    enabled: Config.options.sidebar.sidebarStyle !== "connect"
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

            ConfigSwitch {
                Layout.fillWidth: true
                buttonIcon: "grid_view"
                text: Translation.tr("Enable Overview")
                checked: Config.options.overview.enable
                onCheckedChanged: Config.options.overview.enable = checked
            }

            RippleButtonWithIcon {
                materialIcon: "settings"
                mainText: Translation.tr("More appearance settings")
                onClicked: root.openSettingsPage("colors")
            }
        }
    }
}
