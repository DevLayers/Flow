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

Rectangle {
    id: eventBlock

    property var eventData
    property int colIndex: 0
    property int totalCols: 1
    property int dayIdx
    property var nextEventData
    property real pixelsPerMinute
    property int startHour
    property int startMinute
    property Item coordinateRoot: null
    property bool manipulating: false

    signal editRequested(var event, int dayIndex)
    signal deleteRequested(var event, int dayIndex)
    signal moveDragStarted(var event, real x, real y, real pointerOffsetY)
    signal moveDragMoved(real x, real y)
    signal moveDragEnded
    signal moveDragCanceled
    signal resizeDragStarted(var event, real x, real y)
    signal resizeDragMoved(real x, real y)
    signal resizeDragEnded
    signal resizeDragCanceled

    readonly property bool isNextEvent: nextEventData && nextEventData.dayIndex === dayIdx && nextEventData.startMinutes === eventStartMinutes
    readonly property bool sportEvent: eventData?.sportEvent === true
    readonly property bool readOnly: eventData?.readOnly === true
    readonly property string meetingUrl: {
        const url = String(eventData?.url ?? "").trim();
        if (url.length === 0)
            return "";
        return String(EmailDetections.detectAll(url).meetings[0]?.url ?? "");
    }
    readonly property color semanticColor: eventBlock.sportEvent
        ? Appearance.colors.colTertiaryContainer
        : H.chipColor(eventData, Appearance.colors)

    readonly property int eventStartMinutes: H.eventStartMinutes(eventData) ?? 0
    readonly property int eventEndMinutes: H.eventEndMinutes(eventData) ?? eventStartMinutes

    // Overlap layout
    width: (parent.width - 10) / totalCols - 2
    x: colIndex * ((parent.width - 10) / totalCols) + 5
    
    radius: Appearance.rounding.normal
    clip: true
    z: isNextEvent ? 4 : 3
    color: isNextEvent
        ? ColorUtils.mix(eventBlock.semanticColor, ColorUtils.getContrastingTextColor(eventBlock.semanticColor), 0.88)
        : eventBlock.semanticColor
    y: H.minutesToY(eventStartMinutes, startHour, startMinute, pixelsPerMinute)
    height: Math.max((eventEndMinutes - eventStartMinutes) * pixelsPerMinute - 4, 48)
    opacity: eventBlock.manipulating ? 0.24 : 1

    // Decorative watermark icon for the next event
    MaterialSymbol {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: -10
        text: eventBlock.sportEvent ? "sports_score" : "event_upcoming"
        font.pixelSize: Math.min(parent.height, parent.width) * 0.8
        color: ColorUtils.getContrastingTextColor(eventBlock.color)
        opacity: 0.15
        visible: isNextEvent || eventBlock.sportEvent
        z: 0
        antialiasing: true
    }

    HoverHandler {
        id: eventHover
    }

    StyledToolTip {
        extraVisibleCondition: eventHover.hovered
        text: {
            let title = eventData.content || qsTr("Event");
            let description = eventData.description || "";
            let startStr = H.minutesToTimeStr(eventStartMinutes, Config.options?.time.format);
            let endStr = H.minutesToTimeStr(eventEndMinutes, Config.options?.time.format);
            let range = startStr && endStr ? startStr + " - " + endStr : startStr || endStr;
            return range ? description ? "•  " + title + "\n•  " + range + "\n•  " + description : "•  " + title + "\n•  " + range : "•  " + title;
        }
    }

    // Click to edit, drag the body to move. The proxy itself belongs to the
    // WeekView so it can stay above columns and outlive a clipped delegate.
    MouseArea {
        id: eventPointer
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: eventPointer.started ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        z: 2

        readonly property int dragThreshold: 6
        property real pressX: 0
        property real pressY: 0
        property bool started: false

        function scenePoint(mouse) {
            if (!eventBlock.coordinateRoot)
                return Qt.point(mouse.x, mouse.y);
            return eventBlock.mapToItem(eventBlock.coordinateRoot, mouse.x, mouse.y);
        }

        onPressed: mouse => {
            eventPointer.pressX = mouse.x;
            eventPointer.pressY = mouse.y;
            eventPointer.started = false;
        }

        onPositionChanged: mouse => {
            if (eventBlock.readOnly || !eventPointer.pressedButtons)
                return;
            const point = eventPointer.scenePoint(mouse);
            if (!eventPointer.started) {
                if (Math.abs(mouse.x - eventPointer.pressX) + Math.abs(mouse.y - eventPointer.pressY) < eventPointer.dragThreshold)
                    return;
                eventPointer.started = true;
                eventBlock.moveDragStarted(eventBlock.eventData, point.x, point.y, eventPointer.pressY);
            }
            eventBlock.moveDragMoved(point.x, point.y);
        }

        onReleased: {
            if (eventPointer.started) {
                eventPointer.started = false;
                eventBlock.moveDragEnded();
                return;
            }
            eventBlock.editRequested(eventData, dayIdx);
        }

        onCanceled: {
            if (!eventPointer.started)
                return;
            eventPointer.started = false;
            eventBlock.moveDragCanceled();
        }
    }

    MouseArea {
        id: resizeHandle
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 20, 44)
        height: 14
        hoverEnabled: true
        preventStealing: true
        visible: !eventBlock.readOnly
        cursorShape: Qt.SizeVerCursor
        z: 12

        readonly property int dragThreshold: 4
        property real pressY: 0
        property bool started: false

        function scenePoint(mouse) {
            if (!eventBlock.coordinateRoot)
                return Qt.point(mouse.x, mouse.y);
            return resizeHandle.mapToItem(eventBlock.coordinateRoot, mouse.x, mouse.y);
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, 26)
            height: 3
            radius: Appearance.rounding.full
            color: ColorUtils.getContrastingTextColor(eventBlock.color)
            opacity: resizeHandle.hovered || resizeHandle.pressed ? 0.9 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        onPressed: mouse => {
            resizeHandle.pressY = mouse.y;
            resizeHandle.started = false;
        }

        onPositionChanged: mouse => {
            if (!resizeHandle.pressedButtons)
                return;
            const point = resizeHandle.scenePoint(mouse);
            if (!resizeHandle.started) {
                if (Math.abs(mouse.y - resizeHandle.pressY) < resizeHandle.dragThreshold)
                    return;
                resizeHandle.started = true;
                eventBlock.resizeDragStarted(eventBlock.eventData, point.x, point.y);
            }
            eventBlock.resizeDragMoved(point.x, point.y);
        }

        onReleased: {
            if (!resizeHandle.started)
                return;
            resizeHandle.started = false;
            eventBlock.resizeDragEnded();
        }

        onCanceled: {
            if (!resizeHandle.started)
                return;
            resizeHandle.started = false;
            eventBlock.resizeDragCanceled();
        }
    }

    // Delete button
    RippleButton {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        implicitWidth: 24
        implicitHeight: 24
        buttonRadius: Appearance.rounding.full
        buttonColor: H.withOpacity(Appearance.colors.colOnSurface, 0.15)
        opacity: eventHover.hovered ? 1 : 0
        visible: opacity > 0 && !eventBlock.readOnly
        z: 15

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onClicked: {
            if (eventData?.uid)
                eventBlock.deleteRequested(eventData, eventBlock.dayIdx);
        }

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smallie
            text: "close"
            color: ColorUtils.getContrastingTextColor(eventBlock.color)
        }
    }

    // Frequent meeting action: keep it directly on blocks tall enough to
    // accommodate a secondary affordance without covering their title.
    RippleButton {
        id: joinButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        implicitWidth: 28
        implicitHeight: 28
        buttonRadius: Appearance.rounding.full
        buttonColor: H.withOpacity(Appearance.colors.colOnSurface, 0.15)
        visible: eventBlock.height > 60 && eventBlock.meetingUrl.length > 0 && !eventBlock.manipulating
        z: 15

        onClicked: Qt.openUrlExternally(eventBlock.meetingUrl)

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.small
            text: "videocam"
            color: ColorUtils.getContrastingTextColor(eventBlock.color)
        }

        StyledToolTip {
            extraVisibleCondition: joinButton.hovered
            text: Translation.tr("Join meeting")
        }
    }

    // Event content
    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4
        z: 1

        StyledText {
            text: eventData.content ?? Translation.tr("Event")
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: parent.width - 28
            color: ColorUtils.getContrastingTextColor(eventBlock.color)
        }

        StyledText {
            width: parent.width
            visible: eventBlock.sportEvent && eventBlock.height > 82
            text: [eventData.status, eventData.lastPlay].filter(value => String(value ?? "").length > 0).join(" · ")
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Medium
            color: ColorUtils.getContrastingTextColor(eventBlock.color)
            elide: Text.ElideRight
        }

        Row {
            spacing: 6
            width: parent.width
            visible: eventBlock.height > 60 || eventBlock.isNextEvent

            Rectangle {
                visible: eventBlock.isNextEvent
                width: nextText.implicitWidth + 8
                height: nextText.implicitHeight + 2
                color: ColorUtils.getContrastingTextColor(eventBlock.color)
                radius: Appearance.rounding.full
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: nextText
                    anchors.centerIn: parent
                    text: "NEXT"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    color: eventBlock.color
                }
            }

            StyledText {
                text: H.minutesToTimeStr(eventBlock.eventStartMinutes, Config.options?.time.format) + " - " + H.minutesToTimeStr(eventBlock.eventEndMinutes, Config.options?.time.format)
                font.weight: Font.Medium
                color: ColorUtils.getContrastingTextColor(eventBlock.color)
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                visible: eventBlock.height > 60 || eventBlock.isNextEvent
            }
        }
    }
}
