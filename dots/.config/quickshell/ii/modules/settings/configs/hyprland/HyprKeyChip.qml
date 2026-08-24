import QtQuick
import qs.modules.common
import qs.modules.common.widgets

/// One key of a shortcut, drawn the way the cheatsheet draws it so the same shortcut looks the
/// same in both places. Monospaced, because a row of these is read as a group rather than as text.
Rectangle {
    id: root

    property string text: ""
    property bool subdued: false

    implicitWidth: Math.max(label.implicitWidth + 14, 26)
    implicitHeight: label.implicitHeight + 8
    radius: Appearance.rounding.small
    color: root.subdued ? Appearance.colors.colLayer2 : Appearance.colors.colSurfaceContainerLow

    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
        color: root.subdued ? Appearance.colors.colSubtext : Appearance.colors.colOnSurface
    }
}
