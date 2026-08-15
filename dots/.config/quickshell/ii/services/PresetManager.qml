pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    property bool applying: false
    property string activePreset: ""
    property string activeRequest: ""
    property string lastMode: ""
    property real generation: Date.now()

    readonly property string statusPath: FileUtils.trimFileProtocol(`${Directories.state}/user/preset_apply_status`)

    signal applied(string name, bool success, string mode)

    function nextRequestId() {
        const now = Date.now();
        root.generation = Math.max(root.generation + 1, now);
        return Math.floor(root.generation).toString();
    }

    function apply(name) {
        const cleanName = String(name || "").trim();
        if (cleanName.length === 0)
            return;

        // Hide Settings before touching config. shell.qml listens to applying and
        // destroys the warm Settings tree immediately so it cannot participate in
        // the config/theme invalidation wave.
        GlobalStates.settingsOpen = false;
        root.activePreset = cleanName;
        root.activeRequest = root.nextRequestId();
        root.lastMode = "";
        root.applying = true;
        applyTimeout.restart();

        Quickshell.execDetached([
            Directories.scriptPath + "/presets.sh",
            "load",
            cleanName,
            root.activeRequest
        ]);
    }

    function consumeStatus() {
        if (!statusFile.loaded)
            return;

        const text = statusFile.text().trim();
        if (!text)
            return;

        const fields = text.split("\t");
        if (fields.length < 2 || fields[0] !== root.activeRequest)
            return;

        const state = fields[1];
        if (state !== "success" && state !== "failed")
            return;

        const mode = fields.length >= 3 ? fields[2] : "";
        applyTimeout.stop();
        root.lastMode = mode;
        root.applying = false;
        root.applied(root.activePreset, state === "success", mode);
    }

    Timer {
        id: statusReadTimer
        interval: 16
        repeat: false
        onTriggered: root.consumeStatus()
    }

    Timer {
        id: statusPollTimer
        interval: 50
        repeat: true
        running: root.applying
        onTriggered: statusFile.reload()
    }

    Timer {
        id: applyTimeout
        // A safety valve only. Normal cached applies finish in a few filesystem
        // operations; uncached legacy imports may need Matugen on first use.
        interval: 20000
        repeat: false
        onTriggered: {
            if (!root.applying)
                return;
            console.warn("[PresetManager] Timed out waiting for preset apply status:", root.activePreset);
            root.applying = false;
            root.applied(root.activePreset, false, "timeout");
        }
    }

    FileView {
        id: statusFile
        path: root.statusPath
        watchChanges: true
        printErrors: false

        onFileChanged: {
            statusFile.reload();
            statusReadTimer.restart();
        }

        onLoaded: statusReadTimer.restart()
    }
}
