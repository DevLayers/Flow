pragma Singleton

import QtQuick
import qs.modules.common
import qs.services
import Quickshell

Singleton {
    id: root

    property bool automatic: Config.options?.light?.darkMode?.automatic ?? false
    property string from: Config.options?.light?.darkMode?.from ?? "18:00"
    property string to: Config.options?.light?.darkMode?.to ?? "06:00"

    property int fromHour: Number(from.split(":")[0])
    property int fromMinute: Number(from.split(":")[1])
    property int toHour: Number(to.split(":")[0])
    property int toMinute: Number(to.split(":")[1])

    property int clockHour: DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    // Config's FileView loads asynchronously, so shell.qml touches this singleton
    // while the adapter still holds QML defaults rather than the user's config.json.
    // Acting on that window regenerates the whole theme in the wrong mode, and the
    // result is what the next start reads back.
    property bool initialized: false

    onAutomaticChanged: checkTime()

    onClockMinuteChanged: checkTime()

    Component.onCompleted: root.initialize()

    Connections {
        target: Config
        function onReadyChanged() {
            root.initialize();
        }
    }

    function initialize() {
        if (root.initialized || !Config.ready)
            return;
        root.initialized = true;
        // Always reset to false on startup — auto dark mode should not persist
        // across reboots. User must explicitly re-enable it each session.
        Config.options.light.darkMode.automatic = false;
        root.checkTime();
    }

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t < to);
        } else {
            // Wrapped around midnight
            return (t >= from || t < to);
        }
    }

    function checkTime() {
        if (!root.initialized || !automatic)
            return;

        const t = clockHour * 60 + clockMinute;
        const fromMinutes = fromHour * 60 + fromMinute;
        const toMinutes = toHour * 60 + toMinute;

        if (inBetween(t, fromMinutes, toMinutes)) {
            enableDarkMode();
        } else {
            disableDarkMode();
        }
    }

    function enableDarkMode() {
        if (!Appearance.m3colors.darkmode) {
            if (Config.options?.background?.useSeparateLightModeWallpaper) {
                const darkPath = Config.options.background.wallpaperPath;
                if (darkPath && darkPath !== "") {
                    Wallpapers.apply(darkPath, true);
                    return;
                }
            }
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
        }
    }

    function disableDarkMode() {
        if (Appearance.m3colors.darkmode) {
            if (Config.options?.background?.useSeparateLightModeWallpaper) {
                const lightPath = Config.options.background.lightModeWallpaperPath;
                if (lightPath && lightPath !== "") {
                    Wallpapers.applyLightModeWallpaper(lightPath);
                    return;
                }
            }
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
        }
    }
}
