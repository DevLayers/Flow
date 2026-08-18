pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Automatically reloads generated material colors.
 * It is necessary to run reapplyTheme() on startup because Singletons are lazily loaded.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath

    function reapplyTheme() {
        themeFileView.reload();
    }

    function applyColors(fileContent) {
        try {
            if (!fileContent || fileContent.trim() === "") {
                console.log("[MaterialThemeLoader] applyColors: empty content, skipping")
                return;
            }

            const json = JSON.parse(fileContent)
            const skip = { "darkmode": true, "transparent": true }
            for (const key in json) {
                if (json.hasOwnProperty(key) && !skip[key]) {
                    Appearance.m3colors[root._toM3Key(key)] = json[key]
                }
            }

            root.updateDarkMode(json)
            console.log("[MaterialThemeLoader] applyColors: darkmode=", Appearance.m3colors.darkmode, "bg=", Appearance.m3colors.m3background)
        } catch (e) {
            console.log("[MaterialThemeLoader] Error parsing colors.json:", e)
        }
    }

    function updateDarkMode(json) {
        if (typeof json.darkmode === "boolean") {
            Appearance.m3colors.darkmode = json.darkmode;
            return;
        }

        const background = json.background ?? json.surface;
        if (background !== undefined && background !== null && background !== "") {
            Appearance.m3colors.darkmode = Qt.color(background).hslLightness < 0.5;
        }
    }

    function _toM3Key(key) {
        const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
        return `m3${camelCaseKey}`
    }

    property int retryCount: 0

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = true
    }

    Connections {
        id: resetFilePathNextWallpaperChange
        enabled: false
        target: Config.options.background
        function onWallpaperPathChanged() {
            root.filePath = ""
            root.filePath = Directories.generatedMaterialThemePath
            resetFilePathNextWallpaperChange.enabled = false
        }
    }

    Timer {
        id: retryTimer
        interval: 150
        repeat: false
        running: false
        onTriggered: {
            if (root.retryCount < 5) {
                root.retryCount++
                console.log("[MaterialThemeLoader] Retrying file reload, attempt:", root.retryCount)
                themeFileView.reload()
            } else {
                console.log("[MaterialThemeLoader] Max retries reached, resetting path to re-establish watch")
                root.filePath = ""
                root.filePath = Directories.generatedMaterialThemePath
                root.retryCount = 0
            }
        }
    }

    Timer {
        id: delayedFileRead
        interval: Config.options?.hacks?.arbitraryRaceConditionDelay ?? 100
        repeat: false
        running: false
        onTriggered: {
            root.applyColors(themeFileView.text())
        }
    }

    FileView {
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            console.log("[MaterialThemeLoader] onFileChanged triggered, reloading...")
            this.reload();
            delayedFileRead.restart();
        }
        onLoadedChanged: {
            console.log("[MaterialThemeLoader] onLoadedChanged, loaded=", themeFileView.loaded)
            if (themeFileView.loaded) {
                root.retryCount = 0
                retryTimer.stop()
                root.applyColors(themeFileView.text())
            }
        }
        onLoadFailed: {
            console.log("[MaterialThemeLoader] onLoadFailed, starting retry timer")
            retryTimer.start()
        }
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

        onPressed: {
            root.toggleLightDark();
        }
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
