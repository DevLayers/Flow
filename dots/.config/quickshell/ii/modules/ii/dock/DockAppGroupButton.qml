pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

import "./widgets"

DockButton {
    id: root

    property var apps: []
    property var dockContent: null
    property int delegateIndex: -1
    property string groupId: ""
    property bool groupHovered: false

    readonly property real dotMargin: Math.round((Config.options?.dock.height ?? 60) * 0.2) - 2
    readonly property real dotMarginV: Math.round((Config.options?.dock.height ?? 60) * 0.12) - 2
    readonly property real magScale: root.dockContent
        ? root.dockContent._getSlotMagScale(root)
        : 1.0
    readonly property string dockPos: root.dockContent?.dockPos ?? "bottom"
    readonly property real cellSize: root.buttonSize * 0.36
    readonly property real gridGap: Math.max(2, Math.round(root.buttonSize * 0.04))

    width: root.buttonSize + root.dotMargin * 2
    height: root.buttonSize + root.dotMarginV * 2
    transformOrigin: {
        if (root.dockPos === "top")
            return Item.Top
        if (root.dockPos === "left")
            return Item.Left
        if (root.dockPos === "right")
            return Item.Right
        return Item.Bottom
    }
    scale: root.magScale
    z: root.magScale > 1.01 ? Math.round(root.magScale * 100) : 1

    Behavior on scale {
        animation: Appearance.animation.dockMagnification.numberAnimation.createObject(this)
    }

    Rectangle {
        id: groupSurface
        width: root.buttonSize * 0.92
        height: root.buttonSize * 0.92
        anchors.centerIn: parent
        radius: Appearance.rounding.small
        color: root.groupHovered
            ? Appearance.colors.colLayer2Base
            : Appearance.colors.colLayer1Base

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        Grid {
            anchors.centerIn: parent
            columns: 2
            rows: 2
            spacing: root.gridGap

            Repeater {
                model: Math.min(root.apps.length, 4)
                delegate: Item {
                    required property int index
                    readonly property var appData: root.apps[index] ?? null
                    width: root.cellSize
                    height: root.cellSize

                    DockIcon {
                        anchors.fill: parent
                        appId: appData?.appId ?? ""
                        desktopEntry: TaskbarApps.getCachedDesktopEntry(appData?.appId ?? "")
                        isRunning: (appData?.toplevels?.length ?? 0) > 0
                    }
                }
            }
        }

        Rectangle {
            visible: root.apps.length > 4
            width: Math.max(root.buttonSize * 0.25, Appearance.font.pixelSize.small)
            height: width
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -width * 0.18
            anchors.bottomMargin: -height * 0.18
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary

            StyledText {
                anchors.centerIn: parent
                text: "+" + String(root.apps.length - 4)
                color: Appearance.colors.colOnPrimary
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
            }
        }
    }

    MouseArea {
        id: interactionArea
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        property real pressCoord: 0
        property int pressButton: Qt.NoButton
        property bool dragActive: false

        onEntered: {
            root.groupHovered = true
            if (root.dockContent?.suppressHover)
                return
            root.dockContent?.onButtonEntered(root)
        }
        onExited: {
            root.groupHovered = false
            root.dockContent?.onButtonExited(root)
        }
        onPressed: event => {
            pressButton = event.button
            pressCoord = root.dockContent?.isVertical ? event.y : event.x
        }
        onPositionChanged: event => {
            if (!pressed || pressButton !== Qt.LeftButton)
                return
            const currentCoord = root.dockContent?.isVertical ? event.y : event.x
            const distance = Math.abs(currentCoord - pressCoord)
            if (!dragActive && distance > 5 && root.delegateIndex >= 0) {
                dragActive = true
                root.groupHovered = false
                root.dockContent?.startItemDrag(root.delegateIndex, interactionArea, event.x, event.y)
            }
            if (dragActive)
                root.dockContent?.moveItemDrag(interactionArea, event.x, event.y)
        }
        onReleased: event => {
            if (event.button === Qt.RightButton) {
                dragActive = false
                pressButton = Qt.NoButton
                // A right-click inside the separate group popup can finish
                // after that popup starts closing. Do not let that release
                // fall through and remove the whole group underneath it.
                if (groupPopup.active)
                    return
                groupPopup.close()
                root.dockContent?.removeAppGroup(root.groupId)
                return
            }
            if (dragActive) {
                dragActive = false
                pressButton = Qt.NoButton
                root.dockContent?.endItemDrag()
                return
            }
            pressButton = Qt.NoButton
            root.openGroup()
        }
        onCanceled: {
            pressButton = Qt.NoButton
            if (dragActive) {
                dragActive = false
                root.dockContent?.cancelDrag()
            }
        }
    }

    function openGroup() {
        groupPopup.open()
    }

    DockGroupPopup {
        id: groupPopup
        anchorItem: root
        apps: root.apps
        groupId: root.groupId
        dockContent: root.dockContent
    }

    DockTooltip {
        parentItem: root
        text: Translation.tr("Right click to dissolve group\nRight click an app to remove it from the group")
        showTooltip: root.groupHovered
        tooltipOffset: -root.dotMargin
    }

    Connections {
        target: groupPopup
        function onActiveChanged() {
            if (!root.dockContent)
                return
            if (groupPopup.active)
                root.dockContent.registerContextMenuOpen()
            else
                root.dockContent.registerContextMenuClose()
        }
    }

    Component.onDestruction: {
        if (root.dockContent && groupPopup.active)
            root.dockContent.registerContextMenuClose()
    }
}
