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
import qs.modules.ii.sidebarDashboard.modes
import "SidebarSpaceArbitration.js" as SpaceArbitration

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
    property bool showModesDialog: false
    readonly property bool anyDialogVisible: showAudioOutputDialog || showAudioInputDialog || showBluetoothDialog || showNightLightDialog || showWifiDialog || showDarkModeDialog || showLocalSendDialog || showVpnDialog || showTailscaleDialog || showDnsOverTlsDialog || showIdleInhibitorDialog || showScreenShaderDialog || showModesDialog
    property bool editMode: false

    // Compact-space arbitration is runtime-only. When the height that the
    // notification center would receive with the bottom group expanded falls
    // below its useful minimum, exactly one of the two groups stays expanded.
    // Notifications win when compact mode first activates; a manual expansion
    // request from the bottom group hands the space to it until it is collapsed.
    property bool compactBottomRequestedExpanded: false
    readonly property real expandedNotificationsHeightBudget: SpaceArbitration.expandedCenterBudget(
        adaptiveGroups.availableHeight,
        bottomGroup.expandedHeight,
        sidebarPadding
    )
    readonly property real minimumExpandedNotificationsHeight: centerGroup.item?.minimumExpandedHeight ?? 0
    readonly property bool compactModeRequired: SpaceArbitration.requiresCompactMode(
        expandedNotificationsHeightBudget,
        minimumExpandedNotificationsHeight,
        !editMode && centerGroup.visible && bottomGroup.visible
    )
    readonly property var compactSpaceResolution: SpaceArbitration.resolve(
        compactModeRequired,
        compactBottomRequestedExpanded,
        bottomGroup.collapsed,
        editMode
    )
    readonly property bool notificationsCollapsed: compactSpaceResolution.notificationsCollapsed
    readonly property bool bottomForceCollapsed: compactSpaceResolution.bottomForcedCollapsed

    onCompactModeRequiredChanged: compactBottomRequestedExpanded = false

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
                root.showModesDialog = false;
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

    // Edit mode grows the quick panel by a tray of every toggle that is not on a
    // page, which has no natural cap and runs straight past the bottom of the
    // sidebar. Hand the panel the height the column can actually give it, so it
    // can cap and scroll that tray itself.
    readonly property real quickPanelMaxHeight: {
        let available = mainColumn.height;
        const fixedHeights = [
            sidebarBanner.visible ? sidebarBanner.Layout.preferredHeight : -1,
            headerRow.visible ? headerRow.implicitHeight + headerRow.Layout.topMargin : -1,
            centerGroup.visible ? centerGroup.implicitHeight : -1,
            bottomGroup.visible
                ? (bottomGroup.effectivelyCollapsed
                    ? bottomGroup.collapsedHeight
                    : bottomGroup.expandedHeight)
                : -1
        ];
        for (let i = 0; i < fixedHeights.length; i++) {
            if (fixedHeights[i] < 0)
                continue;
            available -= fixedHeights[i] + mainColumn.spacing;
        }
        return Math.max(0, available);
    }

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
        clip: true
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

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: sidebarRightBackground.width
                height: sidebarRightBackground.height
                radius: sidebarRightBackground.radius
                topLeftRadius: sidebarRightBackground.topLeftRadius
                topRightRadius: sidebarRightBackground.topRightRadius
                bottomLeftRadius: sidebarRightBackground.bottomLeftRadius
                bottomRightRadius: sidebarRightBackground.bottomRightRadius
            }
        }

        property real dialogBlurProgress: root.anyDialogVisible ? 1.0 : 0.0
        Behavior on dialogBlurProgress {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: sidebarPadding
            spacing: sidebarPadding

            layer.enabled: sidebarRightBackground.dialogBlurProgress > 0.01
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                blur: sidebarRightBackground.dialogBlurProgress
            }

            // SIDEBAR BANNER
            SidebarBanner {
                id: sidebarBanner
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                visible: Config.options.sidebar.enableBanner
                enabled: visible
                entranceTrigger: root.entranceTrigger
                editMode: root.editMode
                onEditModeToggled: (newEditMode) => root.editMode = newEditMode
            }

            // DEFAULT
            SystemButtonRow {
                id: headerRow
                Layout.fillHeight: false
                Layout.fillWidth: true
                // Layout.margins: 10
                Layout.topMargin: 5
                Layout.bottomMargin: 0
                visible: !Config.options.sidebar.enableBanner
                enabled: visible
                entranceTrigger: root.entranceTrigger
                editMode: root.editMode
                onEditModeToggled: (newEditMode) => root.editMode = newEditMode
            }

            LoaderedQuickPanelImplementation {
                id: classicQuickPanelLoader
                styleName: "classic"
                sourceComponent: ClassicQuickPanel {
                    editMode: root.editMode
                    onOpenVpnDialog: root.showVpnDialog = true
                    onOpenTailscaleDialog: root.showTailscaleDialog = true
                }
            }

            LoaderedQuickPanelImplementation {
                id: androidQuickPanelLoader
                styleName: "android"
                sourceComponent: AndroidQuickPanel {
                    editMode: root.editMode
                    maxContentHeight: root.quickPanelMaxHeight
                    onOpenVpnDialog: root.showVpnDialog = true
                    onOpenTailscaleDialog: root.showTailscaleDialog = true
                    onOpenDnsOverTlsDialog: root.showDnsOverTlsDialog = true
                    onOpenScreenShaderDialog: root.showScreenShaderDialog = true
                }
            }

            Item {
                id: adaptiveGroups
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumHeight: containmentHeight
                readonly property real availableHeight: Math.max(0, mainColumn.height - y)
                readonly property real packedTakeoverHeight: SpaceArbitration.packedGroupsMinimumHeight(
                        bottomGroup.expandedHeight,
                        centerGroup.collapsedHeight,
                        targetSpacing
                    )
                readonly property real targetContainmentHeight: root.notificationsCollapsed
                    ? packedTakeoverHeight
                    : availableHeight
                property real containmentHeight: targetContainmentHeight
                readonly property real targetSpacing: SpaceArbitration.dashboardSpacing(
                    root.notificationsCollapsed,
                    root.sidebarPadding
                )
                readonly property real targetBottomHeight: bottomGroup.effectivelyCollapsed
                    ? bottomGroup.collapsedHeight
                    : root.notificationsCollapsed
                        ? SpaceArbitration.expandedBottomFillHeight(
                            availableHeight,
                            bottomGroup.expandedHeight,
                            centerGroup.collapsedHeight,
                            targetSpacing
                        )
                        : bottomGroup.expandedHeight
                readonly property real expandedCenterTargetHeight: Math.max(
                    0,
                    availableHeight - targetBottomHeight - targetSpacing
                )
                property real groupSpacing: targetSpacing
                property real animatedBottomHeight: targetBottomHeight

                Behavior on containmentHeight {
                    SidebarGroupAnimation {
                        animationSpec: Appearance.animation.elementMove
                    }
                }

                Behavior on groupSpacing {
                    SidebarGroupAnimation {
                        animationSpec: Appearance.animation.elementMove
                    }
                }

                Behavior on animatedBottomHeight {
                    SidebarGroupAnimation {
                        animationSpec: Appearance.animation.elementMove
                    }
                }

                Loader {
                    id: centerGroup
                    // Notifications remain backed by their global service; only the
                    // heavy visual center group is discarded while the sidebar is closed.
                    active: GlobalStates.sidebarRightOpen
                    asynchronous: true
                    sourceComponent: CenterWidgetGroup {
                        collapsed: root.notificationsCollapsed
                    }
                    readonly property real collapsedHeight: item?.collapsedHeight ?? 0
                    property real animatedHeight: SpaceArbitration.notificationMaximumHeight(
                        root.notificationsCollapsed,
                        collapsedHeight,
                        adaptiveGroups.expandedCenterTargetHeight
                    )

                    Behavior on animatedHeight {
                        SidebarGroupAnimation {
                            animationSpec: Appearance.animation.elementMove
                        }
                    }

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: bottomGroup.top
                    anchors.bottomMargin: adaptiveGroups.groupSpacing
                    height: animatedHeight
                    visible: !root.editMode
                }

                BottomWidgetGroup {
                    id: bottomGroup
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: adaptiveGroups.animatedBottomHeight
                    forceCollapsed: root.bottomForceCollapsed
                    onCollapseRequested: shouldCollapse => {
                        if (root.compactModeRequired)
                            root.compactBottomRequestedExpanded = !shouldCollapse;
                    }
                }
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

    ToggleDialog {
        shownPropertyString: "showModesDialog"
        dialog: ModesDialog {}
    }

    component SidebarBanner: Item {
        id: headerRoot
        property int entranceTrigger: -1
        property bool editMode: false
        signal editModeToggled(bool newEditMode)
        implicitHeight: 220

        Rectangle {
            id: bannerBackground
            anchors.fill: parent
            radius: 15
            color: Appearance.colors.colLayer1

            // wallpaper section (top 70%)
            Item {
                id: wallpaperArea
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: parent.height * 0.7
                
                Rectangle {
                    id: imageMask
                    anchors.fill: parent
                    radius: 15
                    visible: false
                }

                Image {
                    id: bannerImage
                    anchors.fill: parent
                    // A wallpaper-sized banner costs RAM twice - decoded image plus GPU texture - for
                    // detail this strip cannot show. PreserveAspectCrop makes sourceSize a cover box,
                    // so the device-pixel size of the strip is all the decoder ever has to produce.
                    //
                    // The box only ever grows, and nothing loads before the strip is laid out in a
                    // window: a source set against a zero-width box decodes at the file's native
                    // size, and a box that shrinks - the window reports the integer output scale for
                    // a moment before the fractional one arrives - re-decodes the file for nothing.
                    readonly property real windowDpr: (QsWindow.window as QsWindow)?.devicePixelRatio ?? 0
                    property size decodeBox: Qt.size(0, 0)
                    onWindowDprChanged: bannerImage.growDecodeBox()
                    onWidthChanged: bannerImage.growDecodeBox()
                    onHeightChanged: bannerImage.growDecodeBox()
                    function growDecodeBox() {
                        if (bannerImage.windowDpr <= 0 || bannerImage.width <= 0 || bannerImage.height <= 0)
                            return;
                        const boxWidth = Math.ceil(bannerImage.width * bannerImage.windowDpr);
                        const boxHeight = Math.ceil(bannerImage.height * bannerImage.windowDpr);
                        if (boxWidth <= bannerImage.decodeBox.width && boxHeight <= bannerImage.decodeBox.height)
                            return;
                        bannerImage.decodeBox = Qt.size(Math.max(boxWidth, bannerImage.decodeBox.width),
                            Math.max(boxHeight, bannerImage.decodeBox.height));
                    }

                    source: bannerImage.decodeBox.width <= 0 ? "" : (Config.options.sidebar.useCustomBanner
                        ? (Config.options.sidebar.bannerImage || `${Directories.assetsPath}/images/default_wallpaper.png`)
                        : Config.options.background.wallpaperPath)
                    sourceSize: bannerImage.decodeBox
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: imageMask
                    }
                }
            }

            // Button section
            Rectangle {
                id: buttonArea

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                height: parent.height * 0.3
                color: Appearance.colors.colLayer1
                bottomLeftRadius: bannerBackground.bottomLeftRadius
                bottomRightRadius: bannerBackground.bottomRightRadius
            }

            // pfp overlaps both sections
            Item {
                id: profilePicContainer

                anchors {
                    left: parent.left
                    bottom: buttonArea.bottom

                    leftMargin: 16
                    bottomMargin: 55
                }

                width: 70
                height: 70
                visible: Config.options.sidebar.dashboardHeader.profileImageType !== "none"

                property real outerRadius: 15
                property real borderWidth: 4
                readonly property string _style: Config.options.userProfile.imageStyle

                // DISTRO ICON
                Loader {
                    anchors.fill: parent
                    active: Config.options.sidebar.dashboardHeader.profileImageType === "distro"
                    sourceComponent: CustomIcon {
                        anchors.centerIn: parent
                        width: parent.width - profilePicContainer.borderWidth * 2
                        height: parent.height - profilePicContainer.borderWidth * 2
                        source: SystemInfo.distroIcon
                        colorize: true
                        color: Appearance.colors.colOnLayer1
                    }
                }

                // USER PROFILE
                Item {
                    anchors.fill: parent
                    visible: Config.options.sidebar.dashboardHeader.profileImageType === "user_profile"

                    // Custom
                    Image {
                        id: hardcodedProfilePicture
                        anchors {
                            fill: parent
                            margins: profilePicContainer.borderWidth
                        }
                        visible: profilePicContainer._style === "custom"

                        source: parent.visible ? Config.options.userProfile.imagePath : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: width
                        sourceSize.height: height

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: hardcodedProfilePicture.width
                                height: hardcodedProfilePicture.height
                                radius: profilePicContainer.outerRadius - profilePicContainer.borderWidth
                            }
                        }
                    }

                    // Initial
                    Rectangle {
                        id: initialAvatarBg
                        anchors {
                            fill: parent
                            margins: profilePicContainer.borderWidth
                        }
                        radius: profilePicContainer.outerRadius - profilePicContainer.borderWidth
                        color: Appearance.colors.colPrimary
                        visible: profilePicContainer._style === "initial" || profilePicContainer._style === "default"

                        Image {
                            id: initialAvatarSource
                            anchors.fill: parent
                            source: parent.visible ? Directories.userAvatarPathAccountsService : ""
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: initialAvatarSource.width
                                    height: initialAvatarSource.height
                                    radius: initialAvatarBg.radius
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: initialAvatarSource.status !== Image.Ready
                            text: SystemInfo.username.charAt(0).toUpperCase()
                            color: Appearance.colors.colOnPrimary
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.DemiBold
                        }
                    }

                    // Expressive
                    MaterialShape {
                        id: expressiveShape
                        anchors {
                            fill: parent
                            margins: profilePicContainer.borderWidth
                        }
                        visible: profilePicContainer._style === "expressive"

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

                        StyledText {
                            anchors.centerIn: parent
                            text: {
                                let n = Config.options.userProfile.customName || SystemInfo.username;
                                return n.charAt(0).toUpperCase();
                            }
                            color: expressiveShape.resolvedOnColor
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.family: Appearance.font.family.expressive
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // PFP border
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: profilePicContainer.outerRadius
                    border.width: profilePicContainer.borderWidth
                    border.color: Appearance.colors.colLayer1
                    visible: Config.options.sidebar.dashboardHeader.profileImageType !== "distro"
                             && !(Config.options.sidebar.dashboardHeader.profileImageType === "user_profile"
                                  && profilePicContainer._style === "expressive")
                }
            }

            // sidebar banner text
            Column {
                id: greetingTextColumn
                anchors {
                    left: parent.left
                    leftMargin: 20   // matches systemButtonsRow's rightMargin
                    verticalCenter: buttonArea.verticalCenter
                }
                spacing: 2

                // greeting text
                Text {
                    id: greetingText
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: 14
                    font.weight: Font.Normal
                    horizontalAlignment: Text.AlignLeft
                    width: 210
                    elide: Text.ElideRight

                    text: {
                        const mode = Config.options.sidebar.dashboardHeader.textMode;
                        const hour = new Date().getHours();
                        const timeGreeting = hour < 5 ? Translation.tr("Good Night,")
                            : hour < 12 ? Translation.tr("Good Morning,")
                                : hour < 18 ? Translation.tr("Good Afternoon,")
                                    : hour < 22 ? Translation.tr("Good Evening,")
                                        : Translation.tr("Good Night,");
                        return mode === "username"
                            ? (Config.options.userProfile.customGreeting !== "" ? Config.options.userProfile.customGreeting : timeGreeting) + " " + (Config.options.userProfile.customName !== "" ? Config.options.userProfile.customName : SystemInfo.username.charAt(0).toUpperCase() + SystemInfo.username.slice(1))
                            : mode === "uptime"
                                ? Translation.tr("Uptime") + ": " + DateTime.uptime
                                : mode === "custom"
                                    ? Config.options.sidebar.dashboardHeader.customText
                                    : "";
                    }
                }

                // subtext under greeting
                Text {
                    id: greetingSubtextText
                    color: "#888888"
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    horizontalAlignment: Text.AlignLeft
                    width: 220
                    elide: Text.ElideRight

                    visible: Config.options.sidebar.dashboardSubHeader.greetingSubtextMode !== "none"
                    text: {
                        const mode = Config.options.sidebar.dashboardSubHeader.greetingSubtextMode;
                        return mode === "uptime"
                            ? Translation.tr("Up • ") + DateTime.uptime
                            : mode === "custom"
                                ? Config.options.sidebar.dashboardSubHeader.customText
                                : "";
                    }
                }
            }
        }

        // sidebar banner buttons
        Item {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: 10
            }

            height: systemButtonsRow.implicitHeight

            ButtonGroup {
                id: systemButtonsRow
                anchors {
                    right: parent.right
                    rightMargin: 10
                    verticalCenter: buttonArea.verticalCenter
                }
                color: Appearance.colors.colLayer1
                padding: 4

                QuickToggleButton {
                    id: editButton
                    toggled: headerRoot.editMode

                    visible:
                        Config.options.sidebar.quickToggles.style === "android"

                    buttonIcon: "edit"
                    onClicked: {
                        headerRoot.editMode = !headerRoot.editMode
                        headerRoot.editModeToggled(headerRoot.editMode)
                    }
                }

                QuickToggleButton {
                    buttonIcon: "restart_alt"
                    onClicked: {
                        Quickshell.execDetached(["hyprctl", "reload"])
                        Quickshell.reload(true)
                    }
                }

                QuickToggleButton {
                    buttonIcon: "settings"
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false
                        GlobalStates.toggleSettings()
                    }
                }

                QuickToggleButton {
                    buttonIcon: "power_settings_new"
                    onClicked: {
                        GlobalStates.sessionOpen = true
                    }
                }
            }
        }
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
        Layout.preferredHeight: animatedPanelHeight
        visible: active
        active: Config.options.sidebar.quickToggles.style === styleName
        clip: true
        property real animatedPanelHeight: item?.implicitHeight ?? 0

        // Animate the panel at its single layout boundary. Animating nested
        // heights makes the outer target move on every frame and stretches the
        // perceived transition beyond the configured duration.
        Behavior on animatedPanelHeight {
            SidebarGroupAnimation {
                animationSpec: Appearance.animation.elementMove
            }
        }

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
            function onOpenModesDialog() {
                root.showModesDialog = true;
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
                buttonIcon: "edit"
                onClicked: {
                    systemButtonRowRoot.editMode = !systemButtonRowRoot.editMode;
                    systemButtonRowRoot.editModeToggled(systemButtonRowRoot.editMode);
                }
                StyledToolTip {
                    text: Translation.tr("Edit quick toggles") + (!systemButtonRowRoot.editMode ? "" : Config.options.sidebar.quickToggles.style === "android" ? Translation.tr("\nLMB to enable/disable\nDrag handles to resize\nDrag icon to swap position") : Translation.tr("\nLMB to show/hide a toggle"))
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
