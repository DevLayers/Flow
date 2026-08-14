import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.configs.widgets

ContentPage {
    id: page
    forceWidth: false

    ContentSection {
        title: Translation.tr("Notifications")
        icon: "notifications"

        ConfigSpinBox {
            icon: "timer"
            text: Translation.tr("Timeout duration (ms)")
            value: Config.options.notifications.timeout
            from: 1000
            to: 10000
            stepSize: 500
            onValueChanged: {
                Config.options.notifications.timeout = value;
            }
        }

        ConfigSpinBox {
            icon: "zoom_in"
            text: Translation.tr("Notification size (%)")
            value: Config.options.notifications.zoomPercent
            from: 50
            to: 200
            stepSize: 10
            onValueChanged: {
                Config.options.notifications.zoomPercent = value;
            }
        }

        ConfigSwitch {
            buttonIcon: "fullscreen"
            text: Translation.tr("Do not disturb when focused app is fullscreen")
            checked: Config.options.notifications.autoDndFullscreen
            onCheckedChanged: {
                Config.options.notifications.autoDndFullscreen = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "desktop_windows"
            text: Translation.tr("Force specific monitor")
            checked: Config.options.notifications.monitor.enable
            onCheckedChanged: {
                Config.options.notifications.monitor.enable = checked;
            }
        }

        MonitorPicker {
            visible: Config.options.notifications.monitor.enable
            currentValue: Config.options.notifications.monitor.name
            onSelected: (newValue) => {
                Config.options.notifications.monitor.name = newValue;
            }
        }

        ConfigSwitch {
            buttonIcon: "counter_2"
            text: Translation.tr("Show unread count")
            checked: Config.options.bar.indicators.notifications.showUnreadCount
            onCheckedChanged: {
                Config.options.bar.indicators.notifications.showUnreadCount = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Notification indicator style")
            icon: "notifications"

            ConfigSelectionArray {
                currentValue: Config.options.bar.styles.notification
                onSelected: newValue => { Config.options.bar.styles.notification = newValue; }
                options: [
                    { displayName: Translation.tr("Default"),    icon: "style",     value: "default" },
                    { displayName: Translation.tr("Expressive"), icon: "fluid_med", value: "expressive" }
                ]
            }
        }

        Rectangle {
            id: positionCard

            Layout.fillWidth: true
            implicitHeight: positionLayout.implicitHeight + Appearance.font.pixelSize.large
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            ColumnLayout {
                id: positionLayout

                anchors.fill: parent
                anchors.margins: Appearance.font.pixelSize.small
                spacing: Appearance.font.pixelSize.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.font.pixelSize.smallest

                    MaterialSymbol {
                        text: "place"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.font.pixelSize.smallest

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Notification position")
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.weight: Font.DemiBold
                            font.variableAxes: Appearance.font.variableAxes.titleRounded
                            color: Appearance.colors.colOnLayer1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Choose the corner where new notifications will appear.")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                NotificationPositionPicker {
                    Layout.fillWidth: true
                }
            }
        }

    }

    ContentSection {
        icon: "link"
        title: Translation.tr("Related settings")

        Flow {
            Layout.fillWidth: true
            spacing: 8

            RelatedChip {
                pageId: "lockScreen"
                label: Translation.tr("Lock screen")
            }

            RelatedChip {
                pageId: "dock"
                label: Translation.tr("Dock badges")
            }

            RelatedChip {
                pageId: "dynamicIsland"
                label: Translation.tr("Island notch")
            }

            RelatedChip {
                pageId: "soundAlerts"
                label: Translation.tr("Alert sounds")
            }
        }
    }
}
