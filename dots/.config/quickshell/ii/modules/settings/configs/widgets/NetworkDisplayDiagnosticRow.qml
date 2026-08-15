import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property string icon
    required property string label
    property string detail: ""
    property bool ready: false
    property bool isWarning: false

    property bool isFirst: false
    property bool isLast: false
    property bool isAlone: false

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 48

    color: Appearance.colors.colLayer3

    topLeftRadius: (isFirst || isAlone) ? Appearance.rounding.normal : Appearance.rounding.verysmall
    topRightRadius: (isFirst || isAlone) ? Appearance.rounding.normal : Appearance.rounding.verysmall
    bottomLeftRadius: (isLast || isAlone) ? Appearance.rounding.normal : Appearance.rounding.verysmall
    bottomRightRadius: (isLast || isAlone) ? Appearance.rounding.normal : Appearance.rounding.verysmall

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        MaterialShape {
            Layout.alignment: Qt.AlignVCenter
            implicitSize: 32
            shapeString: "Cookie9Sided"
            color: root.ready
                ? Qt.alpha(Appearance.colors.colPrimary, 0.18)
                : (root.isWarning ? Qt.alpha(Appearance.m3colors.m3tertiary, 0.18) : Qt.alpha(Appearance.m3colors.m3error, 0.18))

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.icon
                iconSize: 18
                color: root.ready ? Appearance.colors.colPrimary : (root.isWarning ? Appearance.m3colors.m3tertiary : Appearance.m3colors.m3error)
                fill: root.ready ? 1 : 0
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.weight: Font.Medium
                font.pixelSize: Appearance.font.pixelSize.body
                color: Appearance.colors.colOnLayer2
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.detail
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                visible: root.detail.length > 0
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.ready ? "check_circle" : (root.isWarning ? "info" : "cancel")
                iconSize: 18
                color: root.ready ? Appearance.colors.colPrimary : (root.isWarning ? Appearance.m3colors.m3tertiary : Appearance.m3colors.m3error)
                fill: 1
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: root.ready ? Translation.tr("Ready") : (root.isWarning ? Translation.tr("Optional") : Translation.tr("Missing"))
                font.weight: Font.DemiBold
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.ready ? Appearance.colors.colPrimary : (root.isWarning ? Appearance.m3colors.m3tertiary : Appearance.m3colors.m3error)
            }
        }
    }
}
