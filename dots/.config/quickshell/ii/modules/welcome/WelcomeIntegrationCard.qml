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
    property bool hero: false

    signal activated()

    implicitHeight: root.hero
        ? Appearance.rounding.verylarge * 5 + Appearance.rounding.normal
        : Appearance.rounding.verylarge * 3 + Appearance.rounding.normal
    buttonRadius: Appearance.rounding.large
    buttonRadiusPressed: Appearance.rounding.normal
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

        // Top Row: expressive shape + title + status pill
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.materialIcon
                shape: root.hovered
                    ? MaterialShape.Shape.SoftBurst
                    : MaterialShape.Shape.Cookie7Sided
                iconSize: root.hero
                    ? Appearance.font.pixelSize.huge
                    : Appearance.font.pixelSize.large
                padding: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer
                colSymbol: Appearance.colors.colOnSecondaryContainer
                rotation: root.hovered ? 8 : 0

                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: root.title
                color: Appearance.colors.colOnLayer1
                font.pixelSize: root.hero
                    ? Appearance.font.pixelSize.hugeass
                    : Appearance.font.pixelSize.large
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                visible: root.stateText.length > 0
                radius: Appearance.rounding.full
                implicitHeight: 22
                implicitWidth: statusIcon.implicitWidth + statusTextItem.implicitWidth + 22
                color: root.stateBgColor

                MaterialSymbol {
                    id: statusIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.stateText.indexOf("…") >= 0
                        ? "progress_activity"
                        : root.stateKind === "ready"
                            ? "check"
                            : root.stateKind === "attention"
                                ? "warning"
                                : "info"
                    iconSize: Appearance.font.pixelSize.smaller
                    color: root.stateFgColor
                }

                StyledText {
                    id: statusTextItem
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: statusIcon.right
                    anchors.leftMargin: 4
                    text: root.stateText
                    color: root.stateFgColor
                    font.pixelSize: Appearance.font.pixelSize.smaller - 1
                    font.weight: Font.DemiBold
                }
            }

        }

        // Description
        StyledText {
            Layout.fillWidth: true
            text: root.description
            color: Appearance.colors.colOnLayer2
            font.pixelSize: root.hero
                ? Appearance.font.pixelSize.small
                : Appearance.font.pixelSize.smaller
            maximumLineCount: root.hero ? 2 : 1
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
