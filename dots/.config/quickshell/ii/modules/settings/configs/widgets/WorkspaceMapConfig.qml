import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false

        RowLayout {
            visible: subPageRoot.showBackButton
            spacing: 12

            RippleButton {
                implicitWidth: implicitHeight
                implicitHeight: 40
                topLeftRadius: Appearance.rounding.full
                topRightRadius: Appearance.rounding.full
                bottomLeftRadius: Appearance.rounding.full
                bottomRightRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: subPageRoot.goBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            StyledText {
                text: Translation.tr("Workspace Map")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            title: Translation.tr("Mapping Behavior")
            icon: "map"

            NoticeBox {
                Layout.fillWidth: true
                isFirst: true
                text: Translation.tr("Isolate workspace ranges for each monitor in multi-monitor setups.")
            }

            ConfigSwitch {
                buttonIcon: "map"
                text: Translation.tr("Use workspace map")
                checked: Config.options.bar.workspaces.useWorkspaceMap
                onCheckedChanged: {
                    Config.options.bar.workspaces.useWorkspaceMap = checked;
                }
                StyledToolTip {
                    text: Translation.tr("For multi-monitor setups, isolates workspace ranges for each monitor")
                }
            }

            ConfigSwitch {
                enabled: Config.options.bar.workspaces.useWorkspaceMap
                buttonIcon: "sync"
                text: Translation.tr("Sync overview map")
                checked: Config.options.overview.useWorkspaceMap
                onCheckedChanged: {
                    Config.options.overview.useWorkspaceMap = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Apply the same workspace map constraints to the Overview screen")
                }
            }
        }

        ContentSection {
            visible: Config.options.bar.workspaces.useWorkspaceMap
            title: Translation.tr("Monitor Starting Workspaces")
            icon: "desktop_windows"

            NoticeBox {
                Layout.fillWidth: true
                isFirst: true
                text: Translation.tr("Set the starting workspace number for each monitor based on the number of workspaces shown to prevent overlapping.")
            }

            Repeater {
                model: HyprlandData.monitors

                delegate: ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "monitor"
                    text: modelData.name ? modelData.name : (Translation.tr("Monitor ") + (index + 1))
                    value: {
                        let map = Config.options.bar.workspaces.workspaceMap || [];
                        let offset = map.length > index ? map[index] : (index * (Config.options.bar.workspaces.shown || 10));
                        return offset + 1;
                    }
                    from: 1
                    to: 100
                    stepSize: 1
                    onValueChanged: {
                        let map = JSON.parse(JSON.stringify(Config.options.bar.workspaces.workspaceMap || []));
                        while (map.length <= index)
                            map.push(map.length > 0 ? map[map.length - 1] + (Config.options.bar.workspaces.shown || 10) : 0);

                        map[index] = value - 1;
                        Config.options.bar.workspaces.workspaceMap = map;
                    }
                    StyledToolTip {
                        text: Translation.tr("Starting workspace number for %1").arg(modelData.name ? modelData.name : (Translation.tr("Monitor ") + (index + 1)))
                    }
                }
            }
        }
    }
}
