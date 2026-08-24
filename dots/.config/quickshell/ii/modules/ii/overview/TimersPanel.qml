pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: 0
    property int displayClockTick: 0

    readonly property var countdowns: Array.from(TimerService.countdowns ?? [])
    readonly property var rows: root.filteredRows()
    readonly property var selectedRow: root.selectedIndex >= 0 && root.selectedIndex < root.rows.length
        ? root.rows[root.selectedIndex]
        : null
    readonly property string statusText: root.selectedRow
        ? String(root.selectedRow.title) + " · " + root.valueFor(root.selectedRow)
        : Translation.tr("No timer actions match")

    implicitWidth: Config.options.search.appearance.panelWidth
    implicitHeight: scaffold.implicitHeight

    function formatSeconds(seconds) {
        const safe = Math.max(0, Number(seconds) || 0);
        return String(Math.floor(safe / 60)).padStart(2, "0") + ":" + String(Math.floor(safe % 60)).padStart(2, "0");
    }

    function allRows() {
        const output = [];
        if (Config.options.search.modules.timers.showPomodoro) {
            output.push({
                id: "pomodoro",
                kind: "pomodoro",
                icon: TimerService.pomodoroRunning ? "pause_circle" : "timelapse",
                title: TimerService.pomodoroLongBreak
                    ? Translation.tr("Long break")
                    : (TimerService.pomodoroBreak ? Translation.tr("Pomodoro break") : Translation.tr("Pomodoro focus")),
                subtitle: Translation.tr("Cycle %1 of %2").arg(String(TimerService.pomodoroCycle + 1)).arg(String(TimerService.cyclesBeforeLongBreak)),
                value: "",
                action: TimerService.pomodoroRunning ? Translation.tr("Pause") : Translation.tr("Start"),
                searchable: "pomodoro focus break cycle"
            });
        }

        const presets = Array.from(Config.options.search.modules.timers.quickPresets ?? []);
        for (let index = 0; index < presets.length; index++) {
            const minutes = Number(presets[index]);
            output.push({
                id: "preset-" + String(minutes),
                kind: "preset",
                minutes: minutes,
                icon: "timer",
                title: Translation.tr("%1 minute timer").arg(String(minutes)),
                subtitle: Translation.tr("Quick timer preset"),
                value: Translation.tr("%1m").arg(String(minutes)),
                action: Translation.tr("Create"),
                searchable: String(minutes) + " quick preset timer"
            });
        }

        if (Config.options.search.modules.timers.showStopwatch) {
            output.push({
                id: "stopwatch",
                kind: "stopwatch",
                icon: TimerService.stopwatchRunning ? "pause_circle" : "timer",
                title: Translation.tr("Stopwatch"),
                subtitle: TimerService.stopwatchRunning ? Translation.tr("Running") : Translation.tr("Paused"),
                value: "",
                action: TimerService.stopwatchRunning ? Translation.tr("Pause") : Translation.tr("Start"),
                searchable: "stopwatch chronometer cronometro"
            });
        }

        for (let index = 0; index < root.countdowns.length; index++) {
            const countdown = root.countdowns[index];
            output.push({
                id: String(countdown.id),
                kind: "countdown",
                countdown: countdown,
                icon: countdown.notified ? "notifications_off" : "hourglass_top",
                title: String(countdown.label ?? Translation.tr("Timer")),
                subtitle: countdown.notified ? Translation.tr("Finished") : Translation.tr("Countdown"),
                value: "",
                action: countdown.notified ? Translation.tr("Dismiss") : Translation.tr("Cancel"),
                searchable: String(countdown.label ?? "") + " countdown timer"
            });
        }

        if (Config.options.search.modules.timers.showAlarms) {
            const alarms = Array.from(AlarmService.alarms ?? []);
            for (let index = 0; index < alarms.length; index++) {
                const alarm = alarms[index];
                output.push({
                    id: "alarm-" + String(index),
                    kind: "alarm",
                    alarmIndex: index,
                    icon: alarm.enabled ? "alarm" : "alarm_off",
                    title: String(alarm.label ?? Translation.tr("Alarm")),
                    subtitle: alarm.enabled ? Translation.tr("Alarm enabled") : Translation.tr("Alarm disabled"),
                    value: String(alarm.time ?? ""),
                    action: alarm.enabled ? Translation.tr("Disable") : Translation.tr("Enable"),
                    searchable: String(alarm.label ?? "") + " " + String(alarm.time ?? "") + " alarm"
                });
            }
        }
        return output;
    }

    function valueFor(row) {
        if (!row)
            return "";
        const tick = root.displayClockTick;
        if (row.kind === "pomodoro")
            return root.formatSeconds(TimerService.pomodoroSecondsLeft);
        if (row.kind === "stopwatch")
            return root.formatSeconds(Math.floor((TimerService.stopwatchRunning
                ? TimerService.getCurrentTimeIn10ms() - TimerService.stopwatchStart
                : TimerService.stopwatchTime) / 100));
        if (row.kind === "countdown") {
            return root.formatSeconds(TimerService.countdownSecondsLeft(row.countdown));
        }
        return String(row.value ?? "");
    }

    function filteredRows() {
        const terms = root.searchQuery.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
        const values = root.allRows();
        if (terms.length === 0 || /^\d+\s*(m|min|mins|minute|minutes)?$/i.test(root.searchQuery.trim()))
            return values;
        return values.filter(row => {
            const text = [row.title, row.subtitle, row.value, row.searchable].join(" ").toLocaleLowerCase();
            return terms.every(term => text.includes(term));
        });
    }

    function clampSelection() {
        root.selectedIndex = root.rows.length === 0
            ? -1
            : Math.max(0, Math.min(root.selectedIndex, root.rows.length - 1));
    }

    function navigateUp(): bool {
        if (root.selectedIndex <= 0)
            return false;
        root.selectedIndex--;
        timerList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateDown(): bool {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.rows.length - 1)
            return false;
        root.selectedIndex++;
        timerList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function activateSelected(): bool {
        const row = root.selectedRow;
        if (!row)
            return false;
        if (row.kind === "pomodoro")
            TimerService.togglePomodoro();
        else if (row.kind === "preset")
            TimerService.addCountdown(row.minutes);
        else if (row.kind === "stopwatch")
            TimerService.toggleStopwatch();
        else if (row.kind === "countdown")
            TimerService.removeCountdown(row.countdown.id);
        else if (row.kind === "alarm")
            AlarmService.toggleAlarm(row.alarmIndex);
        else
            return false;
        return true;
    }

    function secondaryActivateSelected(): bool {
        const row = root.selectedRow;
        if (!row)
            return false;
        if (row.kind === "pomodoro") {
            TimerService.resetPomodoro();
            return true;
        }
        if (row.kind === "stopwatch") {
            TimerService.stopwatchReset();
            return true;
        }
        return false;
    }

    function createFromQuery(): bool {
        const match = root.searchQuery.trim().match(/^(\d+)\s*(m|min|mins|minute|minutes)?$/i);
        if (!match)
            return false;
        TimerService.addCountdown(Number(match[1]));
        return true;
    }

    function focusInput(): bool { return false; }

    onRowsChanged: root.clampSelection()
    onSearchQueryChanged: root.selectedIndex = 0

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.displayClockTick++
    }

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Timers")
        icon: "timer"
        accent: true
        showStatus: true
        statusText: root.statusText
        primaryHint: ({ label: root.selectedRow?.action ?? Translation.tr("Run"), keys: ["↵"] })
        hints: [
            { label: Translation.tr("Reset"), keys: ["Ctrl", "↵"] },
            { label: Translation.tr("Create typed minutes"), keys: ["Ctrl", "N"] }
        ]

        ListView {
            id: timerList
            width: parent.width
            height: parent.height
            clip: true
            reuseItems: true
            spacing: Appearance.sizes.elevationMargin / 2
            model: root.rows

            delegate: RippleButton {
                required property int index
                required property var modelData
                width: timerList.width
                implicitHeight: timerContent.implicitHeight + Appearance.sizes.elevationMargin * 2
                buttonRadius: Appearance.rounding.normal
                colBackground: root.selectedIndex === index
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colSurfaceContainerHigh
                colBackgroundHover: root.selectedIndex === index
                    ? Appearance.colors.colPrimaryContainerHover
                    : Appearance.colors.colSurfaceContainerHighHover
                colRipple: root.selectedIndex === index
                    ? Appearance.colors.colPrimaryContainerActive
                    : Appearance.colors.colSurfaceContainerHighActive
                onClicked: {
                    root.selectedIndex = index;
                    root.activateSelected();
                }

                RowLayout {
                    id: timerContent
                    anchors.fill: parent
                    anchors.margins: Appearance.sizes.elevationMargin
                    spacing: Appearance.sizes.elevationMargin

                    MaterialSymbol {
                        text: modelData.icon
                        iconSize: Appearance.font.pixelSize.large
                        color: root.selectedIndex === index
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.sizes.elevationMargin / 4

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.title
                            elide: Text.ElideRight
                            font.weight: Font.DemiBold
                            color: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.subtitle
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colSubtext
                        }
                    }

                    StyledText {
                        text: root.valueFor(modelData)
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: root.selectedIndex === index
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnSurface
                    }

                    StyledText {
                        text: modelData.action
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: root.selectedIndex === index
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colPrimary
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.rows.length === 0
                text: Translation.tr("No timer actions match")
                color: Appearance.colors.colSubtext
            }
        }
    }
}
