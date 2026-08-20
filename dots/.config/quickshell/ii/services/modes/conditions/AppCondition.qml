import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import "../ModeSchema.js" as ModeSchema
import ".."

/**
 * A window whose class (or initial class) matches one of `classes` is open
 * (`when: running`) or focused (`when: focused`).
 */
ModeCondition {
    id: root
    readonly property var regexes: ModeSchema.classRegexes(root.params?.classes)
    readonly property bool wantFocused: root.params?.when === "focused"

    readonly property string focusedAddress: {
        const a = ToplevelManager.activeToplevel?.HyprlandToplevel?.address;
        return a ? `0x${a}` : "";
    }
    readonly property var windows: HyprlandData.windowList ?? []
    readonly property var matching: root.windows.filter(w => ModeSchema.windowMatches(w, root.regexes))
    readonly property var focusedMatch: root.matching.find(w => w.address === root.focusedAddress) ?? null

    satisfied: root.regexes.length > 0
        && (root.wantFocused ? root.focusedMatch !== null : root.matching.length > 0)
    reason: {
        const w = root.focusedMatch ?? root.matching[0];
        return w ? String(w["class"] || w.initialClass || "") : "";
    }
}
