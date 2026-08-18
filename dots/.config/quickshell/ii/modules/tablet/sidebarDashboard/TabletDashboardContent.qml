import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar as Bar
import qs.modules.ii.bar.shared
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

import qs.modules.ii.sidebarDashboard
import qs.modules.ii.sidebarDashboard.quickToggles
import qs.modules.ii.sidebarDashboard.quickToggles.classicStyle
import qs.modules.ii.sidebarDashboard.notifications
import qs.modules.ii.sidebarDashboard.bluetoothDevices
import qs.modules.ii.sidebarDashboard.nightLight
import qs.modules.ii.sidebarDashboard.volumeMixer
import qs.modules.ii.sidebarDashboard.wifiNetworks
import qs.modules.ii.sidebarDashboard.darkMode
import qs.modules.ii.sidebarDashboard.localSend
import qs.modules.ii.sidebarDashboard.vpn
import qs.modules.ii.sidebarDashboard.tailscale
import qs.modules.ii.sidebarDashboard.dnsOverTls
import qs.modules.ii.sidebarDashboard.idleInhibitor
import qs.modules.ii.sidebarDashboard.screenShader

Item {
    id: root

    signal dismissRequested()

    property bool showAudioOutputDialog: false
    property bool showAudioInputDialog: false
    property bool showBluetoothDialog: false
    property bool showNightLightDialog: false
    property bool showWifiDialog: false
    property bool showDarkModeDialog: false
    property bool showLocalSendDialog: false
    property bool showVpnDialog: false
    property bool showTailscaleDialog: false
    property bool showDnsOverTlsDialog: false
    property bool showIdleInhibitorDialog: false
    property bool showScreenShaderDialog: false
    readonly property bool anyDialogVisible: showAudioOutputDialog || showAudioInputDialog || showBluetoothDialog || showNightLightDialog || showWifiDialog || showDarkModeDialog || showLocalSendDialog || showVpnDialog || showTailscaleDialog || showDnsOverTlsDialog || showIdleInhibitorDialog || showScreenShaderDialog
    property bool editMode: false

    property int entranceTrigger: -1

    function triggerContentEntrance() {
        entranceTrigger++;
    }

    Connections {
        target: TabletDashboardGestureController
        function onProgressChanged() {
            if (TabletDashboardGestureController.progress >= 0.95 && root.entranceTrigger < 0) {
                root.triggerContentEntrance();
            } else if (TabletDashboardGestureController.progress <= 0.05) {
                root.showWifiDialog = false;
                root.showBluetoothDialog = false;
                root.showAudioOutputDialog = false;
                root.showAudioInputDialog = false;
                root.showDarkModeDialog = false;
                root.showLocalSendDialog = false;
                root.showVpnDialog = false;
                root.showTailscaleDialog = false;
                root.showDnsOverTlsDialog = false;
                root.showIdleInhibitorDialog = false;
                root.showScreenShaderDialog = false;
                root.entranceTrigger = -1;
            }
        }
    }

    Connections {
        target: GlobalStates
        function onRequestVolumeDialogChanged() {
            if (GlobalStates.requestVolumeDialog) {
                root.showAudioOutputDialog = true;
                GlobalStates.requestVolumeDialog = false;
            }
        }
    }

    BarThemes {
        id: barThemes
    }
    readonly property var activeTheme: barThemes.getTheme(Config.options.bar.expressiveColorTheme)

    // ── MAIN CONTENT CONTAINER ──────────────────────────────────────────────
    Item {
        id: contentContainer
        anchors {
            fill: parent
            leftMargin: Appearance.sizes.hyprlandGapsOut * 3
            rightMargin: Appearance.sizes.hyprlandGapsOut * 3
            topMargin: Appearance.sizes.hyprlandGapsOut * 3
            bottomMargin: Appearance.sizes.hyprlandGapsOut * 3
        }

        property real dialogBlurProgress: root.anyDialogVisible ? 1.0 : 0.0
        Behavior on dialogBlurProgress {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }

        // Two-column landscape layout (Android 16 style)
        RowLayout {
            id: mainRowLayout
            anchors.fill: parent
            spacing: Appearance.sizes.hyprlandGapsOut * 2

            layer.enabled: contentContainer.dialogBlurProgress > 0.01
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                blur: contentContainer.dialogBlurProgress
            }

            // ══════════════════════════════════════════════════════════════════
            // LEFT COLUMN: Quick Toggles (with sliders) + System Button Row
            // ══════════════════════════════════════════════════════════════════
            ColumnLayout {
                id: leftColumn
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width * 0.5
                spacing: Appearance.sizes.hyprlandGapsOut * 2

                // Quick Toggles Card
                Rectangle {
                    id: quickTogglesCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Config.options.bar.expressiveColors ? activeTheme.barBackground : Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        LoaderedQuickPanelImplementation {
                            id: classicQuickPanelLoader
                            styleName: "classic"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: ClassicQuickPanel {
                                onOpenVpnDialog: root.showVpnDialog = true
                                onOpenTailscaleDialog: root.showTailscaleDialog = true
                            }
                        }

                        LoaderedQuickPanelImplementation {
                            id: androidQuickPanelLoader
                            styleName: "android"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: AndroidQuickPanel {
                                editMode: root.editMode
                                onOpenVpnDialog: root.showVpnDialog = true
                                onOpenTailscaleDialog: root.showTailscaleDialog = true
                                onOpenDnsOverTlsDialog: root.showDnsOverTlsDialog = true
                                onOpenScreenShaderDialog: root.showScreenShaderDialog = true
                            }
                        }
                    }
                }

                // System Button Row (Uptime / Profile Banner + Action Buttons)
                SystemButtonRow {
                    id: systemButtonRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    entranceTrigger: root.entranceTrigger
                    editMode: root.editMode
                    onEditModeToggled: (newEditMode) => root.editMode = newEditMode
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // RIGHT COLUMN: Notifications + Bottom Widget Group
            // ══════════════════════════════════════════════════════════════════
            ColumnLayout {
                id: rightColumn
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width * 0.5
                spacing: Appearance.sizes.hyprlandGapsOut * 2

                // Notifications Card
                Rectangle {
                    id: notificationsCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    clip: true

                    NotificationList {
                        anchors.fill: parent
                        anchors.margins: 8
                        entranceTrigger: root.entranceTrigger
                    }
                }

                // Bottom Widget Group (Calendar / To-Do / Timer)
                BottomWidgetGroup {
                    id: bottomWidgetGroup
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    forceCollapsed: root.editMode
                }
            }
        }
    }

    // ── SWIPE UP GESTURE TO DISMISS ─────────────────────────────────────────
    DragHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchScreen
        xAxis.enabled: false
        yAxis.enabled: true
        yAxis.minimum: -500
        yAxis.maximum: 0
        onActiveChanged: {
            if (!active && translation.y < -60) {
                root.dismissRequested();
            }
        }
    }

    // ── DIALOG LOADERS ──────────────────────────────────────────────────────
    DialogHostLoader {
        owner: root
        shownPropertyString: "showAudioOutputDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: VolumeDialog {
            isSink: true
        }
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showAudioInputDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: VolumeDialog {
            isSink: false
        }
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showBluetoothDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: BluetoothDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showNightLightDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: NightLightDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showWifiDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: WifiDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showDarkModeDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: DarkModeDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showLocalSendDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: LocalSendDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showVpnDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: VpnDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showTailscaleDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: TailscaleDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showDnsOverTlsDialog"
        dialogRadius: Appearance.rounding.normal
        dialog: DnsOverTlsDialog {}
    }

    ToggleDialog {
        shownPropertyString: "showIdleInhibitorDialog"
        dialog: IdleInhibitorDialog {}
    }

    ToggleDialog {
        shownPropertyString: "showScreenShaderDialog"
        dialog: ScreenShaderDialog {}
    }

    component ToggleDialog: Loader {
        id: toggleDialogLoader
        required property string shownPropertyString
        property alias dialog: toggleDialogLoader.sourceComponent
        readonly property bool shown: root[shownPropertyString]
        anchors.fill: parent

        onShownChanged: if (shown)
            toggleDialogLoader.active = true
        active: shown
        onActiveChanged: {
            if (active) {
                item.show = true;
                item.forceActiveFocus();
            }
        }
        onLoaded: {
            if (item && item.hasOwnProperty("radius")) {
                item.radius = Appearance.rounding.normal;
            }
        }
        Connections {
            target: toggleDialogLoader.item
            function onDismiss() {
                toggleDialogLoader.item.show = false;
                root[toggleDialogLoader.shownPropertyString] = false;
            }
            function onVisibleChanged() {
                if (!toggleDialogLoader.item.visible && !root[toggleDialogLoader.shownPropertyString])
                    toggleDialogLoader.active = false;
            }
        }
    }

    component LoaderedQuickPanelImplementation: Loader {
        id: quickPanelImplLoader
        required property string styleName
        Layout.alignment: item?.Layout.alignment ?? Qt.AlignHCenter
        Layout.fillWidth: item?.Layout.fillWidth ?? true
        Layout.fillHeight: item?.Layout.fillHeight ?? true
        visible: active
        active: Config.options.sidebar.quickToggles.style === styleName
        Connections {
            target: quickPanelImplLoader.item
            function onOpenAudioOutputDialog() {
                root.showAudioOutputDialog = true;
            }
            function onOpenAudioInputDialog() {
                root.showAudioInputDialog = true;
            }
            function onOpenBluetoothDialog() {
                root.showBluetoothDialog = true;
            }
            function onOpenNightLightDialog() {
                root.showNightLightDialog = true;
            }
            function onOpenWifiDialog() {
                root.showWifiDialog = true;
            }
            function onOpenDarkModeDialog() {
                root.showDarkModeDialog = true;
            }
            function onOpenLocalSendDialog() {
                root.showLocalSendDialog = true;
            }
            function onOpenIdleInhibitorDialog() {
                root.showIdleInhibitorDialog = true;
            }
        }
    }
}
