pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property string pendingScheme: ""
    property string activeScheme: ""

    function request(scheme) {
        if (!scheme || scheme === "")
            return;

        pendingScheme = scheme;
        debounceTimer.restart();
    }

    function launchLatest() {
        if (applyProcess.running)
            return;

        if (!pendingScheme || pendingScheme === "")
            return;

        activeScheme = pendingScheme;

        const command = `env -u LD_LIBRARY_PATH -u PYTHONHOME -u PYTHONPATH PATH=$HOME/.local/bin:$HOME/.cargo/bin:$PATH bash ${Directories.scriptPath}/colors/apply_scheme_core.sh ${activeScheme} > /tmp/switchwall_button.log 2>&1`;
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
            const completedScheme = root.activeScheme;
            root.activeScheme = "";

            if (root.pendingScheme !== "" && root.pendingScheme !== completedScheme)
                Qt.callLater(root.launchLatest);
        }
    }
}
