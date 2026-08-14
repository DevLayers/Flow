import QtQuick
import qs.modules.common

Item {
    id: root
    visible: false

    // Existing consumers rely on the parent target; callers with a different
    // target can opt in explicitly without paying for the animation engine in
    // Settings Performance Mode.
    property Item targetItem: parent
    readonly property bool scrollAnimationsEnabled: Config.options?.appearance?.scrollAnimations ?? true
    readonly property bool performanceMode: Config.options?.appearance?.settingsPerformanceMode ?? false
    property bool active: root.scrollAnimationsEnabled && !root.performanceMode

    Loader {
        active: root.active && root.targetItem !== null
        sourceComponent: scrollAnimationComponent
    }

    Component {
        id: scrollAnimationComponent

        Item {
            id: animation
            property Item targetItem: root.targetItem
            property Item attachedTarget: null
            property Flickable flickable: null
            property bool targetOpacityBindingEnabled: true

            Scale {
                id: scrollScaleTransform
                origin.x: animation.targetItem ? animation.targetItem.width / 2 : 0
                origin.y: animation.targetItem ? animation.targetItem.height / 2 : 0
                xScale: animation.animatedScale
                yScale: animation.animatedScale
            }

            Translate {
                id: scrollTranslateTransform
                y: animation.animatedTranslateY
            }

            Timer {
                id: retryTimer
                interval: 50
                repeat: false
                onTriggered: animation.findFlickable()
            }

            function attachTransform() {
                if (!targetItem)
                    return;

                const transforms = targetItem.transform;
                if (transforms.indexOf(scrollScaleTransform) === -1) {
                    transforms.push(scrollScaleTransform);
                }
                if (transforms.indexOf(scrollTranslateTransform) === -1) {
                    transforms.push(scrollTranslateTransform);
                }
                targetItem.transform = transforms;
                attachedTarget = targetItem;
                targetOpacityBindingEnabled = true;
            }

            function detachTransform() {
                if (!attachedTarget)
                    return;

                targetOpacityBindingEnabled = false;
                const transforms = attachedTarget.transform;
                const scaleIdx = transforms.indexOf(scrollScaleTransform);
                if (scaleIdx !== -1) {
                    transforms.splice(scaleIdx, 1);
                }
                const transIdx = transforms.indexOf(scrollTranslateTransform);
                if (transIdx !== -1) {
                    transforms.splice(transIdx, 1);
                }
                attachedTarget.transform = transforms;
                if (attachedTarget.opacity < 0.999)
                    attachedTarget.opacity = 1.0;
                attachedTarget = null;
            }

            function findFlickable() {
                let nextParent = targetItem ? targetItem.parent : null;
                while (nextParent) {
                    if (nextParent.flickableDirection !== undefined && nextParent.contentY !== undefined) {
                        flickable = nextParent;
                        return;
                    }
                    nextParent = nextParent.parent;
                }
                flickable = null;
            }

            // Calculate relative Y coordinate inside the Flickable viewport.
            readonly property real relativeY: {
                if (!flickable || !targetItem)
                    return 0;
                // Reading contentY keeps this binding reactive to scrolling.
                const scrollY = flickable.contentY;
                try {
                    return targetItem.mapToItem(flickable, 0, 0).y;
                } catch (error) {
                    return 0;
                }
            }

            // Check visibility with a generous buffer to begin the animation
            // before a delegate enters the viewport.
            readonly property bool isVisible: {
                if (!flickable || !targetItem || flickable.height <= 0)
                    return true;

                const isBelowTop = (relativeY + targetItem.height) >= -60;
                const isAboveBottom = relativeY <= (flickable.height + 100);
                return isBelowTop && isAboveBottom;
            }

            readonly property real targetOpacity: isVisible ? 1.0 : 0.0
            readonly property real targetScale: isVisible ? 1.0 : 0.92
            readonly property real targetTranslateY: isVisible ? 0 : 20
            property real animatedOpacity: 0.0
            property real animatedScale: 0.92
            property real animatedTranslateY: 20

            Binding {
                target: animation
                property: "animatedOpacity"
                value: animation.targetOpacity
            }

            Binding {
                target: animation
                property: "animatedScale"
                value: animation.targetScale
            }

            Binding {
                target: animation
                property: "animatedTranslateY"
                value: animation.targetTranslateY
            }

            Behavior on animatedOpacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Behavior on animatedScale {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            Behavior on animatedTranslateY {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            Binding {
                target: animation.targetItem
                property: "opacity"
                value: animation.animatedOpacity
                when: animation.targetOpacityBindingEnabled && animation.animatedOpacity < 0.999
            }

            Component.onCompleted: {
                findFlickable();
                if (!flickable)
                    retryTimer.start();
                attachTransform();
            }

            onTargetItemChanged: {
                retryTimer.stop();
                detachTransform();
                findFlickable();
                if (!flickable)
                    retryTimer.start();
                attachTransform();
            }

            Component.onDestruction: {
                retryTimer.stop();
                detachTransform();
            }
        }
    }
}
