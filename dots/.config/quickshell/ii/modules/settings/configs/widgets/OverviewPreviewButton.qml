pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

RippleButtonWithIcon {
    id: root

    property string tooltipText: ""

    mainText: ""
    materialIcon: "play_arrow"
    centerContent: true
    buttonRadius: Appearance.rounding.windowRounding
    colBackground: Appearance.colors.colSecondaryContainer
    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    colRipple: Appearance.colors.colSecondaryContainerActive
    colText: Appearance.colors.colOnSecondaryContainer
    iconPixelSize: Appearance.font.pixelSize.larger
    implicitWidth: implicitHeight
    implicitHeight: Appearance.rounding.verylarge

    onClicked: {
        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "search", "open"]);
    }

    StyledToolTip {
        extraVisibleCondition: root.tooltipText !== ""
        text: root.tooltipText
    }
}
