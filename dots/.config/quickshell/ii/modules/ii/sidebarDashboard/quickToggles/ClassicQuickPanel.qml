import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

import qs.modules.ii.sidebarDashboard.quickToggles.classicStyle

AbstractQuickPanel {
    id: root
    Layout.fillWidth: true
    implicitWidth: buttonGroup.implicitWidth
    implicitHeight: buttonGroup.implicitHeight
    color: "transparent"

    property int buttonSize: 40
    property int buttonSpacing: 5
    property int groupPadding: 5

    Rectangle {
        id: buttonGroup
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: toggleGrid.implicitWidth + root.groupPadding * 2
        implicitHeight: toggleGrid.implicitHeight + root.groupPadding * 2
        color: Appearance.colors.colLayer1
        radius: (Config.options.appearance.sharpMode ? Appearance.rounding.small : root.buttonSize / 2) + root.groupPadding

        // Toggles wrap onto as many rows as the sidebar width allows, so adding
        // one never pushes the row past the sidebar edge.
        Grid {
            id: toggleGrid
            anchors.centerIn: parent
            spacing: root.buttonSpacing
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            // GroupButton reads this off its parent to drive the press bounce.
            property int clickIndex: -1

            readonly property real availableWidth: root.width - root.groupPadding * 2
            columns: Math.max(1, Math.floor((availableWidth + root.buttonSpacing) / (root.buttonSize + root.buttonSpacing)))

            NetworkToggle {
                altAction: () => {
                    root.openWifiDialog();
                }
            }
            BluetoothToggle {
                altAction: () => {
                    root.openBluetoothDialog();
                }
            }
            VpnToggle {
                altAction: () => {
                    root.openVpnDialog();
                }
            }
            TailscaleToggle {
                altAction: () => {
                    root.openTailscaleDialog();
                }
            }
            NightLight {}
            GameMode {}
            IdleInhibitor {
                altAction: () => {
                    root.openIdleInhibitorDialog();
                }
            }
            ModesQuickToggle {
                altAction: () => {
                    root.openModesDialog();
                }
            }
            EasyEffectsToggle {}
            CloudflareWarp {}
            KeyboardBacklight {}
        }
    }
}
