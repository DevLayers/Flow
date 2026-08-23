import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.modules.common

Item {
    id: lockDesatRoot

    required property var sourceItem
    // Same capture-once caveat as LockBlur, and its source is often LockBlur itself, so it must
    // not capture an effect that has not produced its own texture yet.
    required property bool sourceReady
    required property real baseScale
    required property bool lockAnimationActive

    readonly property real targetSaturation: -Config.options.lock.desaturate.amount

    Loader {
        id: desatLoader
        active: Config.options.lock.desaturate.enable && lockDesatRoot.sourceReady
            && (GlobalStates.screenLocked || (desatLoader.status === Loader.Ready && desatLoader.item && desatLoader.item.saturation !== 0.0))
        anchors.fill: parent
        sourceComponent: MultiEffect {
            source: lockDesatRoot.sourceItem
            saturation: GlobalStates.screenLocked ? lockDesatRoot.targetSaturation : 0.0
            Behavior on saturation {
                NumberAnimation {
                    id: desaturationAnim
                    duration: Math.round(600 * Appearance.animMultiplier)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
