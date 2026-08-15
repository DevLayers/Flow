pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Automatically reloads generated material colors.
 *
 * File notifications can arrive more than once for one atomic replace. Keep a
 * single scheduled apply and fingerprint the payload so a preset switch cannot
 * fan out into two complete Appearance.m3colors invalidation waves.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath
    property string lastAppliedContent: ""
    property int retryCount: 0

    function reapplyTheme() {
        root.lastAppliedContent = "";
        themeFileView.reload();
    }

    function normalizedColor(value) {
        return String(value ?? "").trim().toLowerCase();
    }

    function applyColors(fileContent) {
        try {
            const content = String(fileContent || "").trim();
            if (!content) {
                console.log("[MaterialThemeLoader] applyColors: empty content, skipping");
                return;
            }
            if (content === root.lastAppliedContent)
                return;

            const json = JSON.parse(content);
            const skip = { "darkmode": true, "transparent": true };
            let changed = 0;

            for (const key in json) {
                if (!json.hasOwnProperty(key) || skip[key])
                    continue;

                const propertyName = root._toM3Key(key);
                const nextValue = json[key];
                if (root.normalizedColor(Appearance.m3colors[propertyName]) === root.normalizedColor(nextValue))
                    continue;

                Appearance.m3colors[propertyName] = nextValue;
                changed++;
            }

            root.updateDarkMode(json);
            root.lastAppliedContent = content;
            console.log("[MaterialThemeLoader] applied", changed, "changed colors; darkmode=", Appearance.m3colors.darkmode);
        } catch (e) {
            console.log("[MaterialThemeLoader] Error parsing colors.json:", e);
        }
    }

    function updateDarkMode(json) {
        let nextDarkMode = null;
        if (typeof json.darkmode === "boolean") {
            nextDarkMode = json.darkmode;
        } else {
            const background = json.background ?? json.surface;
            if (background !== undefined && background !== null && background !== "")
                nextDarkMode = Qt.color(background).hslLightness < 0.5;
        }

        if (nextDarkMode !== null && Appearance.m3colors.darkmode !== nextDarkMode)
            Appearance.m3colors.darkmode = nextDarkMode;
    }

    function _toM3Key(key) {
        const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase());
        return `m3${camelCaseKey}`;
    }

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = true;
    }

    Connections {
        id: resetFilePathNextWallpaperChange
        enabled: false
        target: Config.options.background
        function onWallpaperPathChanged() {
            root.filePath = "";
            root.filePath = Directories.generatedMaterialThemePath;
            resetFilePathNextWallpaperChange.enabled = false;
        }
    }

    Timer {
        id: retryTimer
        interval: 150
        repeat: false
        running: false
        onTriggered: {
            if (root.retryCount < 5) {
                root.retryCount++;
                themeFileView.reload();
            } else {
                console.log("[MaterialThemeLoader] Max retries reached, resetting file watch");
                root.filePath = "";
                root.filePath = Directories.generatedMaterialThemePath;
                root.retryCount = 0;
            }
        }
    }

    // Coalesce FileView's file-changed/load signals into exactly one apply on
    // the next event-loop turn. Atomic preset cache copies no longer need the
    // old second delayed read.
    Timer {
        id: applyTimer
        interval: 0
        repeat: false
        running: false
        onTriggered: root.applyColors(themeFileView.text())
    }

    FileView {
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true

        onFileChanged: themeFileView.reload()

        onLoaded: {
            root.retryCount = 0;
            retryTimer.stop();
            applyTimer.restart();
        }

        onLoadFailed: retryTimer.start()
    }

    function toggleLightDark() {
        const currentlyDark = Appearance.m3colors.darkmode;
        if (Config.options?.background?.useSeparateLightModeWallpaper) {
            if (currentlyDark) {
                const lightPath = Config.options.background.lightModeWallpaperPath;
                if (lightPath && lightPath !== "") {
                    Wallpapers.applyLightModeWallpaper(lightPath);
                    return;
                }
            } else {
                const darkPath = Config.options.background.wallpaperPath;
                if (darkPath && darkPath !== "") {
                    Wallpapers.apply(darkPath, true);
                    return;
                }
            }
        }
        Quickshell.execDetached(["bash", "-c", `env -u LD_LIBRARY_PATH -u PYTHONHOME -u PYTHONPATH PATH=$HOME/.local/bin:$HOME/.cargo/bin:$PATH "${Directories.wallpaperSwitchScriptPath}" --mode ${currentlyDark ? "light" : "dark"} --noswitch`]);
    }

    GlobalShortcut {
        name: "toggleLightDark"
        description: "Toggles between dark theme and light theme"
        onPressed: root.toggleLightDark()
    }

    IpcHandler {
        target: "theme"

        function toggleLightDark(): void {
            root.toggleLightDark();
        }

        function reapplyTheme(): void {
            root.reapplyTheme();
        }
    }
}
