pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    title: "Discord Voice"
    showCenterButton: true
    titleIconComponent: Component {
        DiscordGlyph {
            implicitSize: 20
            iconSize: 12
        }
    }
    minimumWidth: overlayContent.implicitWidth
    minimumHeight: overlayContent.implicitHeight

    contentItem: Widget {
        id: overlayContent
        anchors.fill: parent
        namesOnLeft: root.parent
            ? root.x + root.width / 2 >= root.parent.width / 2
            : false
    }
}
