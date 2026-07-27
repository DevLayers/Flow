pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import qs

Singleton {
    id: root

    function changeKey(key, value) {
        if (/['"\\`$|&;]/.test(String(value)) || /['"\\`$|&;]/.test(String(key))) {
            console.error("[HyprlandSettings] Unsafe characters rejected:", key, value)
            return
        }
        if (!key.includes(":")) return
        Quickshell.execDetached([Directories.cliPath, "hyprset", "key", key, String(value)])
    }

    function changeAnimation(animName, style) {
        if (/['"\\`$|&;]/.test(String(animName)) || /['"\\`$|&;]/.test(String(style))) {
            console.error("[HyprlandSettings] Unsafe characters rejected:", animName, style)
            return
        }
        // Apply immediately via hyprctl keyword (takes effect right away, unlike hyprset which only edits a file)
        Quickshell.execDetached(["hyprctl", "keyword", "animation", animName + ",1,7,menu_decel," + style]);
        // Write to the persistent config through hyprset.sh. Calling the helper
        // directly keeps this independent of whether the vynx symlink exists.
        Quickshell.execDetached(["bash", Directories.home.replace("file://", "") + "/.local/share/ii-p3drovfx/sdata/cli/lib/hyprset.sh", "anim", animName, String(style)])
    }

    function setLayout(layout) {
        if (layout !== "default" && layout !== "scrolling" && layout !== "dwindle" && layout !== "monocle" && layout !== "master") return
        // console.log("[HyprlandSettings] Setting layout to", layout)
        changeKey("general:layout", layout)
        Persistent.states.hyprland.layout = layout
    }

    function setRounding(rounding) {
        changeKey("decoration:rounding", rounding)
    }
}
