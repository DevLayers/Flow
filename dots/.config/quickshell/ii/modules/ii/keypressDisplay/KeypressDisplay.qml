pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * On-screen keystrokes, drawn on top of everything so a screen recording picks
 * them up: wlr-screencopy composites layer surfaces, so whatever is shown here
 * lands in the file without any extra plumbing.
 *
 * The window is fully click-through (an empty mask) and reserves no space, so
 * it never disturbs the tiling underneath. It is drawn on every output, because
 * focus can move to another monitor mid-recording and an overlay that follows
 * the focus would then vanish from the footage.
 */
Scope {
    id: root

    readonly property string position: Config.options.screenRecord.keypress.position
    readonly property bool atTop: root.position.startsWith("top")
    readonly property bool atLeft: root.position.endsWith("Left")
    readonly property bool atRight: root.position.endsWith("Right")

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: keypressWindow
            required property ShellScreen modelData
            screen: keypressWindow.modelData

            visible: KeypressService.visible
            WlrLayershell.namespace: "quickshell:keypressDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // Nothing here is ever clicked; an empty region lets every event
            // through to the application being recorded.
            mask: Region {}

            anchors {
                top: root.atTop
                bottom: !root.atTop
                left: true
                right: true
            }
            margins {
                top: root.atTop ? Config.options.screenRecord.keypress.marginV : 0
                bottom: root.atTop ? 0 : Config.options.screenRecord.keypress.marginV
                left: Config.options.screenRecord.keypress.marginH
                right: Config.options.screenRecord.keypress.marginH
            }

            implicitHeight: chipList.height

            ListView {
                id: chipList
                model: KeypressService.chips
                orientation: ListView.Horizontal
                interactive: false
                spacing: 8

                readonly property real fontSize: Appearance.font.pixelSize.huge * Config.options.screenRecord.keypress.scale
                // Height is stated rather than measured: taking it from
                // contentHeight would mean no height until a delegate exists,
                // and no delegate until there is a height to put it in.
                readonly property real chipHeight: Math.round(chipList.fontSize * 2)

                width: Math.min(parent.width, contentWidth)
                height: chipList.chipHeight
                // Newest chips sit at the model's tail, so a run of keys grows
                // away from the anchored edge instead of jumping around.
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: root.atLeft ? parent.left : undefined
                    right: root.atRight ? parent.right : undefined
                    horizontalCenter: (root.atLeft || root.atRight) ? undefined : parent.horizontalCenter
                }

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 0.7
                        to: 1
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                    NumberAnimation {
                        property: "scale"
                        to: 0.8
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                delegate: Item {
                    id: chip
                    required property string label
                    required property string kind

                    readonly property real fontSize: chipList.fontSize
                    readonly property real horizontalPadding: chip.fontSize * 0.75
                    readonly property bool isCombo: chip.kind !== "text"

                    implicitWidth: chipBackground.implicitWidth
                    width: implicitWidth
                    height: chipList.chipHeight

                    StyledRectangularShadow {
                        target: chipBackground
                    }

                    Rectangle {
                        id: chipBackground
                        anchors.centerIn: parent
                        implicitWidth: chipText.implicitWidth + chip.horizontalPadding * 2
                        implicitHeight: chipList.chipHeight
                        radius: Appearance.rounding.full
                        // Shortcuts are what a viewer is meant to notice, so they
                        // carry the accent while plain typing stays quiet.
                        color: chip.isCombo ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        StyledText {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.label
                            color: chip.isCombo ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                            font.pixelSize: chip.fontSize
                            font.weight: Font.DemiBold
                            font.family: Appearance.font.family.main
                        }
                    }
                }
            }
        }
    }
}
