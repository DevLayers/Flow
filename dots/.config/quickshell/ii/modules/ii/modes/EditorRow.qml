import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * A plain settings row: icon, label, hint, and whatever control is put
 * inside it on the right.
 */
Rectangle {
    id: row
    property string icon
    property string label
    property string hint: ""
    default property alias control: controlSlot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(56, rowLayout.implicitHeight + 16)
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2

    RowLayout {
        id: rowLayout
        anchors {
            fill: parent
            leftMargin: 14
            rightMargin: 14
        }
        spacing: 12

        MaterialSymbol {
            text: row.icon
            iconSize: 22
            color: Appearance.colors.colOnLayer2
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: row.label
                color: Appearance.colors.colOnLayer2
            }

            StyledText {
                visible: row.hint.length > 0
                Layout.fillWidth: true
                text: row.hint
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        RowLayout {
            id: controlSlot
            spacing: 8
        }
    }
}
