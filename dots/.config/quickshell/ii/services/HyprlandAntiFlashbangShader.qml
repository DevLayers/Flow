pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/**
 * Anti-flashbang is one of the shaders `ScreenShader` offers, so this is kept only
 * as the name its existing callers already use. Everything goes through
 * `ScreenShader` so the two can never fight over `decoration:screen_shader`.
 */
Singleton {
    id: root

    readonly property string shaderName: "anti-flashbang"
    readonly property bool enabled: ScreenShader.activeName === root.shaderName

    function enable() {
        ScreenShader.apply(root.shaderName);
    }

    function disable() {
        ScreenShader.clear();
    }

    function toggle() {
        if (root.enabled)
            root.disable();
        else
            root.enable();
    }
}
