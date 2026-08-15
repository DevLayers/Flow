import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    implicitWidth: parent ? parent.width : 340
    implicitHeight: 72
    radius: Appearance.rounding.normal
    color: Appearance.colors.colPrimaryContainer

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12

        MaterialShape {
            Layout.alignment: Qt.AlignVCenter
            implicitSize: 42
            shapeString: "Cookie9Sided"
            color: Appearance.colors.colPrimary

            MaterialSymbol {
                anchors.centerIn: parent
                text: "cast_connected"
                iconSize: 22
                color: Appearance.colors.colOnPrimary
                fill: 1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: NetworkDisplayService.activeSinkName || Translation.tr("Wireless Display")
                font.weight: Font.DemiBold
                font.pixelSize: Appearance.font.pixelSize.body
                color: Appearance.colors.colOnPrimaryContainer
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: NetworkDisplayService.sessionState === "Starting" ? Translation.tr("Establishing session…") : Translation.tr("Screen cast active")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colPrimary
                elide: Text.ElideRight
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            buttonText: Translation.tr("Disconnect")
            onClicked: {
                NetworkDisplayService.disconnect();
            }
        }
    }
}
