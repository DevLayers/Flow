import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property real padding: 5
    property real leftPadding: padding
    property real rightPadding: padding
    property real topPadding: padding
    property real bottomPadding: padding

    readonly property bool hasVisibleChild: {
        if (!gridLayout.children) return false;
        for (let i = 0; i < gridLayout.children.length; i++) {
            let child = gridLayout.children[i];
            if (!child) continue;
            let isVis = child.hasOwnProperty("item") ? (child.item && child.item.visible && child.visible) : child.visible;
            if (isVis) return true;
        }
        return false;
    }

    implicitWidth: vertical 
        ? (hasVisibleChild ? Appearance.sizes.baseVerticalBarWidth : 0)
        : (hasVisibleChild && gridLayout.implicitWidth > 0 ? (gridLayout.implicitWidth + leftPadding + rightPadding) : 0)
    implicitHeight: vertical 
        ? (hasVisibleChild && gridLayout.implicitHeight > 0 ? (gridLayout.implicitHeight + topPadding + bottomPadding) : 0) 
        : (hasVisibleChild ? Appearance.sizes.baseBarHeight : 0)
    default property alias items: gridLayout.children
    property var startRadius // left - top
    property var endRadius // right - bottom

    property color colBackground: Appearance.m3colors.m3surfaceContainerLow

    Rectangle {
        id: background
        visible: hasVisibleChild && (root.vertical ? (gridLayout.implicitHeight > 0) : (gridLayout.implicitWidth > 0))
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        color: root.colBackground
        topLeftRadius: startRadius
        bottomLeftRadius: root.vertical ? endRadius: startRadius
        topRightRadius: root.vertical ? startRadius: endRadius
        bottomRightRadius: endRadius

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: root.vertical ? undefined : parent.left
            right: root.vertical ? undefined : parent.right
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            topMargin: root.topPadding
            bottomMargin: root.bottomPadding
            leftMargin: root.leftPadding
            rightMargin: root.rightPadding
        }
        columnSpacing: 4
        rowSpacing: 12
    }
}