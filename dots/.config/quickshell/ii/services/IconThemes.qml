pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property var availableThemes: []

    function refresh() {
        listThemesProcess.running = true;
    }

    Process {
        id: listThemesProcess
        command: ["bash", "-c", "ls -d /usr/share/icons/*/ ~/.local/share/icons/*/ ~/.icons/*/ 2>/dev/null | xargs -n1 basename | sort -u"]

        stdout: StdioCollector {
            id: themeCollector
            onStreamFinished: {
                let themes = themeCollector.text.split("\n").map(t => t.trim()).filter(t => t && t !== "hicolor" && t !== "default" && t !== "DynamicTheme");

                // Remove duplicates
                root.availableThemes = [...new Set(themes)];
            }
        }
    }

    property bool reloadOnFinish: false

    function applyTheme(reload = false) {
        root.reloadOnFinish = reload;
        applyProcess.running = true;
    }

    Process {
        id: applyProcess
        // Explicit apply always regenerates, even when colors/theme look unchanged
        command: ["python3", Directories.scriptPath + "/colors/recolor_icons.py", "--force"]

        onRunningChanged: {
            if (!running && exitCode === 0 && root.reloadOnFinish) {
                Quickshell.reload();
            }
        }
    }

    FileView {
        path: Directories.home + "/.local/share/icons/DynamicTheme.colhash"
        watchChanges: true
        onFileChanged: {
            // DynamicTheme is atomically replaced before the hash is written.
            // A single bounded toggle is enough to invalidate icon bindings without
            // making sourceSize grow after every theme change.
            TaskbarApps.iconThemeRevision = 1 - TaskbarApps.iconThemeRevision;
        }
    }

    Component.onCompleted: refresh()
}
