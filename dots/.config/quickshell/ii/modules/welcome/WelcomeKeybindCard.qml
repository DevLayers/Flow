import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    required property string title
    property var keys: []
    property string materialIcon: "keyboard"
    property string unassignedText: Translation.tr("No shortcut")

    readonly property bool isCompactKeycaps: keys.length >= 3

    implicitHeight: 66
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 8

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.materialIcon
            shape: MaterialShape.Shape.Square
            iconSize: Appearance.font.pixelSize.normal
            padding: 7
            color: Appearance.colors.colSecondaryContainer
            colSymbol: Appearance.colors.colOnSecondaryContainer
        }

        StyledText {
            Layout.fillWidth: true
            Layout.minimumWidth: 44
            Layout.alignment: Qt.AlignVCenter
            text: root.title
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        RowLayout {
            visible: root.keys.length > 0
            Layout.alignment: Qt.AlignVCenter
            spacing: root.isCompactKeycaps ? 2 : 4

            Repeater {
                model: root.keys
                delegate: RowLayout {
                    required property string modelData
                    required property int index
                    spacing: root.isCompactKeycaps ? 2 : 4

                    KeyboardKey {
                        key: modelData
                        horizontalPadding: root.isCompactKeycaps ? 4 : 6
                        pixelSize: root.isCompactKeycaps
                            ? Appearance.font.pixelSize.smaller - 1
                            : Appearance.font.pixelSize.smaller
                    }
                    StyledText {
                        visible: index < root.keys.length - 1
                        text: "+"
                        color: Appearance.colors.colOnLayer3
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }
            }
        }

        StyledText {
            visible: root.keys.length === 0
            Layout.alignment: Qt.AlignVCenter
            text: root.unassignedText
            color: Appearance.colors.colOnLayer2
            opacity: 0.75
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }
}
