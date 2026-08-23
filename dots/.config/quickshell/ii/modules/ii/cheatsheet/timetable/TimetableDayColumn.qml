import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.modules.common.functions
import "."
import "TimetableHelpers.js" as H

Item {
    id: dayColumn

    property int dayIdx
    property var dayData
    property bool isToday
    property real dayColumnWidth
    property real contentHeight
    property real pixelsPerMinute
    property int startHour
    property int startMinute
    property int snapInterval
    property Item coordinateRoot: null
    property var draggedEvent: null
    
    // Ghost state
    property bool ghostVisible
    property int ghostDayIndex
    property real ghostTopY
    property real ghostHeight

    // Drag state (internal or external)
    property bool isDragging: false
    property int dragDayIndex: -1
    property real dragStartY: 0
    property real dragCurrentY: 0

    // For events
    property var nextEventData

    // Colors
    property color todayHighlightFill
    property color dayBackgroundFill
    property color dayBackgroundFillVariant

    signal dragRequestInteractivity(bool interactive)
    signal dragStarted(int dayIndex, real startY)
    signal dragPositionChanged(int dayIndex, real currentY)
    signal dragReleased(int dayIndex, real startY, real currentY)
    signal editRequested(var event, int dayIndex)
    signal deleteRequested(var event, int dayIndex)
    signal eventMoveStarted(var event, real x, real y, real pointerOffsetY)
    signal eventMoveMoved(real x, real y)
    signal eventMoveEnded
    signal eventMoveCanceled
    signal eventResizeStarted(var event, real x, real y)
    signal eventResizeMoved(real x, real y)
    signal eventResizeEnded
    signal eventResizeCanceled

    width: dayColumnWidth
    height: contentHeight
    clip: true

    readonly property int sunriseMinutes: H.parseTimeToMinutes(Weather.data?.sunrise ?? "") ?? -1
    readonly property int sunsetMinutes: H.parseTimeToMinutes(Weather.data?.sunset ?? "") ?? -1
    readonly property bool hasSolarTimes: dayColumn.sunriseMinutes > 0 && dayColumn.sunsetMinutes > dayColumn.sunriseMinutes
    readonly property int gridStartMinutes: dayColumn.startHour * 60 + dayColumn.startMinute
    readonly property string usageDateKey: H.dayKeyOf(dayColumn.dayData?.sportsDate)
    readonly property var usageHours: {
        AppStats.history;
        if (!AppStats.enabled || !dayColumn.usageDateKey || dayColumn.usageDateKey > H.dayKeyOf(DateTime.clock.date))
            return [];
        return AppStats.deviceHours(dayColumn.usageDateKey, "fg");
    }

    function usageIntensity(hour) {
        return Math.max(0, Math.min(1, Number(dayColumn.usageHours?.[hour] ?? 0) / 3600));
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.windowRounding
        color: isToday ? todayHighlightFill : dayIdx % 2 == 0 ? dayBackgroundFill : dayBackgroundFillVariant
    }

    Rectangle {
        id: preDawnShade
        visible: dayColumn.hasSolarTimes && height > 0
        x: 0
        y: 0
        width: parent.width
        height: Math.max(0, Math.min(parent.height, (dayColumn.sunriseMinutes - dayColumn.gridStartMinutes) * dayColumn.pixelsPerMinute))
        color: H.withOpacity(Appearance.colors.colLayer0, 0.22)
    }

    Rectangle {
        id: eveningShade
        readonly property real sunsetY: (dayColumn.sunsetMinutes - dayColumn.gridStartMinutes) * dayColumn.pixelsPerMinute
        visible: dayColumn.hasSolarTimes && height > 0
        x: 0
        y: Math.max(0, Math.min(parent.height, sunsetY))
        width: parent.width
        height: Math.max(0, parent.height - y)
        color: H.withOpacity(Appearance.colors.colLayer0, 0.22)
    }

    // Read-only desktop context: the sampler stores at most 3600 seconds of
    // device screen time per hour. A quiet semantic tint makes actual activity
    // comparable with planned blocks without competing with their colors.
    Repeater {
        model: 24

        delegate: Rectangle {
            required property int index
            readonly property real intensity: dayColumn.usageIntensity(index)
            readonly property real hourStartY: H.minutesToY(index * 60, dayColumn.startHour, dayColumn.startMinute, dayColumn.pixelsPerMinute)
            x: 0
            y: Math.max(0, hourStartY)
            width: dayColumn.width
            height: Math.max(0, Math.min(dayColumn.height, hourStartY + 60 * dayColumn.pixelsPerMinute) - y)
            visible: intensity > 0 && height > 0
            color: H.withOpacity(Appearance.colors.colTertiary, 0.04 + intensity * 0.14)
        }
    }

    // ─── Drag-to-create MouseArea ─────────────
    MouseArea {
        id: dayDragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: ghostVisible && ghostDayIndex === dayIdx ? Qt.ArrowCursor : Qt.CrossCursor
        z: 0

        onPressed: function (mouse) {
            if (ghostVisible) return;
            dragRequestInteractivity(false);
            isDragging = true;
            dragDayIndex = dayIdx;
            dragStartY = mouse.y;
            dragCurrentY = mouse.y;
            dragStarted(dayIdx, mouse.y);
        }

        onPositionChanged: function (mouse) {
            if (isDragging && dragDayIndex === dayIdx) {
                dragCurrentY = Math.max(0, Math.min(mouse.y, contentHeight));
                dragPositionChanged(dayIdx, dragCurrentY);
            }
        }

        onReleased: function (mouse) {
            dragRequestInteractivity(true);
            if (isDragging && dragDayIndex === dayIdx) {
                isDragging = false;
                dragReleased(dayIdx, dragStartY, dragCurrentY);
                dragDayIndex = -1;
            }
        }

        onCanceled: {
            dragRequestInteractivity(true);
            isDragging = false;
            dragDayIndex = -1;
        }
    }

    // ─── Drag preview (during drag) ───────────
    Rectangle {
        id: dragPreview
        visible: isDragging && dragDayIndex === dayIdx
        width: parent.width - 10
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Appearance.rounding.normal
        color: H.withOpacity(Appearance.colors.colPrimary, 0.25)
        z: 5

        y: {
            let topMin = H.snapToGrid(H.yToMinutes(Math.min(dragStartY, dragCurrentY), startHour, startMinute, pixelsPerMinute), snapInterval);
            return H.minutesToY(topMin, startHour, startMinute, pixelsPerMinute);
        }
        height: {
            let topMin = H.snapToGrid(H.yToMinutes(Math.min(dragStartY, dragCurrentY), startHour, startMinute, pixelsPerMinute), snapInterval);
            let botMin = H.snapToGrid(H.yToMinutes(Math.max(dragStartY, dragCurrentY), startHour, startMinute, pixelsPerMinute), snapInterval);
            if (botMin - topMin < snapInterval)
                botMin = topMin + snapInterval;
            return H.minutesToY(botMin, startHour, startMinute, pixelsPerMinute) - H.minutesToY(topMin, startHour, startMinute, pixelsPerMinute);
        }

        StyledText {
            anchors.centerIn: parent
            text: {
                let topMin = H.snapToGrid(H.yToMinutes(Math.min(dragStartY, dragCurrentY), startHour, startMinute, pixelsPerMinute), snapInterval);
                let botMin = H.snapToGrid(H.yToMinutes(Math.max(dragStartY, dragCurrentY), startHour, startMinute, pixelsPerMinute), snapInterval);
                if (botMin - topMin < snapInterval)
                    botMin = topMin + snapInterval;
                return H.minutesToTimeStr(topMin, Config.options?.time.format) + " — " + H.minutesToTimeStr(botMin, Config.options?.time.format);
            }
            font.weight: Font.Medium
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colPrimary
        }
    }

    // ─── Ghost block (post-drag, before confirm) ──
    Rectangle {
        id: ghostBlock
        visible: ghostVisible && ghostDayIndex === dayIdx
        width: parent.width - 10
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Appearance.rounding.normal
        color: Appearance.colors.colPrimary
        z: 8
        y: ghostTopY
        height: ghostHeight

        Column {
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 2

            StyledText {
                text: Translation.tr("New event")
                font.weight: Font.DemiBold
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnPrimary
                visible: parent.height > 40
            }

            StyledText {
                text: {
                    let topMin = H.snapToGrid(H.yToMinutes(ghostTopY, startHour, startMinute, pixelsPerMinute), snapInterval);
                    let botMin = H.snapToGrid(H.yToMinutes(ghostTopY + ghostHeight, startHour, startMinute, pixelsPerMinute), snapInterval);
                    return H.minutesToTimeStr(topMin, Config.options?.time.format) + " — " + H.minutesToTimeStr(botMin, Config.options?.time.format);
                }
                font.weight: Font.Medium
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnPrimary
            }
        }
    }

    // ─── Existing event blocks ────────────────
    Repeater {
        model: H.computeEventLayout(dayData.events, event => CalendarService.isAllDayEvent(event))
        delegate: EventBlock {
            eventData: modelData.event
            colIndex: modelData.colIndex
            totalCols: modelData.totalCols
            dayIdx: dayColumn.dayIdx
            nextEventData: dayColumn.nextEventData
            pixelsPerMinute: dayColumn.pixelsPerMinute
            startHour: dayColumn.startHour
            startMinute: dayColumn.startMinute
            coordinateRoot: dayColumn.coordinateRoot
            manipulating: dayColumn.draggedEvent === modelData.event
            onEditRequested: (evt, dIdx) => dayColumn.editRequested(evt, dIdx)
            onDeleteRequested: (evt, dIdx) => dayColumn.deleteRequested(evt, dIdx)
            onMoveDragStarted: (evt, x, y, offsetY) => dayColumn.eventMoveStarted(evt, x, y, offsetY)
            onMoveDragMoved: (x, y) => dayColumn.eventMoveMoved(x, y)
            onMoveDragEnded: dayColumn.eventMoveEnded()
            onMoveDragCanceled: dayColumn.eventMoveCanceled()
            onResizeDragStarted: (evt, x, y) => dayColumn.eventResizeStarted(evt, x, y)
            onResizeDragMoved: (x, y) => dayColumn.eventResizeMoved(x, y)
            onResizeDragEnded: dayColumn.eventResizeEnded()
            onResizeDragCanceled: dayColumn.eventResizeCanceled()
        }
    }
}
