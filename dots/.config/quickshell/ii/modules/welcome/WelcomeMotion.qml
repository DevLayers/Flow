pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

/**
 * Welcome-only motion policy. It derives every value from the existing
 * Appearance animation system and stores no navigation state.
 */
QtObject {
    id: root

    readonly property real multiplier: Appearance.animMultiplier
    readonly property bool motionEnabled: root.multiplier > 0.01
    readonly property int level: !root.motionEnabled
        ? 0
        : root.multiplier < 0.9
            ? 1
            : root.multiplier < 1.5
                ? 2
                : 3
    readonly property bool blurAllowed: root.level >= 2
    readonly property bool staggerAllowed: root.level >= 3
    readonly property real pageScale: root.level >= 2 ? 0.985 : 1.0
    // The incoming page is already readable while its position and blur settle.
    // Keeping it opaque prevents controls inside the page from dimming and
    // snapping back to full opacity when the transition completes.
    readonly property real pageOpacityIn: 1.0
    readonly property real pageOpacityOut: root.level >= 1 ? 0.0 : 1.0
    readonly property real blurProgress: root.blurAllowed ? 0.68 : 0.0
    readonly property real blurMax: Math.max(Appearance.rounding.small, Appearance.rounding.normal * 1.35)

    function offsetFor(width: real): real {
        return Math.max(
            Appearance.rounding.normal * 2,
            Math.min(Appearance.rounding.large * 5, width * 0.10));
    }

    function staggerFor(index: int): int {
        return root.staggerAllowed
            ? Math.round(index * Appearance.animation.elementMoveFast.duration * 0.18)
            : 0;
    }
}
