import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.widgets

PopupWindow {
    id: rootToolTipPopup

    property Item parentItem: parent
    property string text: ""
    property bool showTooltip: false
    property int tooltipOffset: -12
    
    property string dockPosition: {
        const pos = Config.options?.dock?.position ?? "bottom"
        if (pos !== "auto") return pos
        return (Config.options?.bar?.bottom && !Config.options?.bar?.vertical) ? "top" : "bottom"
    }

    anchor.window: parentItem?.QsWindow?.window
    implicitWidth: tooltipRect.implicitWidth
    implicitHeight: tooltipRect.implicitHeight

    anchor.rect.x: {
        if (!parentItem) return 0
        let mScale = parentItem.dockContent ? parentItem.dockContent._getSlotMagScale(parentItem) : 1.0
        let _ = parentItem.x + parentItem.y + parentItem.width + parentItem.scale + rootToolTipPopup.width + mScale
        
        if (dockPosition === "left") {
            const mappedRight = parentItem.mapToItem(null, parentItem.width, 0)
            return mappedRight.x + 8
        } else if (dockPosition === "right") {
            const mappedLeft = parentItem.mapToItem(null, 0, 0)
            return mappedLeft.x - rootToolTipPopup.width - 8
        } else {
            const mappedCenter = parentItem.mapToItem(null, parentItem.width / 2, 0)
            return mappedCenter.x - rootToolTipPopup.width / 2
        }
    }
    
    anchor.rect.y: {
        if (!parentItem) return 0
        let mScale = parentItem.dockContent ? parentItem.dockContent._getSlotMagScale(parentItem) : 1.0
        let _ = parentItem.x + parentItem.y + parentItem.height + parentItem.scale + rootToolTipPopup.height + mScale
        
        if (dockPosition === "top") {
            const mappedBottom = parentItem.mapToItem(null, 0, parentItem.height)
            return mappedBottom.y + 8
        } else if (dockPosition === "bottom") {
            const mappedTop = parentItem.mapToItem(null, 0, 0)
            return mappedTop.y - rootToolTipPopup.height - 8
        } else {
            const mappedCenter = parentItem.mapToItem(null, 0, parentItem.height / 2)
            return mappedCenter.y - rootToolTipPopup.height / 2
        }
    }

    visible: showTooltip || tooltipRect.opacity > 0.01
    color: "transparent"

    Rectangle {
        id: tooltipRect
        implicitWidth: tooltipText.implicitWidth + 24
        implicitHeight: tooltipText.implicitHeight + 12
        opacity: rootToolTipPopup.showTooltip ? 1.0 : 0.0
        scale: rootToolTipPopup.showTooltip ? 1.0 : 0.8
        transformOrigin: {
            if (rootToolTipPopup.dockPosition === "top") return Item.Top
            if (rootToolTipPopup.dockPosition === "bottom") return Item.Bottom
            if (rootToolTipPopup.dockPosition === "left") return Item.Left
            if (rootToolTipPopup.dockPosition === "right") return Item.Right
            return Item.Bottom
        }

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(tooltipRect)
        }
        Behavior on scale {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(tooltipRect)
        }

        color: Config.options.appearance.transparency.popups ? Appearance.colors.colLayer0 : Appearance.m3colors.m3surfaceContainer
        radius: Appearance.rounding.small
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        StyledText {
            id: tooltipText
            anchors.centerIn: parent
            text: rootToolTipPopup.text
            color: Appearance.colors.colOnSurface
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }
}
