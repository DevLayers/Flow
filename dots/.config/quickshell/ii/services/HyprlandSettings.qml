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

    function changeAnimationSpec(leaf, enabled, speed, curve, style) {
        const allowedLeaves = [
            "global", "windows", "windowsIn", "windowsOut", "windowsMove",
            "fadeIn", "fadeOut", "fadeSwitch", "fadeShadow", "fadeDim", "fadeLayers",
            "fadeLayersIn", "fadeLayersOut", "layers", "layersIn", "layersOut",
            "workspaces", "workspacesIn", "workspacesOut", "specialWorkspace",
            "specialWorkspaceIn", "specialWorkspaceOut", "border", "borderangle",
            "zoomFactor", "fadePopups", "fadePopupsIn", "fadePopupsOut"
        ];
        if (typeof leaf !== "string" || !allowedLeaves.includes(leaf)) {
            console.error("[HyprlandSettings] Invalid animation leaf:", leaf);
            return;
        }
        const isEnabled = Boolean(enabled);
        const numSpeed = Number(speed);
        if (isNaN(numSpeed) || numSpeed <= 0 || numSpeed > 50) {
            console.error("[HyprlandSettings] Invalid animation speed:", speed);
            return;
        }
        if (curve && /[^a-zA-Z0-9_-]/.test(String(curve))) {
            console.error("[HyprlandSettings] Unsafe characters in curve name:", curve);
            return;
        }
        if (style && /[^a-zA-Z0-9_% ]/.test(String(style))) {
            console.error("[HyprlandSettings] Unsafe characters in animation style:", style);
            return;
        }

        let luaExpr = "hl.animation({ leaf = '" + leaf + "', enabled = " + (isEnabled ? "true" : "false") + ", speed = " + numSpeed.toFixed(2);
        if (curve && String(curve).trim() !== "") {
            luaExpr += ", bezier = '" + String(curve).trim() + "'";
        }
        if (style && String(style).trim() !== "") {
            luaExpr += ", style = '" + String(style).trim() + "'";
        }
        luaExpr += " })";

        Quickshell.execDetached(["hyprctl", "eval", luaExpr]);
    }

    function updateAppLaunchAnimation(enabled, startPercent, speed, curve) {
        const isEnabled = enabled !== false;
        const percent = Math.max(5, Math.min(100, Math.round(Number(startPercent) || 20)));
        const animSpeed = Math.max(0.5, Math.min(20, Number(speed) || 3.2));
        const animCurve = (typeof curve === "string" && curve.trim() !== "") ? curve.trim() : "iiAppOpen";

        const inStyle = isEnabled ? ("popin " + percent + "%") : "popin 100%";
        const outPercent = Math.min(90, Math.round(percent + (100 - percent) * 0.5));
        const outStyle = isEnabled ? ("popin " + outPercent + "%") : "popin 100%";
        changeAnimationSpec("windowsIn", isEnabled, animSpeed, animCurve, inStyle);
        changeAnimationSpec("fadeIn", isEnabled, animSpeed, animCurve, "");
        changeAnimationSpec("windowsOut", isEnabled, animSpeed, animCurve, outStyle);
        changeAnimationSpec("fadeOut", isEnabled, animSpeed, animCurve, "");
    }

    function changeAnimation(animName, style) {
        changeAnimationSpec(animName, true, 7, "menu_decel", style);
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
