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
    property string usedIn: ""
    property string stateText: ""
    property string stateKind: "neutral"

    signal activated()

    implicitHeight: 150
    buttonRadius: Appearance.rounding.large
    buttonRadiusPressed: Appearance.rounding.full
    colBackground: Appearance.colors.colLayer1
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colBackgroundActive: Appearance.colors.colLayer1Active
    colRipple: Appearance.colors.colLayer1Active
    onClicked: root.activated()

    readonly property color stateColor: {
        if (root.stateKind === "ready")
            return Appearance.m3colors.m3onSuccessContainer;
        if (root.stateKind === "attention")
            return Appearance.colors.colOnErrorContainer;
        return Appearance.colors.colOnSecondaryContainer;
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.materialIcon
                shape: MaterialShape.Shape.Cookie7Sided
                iconSize: Appearance.font.pixelSize.large
                padding: 10
                color: Appearance.colors.colSecondaryContainer
                colSymbol: Appearance.colors.colOnSecondaryContainer
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.title
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "arrow_forward"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer2
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.description
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Item { Layout.fillHeight: true }

        StyledText {
            Layout.fillWidth: true
            visible: root.usedIn.length > 0
            text: Translation.tr("Used in: ") + root.usedIn
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.stateText.length > 0
            text: root.stateText
            color: root.stateColor
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }
}
