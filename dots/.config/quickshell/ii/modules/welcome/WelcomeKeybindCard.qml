import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property string title
    required property string key1
    property string key2: ""
    property string key3: ""
    property string materialIcon: "keyboard"

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
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            KeyboardKey { key: root.key1 }
            StyledText {
                visible: root.key2.length > 0
                text: "+"
                color: Appearance.colors.colOnLayer3
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            KeyboardKey {
                visible: root.key2.length > 0
                key: root.key2
            }
            StyledText {
                visible: root.key3.length > 0
                text: "+"
                color: Appearance.colors.colOnLayer3
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            KeyboardKey {
                visible: root.key3.length > 0
                key: root.key3
            }
        }
    }
}
