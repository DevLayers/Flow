pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.sidebarDashboard.wifiNetworks
import qs.modules.ii.sidebarDashboard.bluetoothDevices
import qs.modules.ii.sidebarDashboard.volumeMixer

FloatingWindow {
    id: root

    visible: GlobalStates.welcomeOpen
    title: WelcomePageRegistry.titleFor(flow.currentPageId)
    implicitWidth: 1080
    implicitHeight: 780
    minimumSize: Qt.size(900, 640)
    color: "transparent"

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0
        focus: root.visible

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            WelcomeHeader {
                id: header
                Layout.fillWidth: true
                pageId: flow.currentPageId
                pageIndex: WelcomePageRegistry.pageIndexById(flow.currentPageId)
                pageCount: WelcomePageRegistry.pages.length
                onCloseRequested: GlobalStates.closeWelcome()
            }

            WelcomeProgress {
                Layout.fillWidth: true
                currentPageId: flow.currentPageId
                visitedPageIds: flow.visitedPageIds
                onPageRequested: pageId => flow.goToPage(pageId)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer1
                clip: true

                WelcomeFlow {
                    id: flow
                    anchors.fill: parent
                    anchors.margins: 18

                    onOpenWifi: root.showWifiDialog = true
                    onOpenBluetooth: root.showBluetoothDialog = true
                    onOpenAudioOutput: root.showAudioOutputDialog = true

                    onOpenSettingsPage: pageId => {
                        GlobalStates.openSettingsPage(pageId);
                        GlobalStates.closeWelcome();
                    }
                }
            }

            WelcomeNavigation {
                Layout.fillWidth: true
                pageIndex: WelcomePageRegistry.pageIndexById(flow.currentPageId)
                pageCount: WelcomePageRegistry.pages.length
                onPreviousRequested: flow.goPrevious()
                onNextRequested: flow.goNext()
                onFinishRequested: GlobalStates.closeWelcome()
            }
        }
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (!flow.closeNestedPage())
                    GlobalStates.closeWelcome();
                event.accepted = true;
            } else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Left) {
                flow.goPrevious();
                event.accepted = true;
            } else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Right) {
                flow.goNext();
                event.accepted = true;
            }
        }
    }

    // The Welcome host owns these loaders, so opening a quick control does not
    // mutate or close the Dashboard sidebar. Dialog implementations remain the
    // same ones used by Dashboard.
    property bool showWifiDialog: false
    property bool showBluetoothDialog: false
    property bool showAudioOutputDialog: false

    DialogHostLoader {
        owner: root
        shownPropertyString: "showWifiDialog"
        focusTarget: surface
        z: 10
        dialog: WifiDialog {
            closeOwningSidebarOnDetails: false
        }
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showBluetoothDialog"
        focusTarget: surface
        z: 10
        dialog: BluetoothDialog {
            closeOwningSidebarOnDetails: false
        }
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showAudioOutputDialog"
        focusTarget: surface
        z: 10
        dialog: VolumeDialog {
            isSink: true
            closeOwningSidebarOnDetails: false
        }
    }

    onVisibleChanged: {
        if (visible) {
            surface.forceActiveFocus();
        } else {
            root.showWifiDialog = false;
            root.showBluetoothDialog = false;
            root.showAudioOutputDialog = false;
            flow.reset();
        }
    }
}
