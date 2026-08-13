import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal openSettingsPage(string pageId)

    ContentPage {
        anchors.fill: parent
        bottomContentPadding: 28

        ContentSection {
            Layout.fillWidth: true
            icon: "wallpaper"
            title: Translation.tr("Look & feel")

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 820 ? 2 : 1
                columnSpacing: 14
                rowSpacing: 14

                ConfigWallpaperSelector {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 320
                    Layout.preferredWidth: 520
                    Layout.minimumHeight: 220
                    Layout.preferredHeight: 250
                    Layout.maximumHeight: 270
                    text: Translation.tr("Wallpaper")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.minimumWidth: 300
                    Layout.preferredWidth: 360
                    spacing: 12

                    ConfigLightDarkToggle {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 72
                        Layout.preferredHeight: 76
                        text: Translation.tr("Light / Dark Theme")
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 188
                        Layout.preferredHeight: 214
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
            icon: "grid_view"
            title: Translation.tr("Overview")

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
