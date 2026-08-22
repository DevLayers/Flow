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
                    "calendar": evt['calendar']
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

    // Process for loading events
    Process {
        id: getEventsProcess
        running: false
        // get events for 3 months - fetch uid for unique identification
        command: ["khal", "list", "--json", "title", "--json", "start-date", "--json", "start-time", "--json", "end-time", "--json", "description", "--json", "calendar", "--json", "uid", Qt.formatDate((() => {
                    let d = new Date();
                    d.setMonth(d.getMonth() - 3);
                    return d;
                })(), "dd/MM/yyyy"), Qt.formatDate((() => {
                    let d = new Date();
                    d.setMonth(d.getMonth() + 3);
                    return d;
                })(), "dd/MM/yyyy")]
        stdout: StdioCollector {

            onStreamFinished: {
                root.colorCounter = 0;  // Reset color counter for each reload
                let events = [];
                let lines = this.text.split('\n');
                for (let line of lines) {
                    line = line.trim();
                    if (!line || line === "[]")
                        continue;
                    let dayEvents = JSON.parse(line);
                    for (let event of dayEvents) {
                        let startDateParts = event['start-date'].split('/');
                        let startTimeParts = event['start-time'] ? event['start-time'].split(':').map(Number) : [0, 0];

                        let endTimeParts = event['end-time'] ? event['end-time'].split(':').map(Number) : [23, 59]; // event is the whole day if start and end time are not set

                        let startDate = new Date(parseInt(startDateParts[2]), parseInt(startDateParts[1]) - 1, parseInt(startDateParts[0]), parseInt(startTimeParts[0]), parseInt(startTimeParts[1]));

                        let endDate = new Date(parseInt(startDateParts[2]), parseInt(startDateParts[1]) - 1, parseInt(startDateParts[0]), parseInt(endTimeParts[0]), parseInt(endTimeParts[1]));

                        // Simple rotating color assignment
                        let eventColor = root.getNextEventColor();

                        events.push({
                            "content": event['title'],
                            "startDate": startDate,
                            "endDate": endDate,
                            "color": eventColor,
                            "description": event['description'] ?? "",
                            "calendar": event['calendar'] || '',
                            "uid": event['uid'] || ''
                        });
                    }
                }
                root.events = events;
                root.eventsInWeek = root.getEventsInWeek();
            }
        }
    }

    Timer {
        id: interval
        running: false
        interval: 10
        repeat: true
        onTriggered: {
            getEventsProcess.running = true;
            interval.interval = 900000; // 15 minutes
        }
    }

    Process {
        id: vdirsyncerProcess
        command: ["vdirsyncer", "sync"]
        running: false
    }

    Process {
        id: khalAddTaskProcess
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[CalendarService] Event added successfully");
                vdirsyncerProcess.running = true;
                getEventsProcess.running = true;
            } else {
                console.log("[CalendarService] Failed to add event, exit code: " + exitCode);
            }
        }
    }

    function addItem(item) {
        let title = item['content'];
        let formattedDate = Qt.formatDate(item['date'], "dd/MM/yyyy");
        khalAddTaskProcess.command = ["khal", "new", formattedDate, title];
        khalAddTaskProcess.running = true;
    }

    // Create a timed event with start/end times
    // date: JS Date object for the day
    // startTime: string "HH:MM"
    // endTime: string "HH:MM"
    // title: string
    // description: string (optional)
    function addEvent(date, startTime, endTime, title, description) {
        if (!root.khalAvailable) {
            console.log("[CalendarService] khal not available, cannot create event");
            return;
        }

        let formattedDate = Qt.formatDate(date, "dd/MM/yyyy");
        let summary = title;
        if (description && description.length > 0) {
            summary = title + " :: " + description;
        }

        khalAddTaskProcess.command = ["khal", "new", formattedDate, startTime, endTime, summary];
        console.log("[CalendarService] Creating event:", khalAddTaskProcess.command.join(" "));
        khalAddTaskProcess.running = true;
    }

    Process {
        id: khalRemoveProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) {
                    console.log("[CalendarService] remove stdout:", this.text.trim());
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) {
                    console.error("[CalendarService] remove stderr:", this.text.trim());
                }
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[CalendarService] Event removed successfully");
                vdirsyncerProcess.running = true;
                getEventsProcess.running = true;
            } else {
                console.log("[CalendarService] Failed to remove event, exit code: " + exitCode);
            }
        }
    }

    function removeItem(item) {
        root.removeEvent(item['content']);
    }

    // Remove a timed event by UID (unique identifier)
    function removeEventByUid(uid) {
        if (!uid || uid.length === 0)
            return;

        khalRemoveProcess.command = root.buildRemoveCommand("UID:" + uid);
        console.log("[CalendarService] Removing event by UID:", uid);
        khalRemoveProcess.running = true;
    }

    // Deletes every .ics under the known calendar dirs whose content contains `needle`
    // (fixed-string match), then purges the matching rows from khal's cache db so the event
    // disappears immediately instead of waiting for khal's next re-sync.
    // Calendar paths may be globs (khal "discover" collections), hence the unquoted `$g`.
    readonly property string removeScript: [
        'needle="$1"; shift',
        'shopt -s nullglob',
        'for g in "$@"; do for d in $g; do',
        '  [ -d "$d" ] || continue',
        '  find "$d" -type f -name "*.ics" -exec grep -lF -- "$needle" {} + | xargs -r rm -f',
        'done; done',
        "sql_needle=${needle//\\'/\\'\\'}",
        'sqlite3 "$db" "DELETE FROM events WHERE item LIKE \'%${sql_needle}%\';"'
    ].join("\n")

    function buildRemoveCommand(needle) {
        return ["env", "db=" + root.khalDbPath, "bash", "-c", root.removeScript, "khal-remove", needle].concat(root.calendarPaths);
    }

    function removeEvent(title) {
        if (!title || title.length === 0)
            return;

        khalRemoveProcess.command = root.buildRemoveCommand("SUMMARY:" + title);
        console.log("[CalendarService] Removing event:", title);
        khalRemoveProcess.running = true;
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
            getEventsProcess.running = true;
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
