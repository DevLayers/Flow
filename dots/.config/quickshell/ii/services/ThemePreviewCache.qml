pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Shares the small JSON reads used by the built-in and custom theme swatches.
 * A settings page can contain dozens of swatches, so keeping one FileView and
 * one parsed value per path is cheaper than creating a FileView per delegate.
 */
Singleton {
    id: root

    property var values: ({})
    property var pendingPaths: []
    property string currentPath: ""

    signal cacheChanged(string path)

    function get(path) {
        return path && root.values[path] ? root.values[path] : null;
    }

    function request(path) {
        if (!path || root.values[path])
            return;

        if (root.pendingPaths.indexOf(path) === -1)
            root.pendingPaths.push(path);

        if (root.currentPath === "")
            root.loadNext();
    }

    function loadNext() {
        if (root.currentPath !== "" || root.pendingPaths.length === 0)
            return;

        root.currentPath = root.pendingPaths.shift();
    }

    function finishCurrent() {
        root.currentPath = "";
        Qt.callLater(root.loadNext);
    }

    function release() {
        root.pendingPaths = [];
        root.currentPath = "";
        root.values = ({});
    }

    FileView {
        id: themeFile
        path: root.currentPath
        watchChanges: false
        printErrors: false

        onLoaded: {
            if (root.currentPath === "")
                return;

            const pathLoaded = root.currentPath;
            try {
                const raw = themeFile.text().trim();
                const data = raw ? JSON.parse(raw) : null;
                if (data) {
                    root.values[pathLoaded] = {
                        primary: data.primary || "transparent",
                        secondary: data.primary_container || "transparent",
                        tertiary: data.secondary || "transparent"
                    };
                    root.cacheChanged(pathLoaded);
                }
            } catch (e) {
                // A malformed optional theme must not stop the remaining queue.
            }
            root.finishCurrent();
        }

        onLoadFailed: root.finishCurrent()
    }
}
