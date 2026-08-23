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

    readonly property bool eventPopupVisible: eventSidebar.open

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
    property real headerHeight: 64 + (maxHeaderChipCount > 0 ? maxHeaderChipCount * (allDayChipHeight + allDayChipSpacing) + 8 : 0)
    property real currentTimeY: -1
    property bool initialScrollApplied: false
    property bool sportsEnabled: false
    property int loadedDayCount: 0
    property string requestedSportsRange: ""
    readonly property int dayCount: root.days?.length ?? 0
    readonly property bool initialLoadComplete: root.dayCount > 0 && root.loadedDayCount >= root.dayCount

    onLoadedDayCountChanged: {
        if (root.dayCount > 0 && root.loadedDayCount >= root.dayCount)
            console.info("[TimetableLoad][Week] completed=" + root.loadedDayCount);
    }

    readonly property real eventRailWidth: Math.max(300, Math.min(390, root.width * 0.29))
    readonly property real usableWidth: root.width - (eventSidebar.open ? root.eventRailWidth + 14 : 0)
    readonly property real dayColumnWidth: {
        let availableWidth = root.usableWidth > 0 ? root.usableWidth : maxContentWidth;
        return Math.max(80, (availableWidth - timeColumnWidth - root.dayCount * spacing) / Math.max(1, root.dayCount));
    }
    readonly property int currentDayIndex: Config.options.cheatsheet.timetableTodayFirst ? 0 : ((DateTime.clock.date.getDay() - Config.options.time.firstDayOfWeek + 6) % 7)
    readonly property string clockDayKey: Qt.formatDate(DateTime.clock.date, "yyyy-MM-dd")

    implicitWidth: maxContentWidth
    implicitHeight: Math.min(headerHeight + contentHeight, maxHeight)
    readonly property var calendarDays: CalendarService.eventsInWeek
    readonly property var days: {
        // gamesForDate() reads a plain array, so depend explicitly on the
        // replacement that SportsService publishes after each refresh.
        const sportsGames = root.sportsEnabled ? SportsService.timetableGames : [];
        const result = [];
        for (let i = 0; i < 7; i++) {
            const date = H.getDateForDayIndex(i, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst);
            const calendarDay = root.calendarDays?.[i] ?? ({});
            const games = root.sportsEnabled && Array.isArray(sportsGames) ? SportsService.gamesForDate(date) : [];
            result.push({
                name: String(calendarDay.name || Qt.formatDate(date, "dddd")),
                events: calendarDay.events ?? [],
                sportsDate: date,
                sportsCount: games.length
            });
        }
        return result;
    }
    readonly property int allDayChipHeight: 36
    readonly property int allDayChipSpacing: 6
    readonly property int maxHeaderChipCount: {
        if (!root.days || root.days.length === 0)
            return 0;
        let maxCount = 0;
        for (let i = 0; i < root.days.length; i++) {
            const sportsCount = Number(root.days[i]?.sportsCount ?? 0) > 0 ? 1 : 0;
            const count = H.getAllDayEvents(root.days[i]?.events).length + sportsCount;
            if (count > maxCount)
                maxCount = count;
        }
        return maxCount;
    }

    // ─── Theme Colors ───
    readonly property color todayHighlightFill: H.withOpacity(Appearance.colors.colPrimary, 0.12)
    readonly property color dayBackgroundFill: H.withOpacity(Appearance.colors.colSecondary, 0.04)
    readonly property color dayBackgroundFillVariant: H.withOpacity(Appearance.colors.colSecondary, 0.08)

    // ─── State ───
    property var nextEventData: null

    property bool ghostVisible: false
    property int ghostDayIndex: -1
    property real ghostTopY: 0
    property real ghostHeight: 0
    property var timedMutationEvent: null
    property string timedMutationKind: ""
    property real timedMutationPointerOffsetY: 0
    property int timedMutationStartMinutes: 0
    property int timedMutationEndMinutes: 0
    property int timedMutationDayIndex: -1

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
        if (root.initialScrollApplied)
            return;
        if (!styledFlickable || styledFlickable.height <= 0 || !root.days || root.days.length === 0) {
            initialScrollRetryTimer.restart();
            return;
        }
        root.scrollToCurrentTime();
        root.initialScrollApplied = true;
    }

    // A Timer belongs to the week view and is destroyed with it. Keeping the
    // layout retry here avoids a self-perpetuating Qt.callLater callback after
    // the asynchronously-loaded view has been released.
    Timer {
        id: initialScrollRetryTimer
        interval: Appearance.animation.elementMoveFast.duration
        repeat: false
        onTriggered: root.maybeApplyInitialScroll()
    }

    function toggleSportsDay(date) {
        if (eventSidebar.open && eventSidebar.mode === "day" && eventSidebar.sportsListOnly && H.sameDate(eventSidebar.day, date)) {
            eventSidebar.close();
            return;
        }
        eventSidebar.sportsListOnly = true;
        eventSidebar.showSportsDay(date);
    }

    function toggleDay(date) {
        if (eventSidebar.open && eventSidebar.mode === "day" && !eventSidebar.sportsListOnly && H.sameDate(eventSidebar.day, date)) {
            eventSidebar.close();
            return;
        }
        eventSidebar.sportsListOnly = false;
        eventSidebar.showDay(date);
    }

    function startCreate(date) {
        if (!CalendarService.khalAvailable)
            return;
        eventSidebar.sportsListOnly = false;
        eventSidebar.startCreate(date);
    }

    function eventMinutes(date) {
        return date.getHours() * 60 + date.getMinutes();
    }

    function eventEndMinutes(event) {
        const start = root.eventMinutes(event.startDate);
        let end = root.eventMinutes(event.endDate);
        if (end <= start)
            end = 24 * 60;
        return end;
    }

    function dayIndexForDate(date) {
        for (let index = 0; index < root.days.length; index++) {
            if (H.sameDate(root.days[index]?.sportsDate, date))
                return index;
        }
        return -1;
    }

    function gridPointAt(x, y) {
        const point = root.mapToItem(contentRow, x, y);
        const relativeX = point.x - root.timeColumnWidth - root.spacing;
        const stride = root.dayColumnWidth + root.spacing;
        const dayIndex = Math.floor(relativeX / stride);
        if (dayIndex < 0 || dayIndex >= root.dayCount || relativeX - dayIndex * stride > root.dayColumnWidth)
            return null;
        return { dayIndex: dayIndex, contentY: point.y };
    }

    function clampStart(minutes, duration) {
        const snapped = H.snapToGrid(minutes, 15);
        return Math.max(root.startHour * 60 + root.startMinute, Math.min(24 * 60 - duration, snapped));
    }

    function beginEventMove(event, x, y, pointerOffsetY) {
        if (!event?.uid || event.readOnly === true)
            return;
        const dayIndex = root.dayIndexForDate(event.startDate);
        if (dayIndex < 0)
            return;
        root.timedMutationEvent = event;
        root.timedMutationKind = "move";
        root.timedMutationPointerOffsetY = pointerOffsetY;
        root.timedMutationStartMinutes = root.eventMinutes(event.startDate);
        root.timedMutationEndMinutes = root.eventEndMinutes(event);
        root.timedMutationDayIndex = dayIndex;
        root.updateEventMove(x, y);
    }

    function updateEventMove(x, y) {
        if (!root.timedMutationEvent || root.timedMutationKind !== "move")
            return;
        const target = root.gridPointAt(x, y);
        if (!target)
            return;
        const duration = root.timedMutationEndMinutes - root.timedMutationStartMinutes;
        const topY = target.contentY - root.timedMutationPointerOffsetY;
        root.timedMutationStartMinutes = root.clampStart(H.yToMinutes(topY, root.startHour, root.startMinute, root.pixelsPerMinute), duration);
        root.timedMutationEndMinutes = root.timedMutationStartMinutes + duration;
        root.timedMutationDayIndex = target.dayIndex;
    }

    function beginEventResize(event, x, y) {
        if (!event?.uid || event.readOnly === true)
            return;
        const dayIndex = root.dayIndexForDate(event.startDate);
        if (dayIndex < 0)
            return;
        root.timedMutationEvent = event;
        root.timedMutationKind = "resize";
        root.timedMutationStartMinutes = root.eventMinutes(event.startDate);
        root.timedMutationEndMinutes = root.eventEndMinutes(event);
        root.timedMutationDayIndex = dayIndex;
        root.updateEventResize(x, y);
    }

    function updateEventResize(x, y) {
        if (!root.timedMutationEvent || root.timedMutationKind !== "resize")
            return;
        const target = root.gridPointAt(x, y);
        if (!target)
            return;
        const end = H.snapToGrid(H.yToMinutes(target.contentY, root.startHour, root.startMinute, root.pixelsPerMinute), 15);
        root.timedMutationEndMinutes = Math.max(root.timedMutationStartMinutes + 15, Math.min(24 * 60, end));
    }

    function isoForDayMinutes(date, minutes) {
        const value = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        value.setMinutes(minutes);
        return CalendarService.localIso(value, Qt.formatTime(value, "hh:mm"));
    }

    function commitTimedMutation() {
        const event = root.timedMutationEvent;
        const day = root.days[root.timedMutationDayIndex]?.sportsDate;
        const action = root.timedMutationKind;
        if (event?.uid && day && root.timedMutationEndMinutes > root.timedMutationStartMinutes) {
            eventSidebar.requestTimedMutation(event, {
                allDay: false,
                start: root.isoForDayMinutes(day, root.timedMutationStartMinutes),
                end: root.isoForDayMinutes(day, root.timedMutationEndMinutes)
            }, action);
        }
        root.cancelTimedMutation();
    }

    function cancelTimedMutation() {
        root.timedMutationEvent = null;
        root.timedMutationKind = "";
        root.timedMutationDayIndex = -1;
    }

    function requestWeekDelete(event) {
        if (!event?.uid || event.readOnly === true)
            return;
        if (String(event.repeatSymbol ?? "").length === 0) {
            CalendarService.deleteEventWithScope(event, "all");
            return;
        }
        eventSidebar.showEvent(event);
        eventSidebar.requestDelete();
    }

    // ─── Actions ───
    function openPopupForGhost() {
        let topMin = H.snapToGrid(H.yToMinutes(root.ghostTopY, root.startHour, root.startMinute, root.pixelsPerMinute), 15);
        let botMin = H.snapToGrid(H.yToMinutes(root.ghostTopY + root.ghostHeight, root.startHour, root.startMinute, root.pixelsPerMinute), 15);
        let eventDate = H.getDateForDayIndex(root.ghostDayIndex, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst);
        eventSidebar.startCreateAt(eventDate, topMin, botMin);
        root.ghostVisible = false;
    }

    function openPopupForEdit(event, dayIndex) {
        if (event?.sportEvent === true) {
            eventSidebar.showEvent(event);
            return;
        }
        eventSidebar.startEdit(event.sourceEvent ?? event);
    }

    function applySidebarPayload(payload) {
        if (!payload)
            return;
        const nextDay = new Date(payload.date.getFullYear(), payload.date.getMonth(), payload.date.getDate() + 1);
        const fields = {
            summary: payload.title, description: payload.description, location: payload.location,
            url: payload.url, status: payload.status, recurrence: payload.recurrence,
            alarms: payload.alarms, color: payload.color, categories: payload.categories, allDay: payload.allDay,
            start: payload.allDay ? Qt.formatDate(payload.date, "yyyy-MM-dd") : CalendarService.localIso(payload.date, payload.start),
            end: payload.allDay ? Qt.formatDate(nextDay, "yyyy-MM-dd") : CalendarService.localIso(payload.date, payload.end)
        };
        if (payload.editMode) {
            CalendarService.saveEventFields(payload.event, fields, payload.scope ?? "all");
            return;
        }
        CalendarService.createEventFields(payload.calendar, fields);
    }

    Connections {
        target: DateTime.clock
        function onDateChanged() {
            root.updateCurrentTimeLine();
            root.updateNextEvent();
        }
    }

    onClockDayKeyChanged: {
        root.requestedSportsRange = "";
        root.requestSportsRange();
    }
    Connections {
        target: CalendarService
        function onEventsInWeekChanged() {
            root.updateNextEvent();
            root.maybeApplyInitialScroll();
        }
    }
    Connections {
        target: Config.options.cheatsheet
        function onTimetableTodayFirstChanged() {
            root.restartDayLoading();
        }
    }
    Connections {
        target: Config.options.time
        function onFirstDayOfWeekChanged() {
            root.restartDayLoading();
        }
    }

    function requestSportsRange() {
        console.info("[TimetableSports][Week] attempt enabled=" + root.sportsEnabled + " complete=" + root.initialLoadComplete + " active=" + SportsService.timetableActive);
        if (!root.sportsEnabled || !root.initialLoadComplete)
            return;
        const fromDate = H.getDateForDayIndex(0, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst);
        const toDate = H.getDateForDayIndex(6, Config.options.time.firstDayOfWeek, Config.options.cheatsheet.timetableTodayFirst);
        const range = Qt.formatDate(fromDate, "yyyy-MM-dd") + "|" + Qt.formatDate(toDate, "yyyy-MM-dd");
        if (range === root.requestedSportsRange)
            return;
        root.requestedSportsRange = range;
        console.info("[TimetableSports][Week] request=" + range);
        SportsService.requestTimetableRange(fromDate, toDate);
    }

    function restartDayLoading() {
        root.loadedDayCount = -1;
        root.requestedSportsRange = "";
        Qt.callLater(() => root.loadedDayCount = 0);
    }

    function advanceDayLoading(index) {
        if (index !== root.loadedDayCount || index >= root.dayCount)
            return;
        root.loadedDayCount = index + 1;
    }

    onInitialLoadCompleteChanged: {
        if (root.initialLoadComplete)
            root.requestSportsRange();
    }

    onSportsEnabledChanged: {
        if (root.sportsEnabled)
            root.requestSportsRange();
    }

    Component.onCompleted: {
        root.restartDayLoading();
        root.updateCurrentTimeLine();
        root.updateNextEvent();
        root.maybeApplyInitialScroll();
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
            days: (root.days ?? []).slice(0, Math.max(0, root.loadedDayCount))
            currentDayIndex: root.currentDayIndex
            allDayChipHeight: root.allDayChipHeight
            allDayChipSpacing: root.allDayChipSpacing
            createEnabled: CalendarService.khalAvailable
            onCreateRequested: root.startCreate(DateTime.clock.date)
            onDayActivated: date => root.toggleDay(date)
            onSportsDayActivated: date => root.toggleSportsDay(date)
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
                        model: root.days ?? []

                        delegate: Loader {
                            id: dayLoader

                            required property int index
                            required property var modelData

                            width: root.dayColumnWidth
                            height: root.contentHeight
                            active: index <= root.loadedDayCount
                            asynchronous: true

                            onLoaded: root.advanceDayLoading(index)

                            sourceComponent: TimetableDayColumn {
                                id: dayColDelegate

                                dayIdx: dayLoader.index
                                dayData: dayLoader.modelData
                                isToday: dayLoader.index === root.currentDayIndex
                                dayColumnWidth: root.dayColumnWidth
                                contentHeight: root.contentHeight
                                pixelsPerMinute: root.pixelsPerMinute
                                startHour: root.startHour
                                startMinute: root.startMinute
                                snapInterval: 15
                                coordinateRoot: root
                                draggedEvent: root.timedMutationEvent
                                ghostVisible: root.ghostVisible
                                ghostDayIndex: root.ghostDayIndex
                                ghostTopY: root.ghostTopY
                                ghostHeight: root.ghostHeight
                                nextEventData: root.nextEventData
                                todayHighlightFill: root.todayHighlightFill
                                dayBackgroundFill: root.dayBackgroundFill
                                dayBackgroundFillVariant: root.dayBackgroundFillVariant

                                opacity: 0
                                transform: Translate { id: colTrans; y: 15 }

                                Component.onCompleted: animTimer.start()

                                Timer {
                                    id: animTimer
                                    interval: dayLoader.index * 70
                                    repeat: false
                                    onTriggered: colAnim.start()
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
                                onDeleteRequested: (evt, dIdx) => root.requestWeekDelete(evt)
                                onEventMoveStarted: (evt, x, y, offsetY) => root.beginEventMove(evt, x, y, offsetY)
                                onEventMoveMoved: (x, y) => root.updateEventMove(x, y)
                                onEventMoveEnded: root.commitTimedMutation()
                                onEventMoveCanceled: root.cancelTimedMutation()
                                onEventResizeStarted: (evt, x, y) => root.beginEventResize(evt, x, y)
                                onEventResizeMoved: (x, y) => root.updateEventResize(x, y)
                                onEventResizeEnded: root.commitTimedMutation()
                                onEventResizeCanceled: root.cancelTimedMutation()
                            }
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

    Rectangle {
        id: timedMutationProxy
        visible: root.timedMutationEvent !== null && root.timedMutationDayIndex >= 0
        z: 24
        width: Math.max(32, root.dayColumnWidth - 10)
        height: Math.max((root.timedMutationEndMinutes - root.timedMutationStartMinutes) * root.pixelsPerMinute - 4, 48)
        radius: Appearance.rounding.normal
        color: H.chipColor(root.timedMutationEvent, Appearance.colors)
        opacity: 0.96
        x: {
            const point = eventsRow.mapToItem(root, root.timedMutationDayIndex * (root.dayColumnWidth + root.spacing) + 5, 0);
            return point.x;
        }
        y: {
            const point = eventsRow.mapToItem(root, 0, H.minutesToY(root.timedMutationStartMinutes, root.startHour, root.startMinute, root.pixelsPerMinute));
            return point.y;
        }

        StyledText {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: Text.AlignVCenter
            text: root.timedMutationEvent?.content ?? ""
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: ColorUtils.getContrastingTextColor(timedMutationProxy.color)
            elide: Text.ElideRight
        }
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

        EventSidebar {
            id: eventSidebar
            anchors.fill: parent
            sportsListOnly: false
            onSaveRequested: payload => root.applySidebarPayload(payload)
            onTaskCreateRequested: task => Todo.addItem(task)
            onDeleteRequested: (eventData, scope) => CalendarService.deleteEventWithScope(eventData, scope)
            onEventFieldsMutationRequested: (eventData, fields, scope) => CalendarService.saveEventFields(eventData, fields, scope)
            onTimePickerRequested: (which, startHour, startMinute) => {
                timePicker.target = which;
                timePicker.open(startHour, startMinute, which === "start" ? Translation.tr("Starts at") : Translation.tr("Ends at"));
            }
            onDatePickerRequested: (purpose, date) => {
                datePicker.purpose = purpose;
                datePicker.open(date, purpose === "reschedule" ? Translation.tr("Move event to") : Translation.tr("Event date"));
            }
        }
    }

    TimePickerPopup {
        id: timePicker
        anchors.fill: parent
        z: 50
        property string target: "start"
        onAccepted: (pickedHour, pickedMinute) => eventSidebar.applyPickedTime(timePicker.target, pickedHour, pickedMinute)
    }

    DatePickerPopup {
        id: datePicker
        anchors.fill: parent
        z: 50
        property string purpose: "form"
        onAccepted: pickedDate => eventSidebar.applyPickedDate(datePicker.purpose, pickedDate)
    }
}
