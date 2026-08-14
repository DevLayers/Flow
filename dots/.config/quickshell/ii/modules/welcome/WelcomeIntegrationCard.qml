import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

RippleButton {
    id: root

    property string materialIcon: "extension"
    property string title: ""
    property string description: ""
    property var usedInChips: []
    property string stateText: ""
    property string stateKind: "neutral"

    signal activated()

    implicitHeight: 114
    buttonRadius: Appearance.rounding.large
    buttonRadiusPressed: Appearance.rounding.full
    colBackground: Appearance.colors.colLayer1
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colBackgroundActive: Appearance.colors.colLayer1Active
    colRipple: Appearance.colors.colLayer1Active
    onClicked: root.activated()

    readonly property color stateBgColor: {
        if (root.stateKind === "ready")
            return Appearance.colors.colPrimaryContainer;
        if (root.stateKind === "attention")
            return Appearance.colors.colErrorContainer;
        if (root.stateKind === "configured")
            return Appearance.colors.colSecondaryContainer;
        return Appearance.colors.colLayer2;
    }

    readonly property color stateFgColor: {
        if (root.stateKind === "ready")
            return Appearance.colors.colOnPrimaryContainer;
        if (root.stateKind === "attention")
            return Appearance.colors.colOnErrorContainer;
        if (root.stateKind === "configured")
            return Appearance.colors.colOnSecondaryContainer;
        return Appearance.colors.colOnLayer2;
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 6

        // Top Row: Icon + Title + Status Pill + Arrow
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.materialIcon
                shape: MaterialShape.Shape.Cookie7Sided
                iconSize: Appearance.font.pixelSize.normal
                padding: 8
                color: Appearance.colors.colSecondaryContainer
                colSymbol: Appearance.colors.colOnSecondaryContainer
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: root.title
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                visible: root.stateText.length > 0
                radius: Appearance.rounding.full
                implicitHeight: 22
                implicitWidth: statusTextItem.implicitWidth + 14
                color: root.stateBgColor

                StyledText {
                    id: statusTextItem
                    anchors.centerIn: parent
                    text: root.stateText
                    color: root.stateFgColor
                    font.pixelSize: Appearance.font.pixelSize.smaller - 1
                    font.weight: Font.DemiBold
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "arrow_forward"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer2
            }
        }

        // Description
        StyledText {
            Layout.fillWidth: true
            text: root.description
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.smaller
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Item { Layout.fillHeight: true }

        // Bottom Row: Used In Chips
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.usedInChips

                delegate: Rectangle {
                    required property string modelData
                    radius: Appearance.rounding.small
                    implicitHeight: 20
                    implicitWidth: chipLabel.implicitWidth + 10
                    color: Appearance.colors.colLayer2

                    StyledText {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: Translation.tr(modelData)
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.smaller - 1
                    }
                }
            }
        }
    }
}
