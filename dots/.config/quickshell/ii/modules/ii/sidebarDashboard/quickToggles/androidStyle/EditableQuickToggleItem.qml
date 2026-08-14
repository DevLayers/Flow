import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Shared editing surface for every Android quick-toggle delegate. The visual
// widget stays owned by its base component; this item only handles gestures,
// draft mutations, and edit affordances.
Item {
    id: root

    required property var target
    required property var visualItem

    readonly property var controller: target && target.panel ? target.panel.editController : null
    readonly property bool editMode: target ? target.editMode : false
    readonly property bool isUnused: target ? target.isUnused : false
    readonly property bool isMedia: target && target.buttonData ? target.buttonData.type === "mediaWidget" : false
    readonly property bool isSlider: target && target.buttonData ? ["volumeSlider", "micSlider", "brightnessSlider", "gammaSlider"].includes(target.buttonData.type) : false
    readonly property bool canResize: target && target.pageIndex >= 0 && !root.isUnused
    readonly property bool canResizeHeight: root.canResize && !root.isSlider

    property real pressX: 0
    property real pressY: 0
    property real editDragX: 0
    property real editDragY: 0
    property bool editingRight: false
    property bool editingBottom: false
    property int resizeStartW: 1
    property int resizeStartH: 1
    property bool resizing: false

    property alias containsMouse: editInteraction.containsMouse

    anchors.fill: parent
    visible: root.editMode
    z: target && target.isDragging ? 100 : 10

    function beginResize() {
        if (!root.controller || !root.canResize)
            return false;
        if (!root.controller.beginResize(root.target.buttonData.id, root.target.pageIndex))
            return false;
        var size = root.target.catalogSize;
        root.resizeStartW = size[0];
        root.resizeStartH = size[1];
        root.resizing = true;
        return true;
    }

    function previewResize(deltaX, deltaY) {
        if (!root.resizing || !root.controller)
            return;

        var width = root.resizeStartW;
        var height = root.resizeStartH;
        if (root.isMedia) {
            var threshold = root.target.baseCellWidth / 2;
            width = deltaX > threshold ? 4 : (deltaX < -threshold ? 2 : root.resizeStartW);
            width = Math.max(2, Math.min(4, width));
            if (width === 4 && height === 1)
                height = 2;
        } else {
            var columns = root.target.baseCellWidth > 0 ? Math.round(deltaX / root.target.baseCellWidth) : 0;
            width = Math.max(1, Math.min(root.target.gridColumns, root.resizeStartW + columns));
            if (root.canResizeHeight) {
                var rows = root.target.baseCellHeight > 0 ? Math.round(deltaY / root.target.baseCellHeight) : 0;
                height = Math.max(1, Math.min(8, root.resizeStartH + rows));
            }
        }

        root.controller.previewResize(width, height);
    }

    function finishResize() {
        if (!root.resizing)
            return;
        root.resizing = false;
        if (root.controller)
            root.controller.commitResize();
        root.editDragX = 0;
        root.editDragY = 0;
        root.editingRight = false;
        root.editingBottom = false;
    }

    function cancelResize() {
        if (!root.resizing)
            return;
        root.resizing = false;
        if (root.controller)
            root.controller.cancelResize();
        root.editDragX = 0;
        root.editDragY = 0;
        root.editingRight = false;
        root.editingBottom = false;
    }

    MouseArea {
        id: editInteraction
        anchors.fill: parent
        visible: root.editMode
        cursorShape: root.target && root.target.isDragging ? Qt.ClosedHandCursor
                    : (root.isUnused ? Qt.PointingHandCursor : Qt.OpenHandCursor)
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onPressed: event => {
            if (!root.isUnused) {
                if (!root.controller || !root.controller.beginReorder(root.target.buttonData.id, root.target.pageIndex))
                    return;
            }
            root.pressX = event.x;
            root.pressY = event.y;
            root.target.dragOffsetX = 0;
            root.target.dragOffsetY = 0;
            root.target.isDragging = false;
        }

        onPositionChanged: event => {
            if (!pressed)
                return;
            var dx = event.x - root.pressX;
            var dy = event.y - root.pressY;
            if (!root.target.isDragging && (Math.abs(dx) > 4 || Math.abs(dy) > 4))
                root.target.isDragging = root.isUnused || (root.controller && root.controller.active);

            if (!root.target.isDragging)
                return;

            root.target.dragOffsetX = dx;
            root.target.dragOffsetY = dy;
            var centerX = dx + root.target.width / 2;
            var centerY = dy + root.target.height / 2;
            if (!root.isUnused && root.controller) {
                var gridPos = root.target.parent.mapFromItem(root.target, centerX, centerY);
                root.controller.previewReorderAt(
                    root.target.pageIndex,
                    gridPos.x,
                    gridPos.y,
                    root.target.baseCellWidth,
                    root.target.baseCellHeight,
                    root.target.cellSpacing
                );
            }
            if (root.target.panel && root.target.panel.handleDragScrollRequest) {
                var panelPos = root.target.panel.mapFromItem(root.target, centerX, centerY);
                root.target.panel.handleDragScrollRequest(panelPos.x, root.target);
            }
        }

        onReleased: event => {
            if (root.target.isDragging) {
                var targetPage = root.target.panel && root.target.panel.currentPage !== undefined
                        ? root.target.panel.currentPage : root.target.pageIndex;
                if (root.controller) {
                    if (targetPage !== root.target.pageIndex)
                        root.controller.moveToPage(targetPage);
                    root.controller.commitReorder();
                }
                if (root.target.panel && root.target.panel.cancelDragScroll)
                    root.target.panel.cancelDragScroll();
                root.target.isDragging = false;
                root.target.dragOffsetX = 0;
                root.target.dragOffsetY = 0;
                return;
            }

            if (root.controller && root.controller.active)
                root.controller.cancelReorder();
            if (root.editingRight || root.editingBottom)
                return;
            if (!root.controller)
                return;
            if (root.isUnused)
                root.controller.addToggle(root.target.buttonData.type, root.target.pageIndex);
            else
                root.controller.removeToggle(root.target.buttonData.id);
        }
    }

    Rectangle {
        id: editBorder
        anchors.fill: parent
        visible: root.editMode && !root.target.isDragging
        color: "transparent"
        border.width: 2
        radius: Appearance.rounding.large
        border.color: root.isUnused
                ? (root.target.hovered ? Appearance.colors.colPrimary : "transparent")
                : (root.target.hovered ? Appearance.colors.colPrimary
                                        : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7))
        Behavior on border.color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(editBorder)
        }
    }

    Rectangle {
        id: rightDragHandle
        width: 8
        height: 24
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: -width / 2
        visible: root.canResize

        MouseArea {
            anchors.fill: parent
            anchors.margins: -12
            cursorShape: Qt.SizeHorCursor
            preventStealing: true
            property real startX: 0

            onPressed: event => {
                if (!root.beginResize())
                    return;
                startX = event.x;
                root.editingRight = true;
            }
            onPositionChanged: event => {
                if (!root.resizing)
                    return;
                var deltaX = event.x - startX;
                root.editDragX = deltaX;
                root.previewResize(deltaX, 0);
            }
            onReleased: root.finishResize()
        }
    }

    Rectangle {
        id: bottomDragHandle
        width: 24
        height: 8
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -height / 2
        visible: root.canResizeHeight && (!root.isMedia || root.target.catalogSize[0] <= 2)

        MouseArea {
            anchors.fill: parent
            anchors.margins: -12
            cursorShape: Qt.SizeVerCursor
            preventStealing: true
            property real startY: 0

            onPressed: event => {
                if (!root.beginResize())
                    return;
                startY = event.y;
                root.editingBottom = true;
            }
            onPositionChanged: event => {
                if (!root.resizing)
                    return;
                var deltaY = event.y - startY;
                root.editDragY = deltaY;
                root.previewResize(0, deltaY);
            }
            onReleased: root.finishResize()
        }
    }

    Rectangle {
        id: addBadge
        width: 20
        height: 20
        radius: Appearance.rounding.full
        color: Appearance.m3colors.m3success
        anchors.top: parent.top
        anchors.topMargin: -6
        anchors.right: parent.right
        anchors.rightMargin: -6
        visible: root.isUnused
        z: 10

        MaterialSymbol {
            anchors.centerIn: parent
            text: "add"
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.m3colors.m3onSuccess
        }
    }

    StyledToolTip {
        parent: root.target
        extraVisibleCondition: root.target.tooltipText !== ""
                && (root.target.hovered || root.containsMouse)
        text: root.target.tooltipText
    }
}
