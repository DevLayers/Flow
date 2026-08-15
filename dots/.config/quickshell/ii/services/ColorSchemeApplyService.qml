pragma Singleton

import QtQuick
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property string pendingScheme: ""
    property string activeScheme: ""
    property bool rerunPending: false

    function request(scheme) {
        if (!scheme || scheme === "")
            return;

        pendingScheme = scheme;
        debounceTimer.restart();
    }

    function launchLatest() {
        if (applyProcess.running) {
            rerunPending = true;
            return;
        }

        if (!pendingScheme || pendingScheme === "")
            return;

        activeScheme = pendingScheme;
        rerunPending = false;

        const command = `env -u LD_LIBRARY_PATH -u PYTHONHOME -u PYTHONPATH PATH=$HOME/.local/bin:$HOME/.cargo/bin:$PATH ${Directories.wallpaperSwitchScriptPath} --type ${activeScheme} --noswitch > /tmp/switchwall_button.log 2>&1`;
        applyProcess.command = ["bash", "-c", command];
        applyProcess.running = true;
    }

    Timer {
        id: debounceTimer
        interval: 180
        repeat: false
        onTriggered: root.launchLatest()
    }

    Process {
        id: applyProcess
        running: false

        onExited: {
            const hasNewerRequest = root.pendingScheme !== "" && root.pendingScheme !== root.activeScheme;
            root.activeScheme = "";

            if (hasNewerRequest || root.rerunPending)
                Qt.callLater(root.launchLatest);
        }
    }
}
