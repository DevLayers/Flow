pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property string pageId: "start"
    signal closeRequested()

    readonly property string pageTitle: WelcomePageRegistry.titleFor(root.pageId)
    readonly property string pageSubtitle: WelcomePageRegistry.subtitleFor(root.pageId)

    implicitHeight: Math.max(84, headerRow.implicitHeight)

    RowLayout {
        id: headerRow
        anchors.fill: parent
        spacing: 14

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: {
                const page = WelcomePageRegistry.pageById(root.pageId);
                return page ? page.icon : "waving_hand";
            }
            shape: MaterialShape.Shape.Cookie9Sided
            iconSize: Appearance.font.pixelSize.large
            padding: 13
            fill: 1
            color: Appearance.colors.colPrimary
            colSymbol: Appearance.colors.colOnPrimary
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            StyledText {
                Layout.fillWidth: true
                text: root.pageTitle
                color: Appearance.colors.colOnLayer0
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.huge
                font.variableAxes: Appearance.font.variableAxes.title
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.pageSubtitle
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            RippleButton {
                Layout.alignment: Qt.AlignRight
                implicitWidth: 48
                implicitHeight: 48
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colBackgroundActive: Appearance.colors.colLayer1Active
                colRipple: Appearance.colors.colLayer1Active

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }

                onClicked: root.closeRequested()
            }
        }
    }
}
