import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * One app in the usage list: icon, name, its share of the selected metric as a
 * proportional bar, and the figure itself.
 *
 * The bar is drawn against the largest app in the list rather than the total, so
 * the top entry always fills the row — with a long tail of small apps a
 * total-relative bar would collapse everything below the leader into a stub.
 */
Rectangle {
    id: root

    required property var record
    required property real value
    required property real maxValue
    required property string valueText
    required property bool selected
    readonly property string appKey: root.record.key
    readonly property string iconName: AppStats.iconFor(root.appKey)
    readonly property bool isSystem: root.appKey === AppStats.systemKey
    readonly property bool isHeadless: root.record.headless ?? false

    signal clicked()

    implicitHeight: 54
    radius: Appearance.rounding.small
    color: {
        if (root.selected)
            return Appearance.colors.colSecondaryContainer;

        return rowArea.containsMouse ? Appearance.colors.colLayer2Hover : "transparent";
    }

    MouseArea {
        id: rowArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        spacing: 10

        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 12
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 32
            implicitHeight: 32

            IconImage {
                anchors.centerIn: parent
                visible: root.iconName.length > 0
                implicitSize: 32
                source: root.iconName.length > 0 ? Quickshell.iconPath(root.iconName, "") : ""
            }

            // Headless daemons and the system row have no desktop entry to draw from.
            // A window-bearing app that merely failed to resolve is not a daemon, so
            // it does not get the terminal glyph that would say it is one.
            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.iconName.length === 0
                text: {
                    if (root.isSystem)
                        return "memory";
                    return root.isHeadless ? "terminal" : "apps";
                }
                iconSize: 24
                color: Appearance.colors.colSubtext
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: AppStats.displayName(root.appKey)
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: root.valueText
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                }

            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer2

                Rectangle {
                    width: parent.width * (root.maxValue > 0 ? Math.min(1, root.value / root.maxValue) : 0)
                    radius: parent.radius
                    color: root.isSystem ? Appearance.colors.colSubtext : Appearance.colors.colPrimary

                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Appearance.animation.elementMove.duration
                            easing.type: Appearance.animation.elementMove.type
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }

                }

            }

        }

    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

}
