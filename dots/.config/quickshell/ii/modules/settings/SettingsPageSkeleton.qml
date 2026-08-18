import QtQuick
import QtQuick.Layouts
import qs.modules.common

Item {
    id: root

    property bool revealed: false
    readonly property bool performanceMode: Config.options?.appearance?.settingsPerformanceMode ?? false

    opacity: revealed ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        enabled: !root.performanceMode
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.rounding.normal
        spacing: Appearance.rounding.small

        Repeater {
            model: 3

            delegate: Rectangle {
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: index === 0 ? 190 : 150
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.rounding.large
                    spacing: Appearance.rounding.small

                    Rectangle {
                        Layout.preferredWidth: parent.width * (index === 0 ? 0.34 : 0.48)
                        Layout.preferredHeight: Appearance.font.pixelSize.normal
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer3
                    }

                    Item {
                        Layout.preferredHeight: Appearance.rounding.unsharpenmore
                    }

                    Repeater {
                        model: 2

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Appearance.font.pixelSize.small
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer3
                            opacity: 0.72
                        }
                    }
                }
            }
        }
    }
}
