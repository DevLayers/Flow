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

    ReloadPopup {}

    Component.onCompleted: {
        if (Qt.application) {
            Qt.application.applicationName = "quickshell";
            Qt.application.organizationName = "Unknown Organization";
            Qt.application.organizationDomain = "unknown.organization";
        }
        MaterialThemeLoader.reapplyTheme();
        Hyprsunset.load();
        FirstRunExperience.load();
        ConflictKiller.load();
        Cliphist.refresh();
        Wallpapers.load();
        Updates.load();
        DarkModeService.automatic;
        ChangelogService.load();
        SoundService.indexReady;
        VideoColorSampler.active;
        WaterReminderService.enabled;
        GoogleDriveService.configured;
        AppStats.stateDir;
        TilingAssistant.enabled;
        TouchGestureService.enabled;
        if (Config.options && Config.options.policies && Config.options.policies.phone !== 0) {
            KdeConnectService.available;
            PhoneContactsService.available;
            PhoneScrcpyService.available;
        }
        root.applyOpenRgbIfEnabled();
    }

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

        function unloadNow() {
            if (GlobalStates.settingsOpen)
                return;
            settingsUnloadTimer.stop();
            SearchRegistry.clearIndex();
            ThemePreviewCache.release();
            WallpaperPreviewCache.release();
            settingsLoader.loadedOnce = false;
        }

        Timer {
            id: settingsUnloadTimer
            interval: root.settingsUnloadDelaySeconds() * 1000
            repeat: false
            onTriggered: settingsLoader.unloadNow()
        }

        Connections {
            target: GlobalStates
            function onSettingsOpenChanged() {
                if (GlobalStates.settingsOpen) {
                    settingsUnloadTimer.stop();
                    if (!settingsLoader.loadedOnce)
                        settingsLoader.loadedOnce = true;
                } else {
                    const s = root.settingsUnloadDelaySeconds();
                    if (s > 0) {
                        settingsUnloadTimer.interval = s * 1000;
                        settingsUnloadTimer.restart();
                    }
                }
            }
        }

        // Preset application is different from an ordinary Settings close: the
        // entire config/theme graph is about to invalidate. Destroy the heavy
        // Settings tree immediately instead of keeping it warm for five seconds.
        Connections {
            target: PresetManager
            function onApplyingChanged() {
                if (PresetManager.applying)
                    settingsLoader.unloadNow();
            }
        }
    }

    Loader {
        id: welcomeLoader
        active: Config.ready && GlobalStates.welcomeOpen
        asynchronous: true
        source: "modules/welcome/WelcomeWindow.qml"
    }

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
