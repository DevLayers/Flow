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

import qs.modules.ii.sidebarDashboard.quickToggles
import qs.modules.ii.sidebarDashboard.quickToggles.classicStyle

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
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 10
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

    readonly property bool isDynamicIslandTop: !Config.options.bar.vertical && !Config.options.bar.bottom && Config.options.bar.cornerStyle === 3
    readonly property bool isDynamicIslandBottom: !Config.options.bar.vertical && Config.options.bar.bottom && Config.options.bar.cornerStyle === 3

    property bool isLoadedOnLeft: false

    Component.onCompleted: {
        if (GlobalStates.requestVolumeDialog) {
            root.showAudioOutputDialog = true;
            GlobalStates.requestVolumeDialog = false;
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (GlobalStates.sidebarRightOpen) {
                root.triggerContentEntrance();
            }
            if (!GlobalStates.sidebarRightOpen) {
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

    implicitHeight: sidebarRightBackground.implicitHeight
    implicitWidth: sidebarRightBackground.implicitWidth

    Loader {
        id: sidebarRightShadowLoader
        active: (!GlobalStates.connectModeActive || GlobalStates.connectSidebarsSeparate || root.isDynamicIslandTop || root.isDynamicIslandBottom) && !root.anyDialogVisible
        sourceComponent: Component {
            StyledRectangularShadow {
                target: sidebarRightBackground
                radius: sidebarRightBackground.radius
            }
        }
    }
    Rectangle {
        id: sidebarRightBackground

        anchors.fill: parent
        implicitHeight: Math.max(0, parent.height - Appearance.sizes.hyprlandGapsOut * 2)
        implicitWidth: sidebarWidth - Appearance.sizes.hyprlandGapsOut * 2
        color: (GlobalStates.connectModeActive && !GlobalStates.connectSidebarsSeparate) ? "transparent" : (Config.options.bar.expressiveColors ? activeTheme.barBackground : Appearance.colors.colLayer0)
        border.width: (GlobalStates.connectModeActive && !GlobalStates.connectSidebarsSeparate) ? 0 : 1
        border.color: (GlobalStates.connectModeActive && !GlobalStates.connectSidebarsSeparate) ? "transparent" : Appearance.colors.colLayer0Border
        readonly property bool isConnectDynamicIslandTop: GlobalStates.connectModeActive && !GlobalStates.connectSidebarsSeparate && root.isDynamicIslandTop
        readonly property bool isConnectDynamicIslandBottom: GlobalStates.connectModeActive && !GlobalStates.connectSidebarsSeparate && root.isDynamicIslandBottom
        readonly property real defaultRadius: (GlobalStates.connectModeActive && !GlobalStates.connectSidebarsSeparate && !root.isDynamicIslandTop && !root.isDynamicIslandBottom) ? 0 : Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
        radius: isConnectDynamicIslandTop ? 0 : defaultRadius
        topRightRadius: ((isConnectDynamicIslandTop && !root.isLoadedOnLeft) || (isConnectDynamicIslandBottom && root.isLoadedOnLeft)) ? 0 : defaultRadius
        topLeftRadius: ((isConnectDynamicIslandTop && root.isLoadedOnLeft) || (isConnectDynamicIslandBottom && !root.isLoadedOnLeft)) ? 0 : defaultRadius
        bottomRightRadius: (GlobalStates.connectModeActive && !GlobalStates.connectSidebarsSeparate && !isConnectDynamicIslandBottom) ? 0 : ((isConnectDynamicIslandBottom && !root.isLoadedOnLeft) ? 0 : defaultRadius)
        bottomLeftRadius: (GlobalStates.connectModeActive && !GlobalStates.connectSidebarsSeparate && !isConnectDynamicIslandBottom) ? 0 : ((isConnectDynamicIslandBottom && root.isLoadedOnLeft) ? 0 : defaultRadius)

        property real dialogBlurProgress: root.anyDialogVisible ? 1.0 : 0.0
        Behavior on dialogBlurProgress {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebarPadding
            spacing: sidebarPadding

            layer.enabled: sidebarRightBackground.dialogBlurProgress > 0.01
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                blur: sidebarRightBackground.dialogBlurProgress
            }

            SystemButtonRow {
                id: headerRow
                Layout.fillHeight: false
                Layout.fillWidth: true
                // Layout.margins: 10
                Layout.topMargin: 5
                Layout.bottomMargin: 0
                entranceTrigger: root.entranceTrigger
                editMode: root.editMode
                onEditModeToggled: (newEditMode) => root.editMode = newEditMode
            }

            LoaderedQuickPanelImplementation {
                id: classicQuickPanelLoader
                styleName: "classic"
                sourceComponent: ClassicQuickPanel {
                    onOpenVpnDialog: root.showVpnDialog = true
                    onOpenTailscaleDialog: root.showTailscaleDialog = true
                }
            }

            LoaderedQuickPanelImplementation {
                id: androidQuickPanelLoader
                styleName: "android"
                sourceComponent: AndroidQuickPanel {
                    editMode: root.editMode
                    onOpenVpnDialog: root.showVpnDialog = true
                    onOpenTailscaleDialog: root.showTailscaleDialog = true
                    onOpenDnsOverTlsDialog: root.showDnsOverTlsDialog = true
                    onOpenScreenShaderDialog: root.showScreenShaderDialog = true
                }
            }

            Loader {
                id: centerGroup
                // Notifications remain backed by their global service; only the
                // heavy visual center group is discarded while the sidebar is closed.
                active: GlobalStates.sidebarRightOpen
                asynchronous: true
                sourceComponent: CenterWidgetGroup {}
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.fillWidth: true
                visible: !root.editMode
            }

            Item {
                Layout.fillHeight: true
                visible: root.editMode
            }

            BottomWidgetGroup {
                id: bottomGroup
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                forceCollapsed: root.editMode
            }
        }
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showAudioOutputDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
        dialog: VolumeDialog {
            isSink: true
        }
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showAudioInputDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
        dialog: VolumeDialog {
            isSink: false
        }
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showBluetoothDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
        dialog: BluetoothDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showNightLightDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
        dialog: NightLightDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showWifiDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
        dialog: WifiDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showDarkModeDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
        dialog: DarkModeDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showLocalSendDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
        dialog: LocalSendDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showVpnDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
        dialog: VpnDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showTailscaleDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
        dialog: TailscaleDialog {}
    }

    DialogHostLoader {
        owner: root
        shownPropertyString: "showDnsOverTlsDialog"
        dialogRadius: sidebarRightBackground.defaultRadius
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
                item.radius = sidebarRightBackground.defaultRadius;
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
        Layout.fillWidth: item?.Layout.fillWidth ?? false
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

    component SystemButtonRow: Item {
        id: systemButtonRowRoot
        implicitHeight: Math.max(uptimeContainer.implicitHeight, systemButtonsRow.implicitHeight)
        property int entranceTrigger: -1
        property bool editMode: false
        signal editModeToggled(bool newEditMode)

        // Entrance animation properties
        property real _leftTranslateX: -30
        property real _rightTranslateX: 30
        property real _entranceTranslateY: -15
        property real _entranceOpacity: 0
        property bool _entranceDone: false
        readonly property bool _animationsDisabled: (Config.options?.appearance?.animationMultiplier ?? 1.0) <= 0.25

        onEntranceTriggerChanged: {
            if (_animationsDisabled) {
                _entranceDone = true;
                _entranceOpacity = 1;
                _leftTranslateX = 0;
                _rightTranslateX = 0;
                _entranceTranslateY = 0;
                return;
            }
            _entranceDone = false;
            _entranceOpacity = 0;
            _leftTranslateX = -30;
            _rightTranslateX = 30;
            _entranceTranslateY = -15;
            Qt.callLater(function() {
                entranceAnim.start();
            });
        }

        Component.onCompleted: {
            if (_animationsDisabled) {
                _entranceDone = true;
                _entranceOpacity = 1;
                _leftTranslateX = 0;
                _rightTranslateX = 0;
                _entranceTranslateY = 0;
                return;
            }
            _entranceDone = false;
            _entranceOpacity = 0;
            _leftTranslateX = -30;
            _rightTranslateX = 30;
            _entranceTranslateY = -15;
            Qt.callLater(function() {
                entranceAnim.start();
            });
        }

        SequentialAnimation {
            id: entranceAnim
            ParallelAnimation {
                NumberAnimation { target: systemButtonRowRoot; property: "_entranceOpacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { target: systemButtonRowRoot; property: "_leftTranslateX"; from: -30; to: 0; duration: 320; easing.type: Easing.OutCubic }
                NumberAnimation { target: systemButtonRowRoot; property: "_rightTranslateX"; from: 30; to: 0; duration: 340; easing.type: Easing.OutCubic }
                NumberAnimation { target: systemButtonRowRoot; property: "_entranceTranslateY"; from: -15; to: 0; duration: 300; easing.type: Easing.OutCubic }
            }
            PropertyAction { target: systemButtonRowRoot; property: "_entranceDone"; value: true }
        }

        Rectangle {
            id: uptimeContainer
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            color: Appearance.colors.colLayer1
            readonly property int fullRadius: Config.options.appearance.sharpMode ? Appearance.rounding.full : height / 2
            radius: fullRadius

            visible: Config.options.sidebar.dashboardHeader.profileImageType !== "none" || Config.options.sidebar.dashboardHeader.textMode !== "none"

            opacity: systemButtonRowRoot._entranceDone ? 1.0 : systemButtonRowRoot._entranceOpacity
            transform: Translate {
                x: systemButtonRowRoot._entranceDone ? 0 : systemButtonRowRoot._leftTranslateX
                y: systemButtonRowRoot._entranceDone ? 0 : systemButtonRowRoot._entranceTranslateY
            }

            property int rowLeftMargin: Config.options.sidebar.dashboardHeader.profileImageType === "user_profile" ? 6 : 14
            readonly property bool _hasText: Config.options.sidebar.dashboardHeader.textMode !== "none"
            readonly property int rowRightMargin: _hasText ? 14 : rowLeftMargin

            implicitWidth: uptimeRow.implicitWidth + rowLeftMargin + rowRightMargin
            implicitHeight: Math.max(32, uptimeRow.implicitHeight + (Config.options.sidebar.dashboardHeader.profileImageType === "user_profile" ? 4 : 12))

            Row {
                id: uptimeRow
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: uptimeContainer.rowLeftMargin
                }
                spacing: 8

                // PROFILE PICTURE
                Item {
                    id: profilePicContainer

                    anchors.verticalCenter: parent.verticalCenter
                    width: Config.options.sidebar.dashboardHeader.profileImageType === "distro" ? 24 : 40
                    height: Config.options.sidebar.dashboardHeader.profileImageType === "distro" ? 24 : 40
                    visible: Config.options.sidebar.dashboardHeader.profileImageType !== "none"

                    Loader {
                        anchors.fill: parent
                        active: Config.options.sidebar.dashboardHeader.profileImageType === "distro"
                        sourceComponent: CustomIcon {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: SystemInfo.distroIcon
                            colorize: true
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: Config.options.sidebar.dashboardHeader.profileImageType === "user_profile"

                        readonly property string _style: Config.options.userProfile.imageStyle

                        // Custom
                        Item {
                            anchors.fill: parent
                            visible: parent._style === "custom"
                            Image {
                                id: profilePicSource
                                anchors.fill: parent
                                source: parent.visible ? Config.options.userProfile.imagePath : ""
                                sourceSize.width: parent.width
                                sourceSize.height: parent.height
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                            }
                            Rectangle {
                                id: profilePicMask
                                anchors.fill: parent
                                radius: width / 2
                                visible: false
                            }
                            OpacityMask {
                                anchors.fill: parent
                                source: profilePicSource
                                maskSource: profilePicMask
                            }
                        }

                        // Initial
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            visible: parent._style === "initial" || parent._style === "default"

                            Image {
                                id: initialAvatarSource
                                anchors.fill: parent
                                source: parent.visible ? Directories.userAvatarPathAccountsService : ""
                                sourceSize.width: parent.width
                                sourceSize.height: parent.height
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                            }
                            Rectangle {
                                id: initialAvatarMask
                                anchors.fill: parent
                                radius: width / 2
                                visible: false
                            }
                            OpacityMask {
                                id: initialAvatarImage
                                anchors.fill: parent
                                source: initialAvatarSource
                                maskSource: initialAvatarMask
                                visible: initialAvatarSource.status === Image.Ready
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Appearance.colors.colPrimary
                                visible: initialAvatarSource.status !== Image.Ready

                                StyledText {
                                    anchors.centerIn: parent
                                    text: SystemInfo.username.charAt(0).toUpperCase()
                                    color: Appearance.colors.colOnPrimary
                                    font.pixelSize: Appearance.font.pixelSize.larger
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        // Expressive
                        MaterialShape {
                            anchors.fill: parent

                            function resolveShapeInner(s) {
                                switch (s) {
                                case "Cookie9Sided":
                                    return MaterialShape.Shape.Cookie9Sided;
                                case "Cookie12Sided":
                                    return MaterialShape.Shape.Cookie12Sided;
                                case "Circle":
                                    return MaterialShape.Shape.Circle;
                                case "Clover4Leaf":
                                    return MaterialShape.Shape.Clover4Leaf;
                                case "Burst":
                                    return MaterialShape.Shape.Burst;
                                case "Heart":
                                    return MaterialShape.Shape.Heart;
                                case "Bun":
                                    return MaterialShape.Shape.Bun;
                                default:
                                    return MaterialShape.Shape.Cookie9Sided;
                                }
                            }
                            shape: resolveShapeInner(Config.options.userProfile.avatarShape)

                            property color resolvedColor: {
                                switch (Config.options.userProfile.avatarColor) {
                                case "primary":
                                    return Appearance.colors.colPrimary;
                                case "secondary":
                                    return Appearance.colors.colSecondary;
                                case "tertiary":
                                    return Appearance.colors.colTertiary;
                                case "error":
                                    return Appearance.colors.colError;
                                default:
                                    return Appearance.colors.colPrimary;
                                }
                            }
                            property color resolvedOnColor: {
                                switch (Config.options.userProfile.avatarColor) {
                                case "primary":
                                    return Appearance.colors.colOnPrimary;
                                case "secondary":
                                    return Appearance.colors.colOnSecondary;
                                case "tertiary":
                                    return Appearance.colors.colOnTertiary;
                                case "error":
                                    return Appearance.colors.colOnError;
                                default:
                                    return Appearance.colors.colOnPrimary;
                                }
                            }

                            color: resolvedColor
                            visible: parent._style === "expressive"

                            StyledText {
                                anchors.centerIn: parent
                                text: {
                                    let n = Config.options.userProfile.customName || SystemInfo.username;
                                    return n.charAt(0).toUpperCase();
                                }
                                color: parent.resolvedOnColor
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.family: Appearance.font.family.expressive
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    visible: Config.options.sidebar.dashboardHeader.textMode !== "none"

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colOnLayer0
                        text: {
                            const mode = Config.options.sidebar.dashboardHeader.textMode;
                            if (mode === "username") {
                                const greeting = Config.options.userProfile.customGreeting;
                                return (greeting !== "" ? greeting : Translation.tr("Hello,")) + " " + (Config.options.userProfile.customName !== "" ? Config.options.userProfile.customName : SystemInfo.username);
                            }
                            if (mode === "uptime")
                                return Translation.tr("Uptime") + ": " + DateTime.uptime;
                            if (mode === "custom")
                                return Config.options.sidebar.dashboardHeader.customText;
                            return "";
                        }
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                        text: Config.options.userProfile.customBio
                        visible: Config.options.sidebar.dashboardHeader.textMode === "username" && text !== ""
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        ButtonGroup {
            id: systemButtonsRow
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            color: Appearance.colors.colLayer1
            padding: 4

            opacity: systemButtonRowRoot._entranceDone ? 1.0 : systemButtonRowRoot._entranceOpacity
            transform: Translate {
                x: systemButtonRowRoot._entranceDone ? 0 : systemButtonRowRoot._rightTranslateX
                y: systemButtonRowRoot._entranceDone ? 0 : systemButtonRowRoot._entranceTranslateY
            }

            QuickToggleButton {
                id: editButton
                toggled: systemButtonRowRoot.editMode
                visible: Config.options.sidebar.quickToggles.style === "android"
                buttonIcon: "edit"
                onClicked: {
                    systemButtonRowRoot.editMode = !systemButtonRowRoot.editMode;
                    systemButtonRowRoot.editModeToggled(systemButtonRowRoot.editMode);
                }
                StyledToolTip {
                    text: Translation.tr("Edit quick toggles") + (systemButtonRowRoot.editMode ? Translation.tr("\nLMB to enable/disable\nDrag handles to resize\nDrag icon to swap position") : "")
                }

                SequentialAnimation {
                    id: editEntranceAnim
                    ScriptAction { script: editButton.rotation = -180 }
                    NumberAnimation { target: editButton; property: "rotation"; from: -180; to: 0; duration: 400; easing.type: Easing.OutCubic }
                }
                Connections {
                    target: systemButtonRowRoot
                    function onEntranceTriggerChanged() {
                        if (systemButtonRowRoot.entranceTrigger >= 0) {
                            editEntranceAnim.start();
                        }
                    }
                }
            }
            QuickToggleButton {
                id: reloadButton
                toggled: false
                buttonIcon: "restart_alt"
                onClicked: {
                    Quickshell.execDetached(["hyprctl", "reload"]);
                    Quickshell.reload(true);
                }
                StyledToolTip {
                    text: Translation.tr("Reload Hyprland & Quickshell")
                }

                SequentialAnimation {
                    id: reloadEntranceAnim
                    ScriptAction { script: reloadButton.rotation = -360 }
                    NumberAnimation { target: reloadButton; property: "rotation"; from: -360; to: 0; duration: 500; easing.type: Easing.OutCubic }
                }
                Connections {
                    target: systemButtonRowRoot
                    function onEntranceTriggerChanged() {
                        if (systemButtonRowRoot.entranceTrigger >= 0) {
                            reloadEntranceAnim.start();
                        }
                    }
                }
            }
            QuickToggleButton {
                id: settingsButton
                toggled: false
                buttonIcon: "settings"
                onClicked: {
                    GlobalStates.sidebarRightOpen = false;
                    GlobalStates.toggleSettings();
                }
                StyledToolTip {
                    text: Translation.tr("Settings")
                }

                SequentialAnimation {
                    id: settingsEntranceAnim
                    ScriptAction { script: settingsButton.rotation = 90 }
                    NumberAnimation { target: settingsButton; property: "rotation"; from: 90; to: 0; duration: 350; easing.type: Easing.OutBack }
                }
                Connections {
                    target: systemButtonRowRoot
                    function onEntranceTriggerChanged() {
                        if (systemButtonRowRoot.entranceTrigger >= 0) {
                            settingsEntranceAnim.start();
                        }
                    }
                }
            }

            QuickToggleButton {
                id: powerButton
                toggled: false
                buttonIcon: "power_settings_new"
                onClicked: {
                    GlobalStates.sessionOpen = true;
                }
                StyledToolTip {
                    text: Translation.tr("Session")
                }

                SequentialAnimation {
                    id: powerEntranceAnim
                    ScriptAction { script: powerButton.rotation = -90 }
                    NumberAnimation { target: powerButton; property: "rotation"; from: -90; to: 0; duration: 350; easing.type: Easing.OutBack }
                }
                Connections {
                    target: systemButtonRowRoot
                    function onEntranceTriggerChanged() {
                        if (systemButtonRowRoot.entranceTrigger >= 0) {
                            powerEntranceAnim.start();
                        }
                    }
                }
            }
        }
    }
}
