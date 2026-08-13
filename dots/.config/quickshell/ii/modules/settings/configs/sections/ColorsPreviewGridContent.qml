import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    implicitHeight: contentLayout.implicitHeight
    Layout.fillWidth: true

    StyledFlickable {
        id: flickable

        anchors.fill: parent
        contentHeight: contentLayout.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout {
            id: contentLayout

            width: flickable.width

            Repeater {
                model: [
                    { customTheme: false, builtInTheme: false },
                    { customTheme: false, builtInTheme: true },
                    { customTheme: true, builtInTheme: false }
                ]

                delegate: ColorPreviewGrid {
                    required property var modelData

                    customTheme: modelData.customTheme
                    builtInTheme: modelData.builtInTheme
                }
            }
        }
    }
}
