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
    property string unassignedText: Translation.tr("Not assigned")

    implicitHeight: 82
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.materialIcon
            shape: MaterialShape.Shape.Square
            iconSize: Appearance.font.pixelSize.normal
            padding: 8
            color: Appearance.colors.colSecondaryContainer
            colSymbol: Appearance.colors.colOnSecondaryContainer
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.title
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        RowLayout {
            visible: root.keys.length > 0
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Repeater {
                model: root.keys
                delegate: RowLayout {
                    required property string modelData
                    required property int index
                    spacing: 4

                    KeyboardKey { key: modelData }
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
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.italic: true
        }
    }
}
