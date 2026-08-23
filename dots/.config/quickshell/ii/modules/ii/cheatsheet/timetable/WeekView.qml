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
    id: root
    property real spacing: 8

    readonly property bool eventPopupVisible: eventPopup.visible || eventSidebar.open

    property int startHour: 0
    property int startMinute: 0
    property int endHour: 24
    property int slotDuration: 60 // in minutes
    property int slotHeight: 120 // in pixels
    property int timeColumnWidth: 100
    property real maxContentWidth: 1600

    readonly property int totalSlots: Math.floor(((endHour * 60) - (startHour * 60 + startMinute)) / slotDuration)
    readonly property real pixelsPerMinute: slotHeight / slotDuration
    readonly property int contentHeight: totalSlots * slotHeight

    property real maxHeight: 700
    property real headerHeight: 64 + (hasAllDayEvents ? maxAllDayEventCount * (allDayChipHeight + allDayChipSpacing) + 8 : 0)
    property real currentTimeY: -1
    property bool initialScrollApplied: false
    property string requestedSportsRange: ""
    readonly property real eventRailWidth: Math.max(300, Math.min(390, root.width * 0.29))
    readonly property real usableWidth: root.width - (eventSidebar.open ? root.eventRailWidth + 14 : 0)
    readonly property real dayColumnWidth: {
        let availableWidth = root.usableWidth > 0 ? root.usableWidth : maxContentWidth;
        return Math.max(80, (availableWidth - timeColumnWidth - days.length * spacing) / Math.max(1, days.length));
    }
    readonly property int currentDayIndex: Config.options.cheatsheet.timetableTodayFirst ? 0 : ((DateTime.clock.date.getDay() - Config.options.time.firstDayOfWeek + 6) % 7)

    implicitWidth: maxContentWidth
    implicitHeight: Math.min(headerHeight + contentHeight, maxHeight)
    readonly property var calendarDays: CalendarService.eventsInWeek
    readonly property var days: {
        // Keep this explicit dependency: gamesForDate() reads a plain JS array,
        // while the array replacement is what makes this projection reactive.
        const sportsGames = SportsService.timetableGames;
        const result = [];
        for (let i = 0; i < 7; i++) {
            const date = H.getDateForDayIndex(i, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst);
            const calendarDay = root.calendarDays?.[i] ?? ({});
            result.push({
                name: String(calendarDay.name || Qt.formatDate(date, "dddd")),
                events: (calendarDay.events ?? []).concat(SportsService.gamesForDate(date))
            });
        }
        return result;
    }
    readonly property int allDayChipHeight: 36
    readonly property int allDayChipSpacing: 6
    readonly property int maxAllDayEventCount: {
        if (!root.days || root.days.length === 0)
            return 0;
        let maxCount = 0;
        for (let i = 0; i < root.days.length; i++) {
            let count = H.getAllDayEvents(root.days[i]?.events).length;
            if (count > maxCount)
                maxCount = count;
        }
        return maxCount;
    }
    readonly property bool hasAllDayEvents: maxAllDayEventCount > 0

    // ─── Theme Colors ───
    readonly property color todayHighlightFill: H.withOpacity(Appearance.colors.colPrimary, 0.12)
    readonly property color todayHighlightBorder: H.withOpacity(Appearance.colors.colPrimary, 0.28)
    readonly property color dayBackgroundFill: H.withOpacity(Appearance.colors.colSecondary, 0.04)
    readonly property color dayBackgroundFillVariant: H.withOpacity(Appearance.colors.colSecondary, 0.08)

    // ─── State ───
    property var nextEventData: null
    property real maxLogicalDistance: 1.0

    property bool ghostVisible: false
    property int ghostDayIndex: -1
    property real ghostTopY: 0
    property real ghostHeight: 0

    // ─── Helpers ───
    function updateCurrentTimeLine() {
        let time = DateTime.clock.date;
        let currentTotalMinutes = time.getHours() * 60 + time.getMinutes();
        let baseTotalMinutes = root.startHour * 60 + root.startMinute;
        currentTimeY = (currentTotalMinutes - baseTotalMinutes) * root.pixelsPerMinute;
    }

    function updateNextEvent() {
        if (!root.days || root.days.length === 0) {
            root.nextEventData = null;
            root.maxLogicalDistance = 1.0;
            return;
        }

        let now = DateTime.clock.date;
        let currentDayIdx = root.currentDayIndex;
        let nowTotalMins = currentDayIdx * 24 * 60 + (now.getHours() * 60 + now.getMinutes());

        let bestDiff = Infinity;
        let nextEvt = null;

        for (let i = 0; i < root.days.length; i++) {
            let events = H.getTimedEvents(root.days[i]?.events);
            for (let evt of events) {
                let startMins = H.parseTimeToMinutes(evt.start);
                let endMins = H.parseTimeToMinutes(evt.end);
                if (startMins === null)
                    continue;
                if (endMins === null || (endMins === 0 && startMins > 0))
                    endMins = 24 * 60;

                let evtStartTotal = i * 24 * 60 + startMins;
                let evtEndTotal = i * 24 * 60 + endMins;

                if (evtEndTotal > nowTotalMins) {
                    let diff = Math.max(0, evtStartTotal - nowTotalMins);
                    if (diff < bestDiff) {
                        bestDiff = diff;
                        nextEvt = {
                            dayIndex: i,
                            startMinutes: startMins,
                            endMinutes: endMins
                        };
                    }
                }
            }
        }

        if (!nextEvt) {
            let earliestTotal = Infinity;
            for (let i = 0; i < root.days.length; i++) {
                for (let evt of H.getTimedEvents(root.days[i]?.events)) {
                    let startMins = H.parseTimeToMinutes(evt.start);
                    if (startMins === null)
                        continue;
                    let evtStartTotal = i * 24 * 60 + startMins;
                    if (evtStartTotal < earliestTotal) {
                        earliestTotal = evtStartTotal;
                        nextEvt = {
                            dayIndex: i,
                            startMinutes: startMins,
                            endMinutes: H.parseTimeToMinutes(evt.end)
                        };
                    }
                }
            }
        }

        root.nextEventData = nextEvt;

        let maxDist = 0;
        if (nextEvt) {
            for (let i = 0; i < root.days.length; i++) {
                for (let evt of H.getTimedEvents(root.days[i]?.events)) {
                    let startMins = H.parseTimeToMinutes(evt.start);
                    if (startMins === null)
                        continue;
                    let dist = Math.sqrt(Math.pow(i - nextEvt.dayIndex, 2) + Math.pow((startMins - nextEvt.startMinutes) / 60.0, 2));
                    if (dist > maxDist)
                        maxDist = dist;
                }
            }
        }
        root.maxLogicalDistance = Math.max(1.0, maxDist);
    }

    function scrollToCurrentTime() {
        if (!styledFlickable || styledFlickable.height <= 0) {
            Qt.callLater(root.scrollToCurrentTime);
            return;
        }
        let now = DateTime.clock.date;
        let diff = Math.max(0, (now.getHours() * 60 + now.getMinutes()) - (root.startHour * 60 + root.startMinute));
        let targetY = diff * root.pixelsPerMinute - (styledFlickable.height / 3);
        styledFlickable.contentY = Math.min(Math.max(0, targetY), Math.max(0, styledFlickable.contentHeight - styledFlickable.height));
    }

    function maybeApplyInitialScroll() {
        if (root.initialScrollApplied || !styledFlickable || styledFlickable.height <= 0 || !root.days || root.days.length === 0) {
            Qt.callLater(root.maybeApplyInitialScroll);
            return;
        }
        root.scrollToCurrentTime();
        root.initialScrollApplied = true;
    }

    // ─── Actions ───
    function openPopupForGhost() {
        let topMin = H.snapToGrid(H.yToMinutes(root.ghostTopY, root.startHour, root.startMinute, root.pixelsPerMinute), 15);
        let botMin = H.snapToGrid(H.yToMinutes(root.ghostTopY + root.ghostHeight, root.startHour, root.startMinute, root.pixelsPerMinute), 15);
        let eventDate = H.getDateForDayIndex(root.ghostDayIndex, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst);
        let colX = root.timeColumnWidth + (root.ghostDayIndex * (root.dayColumnWidth + root.spacing)) + root.dayColumnWidth;
        let colY = root.ghostTopY + root.headerHeight - styledFlickable.contentY + 20;
        eventPopup.open(H.minutesToTimeStr(topMin, Config.options?.time.format), H.minutesToTimeStr(botMin, Config.options?.time.format), eventDate, root.ghostDayIndex, colX, colY);
    }

    function openPopupForEdit(event, dayIndex) {
        if (event?.sportEvent === true) {
            eventSidebar.showEvent(event);
            return;
        }
        let startMin = H.parseTimeToMinutes(event.start);
        let endMin = H.parseTimeToMinutes(event.end);
        let eventDate = H.getDateForDayIndex(dayIndex, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst);
        let colX = root.timeColumnWidth + (dayIndex * (root.dayColumnWidth + root.spacing)) + root.dayColumnWidth;
        let colY = H.minutesToY(startMin, root.startHour, root.startMinute, root.pixelsPerMinute) + root.headerHeight - styledFlickable.contentY + 20;
        eventPopup.openForEdit(H.minutesToTimeStr(startMin, Config.options?.time.format), H.minutesToTimeStr(endMin, Config.options?.time.format), eventDate, dayIndex, colX, colY, event);
    }

    Connections {
        target: DateTime.clock
        function onDateChanged() {
            root.updateCurrentTimeLine();
            root.updateNextEvent();
            root.requestSportsRange();
        }
    }
    Connections {
        target: CalendarService
        function onEventsInWeekChanged() {
            root.updateNextEvent();
            Qt.callLater(root.maybeApplyInitialScroll);
        }
    }
    Connections {
        target: SportsService
        function onTimetableGamesChanged() {
            root.updateNextEvent();
        }
    }
    Connections {
        target: Config.options.cheatsheet
        function onTimetableTodayFirstChanged() {
            root.requestSportsRange();
        }
    }
    Connections {
        target: Config.options.time
        function onFirstDayOfWeekChanged() {
            root.requestSportsRange();
        }
    }

    function requestSportsRange() {
        const fromDate = H.getDateForDayIndex(0, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst);
        const toDate = H.getDateForDayIndex(6, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst);
        const range = Qt.formatDate(fromDate, "yyyy-MM-dd") + "|" + Qt.formatDate(toDate, "yyyy-MM-dd");
        if (range === root.requestedSportsRange)
            return;
        root.requestedSportsRange = range;
        SportsService.requestTimetableRange(fromDate, toDate);
    }

    Component.onCompleted: {
        root.requestSportsRange();
        root.updateCurrentTimeLine();
        root.updateNextEvent();
        Qt.callLater(root.maybeApplyInitialScroll);
    }

    // The surface is owned by CheatsheetTimetable so both views sit on the
    // same borderless plate and can cross-fade without one drawing a second
    // background over the other.

    ColumnLayout {
        id: timetablePane
        anchors.fill: parent
        anchors.rightMargin: eventSidebar.open ? root.eventRailWidth + 14 : 0
        spacing: 0

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        TimetableHeader {
            id: headerRow
            Layout.fillWidth: true
            headerHeight: root.headerHeight
            itemSpacing: root.spacing
            timeColumnWidth: root.timeColumnWidth
            dayColumnWidth: root.dayColumnWidth
            days: root.days
            currentDayIndex: root.currentDayIndex
            allDayChipHeight: root.allDayChipHeight
            allDayChipSpacing: root.allDayChipSpacing
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Appearance.colors.colOutlineVariant
            Layout.bottomMargin: 8
        }

        StyledFlickable {
            id: styledFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: root.contentHeight
            topMargin: 20
            bottomMargin: 20

            Row {
                id: contentRow
                spacing: root.spacing

                TimetableTimeColumn {
                    totalSlots: root.totalSlots
                    slotHeight: root.slotHeight
                    slotDuration: root.slotDuration
                    startMinute: root.startMinute
                    timeColumnWidth: root.timeColumnWidth
                }

                Row {
                    id: eventsRow
                    height: root.contentHeight
                    spacing: root.spacing
                    Repeater {
                        model: root.days
                        delegate: TimetableDayColumn {
                            dayIdx: index
                            dayData: modelData
                            isToday: index === root.currentDayIndex
                            dayColumnWidth: root.dayColumnWidth
                            contentHeight: root.contentHeight
                            pixelsPerMinute: root.pixelsPerMinute
                            startHour: root.startHour
                            startMinute: root.startMinute
                            snapInterval: 15
                            ghostVisible: root.ghostVisible
                            ghostDayIndex: root.ghostDayIndex
                            ghostTopY: root.ghostTopY
                            ghostHeight: root.ghostHeight
                            nextEventData: root.nextEventData
                            maxLogicalDistance: root.maxLogicalDistance
                            todayHighlightFill: root.todayHighlightFill
                            todayHighlightBorder: root.todayHighlightBorder
                            dayBackgroundFill: root.dayBackgroundFill
                            dayBackgroundFillVariant: root.dayBackgroundFillVariant

                            id: dayColDelegate
                            opacity: 0
                            transform: Translate { id: colTrans; y: 15 }

                            Component.onCompleted: {
                                animTimer.start();
                            }

                            Timer {
                                id: animTimer
                                interval: index * 70
                                repeat: false
                                onTriggered: {
                                    colAnim.start();
                                }
                            }

                            ParallelAnimation {
                                id: colAnim
                                NumberAnimation {
                                    target: colTrans
                                    property: "y"
                                    to: 0
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: dayColDelegate
                                    property: "opacity"
                                    to: 1
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }

                            onDragRequestInteractivity: i => styledFlickable.interactive = i
                            onDragReleased: (dIdx, sY, cY) => {
                                let dist = Math.abs(cY - sY);
                                if (dist < 10) {
                                    let clickMin = H.snapToGrid(H.yToMinutes(sY, root.startHour, root.startMinute, root.pixelsPerMinute), 15);
                                    root.ghostTopY = H.minutesToY(clickMin, root.startHour, root.startMinute, root.pixelsPerMinute);
                                    root.ghostHeight = H.minutesToY(clickMin + 60, root.startHour, root.startMinute, root.pixelsPerMinute) - root.ghostTopY;
                                } else {
                                    let topMin = H.snapToGrid(H.yToMinutes(Math.min(sY, cY), root.startHour, root.startMinute, root.pixelsPerMinute), 15);
                                    let botMin = H.snapToGrid(H.yToMinutes(Math.max(sY, cY), root.startHour, root.startMinute, root.pixelsPerMinute), 15);
                                    if (botMin - topMin < 15)
                                        botMin = topMin + 15;
                                    root.ghostTopY = H.minutesToY(topMin, root.startHour, root.startMinute, root.pixelsPerMinute);
                                    root.ghostHeight = H.minutesToY(botMin, root.startHour, root.startMinute, root.pixelsPerMinute) - root.ghostTopY;
                                }
                                root.ghostDayIndex = dIdx;
                                root.ghostVisible = true;
                                Qt.callLater(root.openPopupForGhost);
                            }
                            onEditRequested: (evt, dIdx) => root.openPopupForEdit(evt, dIdx)
                        }
                    }
                }
            }

            TimetableCurrentTime {
                currentTimeY: root.currentTimeY
                contentRowWidth: contentRow.width
                timeColumnWidth: root.timeColumnWidth
                visible: root.currentTimeY >= 0 && root.currentTimeY <= contentRow.height
            }
        }
    }

    TimetableNextEventFAB {
        nextEventData: root.nextEventData
        headerHeight: root.headerHeight
        timeColumnWidth: root.timeColumnWidth
        dayColumnWidth: root.dayColumnWidth
        spacing: root.spacing
        contentY: styledFlickable.contentY
        flickableHeight: styledFlickable.height
        flickableContentHeight: styledFlickable.contentHeight
        pixelsPerMinute: root.pixelsPerMinute
        startHour: root.startHour
        startMinute: root.startMinute
        onScrollRequested: y => styledFlickable.contentY = Math.min(y, Math.max(0, styledFlickable.contentHeight - styledFlickable.height))
    }

    Item {
        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
        }
        width: eventSidebar.open ? root.eventRailWidth : 0
        clip: true
        z: 30

        Behavior on width {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        MonthEventSidebar {
            id: eventSidebar
            anchors.fill: parent
            detailsOnly: true
        }
    }

    EventCreationPopup {
        id: eventPopup
        anchors.fill: parent
        z: 50
        onEventCreated: (title, description) => {
            let topMin = H.snapToGrid(H.yToMinutes(root.ghostTopY, root.startHour, root.startMinute, root.pixelsPerMinute), 15);
            let botMin = H.snapToGrid(H.yToMinutes(root.ghostTopY + root.ghostHeight, root.startHour, root.startMinute, root.pixelsPerMinute), 15);
            CalendarService.addEvent(H.getDateForDayIndex(root.ghostDayIndex, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst), H.minutesToKhalTimeStr(topMin), H.minutesToKhalTimeStr(botMin), title, description);
            root.ghostVisible = false;
        }
        onEventUpdated: (oldTitle, title, description) => {
            let evt = eventPopup.editEventData;
            const sourceEvent = evt?.sourceEvent;
            if (!sourceEvent?.uid)
                return;
            let startMin = H.parseTimeToMinutes(evt.start);
            let endMin = H.parseTimeToMinutes(evt.end);
            if (endMin === 0 && startMin > 0)
                endMin = 24 * 60;
            CalendarService.updateEvent(sourceEvent, H.getDateForDayIndex(eventPopup.dayIndex, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst), H.minutesToKhalTimeStr(startMin), H.minutesToKhalTimeStr(endMin), title, description, false);
        }
        onEventDeleted: title => {
            const sourceEvent = eventPopup.editEventData?.sourceEvent;
            if (sourceEvent?.uid)
                CalendarService.removeEventByUid(sourceEvent.uid);
            root.ghostVisible = false;
        }
        onCancelled: root.ghostVisible = false
    }
}
