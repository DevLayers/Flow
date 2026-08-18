//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell

// Compatibility entrypoint for the existing Hyprland keybind. The real
// Welcome UI now lives in-process under shell.qml; this tiny wrapper only
// requests the shared window and exits its helper process.
QtObject {
    Component.onCompleted: {
        Quickshell.execDetached(["bash", "-c", "qs -c ii ipc call welcome toggle; sleep 0.1; pkill -9 -f 'welcome\\.qml'"]);
    }
}
