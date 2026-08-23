import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

TextField {
    id: filterField

    property alias colBackground: background.color

    Layout.fillHeight: true
    implicitWidth: 200
    padding: 10

    placeholderTextColor: Appearance.colors.colSubtext
    color: Appearance.colors.colOnLayer1
    font {
        family: Appearance.font.family.main
        pixelSize: Appearance.font.pixelSize.small
        hintingPreference: Font.PreferFullHinting
        variableAxes: Appearance.font.variableAxes.main
    }
    renderType: Text.NativeRendering
    selectedTextColor: Appearance.colors.colOnSecondaryContainer
    selectionColor: Appearance.colors.colSecondaryContainer

    background: Rectangle {
        id: background
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.full
    }

    StyledTextContextMenu {
        id: contextMenu
        targetField: filterField
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                filterField.forceActiveFocus();
                contextMenu.popup(mouse.x, mouse.y);
            }
        }
    }
}
