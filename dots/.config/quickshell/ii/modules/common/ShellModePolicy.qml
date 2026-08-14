pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/**
 * Shared policy for the Default/Connect shell modes.
 *
 * Keep capability checks here so Settings, Welcome and future setup flows do
 * not drift into slightly different interpretations of the same constraints.
 * This object only reads Config and performs explicit writes through setMode().
 */
QtObject {
    id: root

    readonly property string effectiveMode: Config.ready
        ? (Config.options.sidebar.sidebarStyle || "default")
        : "default"

    readonly property bool barCenterActive: Config.ready
        && Config.options.bar.floatingNotch.centerInBar
    readonly property bool floatingNotchActive: Config.ready
        && Config.options.bar.floatingNotch.enable
    readonly property bool transparentBarBackground: Config.ready
        && Config.options.bar.barBackgroundStyle === 0
    readonly property bool edgeRoundingActive: Config.ready
        && Config.options.appearance.fakeScreenRounding === 4

    // Connect is intentionally available from Welcome even when the current
    // bar uses an incompatible presentation. setMode("connect") normalizes
    // only the two bar choices required by Connect before switching modes.
    readonly property bool canSelectConnect: Config.ready
    // Existing shell behavior keeps the Default option unavailable while the
    // current Connect session is backed by a floating Dynamic Island.
    readonly property bool canSelectDefault: Config.ready
        && !(root.floatingNotchActive && root.effectiveMode === "connect")

    readonly property bool shouldForceDefault: Config.ready
        && root.effectiveMode === "connect"
        && !root.canSelectConnect

    readonly property bool barPositionLocked: root.barCenterActive
    readonly property bool osdStyleEditable: root.effectiveMode !== "connect"
    readonly property bool connectModeActive: root.effectiveMode === "connect"

    readonly property string defaultBlockedReasonKey: root.floatingNotchActive
        && root.effectiveMode === "connect"
        ? "Disable Floating Dynamic Island first"
        : ""
    readonly property string connectBlockedReasonKey: ""
    readonly property string barPositionBlockedReasonKey:
        "The bar stays at the top while Dynamic Island is centered in it."

    function setMode(mode: string): bool {
        if (!Config.ready || (mode !== "default" && mode !== "connect"))
            return false;
        if (mode === "default" && !root.canSelectDefault)
            return false;
        if (mode === "connect") {
            // Connect requires a compact Hug bar with a visible surface. Do
            // this as one explicit user action so new users can preview it
            // without first understanding the full Bar settings matrix.
            Config.options.bar.cornerStyle = 0;
            Config.options.bar.barBackgroundStyle = 1;
        }
        Config.options.sidebar.sidebarStyle = mode;
        return true;
    }

    function setBarPosition(value: int): bool {
        if (!Config.ready || root.barPositionLocked)
            return false;
        Config.options.bar.bottom = (value & 1) !== 0;
        Config.options.bar.vertical = (value & 2) !== 0;
        return true;
    }
}
