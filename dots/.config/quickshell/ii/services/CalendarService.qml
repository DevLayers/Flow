// https://github.com/AvengeMedia/DankMaterialShell/blob/master/Services/CalendarService.qml

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import Qt.labs.platform
import qs.modules.common.functions
import qs.modules.common

Singleton {
    id: root

    readonly property string homePath: String(StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]).replace("file://", "")
    property bool khalAvailable: false
    property var events: []
    property var weekdays: [Translation.tr("Sunday"), Translation.tr("Monday"), Translation.tr("Tuesday"), Translation.tr("Wednesday"), Translation.tr("Thursday"), Translation.tr("Friday"), Translation.tr("Saturday"),]
    property var sortedWeekdays: root.weekdays.map((_, i) => weekdays[(i + Config.options.time.firstDayOfWeek + 1) % 7])
    property var eventsInWeek: [
        {
            name: sortedWeekdays[0],
            events: [
                {
                    title: "Example: You need to install khal to view events",
                    start: "7:30",
                    end: "9:20",
                    color: Appearance.m3colors.m3error
                },
            ]
        },
        {
            name: sortedWeekdays[1],
            events: []
        },
        {
            name: sortedWeekdays[2],
            events: []
        },
        {
            name: sortedWeekdays[3],
            events: []
        },
        {
            name: sortedWeekdays[4],
            events: []
        },
        {
            name: sortedWeekdays[5],
            events: []
        },
        {
            name: sortedWeekdays[6],
            events: []
        }
    ]

    // Directories holding the .ics files of every configured khal calendar.
    // Read from khal's own config so deletion works wherever the user keeps their calendars.
    property var calendarPaths: [root.homePath + "/.calendars"]
    property string khalDbPath: root.homePath + "/.cache/khal/khal.db"
    readonly property string icsHelperPath: Directories.scriptPath + "/calendar/ics.py"
    property list<var> calendars: []
    property string defaultCalendar: ""
    property list<var> calendarRequestQueue: []
    property var calendarCurrentRequest: null

    // Process for checking khal configuration
    Process {
        id: khalCheckProcess

        command: ["khal", "list", "today"]
        running: true
        onExited: exitCode => {
            root.khalAvailable = (exitCode === 0);
            if (root.khalAvailable) {
                khalPathsProcess.running = true;
                interval.running = true;
                root.loadCalendarList();
            }
        }
    }

    Process {
        id: khalPathsProcess
        running: false
        // First line: sqlite cache path; following lines: one calendar directory (or glob) each
        command: ["python3", "-c", "from khal.settings import get_config\nimport os\ncfg = get_config()\nprint(os.path.expanduser(cfg['sqlite']['path']))\nfor c in cfg['calendars'].values():\n    print(os.path.expanduser(c['path']))"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                if (lines.length === 0)
                    return;
                root.khalDbPath = lines[0];
                const paths = lines.slice(1);
                if (paths.length === 0)
                    return;
                if (!paths.includes(root.homePath + "/.calendars"))
                    paths.push(root.homePath + "/.calendars");
                root.calendarPaths = paths;
            }
        }
    }

    function getTasksByDate(currentDate) {
        if (!khalAvailable) {
            return [];
        }
        const res = [];

        const currentDay = currentDate.getDate();
        const currentMonth = currentDate.getMonth();
        const currentYear = currentDate.getFullYear();

        for (let i = 0; i < root.events.length; i++) {
            const taskDate = new Date(root.events[i]['startDate']);
            if (taskDate.getDate() === currentDay && taskDate.getMonth() === currentMonth && taskDate.getFullYear() === currentYear) {
                res.push(root.events[i]);
            }
        }

        return res;
    }

    function getEventsInWeek() {
        let result = [];
        const now = new Date();
        const currentConfiguredDayIndex = (now.getDay() - Config.options.time.firstDayOfWeek + 6) % 7;

        for (let i = 0; i < root.weekdays.length; i++) {
            const d = new Date(now);
            if (Config.options.cheatsheet.timetableTodayFirst) {
                d.setDate(d.getDate() + i);
            } else {
                d.setDate(d.getDate() - currentConfiguredDayIndex + i);
            }
            const events = this.getTasksByDate(d);
            const name_weekday = root.weekdays[d.getDay()];
            let obj = {
                "name": name_weekday,
                "events": []
            };
            events.forEach((evt, i) => {
                let start_time = Qt.formatDateTime(evt["startDate"], "hh:mm");
                let end_time = Qt.formatDateTime(evt["endDate"], "hh:mm");
                let title = evt["content"];
                obj["events"].push({
                    "start": start_time,
                    "end": end_time,
                    "title": title,
                    "color": evt['color'],
                    "description": evt['description'],
                    "uid": evt['uid'],
                    "calendar": evt['calendar'],
                    "sourceEvent": evt
                });
            });
            result.push(obj);
        }

        return result;
    }

    // Simple color list for events
    property var eventColors: [Appearance.m3colors.m3primary, Appearance.m3colors.m3secondary, Appearance.m3colors.m3tertiary, Appearance.colors.colPrimary, Appearance.colors.colSecondary, Appearance.colors.colTertiary]
    property int colorCounter: 0

    function getNextEventColor() {
        let color = eventColors[colorCounter % eventColors.length];
        colorCounter++;
        return color;
    }

    // ------------------------------------------------------------------
    // Fetch window
    // ------------------------------------------------------------------
    // khal is queried for a bounded date range. The window starts at -3/+3
    // months around today and only ever grows (see `ensureRangeCovers`), so
    // navigating far away in the calendar still yields events.

    function monthWindowStart(monthOffset) {
        const d = new Date();
        return new Date(d.getFullYear(), d.getMonth() + monthOffset, 1);
    }

    function monthWindowEnd(monthOffset) {
        const d = new Date();
        return new Date(d.getFullYear(), d.getMonth() + monthOffset + 1, 0);
    }

    property date rangeStart: root.monthWindowStart(-3)
    property date rangeEnd: root.monthWindowEnd(3)
    readonly property bool loading: getEventsProcess.running

    // Set when a reload is requested while a fetch is already in flight.
    property bool eventsReloadQueued: false

    // Rebuilds the khal command from the current window and starts the fetch.
    // `command` is assigned imperatively (no binding) so the window can change
    // without re-triggering a fetch on every intermediate value.
    function loadEvents() {
        if (!root.khalAvailable)
            return;
        if (getEventsProcess.running) {
            root.eventsReloadQueued = true;
            return;
        }
        getEventsProcess.command = ["khal", "list", "--json", "title", "--json", "start-date", "--json", "start-time", "--json", "end-time", "--json", "description", "--json", "calendar", "--json", "uid", "--json", "url", "--json", "location", "--json", "categories", "--json", "repeat-symbol", "--json", "status", "--json", "organizer", "--json", "all-day", "--json", "calendar-color", Qt.formatDate(root.rangeStart, "dd/MM/yyyy"), Qt.formatDate(root.rangeEnd, "dd/MM/yyyy")];
        getEventsProcess.running = true;
    }

    // Grows the fetch window so that `date` is covered, with 3 months of slack
    // in the direction that was extended. Never shrinks. Debounced so that
    // flicking through months does not spawn one khal process per month.
    function ensureRangeCovers(date) {
        if (!date)
            return;
        const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        let changed = false;
        if (d < root.rangeStart) {
            root.rangeStart = new Date(d.getFullYear(), d.getMonth() - 3, 1);
            changed = true;
        }
        if (d > root.rangeEnd) {
            root.rangeEnd = new Date(d.getFullYear(), d.getMonth() + 4, 0);
            changed = true;
        }
        if (changed)
            rangeDebounceTimer.restart();
    }

    Timer {
        id: rangeDebounceTimer
        interval: 150
        repeat: false
        onTriggered: root.loadEvents()
    }

    // ------------------------------------------------------------------
    // Per-day index
    // ------------------------------------------------------------------

    function dayKey(date) {
        if (!date)
            return "";
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    // true when the event spans a whole day: starts at 00:00 and ends at
    // 23:59 (khal's implicit all-day end) or 00:00.
    function isAllDayEvent(event) {
        if (!event || !event.startDate || !event.endDate)
            return false;
        if (event.allDay === true)
            return true;
        if (event.startDate.getHours() !== 0 || event.startDate.getMinutes() !== 0)
            return false;
        const endHours = event.endDate.getHours();
        const endMinutes = event.endDate.getMinutes();
        return (endHours === 23 && endMinutes === 59) || (endHours === 0 && endMinutes === 0);
    }

    // { "yyyy-MM-dd": [event, ...] } — all-day events first, then by start time.
    // khal always reports start and end on the same day, so one bucket per
    // event is enough (no multi-day expansion).
    readonly property var eventsByDay: {
        const map = {};
        const evts = root.events;
        if (!evts)
            return map;
        for (let i = 0; i < evts.length; i++) {
            const evt = evts[i];
            if (!evt || !evt.startDate)
                continue;
            const key = root.dayKey(evt.startDate);
            if (key.length === 0)
                continue;
            if (!map[key])
                map[key] = [];
            map[key].push(evt);
        }
        for (const key in map) {
            map[key].sort((a, b) => {
                const aRank = root.isAllDayEvent(a) ? 0 : 1;
                const bRank = root.isAllDayEvent(b) ? 0 : 1;
                if (aRank !== bRank)
                    return aRank - bRank;
                return a.startDate.getTime() - b.startDate.getTime();
            });
        }
        return map;
    }

    function eventsForDay(date) {
        return root.eventsByDay[root.dayKey(date)] ?? [];
    }

    // Process for loading events
    Process {
        id: getEventsProcess
        running: false
        stdout: StdioCollector {

            onStreamFinished: {
                root.colorCounter = 0;  // Reset color counter for each reload
                let events = [];
                let lines = this.text.split('\n');
                for (let line of lines) {
                    line = line.trim();
                    if (!line || line === "[]")
                        continue;
                    let dayEvents;
                    try {
                        dayEvents = JSON.parse(line);
                    } catch (error) {
                        console.warn("[CalendarService] Ignoring invalid khal JSON:", error.message);
                        continue;
                    }
                    for (let event of dayEvents) {
                        if (!event['start-date'])
                            continue;
                        let startDateParts = event['start-date'].split('/');
                        let startTimeParts = event['start-time'] ? event['start-time'].split(':').map(Number) : [0, 0];

                        let endTimeParts = event['end-time'] ? event['end-time'].split(':').map(Number) : [23, 59]; // event is the whole day if start and end time are not set

                        let startDate = new Date(parseInt(startDateParts[2]), parseInt(startDateParts[1]) - 1, parseInt(startDateParts[0]), parseInt(startTimeParts[0]), parseInt(startTimeParts[1]));

                        let endDate = new Date(parseInt(startDateParts[2]), parseInt(startDateParts[1]) - 1, parseInt(startDateParts[0]), parseInt(endTimeParts[0]), parseInt(endTimeParts[1]));

                        const rawCategories = event['categories'];
                        const categoryValues = Array.isArray(rawCategories)
                            ? rawCategories
                            : (rawCategories ? String(rawCategories).split(',') : []);
                        const categories = [];
                        let colorToken = "";
                        for (let value of categoryValues) {
                            const category = String(value).trim();
                            if (!category)
                                continue;
                            if (category.startsWith("ii/color=")) {
                                colorToken = category.substring("ii/color=".length);
                                continue;
                            }
                            if (!categories.includes(category))
                                categories.push(category);
                        }

                        // The existing chip renderer still consumes a QColor.
                        // Phase 2 switches this fallback to the token palette;
                        // retain it here while keeping the token lossless.
                        let eventColor = root.getNextEventColor();

                        events.push({
                            "content": event['title'],
                            "startDate": startDate,
                            "endDate": endDate,
                            "color": eventColor,
                            "description": event['description'] ?? "",
                            "calendar": event['calendar'] || '',
                            "uid": event['uid'] || '',
                            "url": event['url'] ?? "",
                            "location": event['location'] ?? "",
                            "categories": categories,
                            "colorToken": colorToken,
                            "repeatSymbol": event['repeat-symbol'] ?? "",
                            "status": event['status'] ?? "CONFIRMED",
                            "organizer": event['organizer'] ?? "",
                            "allDay": event['all-day'] === true || String(event['all-day']).toLowerCase() === "true",
                            "calendarColor": event['calendar-color'] ?? ""
                        });
                    }
                }
                root.events = events;
                root.eventsInWeek = root.getEventsInWeek();
            }
        }
        onExited: {
            if (root.eventsReloadQueued) {
                root.eventsReloadQueued = false;
                rangeDebounceTimer.restart();
            }
        }
    }

    Timer {
        id: interval
        running: false
        interval: 10
        repeat: true
        onTriggered: {
            root.loadEvents();
            interval.interval = 900000; // 15 minutes
        }
    }

    Process {
        id: vdirsyncerProcess
        command: ["vdirsyncer", "sync"]
        running: false
    }

    // A single helper process is serialized because khal owns one SQLite
    // index. Every event field stays JSON data on stdin, never a shell string.
    function enqueueCalendarRequest(payload, callback = null) {
        const queue = root.calendarRequestQueue.slice();
        queue.push({ payload: payload, callback: callback });
        root.calendarRequestQueue = queue;
        root.startNextCalendarRequest();
    }

    function startNextCalendarRequest() {
        if (calendarHelperProcess.running || root.calendarCurrentRequest || root.calendarRequestQueue.length === 0)
            return;
        root.calendarCurrentRequest = root.calendarRequestQueue[0];
        root.calendarRequestQueue = root.calendarRequestQueue.slice(1);
        calendarHelperProcess.replyReceived = false;
        calendarHelperProcess.stdinEnabled = true;
        calendarHelperProcess.running = true;
    }

    function finishCalendarRequest(reply) {
        const current = root.calendarCurrentRequest;
        root.calendarCurrentRequest = null;
        if (!reply || !reply.ok) {
            console.warn("[CalendarService] Calendar request failed:", String(reply?.error ?? "No response from calendar helper."));
        } else if (current?.payload?.op === "save" || current?.payload?.op === "deleteSeries" || current?.payload?.op === "deleteOccurrence" || current?.payload?.op === "overrideOccurrence" || current?.payload?.op === "splitSeries" || current?.payload?.op === "truncateSeries" || current?.payload?.op === "setCalendarColor") {
            vdirsyncerProcess.running = true;
            root.loadEvents();
            if (current?.payload?.op === "setCalendarColor")
                root.loadCalendarList();
        }
        if (typeof current?.callback === "function")
            current.callback(reply);
        Qt.callLater(root.startNextCalendarRequest);
    }

    function loadCalendarList() {
        root.enqueueCalendarRequest({ op: "calendars" }, reply => {
            if (!reply?.ok)
                return;
            root.calendars = reply.calendars ?? [];
            const writable = root.calendars.find(calendar => !calendar.readOnly);
            root.defaultCalendar = writable?.name ?? "";
        });
    }

    Process {
        id: calendarHelperProcess
        command: ["python3", root.icsHelperPath]
        stdinEnabled: true
        property bool replyReceived: false
        onRunningChanged: {
            if (running && root.calendarCurrentRequest) {
                write(JSON.stringify(root.calendarCurrentRequest.payload) + "\n");
                stdinEnabled = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let reply;
                try {
                    reply = JSON.parse(this.text.trim());
                } catch (error) {
                    reply = { ok: false, error: "Calendar helper returned invalid JSON: " + error.message };
                }
                calendarHelperProcess.replyReceived = true;
                root.finishCalendarRequest(reply);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim())
                    console.warn("[CalendarService] calendar helper:", this.text.trim());
            }
        }
        onExited: exitCode => {
            if (!calendarHelperProcess.replyReceived && root.calendarCurrentRequest)
                root.finishCalendarRequest({ ok: false, error: "Calendar helper exited with code " + exitCode + "." });
        }
    }

    function localIso(date, time = "00:00") {
        if (!date)
            return "";
        const normalizedTime = String(time || "00:00").length === 5 ? String(time) + ":00" : String(time);
        return Qt.formatDate(date, "yyyy-MM-dd") + "T" + normalizedTime;
    }

    function recurrenceIdForEvent(event) {
        if (!event?.startDate)
            return "";
        if (root.isAllDayEvent(event))
            return Qt.formatDate(event.startDate, "yyyy-MM-dd");
        return root.localIso(event.startDate, Qt.formatTime(event.startDate, "hh:mm:ss"));
    }

    function addItem(item) {
        if (!item?.content || !item?.date)
            return;
        root.addAllDayEvent(item.date, item.content, item.description ?? "");
    }

    function addEvent(date, startTime, endTime, title, description) {
        if (!root.khalAvailable || !date || !title)
            return;
        root.enqueueCalendarRequest({
            op: "save",
            calendar: root.defaultCalendar,
            event: {
                summary: String(title),
                description: String(description ?? ""),
                allDay: false,
                start: root.localIso(date, startTime || "09:00"),
                end: root.localIso(date, endTime || "10:00")
            }
        });
    }

    function addAllDayEvent(date, title, description) {
        if (!root.khalAvailable || !date || !title)
            return;
        const nextDay = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1);
        root.enqueueCalendarRequest({
            op: "save",
            calendar: root.defaultCalendar,
            event: {
                summary: String(title),
                description: String(description ?? ""),
                allDay: true,
                start: Qt.formatDate(date, "yyyy-MM-dd"),
                end: Qt.formatDate(nextDay, "yyyy-MM-dd")
            }
        });
    }

    function removeItem(item) {
        root.removeEventByUid(item?.uid ?? "");
    }

    function removeEventByUid(uid) {
        if (!uid)
            return;
        root.enqueueCalendarRequest({ op: "deleteSeries", uid: String(uid) });
    }

    // A summary is not an identifier. Callers that only have a title must
    // refresh and pick an event object first rather than risking a sibling.
    function removeEvent(title) {
        console.warn("[CalendarService] Refusing to delete an event by summary:", String(title ?? ""));
    }

    function readEvent(uid, callback) {
        if (uid)
            root.enqueueCalendarRequest({ op: "read", uid: String(uid) }, callback);
    }

    function saveEventFields(event, fields, scope = "all") {
        if (!event?.uid)
            return;
        const payload = { uid: String(event.uid) };
        for (const key in fields)
            payload[key] = fields[key];
        const recurrenceId = fields.recurrenceId || root.recurrenceIdForEvent(event);
        const request = scope === "this"
            ? { op: "overrideOccurrence", uid: String(event.uid), recurrenceId: recurrenceId, fields: payload }
            : scope === "future"
                ? { op: "splitSeries", uid: String(event.uid), recurrenceId: recurrenceId, fields: payload }
                : { op: "save", calendar: event.calendar ?? "", event: payload };
        root.enqueueCalendarRequest(request);
    }

    function createEventFields(calendar, fields) {
        root.enqueueCalendarRequest({ op: "save", calendar: calendar || root.defaultCalendar, event: fields });
    }

    function setCalendarColor(calendar, color) {
        if (!calendar)
            return;
        root.enqueueCalendarRequest({ op: "setCalendarColor", calendar: String(calendar), color: String(color ?? "") });
    }

    function deleteEventWithScope(event, scope = "all") {
        if (!event?.uid)
            return;
        const recurrenceId = root.recurrenceIdForEvent(event);
        const request = scope === "this"
            ? { op: "deleteOccurrence", uid: String(event.uid), recurrenceId: recurrenceId }
            : scope === "future"
                ? { op: "truncateSeries", uid: String(event.uid), recurrenceId: recurrenceId }
                : { op: "deleteSeries", uid: String(event.uid) };
        root.enqueueCalendarRequest(request);
    }

    function moveEvent(event, newDate) {
        if (!root.khalAvailable || !event?.uid || !newDate)
            return;
        const allDay = root.isAllDayEvent(event);
        const oldStart = event.startDate;
        const oldEnd = event.endDate;
        const movedStart = new Date(newDate.getFullYear(), newDate.getMonth(), newDate.getDate(), oldStart.getHours(), oldStart.getMinutes());
        const movedEnd = new Date(newDate.getFullYear(), newDate.getMonth(), newDate.getDate(), oldEnd.getHours(), oldEnd.getMinutes());
        if (!allDay && movedEnd <= movedStart)
            movedEnd.setDate(movedEnd.getDate() + 1);
        const nextDay = new Date(newDate.getFullYear(), newDate.getMonth(), newDate.getDate() + 1);
        root.enqueueCalendarRequest({
            op: "save",
            calendar: event.calendar ?? "",
            event: {
                uid: String(event.uid),
                allDay: allDay,
                start: allDay ? Qt.formatDate(newDate, "yyyy-MM-dd") : root.localIso(movedStart, Qt.formatTime(movedStart, "hh:mm")),
                end: allDay ? Qt.formatDate(nextDay, "yyyy-MM-dd") : root.localIso(movedEnd, Qt.formatTime(movedEnd, "hh:mm"))
            }
        });
    }

    function updateEvent(event, newDate, startTimeHHMM, endTimeHHMM, title, description, allDay) {
        if (!root.khalAvailable || !event?.uid)
            return;
        const base = newDate ?? event.startDate;
        const isAllDay = allDay === undefined || allDay === null ? root.isAllDayEvent(event) : !!allDay;
        const start = startTimeHHMM || Qt.formatTime(event.startDate, "hh:mm");
        const end = endTimeHHMM || Qt.formatTime(event.endDate, "hh:mm");
        const nextDay = new Date(base.getFullYear(), base.getMonth(), base.getDate() + 1);
        root.enqueueCalendarRequest({
            op: "save",
            calendar: event.calendar ?? "",
            event: {
                uid: String(event.uid),
                summary: title?.length ? String(title) : String(event.content ?? ""),
                description: description ?? String(event.description ?? ""),
                allDay: isAllDay,
                start: isAllDay ? Qt.formatDate(base, "yyyy-MM-dd") : root.localIso(base, start),
                end: isAllDay ? Qt.formatDate(nextDay, "yyyy-MM-dd") : root.localIso(base, end)
            }
        });
    }

    Process {
        id: icsImportProcess
        property string targetPath: ""
        command: ["python3", Directories.scriptPath + "/email/import_ics.py", targetPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    if (data.success) {
                        console.log("[CalendarService] ICS imported successfully, events:", data.event_count);
                        refreshTimer.start();
                    } else {
                        console.warn("[CalendarService] ICS import failed:", data.error);
                    }
                } catch (e) {
                    console.warn("[CalendarService] ICS import response parse error:", e, this.text);
                }
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 1500
        repeat: false
        onTriggered: {
            vdirsyncerProcess.running = true;
            root.loadEvents();
        }
    }

    function importFromIcs(path, autoDelete) {
        if (!root.khalAvailable)
            return;
        console.log("[CalendarService] Importing ICS:", path, "autoDelete:", !!autoDelete);
        icsImportProcess.command = ["python3", Directories.scriptPath + "/email/import_ics.py", path, autoDelete ? "true" : "false"];
        icsImportProcess.running = true;
    }

    Connections {
        target: Config.options.cheatsheet
        function onTimetableTodayFirstChanged() {
            root.eventsInWeek = root.getEventsInWeek();
        }
    }
}
