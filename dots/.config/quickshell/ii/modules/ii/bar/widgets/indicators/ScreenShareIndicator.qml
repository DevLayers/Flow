import qs.modules.ii.bar.shared
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell.Io
import "../../shared/cards"

MouseArea {
    id: indicator

    readonly property bool activelyCasting: NetworkDisplayService.activeStreamUnit !== ""
    property bool activelyPortalSharing: false
    property bool activelyScreenSharing: activelyPortalSharing || activelyCasting

    visible: activelyScreenSharing
    implicitWidth: activelyScreenSharing ? (vertical ? Appearance.sizes.verticalBarWidth : 40) : 0
    implicitHeight: activelyScreenSharing ? (vertical ? 40 : Appearance.sizes.baseBarHeight) : 0
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: GlobalStates.toggleDisplayCast()

    Process {
        id: screenShareProc
        running: true
        command: ["bash", "-c", Directories.screenshareStateScript]
    }
    
    FileView {
        id: stateFile
        path: Directories.screenshareStatePath
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            let txt = stateFile.text().trim();
            indicator.activelyPortalSharing = txt.length > 0 && txt.toLowerCase() !== "none" && !txt.toLowerCase().includes("none");
            rootItem.toggleVisible(indicator.activelyScreenSharing);
        }
    }

    MaterialShape {
        id: indicatorShape
        implicitSize: 32
        shapeString: "Cookie9Sided"
        color: indicator.containsMouse
            ? Appearance.colors.colPrimaryContainerHover
            : Appearance.colors.colPrimaryContainer
        anchors.centerIn: parent

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: indicator.activelyCasting ? "cast_connected" : "cast"
            iconSize: 20
            color: Appearance.colors.colOnPrimaryContainer
        }
    }

    StyledPopup {
        hoverTarget: indicator
        animate: false
        contentItem: HeroCard {
            compactMode: true
            anchors.centerIn: parent
            icon: indicator.activelyCasting ? "cast_connected" : "screen_share"

            title: indicator.activelyCasting ? (NetworkDisplayService.activeSinkName || Translation.tr("Wireless Display")) : stateFile.text().trim()
            subtitle: indicator.activelyCasting ? Translation.tr("Screen cast active — click to manage") : Translation.tr("is using your screen")

            pillText: indicator.activelyCasting ? Translation.tr("Casting") : Translation.tr("Sharing..")
            pillIcon: indicator.activelyCasting ? "cast_connected" : "screen_share"
        }
    }
}