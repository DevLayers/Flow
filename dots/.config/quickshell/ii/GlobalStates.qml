pragma Singleton
pragma ComponentBehavior: Bound
import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property alias sidebarLeftOpen: root.policiesPanelOpen // Until all sidebars naming is fixed
    property alias sidebarRightOpen: root.dashboardPanelOpen // Until all sidebars naming is fixed

    property bool barOpen: true
    property bool phoneCameraRunning: false
    property bool phoneMicRunning: false
    property int mediaModeCount: 0
    readonly property bool mediaModeActive: mediaModeCount > 0
    property var mediaModeMonitors: []
    property int mediaModeCloseAllTrigger: 0
    property int widgetReStackTrigger: 0

    function setMediaModeActiveForScreen(screenName, active) {
        if (!screenName)
            return;
        var list = mediaModeMonitors.slice();
        var index = list.indexOf(screenName);
        if (active && index === -1) {
            list.push(screenName);
        } else if (!active && index !== -1) {
            list.splice(index, 1);
        }
        mediaModeMonitors = list;
    }

    function isMediaModeActiveForScreen(screenName) {
        if (!Config.options.background.mediaMode.togglePerMonitor) {
            return mediaModeActive;
        }
        if (!screenName)
            return false;
        return mediaModeMonitors.includes(screenName);
    }
    property bool alarmRinging: false
    property bool cheatsheetOpen: false
    property bool crosshairOpen: false
    property bool notesOpen: false
    property bool mediaControlsOpen: false
    property bool mediaControlsPinned: false
    // Names of screens currently blacked out by the OLED saver overlay. Independent
    // per monitor: toggling one monitor doesn't affect the others.
    property var oledSaverMonitors: []
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool searchOnlyMode: false

    // scaleValue: animated 1.0 → ~0.85 during overview open (zoomOutStyle 0 only)
    // originX/Y: scale transform center in screen coordinates
    property real overviewZoomScale: 1.0
    property real overviewZoomOriginX: 0.5
    property real overviewZoomOriginY: 0.5
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    // Shared transition clock for the bar and wrapped-frame visuals. Their
    // PanelWindows stay mapped while this runs; each layer chooses fade or
    // slide based on whether the wrapped frame is active.
    property real lockBarTransitionProgress: screenLocked ? 1.0 : 0.0
    Behavior on lockBarTransitionProgress {
        // Use the non-overshooting effects curve for opacity. Spatial curves
        // overshoot and make a fade look like an abrupt blink.
        animation: Appearance.animation.elementMoveSlow.numberAnimation.createObject(root)
    }
    property bool lockScreenCentered: false
    property bool lockAnimationActive: false
    property bool workspaceRestoreInProgress: false
    property bool capsLockActive: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool screenTranslatorOpen: false
    // Ripple signal: emitted by LockSurface on click, received by Background.qml
    // (WlSessionLock and WlrLayershell panels can't directly share children)
    signal lockScreenRipple(x: real, y: real)
    property bool sessionOpen: false
    property bool superDown: false
    property bool usageOpen: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property string wallpaperSelectorTarget: "desktop" // "desktop" or "lockscreen"
    property bool workspaceShowNumbers: false
    property bool filePickerOpen: false
    property bool videoEditorPopupOpen: false
    property bool videoEditorOpen: false
    property string videoEditorPath: ""
    property bool screenshotOverlayOpen: false
    property string screenshotOverlayImagePath: ""
    // Monitor that owns the current screenshot preview overlay.
    property string screenshotOverlayMonitor: ""
    property real screenshotOverlayRegionX: 0
    property real screenshotOverlayRegionY: 0
    property real screenshotOverlayRegionW: 0
    property real screenshotOverlayRegionH: 0
    property bool settingsOpen: false
    property int settingsPendingPage: -1
    property string settingsPendingSubPage: ""
    property string settingsPendingPageName: ""
    // Welcome is an in-process window. Keep its lifecycle in the shared state
    // graph so first-run, keybinds and Settings deep links all use one owner.
    property bool welcomeOpen: false
    // A serial makes repeated requests observable even when the same page is
    // requested twice while Settings is already visible.
    property int settingsNavigationRequest: 0
    property string activeLeftSidebarMonitor: ""
    property string activeRightSidebarMonitor: ""

    function isScreenAllowedForBar(screen) {
        if (!screen)
            return false;
        if (!Config.ready)
            return true;
        if (Config.options.bar.onlyShowOnSingleMonitor) {
            return screen.name === Config.options.bar.singleMonitorName;
        }
        const list = Config.options.bar.screenList;
        if (list && list.length > 0) {
            return list.includes(screen.name);
        }
        return true;
    }

    readonly property var allowedScreens: {
        if (!Config.ready)
            return Quickshell.screens;
        return Quickshell.screens.filter(screen => root.isScreenAllowedForBar(screen));
    }

    readonly property string effectiveLeftMonitor: {
        if (!Config.ready)
            return "";
        switch (Config.options.sidebar.position) {
        case "default":
            return activeLeftSidebarMonitor;
        case "inverted":
            return activeRightSidebarMonitor;
        case "left":
            return policiesPanelOpen ? activeLeftSidebarMonitor : activeRightSidebarMonitor;
        case "right":
            return "";
        default:
            return activeLeftSidebarMonitor;
        }
    }

    readonly property string effectiveRightMonitor: {
        if (!Config.ready)
            return "";
        switch (Config.options.sidebar.position) {
        case "default":
            return activeRightSidebarMonitor;
        case "inverted":
            return activeLeftSidebarMonitor;
        case "left":
            return "";
        case "right":
            return policiesPanelOpen ? activeLeftSidebarMonitor : activeRightSidebarMonitor;
        default:
            return activeRightSidebarMonitor;
        }
    }
    property string activeSearchMonitor: ""
    property real activeSearchHeight: 0
    property real activeSearchWidth: 0
    property string activeSearchQuery: ""
    property bool searchDropActive: false
    property real searchDropExclusionX: 0
    property real searchDropExclusionY: 0
    property real searchDropExclusionWidth: 0
    property real searchDropExclusionHeight: 0
    property real searchDropTopRadius: 0
    property real searchDropBottomRadius: 0

    property bool osdDropActive: false
    property real osdDropExclusionX: 0
    property real osdDropExclusionY: 0
    property real osdDropExclusionWidth: 0
    property real osdDropExclusionHeight: 0
    property real osdDropTopRadius: 0
    property real osdDropBottomRadius: 0

    property string osdCurrentIndicator: "volume"
    property string osdProtectionMessage: ""
    signal osdInteraction
    property bool policiesExtended: false
    property bool policiesPinned: false
    property bool policiesDetached: false

    // Bluetooth connection OSD override
    property bool blockVolumeOsdForBluetooth: false
    Connections {
        target: BluetoothStatus
        ignoreUnknownSignals: true
        function onDeviceConnected(device) {
            root.blockVolumeOsdForBluetooth = true;
            blockOsdTimer.restart();
        }
        function onDeviceDisconnected(device) {
            root.blockVolumeOsdForBluetooth = true;
            blockOsdTimer.restart();
        }
    }
    property Timer blockOsdTimer: Timer {
        id: blockOsdTimer
        interval: 4000
        onTriggered: root.blockVolumeOsdForBluetooth = false
    }

    // Bluetooth connection popup
    property bool bluetoothConnectionPopupOpen: false
    property var bluetoothConnectionPopupDevice: null

    // Floating Notch Bluetooth notification
    property var floatingNotchBtDevice: null
    property string floatingNotchBtAction: "connected"
    property bool floatingNotchBtNotifActive: false

    // LocalSend transfer popup
    property bool localSendPopupOpen: false
    property var localSendPopupTransfer: null

    // Media Popup placement (transient, non-persistent)
    property rect mediaPopupRect: Qt.rect(0, 0, 0, 0)
    property bool mediaWidgetHovered: false
    property Timer mediaWidgetHoverTimer: Timer {
        id: mediaWidgetHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            root.mediaWidgetHovered = false;
        }
    }

    function setMediaWidgetHovered(hovered) {
        if (hovered) {
            mediaWidgetHoverTimer.stop();
            root.mediaWidgetHovered = true;
        } else {
            mediaWidgetHoverTimer.restart();
        }
    }

    // Color Picker Popup
    property bool colorPickerPopupOpen: false
    property string colorPickerPopupColor: ""

    function pickColor(hex) {
        if (hex && hex.startsWith("#")) {
            root.colorPickerPopupColor = hex;
            if (Config.options && Config.options.bar && Config.options.bar.tooltips && Config.options.bar.tooltips.enablePopups && Config.options.bar.tooltips.enableColorPickerPopup) {
                root.colorPickerPopupOpen = false;
                Qt.callLater(() => {
                    root.colorPickerPopupOpen = true;
                });
            }
        }
    }

    function launchColorPicker() {
        Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "colorPickerLaunch", "trigger"]);
    }

    IpcHandler {
        target: "pickColor"
        function handle(hex: string): void {
            root.pickColor(hex);
        }
    }

    function launchLosslessCut(path) {
        root.videoEditorPath = path;
        root.videoEditorPopupOpen = false;
        root.videoEditorOpen = false;
        Quickshell.execDetached(["gio", "launch", Directories.losslessCutDesktopPath, path]);
    }

    function launchVideoEditor(path) {
        root.videoEditorPath = path;
        // The "Recording Finished" prompt is opt-out: keep the path around so the
        // editor can still be opened manually, just don't pop anything up.
        if (!Config.options.screenRecord.showEditPrompt)
            return;
        root.videoEditorPopupOpen = true;
    }

    IpcHandler {
        target: "launchVideoEditor"
        function handle(path: string): void {
            root.launchVideoEditor(path);
        }
    }

    function toggleSettings() {
        root.settingsOpen = !root.settingsOpen;
    }

    function openSettings() {
        root.settingsOpen = true;
    }

    function openSettingsPage(pageId, subPageId, sectionId) {
        const targetSubPage = subPageId || "";
        if (!pageId || pageId === "") {
            root.settingsPendingPageName = "";
            root.settingsPendingSubPage = targetSubPage;
            root.settingsOpen = true;
            return;
        }

        if (SettingsPageRegistry.pageIndexById(pageId) < 0)
            return;

        root.settingsPendingPageName = pageId;
        root.settingsPendingSubPage = targetSubPage;
        root.settingsNavigationRequest += 1;
        root.settingsOpen = true;
    }

    function consumePendingSettingsPage() {
        const pending = root.settingsPendingPageName;
        root.settingsPendingPageName = "";
        return pending;
    }

    function toggleWelcome() {
        root.welcomeOpen = !root.welcomeOpen;
    }

    function openWelcome() {
        root.welcomeOpen = true;
    }

    function closeWelcome() {
        root.welcomeOpen = false;
    }

    function toggleCheatsheet() {
        root.cheatsheetOpen = !root.cheatsheetOpen;
    }

    function openCheatsheet() {
        if (root.cheatsheetOpen) {
            root.cheatsheetOpen = false;
        }
        root.cheatsheetOpen = true;
    }

    function closeCheatsheet() {
        root.cheatsheetOpen = false;
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            root.toggleSettings();
        }

        function open(): void {
            root.openSettings();
        }

        function openPage(pageId: string): void {
            root.openSettingsPage(pageId);
        }

    }

    IpcHandler {
        target: "welcome"

        function toggle(): void {
            root.toggleWelcome();
        }

        function open(): void {
            root.openWelcome();
        }

        function close(): void {
            root.closeWelcome();
        }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            root.toggleCheatsheet();
        }

        function open(): void {
            root.openCheatsheet();
        }

        function close(): void {
            root.closeCheatsheet();
        }
    }

    GlobalShortcut {
        name: "settingsToggle"
        description: "Toggles the settings window"
        onPressed: root.toggleSettings()
    }

    readonly property bool connectModeActive: ShellModePolicy.connectModeActive

    // In Float mode (cornerStyle 1), sidebars remain as separate PanelWindows
    // rather than being embedded in the TopLayer. Only search/OSD are integrated.
    readonly property bool connectSidebarsSeparate: {
        return connectModeActive && Config.options.bar.cornerStyle === 1;
    }

    readonly property bool searchCenterMode: {
        if (!Config.ready)
            return false;
        return Config.options.search.positionStyle === "center";
    }

    readonly property bool searchConnectActive: {
        if (!connectModeActive)
            return false;
        if (root.searchCenterMode)
            return false;
        if (Config.options.search.connectStyle !== "connect")
            return false;

        // All corner styles supported
        return true;
    }

    readonly property bool osdConnectActive: {
        if (!connectModeActive)
            return false;

        // All corner styles supported
        return true;
    }

    function enforceSidebarStyle() {
        if (!Config.ready)
            return;
        if (ShellModePolicy.shouldForceDefault) {
            Config.options.sidebar.sidebarStyle = "default";
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                root.enforceSidebarStyle();
            }
        }
    }

    Connections {
        target: Config.ready ? Config.options.bar : null
        function onBarBackgroundStyleChanged() {
            root.enforceSidebarStyle();
        }
    }

    Connections {
        target: Config.ready ? Config.options.sidebar : null
        function onSidebarStyleChanged() {
            root.enforceSidebarStyle();
        }
    }

    property real _lastPoliciesWidth: Appearance.sizes.sidebarWidth + 300

    onPoliciesWidthChanged: {
        if (Config.ready && !policiesExtended) {
            _lastPoliciesWidth = policiesWidth;
        }
    }

    readonly property real policiesWidth: {
        if (policiesExtended)
            return Appearance.sizes.sidebarWidthExtended;

        if (!Config.ready)
            return _lastPoliciesWidth;

        const p = Config.options.policies;
        let activeCount = 0;
        if (p.ai !== 0)
            activeCount++;
        if (p.translator !== 0)
            activeCount++;
        if (p.player !== 0)
            activeCount++;
        if (p.wallpapers !== 0)
            activeCount++;
        if (p.weeb !== 0 && p.weeb !== 2)
            activeCount++;
        if (p.phone !== 0)
            activeCount++;

        const minTabs = 3;
        const perTabWidth = 100;
        return Appearance.sizes.sidebarWidth + Math.max(0, activeCount - minTabs) * perTabWidth;
    }

    readonly property real dashboardWidth: Appearance.sizes.sidebarWidth

    readonly property real leftSidebarTargetWidth: {
        if (!effectiveLeftOpen)
            return 0;
        switch (Config.options.sidebar.position) {
        case "default":
            return policiesDetached ? 0 : policiesWidth;
        case "inverted":
            return dashboardWidth;
        case "left":
            if (policiesPanelOpen)
                return policiesDetached ? 0 : policiesWidth;
            if (dashboardPanelOpen)
                return dashboardWidth;
            return 0;
        default:
            return policiesDetached ? 0 : policiesWidth;
        }
    }

    readonly property real rightSidebarTargetWidth: {
        if (!effectiveRightOpen)
            return 0;
        switch (Config.options.sidebar.position) {
        case "default":
            return dashboardWidth;
        case "inverted":
            return policiesDetached ? 0 : policiesWidth;
        case "right":
            if (policiesPanelOpen)
                return policiesDetached ? 0 : policiesWidth;
            if (dashboardPanelOpen)
                return dashboardWidth;
            return 0;
        default:
            return dashboardWidth;
        }
    }

    property real animatedLeftSidebarWidth: 0
    property real animatedRightSidebarWidth: 0

    // Exposed for TopLayerPanel/WrappedFrameVisuals to gate `layer.enabled`
    // so the FBO layer is only active during the open/close animation, NOT
    // while the sidebar is statically open. Keeping the layer enabled while
    // open caused massive CPU usage (380%+) because every minor visual
    // change (timer ticks, notification syncs, infinite pulse animations)
    // forced a full FBO re-render of the entire sidebar subtree.
    readonly property bool leftSidebarAnimating: leftSidebarAnimation.running
    readonly property bool rightSidebarAnimating: rightSidebarAnimation.running

    NumberAnimation {
        id: leftSidebarAnimation
        target: root
        property: "animatedLeftSidebarWidth"
        easing.type: Easing.OutQuart
    }

    NumberAnimation {
        id: rightSidebarAnimation
        target: root
        property: "animatedRightSidebarWidth"
        easing.type: Easing.OutQuart
    }

    onLeftSidebarTargetWidthChanged: {
        leftSidebarAnimation.stop();
        if ((Config.options?.appearance?.animationMultiplier ?? 1.0) <= 0.25) {
            animatedLeftSidebarWidth = leftSidebarTargetWidth;
            return;
        }
        if (leftSidebarTargetWidth > 0) {
            leftSidebarAnimation.duration = Appearance.animation.elementMoveEnter.duration;
            leftSidebarAnimation.easing.type = Easing.OutQuart;
            leftSidebarAnimation.to = leftSidebarTargetWidth;
            leftSidebarAnimation.start();
        } else {
            leftSidebarAnimation.duration = Appearance.animation.elementMoveEnter.duration;
            leftSidebarAnimation.easing.type = Easing.OutQuart;
            leftSidebarAnimation.to = leftSidebarTargetWidth;
            leftSidebarAnimation.start();
        }
    }

    onRightSidebarTargetWidthChanged: {
        rightSidebarAnimation.stop();
        if ((Config.options?.appearance?.animationMultiplier ?? 1.0) <= 0.25) {
            animatedRightSidebarWidth = rightSidebarTargetWidth;
            return;
        }
        if (rightSidebarTargetWidth > 0) {
            rightSidebarAnimation.duration = Appearance.animation.elementMoveEnter.duration;
            rightSidebarAnimation.easing.type = Easing.OutQuart;
            rightSidebarAnimation.to = rightSidebarTargetWidth;
            rightSidebarAnimation.start();
        } else {
            rightSidebarAnimation.duration = Appearance.animation.elementMoveEnter.duration;
            rightSidebarAnimation.easing.type = Easing.OutQuart;
            rightSidebarAnimation.to = rightSidebarTargetWidth;
            rightSidebarAnimation.start();
        }
    }

    Component.onCompleted: {
        animatedLeftSidebarWidth = leftSidebarTargetWidth;
        animatedRightSidebarWidth = rightSidebarTargetWidth;
        root.enforceSidebarStyle();
        // Instantiate sidebars immediately on startup on the primary/focused screen to keep them warm
        Qt.callLater(() => {
            root.activeLeftSidebarMonitor = Hyprland.focusedMonitor?.name ?? Quickshell.primaryScreen?.name ?? "";
            root.activeRightSidebarMonitor = Hyprland.focusedMonitor?.name ?? Quickshell.primaryScreen?.name ?? "";
        });
    }

    property bool dashboardPanelOpen: false // formerly sidebarRightOpen
    property bool policiesPanelOpen: false  // formerly sidebarLeftOpen

    property bool requestVolumeDialog: false

    readonly property bool effectiveLeftOpen: {
        switch (Config.options.sidebar.position) {
        case "default":
            return policiesPanelOpen;
        case "inverted":
            return dashboardPanelOpen;
        case "left":
            return dashboardPanelOpen || policiesPanelOpen;
        case "right":
            return false;
        default:
            return policiesPanelOpen;
        }
    }
    readonly property bool effectiveRightOpen: {
        switch (Config.options.sidebar.position) {
        case "default":
            return dashboardPanelOpen;
        case "inverted":
            return policiesPanelOpen;
        case "left":
            return false;
        case "right":
            return dashboardPanelOpen || policiesPanelOpen;
        default:
            return dashboardPanelOpen;
        }
    }

    function toggleLeftSidebar(monitorName) {
        if (root.policiesPanelOpen) {
            root.policiesPanelOpen = false;
        } else {
            root.activeLeftSidebarMonitor = monitorName || Hyprland.focusedMonitor?.name || "";
            root.policiesPanelOpen = true;
        }
    }

    function toggleRightSidebar(monitorName) {
        if (root.dashboardPanelOpen) {
            root.dashboardPanelOpen = false;
        } else {
            root.activeRightSidebarMonitor = monitorName || Hyprland.focusedMonitor?.name || "";
            root.dashboardPanelOpen = true;
        }
    }

    function openLeftSidebar(monitorName) {
        root.activeLeftSidebarMonitor = monitorName || Hyprland.focusedMonitor?.name || "";
        root.policiesPanelOpen = true;
    }

    function openRightSidebar(monitorName) {
        root.activeRightSidebarMonitor = monitorName || Hyprland.focusedMonitor?.name || "";
        root.dashboardPanelOpen = true;
    }

    function toggleSearch(monitorName) {
        if (root.overviewOpen) {
            root.overviewOpen = false;
        } else {
            root.activeSearchMonitor = monitorName || Hyprland.focusedMonitor?.name || "";
            root.overviewOpen = true;
        }
    }

    function openSearch(monitorName) {
        root.activeSearchMonitor = monitorName || Hyprland.focusedMonitor?.name || "";
        root.overviewOpen = true;
    }

    Timer {
        id: resetSearchOnlyModeTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!root.overviewOpen) {
                root.searchOnlyMode = false;
            }
        }
    }

    onOverviewOpenChanged: {
        if (root.overviewOpen) {
            resetSearchOnlyModeTimer.stop();
            if (root.activeSearchMonitor === "") {
                root.activeSearchMonitor = Hyprland.focusedMonitor?.name ?? "";
            }
        } else {
            root.activeSearchMonitor = "";
            resetSearchOnlyModeTimer.start();
        }
    }

    onAnimatedLeftSidebarWidthChanged: {}

    onAnimatedRightSidebarWidthChanged: {}

    onPoliciesPanelOpenChanged: {
        if (policiesPanelOpen) {
            if (root.activeLeftSidebarMonitor === "") {
                root.activeLeftSidebarMonitor = Hyprland.focusedMonitor?.name ?? "";
            }
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                root.dashboardPanelOpen = false;
            }
        }
    }

    onDashboardPanelOpenChanged: {
        if (dashboardPanelOpen) {
            if (root.activeRightSidebarMonitor === "") {
                root.activeRightSidebarMonitor = Hyprland.focusedMonitor?.name ?? "";
            }
            Notifications.timeoutAll();
            Notifications.markAllRead();
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                root.policiesPanelOpen = false;
            }
        }
    }

    // Sidebar Right (Dashboard) IPC
    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            root.toggleRightSidebar();
        }

        function close(): void {
            root.dashboardPanelOpen = false;
        }

        function open(): void {
            root.openRightSidebar();
        }
    }

    // Sidebar Left (Policies) IPC
    IpcHandler {
        target: "sidebarLeft"
        function toggle(): void {
            root.toggleLeftSidebar();
        }
        function close(): void {
            root.sidebarLeftOpen = false;
        }
        function open(): void {
            root.openLeftSidebar();
        }
    }

    // Sidebar Right Global Shortcuts
    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"
        onPressed: {
            root.toggleRightSidebar();
        }
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Opens right sidebar on press"
        onPressed: {
            root.openRightSidebar();
        }
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Closes right sidebar on press"
        onPressed: {
            root.sidebarRightOpen = false;
        }
    }

    // Sidebar Left Global Shortcuts
    GlobalShortcut {
        name: "sidebarLeftToggle"
        description: "Toggles left sidebar on press"
        onPressed: {
            root.toggleLeftSidebar();
        }
    }
    GlobalShortcut {
        name: "sidebarLeftOpen"
        description: "Opens left sidebar on press"
        onPressed: {
            root.openLeftSidebar();
        }
    }
    GlobalShortcut {
        name: "sidebarLeftClose"
        description: "Closes left sidebar on press"
        onPressed: {
            root.sidebarLeftOpen = false;
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"
        onPressed: {
            root.superDown = true;
        }
        onReleased: {
            root.superDown = false;
        }
    }
}
