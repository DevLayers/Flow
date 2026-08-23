import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import "TimetableHelpers.js" as H

/**
 * Month grid, Google-Calendar shaped, Material 3 dressed.
 *
 * Geometry is computed rather than delegated to a layout: the grid needs exact
 * cell rectangles anyway to answer "which day is the cursor over" during a
 * drag, and computing it once means the drop hit-test cannot disagree with what
 * is on screen. Nothing here scrolls — a month always fits, and a cell that
 * runs out of room collapses into a counter.
 */
Item {
    id: root

    property int viewYear: DateTime.clock.date.getFullYear()
    property int viewMonth: DateTime.clock.date.getMonth()
    property bool showUpcoming: true
    property string categoryFilter: ""

    readonly property int firstDayOfWeek: Config.options.time.firstDayOfWeek
    readonly property real gridGap: 6

    readonly property var cells: H.buildMonthCells(root.viewYear, root.viewMonth, root.firstDayOfWeek, DateTime.clock.date)
    readonly property int rowCount: Math.max(1, root.cells.length / 7)

    readonly property bool holidaysVisible: (Config.options.calendar.holidays.enable ?? false) && (Config.options.calendar.holidays.showInMonthView ?? false)
    readonly property var holidayMap: root.holidaysVisible ? Holidays.byDayKey : ({})
    readonly property var availableCategories: {
        const seen = new Set();
        for (const event of CalendarService.events ?? []) {
            for (const category of (event.categories ?? []))
                seen.add(String(category));
        }
        return Array.from(seen).sort((left, right) => left.localeCompare(right));
    }

    // The event rail takes room from the grid. When the view is not wide enough
    // for both rails, the upcoming list is the one that yields.
    readonly property real eventRailWidth: Math.max(300, Math.min(390, root.width * 0.29))
    readonly property real usableWidth: root.width - (eventSidebar.open ? root.eventRailWidth + 14 : 0)
    readonly property bool sidebarAllowed: root.showUpcoming && root.usableWidth >= 1000
    readonly property real sidebarWidth: Math.max(260, Math.min(330, root.width * 0.23))
    readonly property bool compactNav: root.usableWidth < 830
    readonly property bool viewingCurrentMonth: root.viewYear === DateTime.clock.date.getFullYear() && root.viewMonth === DateTime.clock.date.getMonth()

    readonly property date viewAnchorDate: new Date(root.viewYear, root.viewMonth, 1)

    signal weekViewRequested

    function filteredEvents(events) {
        if (!root.categoryFilter)
            return events ?? [];
        return (events ?? []).filter(event => (event.categories ?? []).includes(root.categoryFilter));
    }

    function tasksForDay(date) {
        const isToday = H.sameDate(date, DateTime.clock.date);
        const overdueTasks = Todo.getOverdueTasks(DateTime.clock.date);
        const dueToday = Todo.getTasksByDate(date).filter(task => {
            if (!task?.hasDate || task.done)
                return true;
            return isToday || !overdueTasks.some(overdue => overdue === task || String(overdue?.id ?? "") === String(task?.id ?? ""));
        });
        if (!isToday)
            return dueToday;
        // Overdue tasks live on today only: a calendar user sees the action
        // where it matters now, rather than in a past cell and today.
        return overdueTasks.concat(dueToday);
    }

    // ─── Month navigation ───
    property int entranceKey: 0
    property real gridOpacity: 1
    property real gridShiftX: 0

    function goToMonth(year, month, direction) {
        if (year === root.viewYear && month === root.viewMonth)
            return;
        root.viewYear = year;
        root.viewMonth = month;
        root.playMonthTransition(direction);
    }

    function shiftMonth(delta) {
        const target = H.addMonths(new Date(root.viewYear, root.viewMonth, 1), delta);
        root.goToMonth(target.getFullYear(), target.getMonth(), delta >= 0 ? 1 : -1);
    }

    function goToday() {
        const now = DateTime.clock.date;
        const currentIndex = root.viewYear * 12 + root.viewMonth;
        const targetIndex = now.getFullYear() * 12 + now.getMonth();
        if (currentIndex === targetIndex) {
            root.playMonthTransition(0);
            return;
        }
        root.goToMonth(now.getFullYear(), now.getMonth(), targetIndex > currentIndex ? 1 : -1);
    }

    // Explicit reset then start: a Behavior would not fire on a repeat in the
    // same direction, because the values it would animate are already final.
    function playMonthTransition(direction) {
        monthAnim.stop();
        root.gridShiftX = direction * 44;
        root.gridOpacity = 0;
        root.entranceKey++;
        monthAnim.start();
    }

    ParallelAnimation {
        id: monthAnim

        NumberAnimation {
            target: root
            property: "gridShiftX"
            to: 0
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
        }

        NumberAnimation {
            target: root
            property: "gridOpacity"
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.OutCubic
        }
    }

    onViewAnchorDateChanged: root.ensureDataForView()

    function ensureDataForView() {
        CalendarService.ensureRangeCovers(new Date(root.viewYear, root.viewMonth, 1));
        CalendarService.ensureRangeCovers(new Date(root.viewYear, root.viewMonth + 1, 0));
        if (root.cells.length > 0)
            SportsService.requestTimetableRange(root.cells[0].date, root.cells[root.cells.length - 1].date);
        if (root.holidaysVisible) {
            Holidays.ensureYear(root.viewYear);
            Holidays.ensureYear(new Date(root.viewYear, root.viewMonth + 1, 0).getFullYear());
        }
    }

    Component.onCompleted: {
        root.ensureDataForView();
        root.playMonthTransition(0);
    }

    onHolidaysVisibleChanged: {
        if (root.holidaysVisible)
            Holidays.ensureYear(root.viewYear);
    }

    // ─── Drag state ───
    property var dragEvent: null
    property bool dragOffsetKnown: false
    property real dragOriginX: 0
    property real dragOriginY: 0
    property real dragGrabX: 0
    property real dragGrabY: 0
    property real dragProxyX: 0
    property real dragProxyY: 0
    property real dragProxyW: 0
    property real dragProxyH: 0
    property int dropIndex: -1

    function beginEventDrag(eventData, originX, originY, w, h) {
        root.dragEvent = eventData;
        root.dragOriginX = originX;
        root.dragOriginY = originY;
        root.dragProxyX = originX;
        root.dragProxyY = originY;
        root.dragProxyW = w;
        root.dragProxyH = h;
        root.dragOffsetKnown = false;
        root.dropIndex = -1;
    }

    function moveEventDrag(x, y) {
        if (!root.dragEvent)
            return;
        if (!root.dragOffsetKnown) {
            root.dragGrabX = x - root.dragOriginX;
            root.dragGrabY = y - root.dragOriginY;
            root.dragOffsetKnown = true;
        }
        root.dragProxyX = x - root.dragGrabX;
        root.dragProxyY = y - root.dragGrabY;

        const local = gridArea.mapFromItem(root, x, y);
        root.dropIndex = gridArea.cellIndexAt(local.x, local.y);
    }

    function endEventDrag() {
        const moved = root.dragEvent;
        const target = root.dropIndex >= 0 && root.dropIndex < root.cells.length ? root.cells[root.dropIndex] : null;
        root.cancelEventDrag();
        if (!moved || !target)
            return;
        if (H.sameDate(target.date, moved.startDate))
            return;
        CalendarService.moveEvent(moved, target.date);
    }

    function cancelEventDrag() {
        root.dragEvent = null;
        root.dropIndex = -1;
        root.dragOffsetKnown = false;
    }

    // ─── Actions ───
    function requestCreate(date) {
        eventSidebar.startCreate(date);
    }

    function requestOpen(eventData) {
        eventSidebar.showEvent(eventData);
    }

    function requestDay(date) {
        eventSidebar.showDay(date);
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

    function deleteEvent(eventData, scope = "all") {
        if (!eventData)
            return;
        if (eventData.uid)
            CalendarService.deleteEventWithScope(eventData, scope);
    }

    // ─── Layout ───
    RowLayout {
        anchors.fill: parent
        spacing: 14

        // ─── Upcoming rail ───
        Item {
            id: sidebarSlot
            Layout.fillHeight: true
            Layout.preferredWidth: root.sidebarAllowed ? root.sidebarWidth : 0
            visible: Layout.preferredWidth > 1
            clip: true

            Behavior on Layout.preferredWidth {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(sidebarSlot)
            }

            MonthUpcomingPanel {
                anchors.fill: parent
                anchors.rightMargin: 2
                entranceKey: root.entranceKey
                onEventActivated: eventData => root.requestOpen(eventData)
                onDateActivated: date => root.goToMonth(date.getFullYear(), date.getMonth(), 0)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // ─── Navigation ───
            RowLayout {
                id: navBar
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.formatDate(root.viewAnchorDate, "MMMM")
                        font.family: Appearance.font.family.title
                        font.pixelSize: root.compactNav ? 26 : 32
                        font.weight: Font.Bold
                        font.variableAxes: Appearance.font.variableAxes.title
                        color: Appearance.colors.colOnSurface
                        elide: Text.ElideRight
                        animateChange: true
                        animationDistanceX: 0
                        animationDistanceY: 10
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.viewingCurrentMonth ? Translation.tr("%1 · this month").arg(String(root.viewYear)) : String(root.viewYear)
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        font.weight: Font.Bold
                        color: root.viewingCurrentMonth ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                RippleButton {
                    id: upcomingToggle
                    visible: root.usableWidth >= 1000
                    implicitWidth: 42
                    implicitHeight: 42
                    buttonRadius: Appearance.rounding.full
                    toggled: root.showUpcoming
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colBackgroundToggled: Appearance.colors.colSecondaryContainer
                    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                    onClicked: {
                        root.showUpcoming = !root.showUpcoming;
                        Persistent.states.cheatsheet.timetableShowUpcoming = root.showUpcoming;
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "view_sidebar"
                        iconSize: Appearance.font.pixelSize.larger
                        color: root.showUpcoming ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                    }

                    StyledToolTip {
                        extraVisibleCondition: upcomingToggle.hovered
                        text: root.showUpcoming ? Translation.tr("Hide upcoming events") : Translation.tr("Show upcoming events")
                    }
                }

                RippleButtonWithIcon {
                    id: todayButton
                    implicitWidth: root.compactNav ? 42 : todayButton.contentImplicitWidth + 32
                    implicitHeight: 42
                    buttonRadius: Appearance.rounding.full
                    centerContent: true
                    materialIcon: "today"
                    materialIconFill: false
                    mainText: root.compactNav ? "" : Translation.tr("Today")
                    iconPixelSize: Appearance.font.pixelSize.larger
                    textPixelSize: Appearance.font.pixelSize.small
                    mainTextWeight: Font.Bold
                    colText: Appearance.colors.colOnSurface
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colBackgroundActive: Appearance.colors.colLayer2Active
                    onClicked: root.goToday()

                    StyledToolTip {
                        extraVisibleCondition: todayButton.hovered && root.compactNav
                        text: Translation.tr("Today")
                    }
                }

                RippleButton {
                    implicitWidth: 42
                    implicitHeight: 42
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colBackgroundActive: Appearance.colors.colLayer2Active
                    onClicked: root.shiftMonth(-1)

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnSurface
                    }
                }

                RippleButton {
                    implicitWidth: 42
                    implicitHeight: 42
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colBackgroundActive: Appearance.colors.colLayer2Active
                    onClicked: root.shiftMonth(1)

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnSurface
                    }
                }

                RippleButtonWithIcon {
                    id: newEventButton
                    implicitWidth: root.compactNav ? 46 : newEventButton.contentImplicitWidth + 36
                    implicitHeight: 46
                    buttonRadius: Appearance.rounding.full
                    centerContent: true
                    materialIcon: "add"
                    materialIconFill: false
                    mainText: root.compactNav ? "" : Translation.tr("New event")
                    iconPixelSize: Appearance.font.pixelSize.huge
                    textPixelSize: Appearance.font.pixelSize.small
                    mainTextWeight: Font.Bold
                    colText: Appearance.colors.colOnPrimary
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colBackgroundActive: Appearance.colors.colPrimaryActive
                    enabled: CalendarService.khalAvailable
                    onClicked: root.requestCreate(root.viewingCurrentMonth ? DateTime.clock.date : root.viewAnchorDate)

                    StyledToolTip {
                        extraVisibleCondition: newEventButton.hovered && root.compactNav
                        text: Translation.tr("New event")
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                visible: root.availableCategories.length > 0
                spacing: 6

                Repeater {
                    model: [""].concat(root.availableCategories)

                    delegate: RippleButton {
                        required property string modelData
                        readonly property bool selected: root.categoryFilter === modelData

                        implicitWidth: filterLabel.implicitWidth + 24
                        implicitHeight: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: selected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                        colBackgroundHover: selected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
                        onClicked: root.categoryFilter = modelData

                        contentItem: StyledText {
                            id: filterLabel
                            anchors.centerIn: parent
                            text: modelData ? modelData : Translation.tr("All labels")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Bold
                            color: selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                        }
                    }
                }
            }

            // ─── Weekday header ───
            Item {
                id: weekdayHeader
                Layout.fillWidth: true
                Layout.preferredHeight: 26

                // Locale short names ("Mon", "Seg"). Deliberately not tied to
                // the waffles two-character tweak: that one belongs to the
                // Windows-style shell, not to this calendar.
                readonly property var labels: H.weekdayLabels(root.firstDayOfWeek, Config.options.calendar.locale, Locale.ShortFormat)

                Repeater {
                    model: 7

                    delegate: StyledText {
                        required property int index

                        x: index * (gridArea.cellWidth + root.gridGap)
                        width: gridArea.cellWidth
                        height: weekdayHeader.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: String(weekdayHeader.labels?.[index] ?? "").toUpperCase()
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: H.isWeekendColumn(index, root.firstDayOfWeek) ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            // ─── Grid ───
            Item {
                id: gridArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real cellWidth: Math.max(1, (width - root.gridGap * 6) / 7)
                readonly property real cellHeight: Math.max(1, (height - root.gridGap * (root.rowCount - 1)) / root.rowCount)

                function cellRect(index) {
                    const column = index % 7;
                    const row = Math.floor(index / 7);
                    return Qt.rect(column * (gridArea.cellWidth + root.gridGap), row * (gridArea.cellHeight + root.gridGap), gridArea.cellWidth, gridArea.cellHeight);
                }

                function cellIndexAt(x, y) {
                    if (x < 0 || y < 0 || x > gridArea.width || y > gridArea.height)
                        return -1;
                    const column = Math.floor(x / (gridArea.cellWidth + root.gridGap));
                    const row = Math.floor(y / (gridArea.cellHeight + root.gridGap));
                    if (column < 0 || column > 6 || row < 0 || row >= root.rowCount)
                        return -1;
                    return row * 7 + column;
                }

                opacity: root.gridOpacity
                transform: Translate {
                    x: root.gridShiftX
                }

                Repeater {
                    model: root.cells

                    delegate: MonthDayCell {
                        required property var modelData
                        required property int index

                        x: index % 7 * (gridArea.cellWidth + root.gridGap)
                        y: Math.floor(index / 7) * (gridArea.cellHeight + root.gridGap)
                        width: gridArea.cellWidth
                        height: gridArea.cellHeight

                        cellData: modelData
                        events: root.filteredEvents(CalendarService.eventsByDay[modelData.key])
                        tasks: root.tasksForDay(modelData.date)
                        holidays: root.holidayMap[modelData.key] ?? []
                        dropTarget: root.dropIndex === index && root.dragEvent !== null
                        coordinateRoot: root
                        draggedEvent: root.dragEvent
                        entranceKey: root.entranceKey

                        onCreateRequested: date => root.requestCreate(date)
                        onDayActivated: date => root.requestDay(date)
                        onEventActivated: eventData => root.requestOpen(eventData)
                        onTaskCompletionRequested: task => Todo.markDone(task)
                        onEventDragBegan: (eventData, x, y, w, h) => root.beginEventDrag(eventData, x, y, w, h)
                        onEventDragMoved: (x, y) => root.moveEventDrag(x, y)
                        onEventDragEnded: root.endEventDrag()
                        onEventDragCanceled: root.cancelEventDrag()
                    }
                }
            }
        }

        // ─── Event rail ───
        Item {
            id: eventRailSlot
            Layout.fillHeight: true
            Layout.preferredWidth: eventSidebar.open ? root.eventRailWidth : 0
            visible: Layout.preferredWidth > 1
            clip: true

            Behavior on Layout.preferredWidth {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(eventRailSlot)
            }

            MonthEventSidebar {
                id: eventSidebar
                width: root.eventRailWidth
                height: parent.height
                anchors.right: parent.right

                onSaveRequested: payload => root.applySidebarPayload(payload)
                onTaskCreateRequested: task => Todo.addItem(task)
                onDeleteRequested: (eventData, scope) => root.deleteEvent(eventData, scope)
                onMoveRequested: (eventData, newDate) => {
                    if (!eventData || !newDate)
                        return;
                    CalendarService.moveEvent(eventData, newDate);
                    root.goToMonth(newDate.getFullYear(), newDate.getMonth(), 0);
                }
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
    }

    // ─── khal missing ───
    Rectangle {
        anchors.fill: parent
        visible: !CalendarService.khalAvailable
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0
        z: 90

        PagePlaceholder {
            icon: "calendar_add_on"
            shape: "Cookie12Sided"
            title: Translation.tr("No calendar backend")
            description: Translation.tr("Install khal to create and browse events here")
            animateIconOnShow: true
        }
    }

    // ─── Drag proxy ───
    Rectangle {
        id: dragProxy
        visible: root.dragEvent !== null
        x: root.dragProxyX
        y: root.dragProxyY
        width: Math.max(120, root.dragProxyW)
        height: Math.max(26, root.dragProxyH)
        radius: Math.min(height / 2, Appearance.rounding.small)
        color: H.chipColor(root.dragEvent, Appearance.colors)
        opacity: 0.96
        scale: 1.06
        z: 120

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "drag_indicator"
                iconSize: Appearance.font.pixelSize.small
                color: ColorUtils.getContrastingTextColor(dragProxy.color)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - x)
                text: root.dragEvent?.content ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: ColorUtils.getContrastingTextColor(dragProxy.color)
                elide: Text.ElideRight
            }
        }
    }

    // ─── Pickers ───
    // Owned here rather than by the rail so they centre over the whole view.
    TimePickerPopup {
        id: timePicker
        anchors.fill: parent

        property string target: "start"

        onAccepted: (pickedHour, pickedMinute) => eventSidebar.applyPickedTime(timePicker.target, pickedHour, pickedMinute)
    }

    DatePickerPopup {
        id: datePicker
        anchors.fill: parent

        property string purpose: "form"

        onAccepted: pickedDate => eventSidebar.applyPickedDate(datePicker.purpose, pickedDate)
    }
}
