pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * One shared reader/generator for wallpaper color previews. The settings UI
 * shows many schemes backed by the same JSON file; individual FileViews and
 * fallback Processes multiplied both memory and I/O without changing output.
 */
Singleton {
    id: root

    property bool active: false
    property bool loaded: false
    property var values: ({})
    property string lastRaw: ""
    property string pendingCommand: ""
    property bool awaitingFreshCache: false
    property int staleRetryCount: 0

    signal cacheChanged

    function ensureActive() {
        root.active = true;
    }

    function get(scheme) {
        return scheme && root.values[scheme] ? root.values[scheme] : null;
    }

    function requestGeneration(command, scheme) {
        root.ensureActive();
        if (!command || colorGeneration.running || (scheme && root.values[scheme]))
            return;

        root.pendingCommand = command;
        colorGeneration.command = ["bash", "-c", root.pendingCommand];
        colorGeneration.running = true;
    }

    function invalidateForWallpaperChange() {
        root.ensureActive();
        root.loaded = false;
        reloadTimer.restart();
    }

    function reloadAfterGeneration() {
        if (root.active)
            previewFile.reload();
    }

    function parsePreviewFile() {
        if (!root.active)
            return;

        let raw = "";
        try {
            raw = previewFile.text().trim();
            if (root.awaitingFreshCache && raw === root.lastRaw && root.staleRetryCount < 6) {
                root.staleRetryCount++;
                staleRetryTimer.restart();
                return;
            }

            const parsed = raw ? JSON.parse(raw) : {};
            root.values = parsed || {};
            root.lastRaw = raw;
            root.loaded = true;
            root.awaitingFreshCache = false;
            root.staleRetryCount = 0;
            root.cacheChanged();
        } catch (e) {
            root.loaded = false;
        }
    }

    function release() {
        reloadTimer.stop();
        staleRetryTimer.stop();
        colorGeneration.running = false;
        root.pendingCommand = "";
        root.awaitingFreshCache = false;
        root.staleRetryCount = 0;
        root.active = false;
        root.loaded = false;
        root.values = ({});
        root.lastRaw = "";
    }

    FileView {
        id: previewFile
        path: root.active ? Directories.wallpaperPreviewColorsPath : ""
        watchChanges: root.active
        printErrors: false

        onLoaded: root.parsePreviewFile()
        onLoadFailed: root.loaded = false
    }

    Timer {
        id: reloadTimer
        interval: 900
        repeat: false
        onTriggered: {
            if (!root.active)
                return;
            root.awaitingFreshCache = true;
            root.staleRetryCount = 0;
            root.reloadAfterGeneration();
        }
    }

    Timer {
        id: staleRetryTimer
        interval: 400
        repeat: false
        onTriggered: root.reloadAfterGeneration()
    }

    Process {
        id: colorGeneration
        running: false
        onExited: Qt.callLater(root.reloadAfterGeneration)
    }
}
