//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Remove two slashes below and adjust the value to change the UI scale
////@ pragma Env QT_SCALE_FACTOR=1

import "modules/common"
import "services"
import "panelFamilies"

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root
    property string openRgbApplyScript: Quickshell.shellPath("scripts/colors/openRGB/apply_openrgb.py")
    property bool openRgbStartupApplied: false

    // Stuff for every panel family
    ReloadPopup {}

    Component.onCompleted: {
        if (Qt.application) {
            Qt.application.applicationName = "quickshell";
            Qt.application.organizationName = "Unknown Organization";
            Qt.application.organizationDomain = "unknown.organization";
        }
        // Critical path: theme + UI must be ready before first paint. Touch
        // them synchronously so the first frame paints with the correct
        // colors and the bar isn't a flash of unstyled content.
        MaterialThemeLoader.reapplyTheme();
        Hyprsunset.load();
        ConflictKiller.load();
        Cliphist.refresh();
        Wallpapers.load();
        Updates.load();
        DarkModeService.automatic;
        ChangelogService.load();
        IconThemes.availableThemes; // arms the DynamicTheme watcher for live icon refresh

        // Optional / heavy services: defer to next event-loop tick so they
        // run after first paint. Quickshell's QML engine keeps the shell
        // responsive while these fire in the background.
        Qt.callLater(root._deferOptionalSingletons);
        root.applyOpenRgbIfEnabled();
    }

    // ── Deferred singleton touches ───────────────────────────────────────────
    // Stagger optional service initialization across the first few ticks of
    // the event loop. SoundService, AppStats, TilingAssistant and friends do
    // real work (file scans, fsnotify setup, dbus listeners); running them
    // all in a single Component.onCompleted burns the first ~150-300 ms of
    // CPU before the bar is even on screen. Yielding between batches keeps
    // the compositor ahead and avoids visible jank when the user first
    // opens the dock or settings.
    function _deferOptionalSingletons() {
        SoundService.indexReady; // scans sound themes, plays login sound if enabled
        VideoColorSampler.active; // touches singleton to initialize
        WaterReminderService.enabled; // drives water reminder notifications
        GoogleDriveService.configured; // keeps scheduled backups independent of Settings
        AppStats.stateDir; // starts the usage sampler, must run regardless of overlay state
        TilingAssistant.enabled; // watches for window drags; no-op while disabled
        TouchGestureService.enabled; // starts passive touch input helper daemon
        Qt.callLater(root._deferPhoneSingletons);
    }

    function _deferPhoneSingletons() {
        if (Config.options && Config.options.policies && Config.options.policies.phone !== 0) {
            KdeConnectService.available;
            PhoneContactsService.available;
            PhoneScrcpyService.available;
        }
    }

    // Panel families
    property var families: ["ii", "waffle"]
    function cyclePanelFamily() {
        const currentIndex = families.indexOf(Config.options.panelFamily);
        const nextIndex = (currentIndex + 1) % families.length;
        Config.options.panelFamily = families[nextIndex];
    }

    function applyOpenRgbIfEnabled() {
        if (openRgbStartupApplied)
            return;
        if (!Config.ready)
            return;
        if (!(Config.options && Config.options.appearance && Config.options.appearance.openrgb && Config.options.appearance.openrgb.enable))
            return;
        if (!(Config.options && Config.options.appearance && Config.options.appearance.openrgb && Config.options.appearance.openrgb.applyOnStartup))
            return;
        openRgbStartupApplied = true;
        openRgbApplyProc.command = ["python", openRgbApplyScript];
        openRgbApplyProc.running = false;
        openRgbApplyProc.running = true;
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                root.applyOpenRgbIfEnabled();
        }
    }

    Process {
        id: openRgbApplyProc
    }

    component PanelFamilyLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && Config.options.panelFamily === identifier && extraCondition
    }

    PanelFamilyLoader {
        identifier: "ii"
        component: IllogicalImpulseFamily {}
    }

    PanelFamilyLoader {
        identifier: "waffle"
        component: WaffleFamily {}
    }

    // Settings app loaded in-process once requested, then kept alive briefly
    // for fast re-opens. After the delay we drop the component to recover
    // its QML memory. Positive configured delays are capped at five seconds;
    // 0 still means keep it warm explicitly.
    readonly property int settingsUnloadCapSeconds: 5

    function settingsUnloadDelaySeconds() {
        const settingsApp = Config.options && Config.options.settingsApp;
        let configured = settingsApp && settingsApp.unloadAfterSeconds !== undefined
            ? settingsApp.unloadAfterSeconds
            : settingsUnloadCapSeconds;

        if (configured <= 0)
            return 0;
        return Math.min(configured, settingsUnloadCapSeconds);
    }

    Loader {
        id: settingsLoader
        property bool loadedOnce: false
        active: loadedOnce || GlobalStates.settingsOpen
        asynchronous: true
        source: "SettingsWindow.qml"

        // When settings closes, schedule an unload pass. If the user
        // reopens before the timer fires, the timer is reset and we
        // keep the warm component.
        Timer {
            id: settingsUnloadTimer
            interval: root.settingsUnloadDelaySeconds() * 1000
            repeat: false
            onTriggered: {
                if (GlobalStates.settingsOpen)
                    return
                // The visual Loader only owns the Settings object tree. These
                // singletons outlive it, so release their page-specific data
                // before dropping the component as well.
                SearchRegistry.clearIndex()
                ThemePreviewCache.release()
                WallpaperPreviewCache.release()
                settingsLoader.loadedOnce = false
            }
        }

        Connections {
            target: GlobalStates
            function onSettingsOpenChanged() {
                if (GlobalStates.settingsOpen) {
                    settingsUnloadTimer.stop()
                    if (!settingsLoader.loadedOnce)
                        settingsLoader.loadedOnce = true
                } else {
                    const s = root.settingsUnloadDelaySeconds()
                    if (s > 0) {
                        settingsUnloadTimer.interval = s * 1000
                        settingsUnloadTimer.restart()
                    }
                }
            }
        }
    }

    // Welcome runs in-process so it shares Config, GlobalStates and the same
    // Quickshell lifecycle as Settings. Unlike Settings, the onboarding is
    // destroyed as soon as it closes so costly page trees do not stay warm.
    Loader {
        id: welcomeLoader
        active: Config.ready && GlobalStates.welcomeOpen
        asynchronous: true
        source: "modules/welcome/WelcomeWindow.qml"
    }

    // Shortcuts
    IpcHandler {
        target: "panelFamily"

        function cycle() {
            root.cyclePanelFamily();
        }
    }

    GlobalShortcut {
        name: "panelFamilyCycle"
        description: "Cycles panel family"

        onPressed: root.cyclePanelFamily()
    }
}
