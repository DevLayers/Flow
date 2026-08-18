pragma ComponentBehavior: Bound

/**
 * The strip of layout names shown when the tiling layout is cycled.
 *
 * Purely a readout: the shortcut has already changed the layout by the time
 * this appears, and the zones behind it are the real feedback. It exists
 * because a preset changing is completely silent on a workspace with nothing
 * tiled on it yet, and because the layouts are worth being able to name.
 *
 * Click-through, like the zone overlay - there is nothing here to press.
 */

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/tiling.js" as Tiling
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    readonly property int fadeDuration: Config.options?.tiling?.overlay?.fadeDuration ?? 150
    readonly property string monitorName: TilingAssistant.layoutHintMonitor
    readonly property var targetScreen: Quickshell.screens.find(candidate => candidate.name === root.monitorName) ?? null
    readonly property var ring: root.monitorName ? TilingAssistant.layoutRing(root.monitorName) : []
    readonly property string current: root.monitorName ? TilingAssistant.presetFor(root.monitorName) : ""

    readonly property bool shown: TilingAssistant.layoutHintVisible && root.targetScreen !== null

    // Outlives `shown` so the surface is still there to fade out on.
    property bool surfaceAlive: false

    onShownChanged: {
        if (root.shown) {
            fadeOutTimer.stop();
            root.surfaceAlive = true;
        } else {
            fadeOutTimer.restart();
        }
    }

    Timer {
        id: fadeOutTimer
        interval: root.fadeDuration + 50
        onTriggered: root.surfaceAlive = false
    }

    Loader {
        active: root.surfaceAlive

        sourceComponent: PanelWindow {
            screen: root.targetScreen
            WlrLayershell.namespace: "quickshell:tiling_layout_hint"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            color: "transparent"
            visible: true

            implicitWidth: card.implicitWidth
            implicitHeight: card.implicitHeight

            anchors.bottom: true
            // Clear of the bar only when the bar is down here to be cleared of.
            margins.bottom: ((Config.options?.bar?.bottom ?? false) ? Appearance.sizes.barHeight : 0) + 24

            Rectangle {
                id: card

                anchors.centerIn: parent
                implicitWidth: chips.implicitWidth + 16
                implicitHeight: chips.implicitHeight + 16
                radius: Appearance.rounding.verylarge
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant
                opacity: 0

                Component.onCompleted: card.opacity = Qt.binding(() => root.shown ? 1 : 0)

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.fadeDuration
                        easing.type: Easing.OutCubic
                    }
                }

                RowLayout {
                    id: chips
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: root.ring

                        delegate: Rectangle {
                            id: chip

                            required property string modelData

                            readonly property bool selected: chip.modelData === root.current

                            implicitWidth: chipRow.implicitWidth + 20
                            implicitHeight: chipRow.implicitHeight + 12
                            radius: Appearance.rounding.full
                            color: chip.selected ? Appearance.colors.colPrimary : Appearance.colors.colLayer1

                            Behavior on color {
                                animation: Appearance?.animation.elementMoveFast.colorAnimation.createObject(this)
                            }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialSymbol {
                                    text: Tiling.presetIcon(chip.modelData)
                                    iconSize: Appearance.font.pixelSize.large
                                    color: chip.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                }

                                StyledText {
                                    text: Translation.tr(Tiling.presetName(chip.modelData))
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: chip.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
