pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: 0

    readonly property var countdowns: Array.from(TimerService.countdowns ?? [])
    readonly property var selectedCountdown: root.selectedIndex >= 0 && root.selectedIndex < root.countdowns.length
        ? root.countdowns[root.selectedIndex]
        : null
    readonly property string statusText: root.selectedCountdown
        ? `${root.selectedCountdown.label} · ${root.formatSeconds(TimerService.countdownSecondsLeft(root.selectedCountdown))}`
        : TimerService.pomodoroRunning
            ? Translation.tr("Pomodoro running")
            : Translation.tr("Ready")

    implicitWidth: 720
    implicitHeight: scaffold.implicitHeight

    function formatSeconds(seconds) {
        const safe = Math.max(0, Number(seconds) || 0);
        return String(Math.floor(safe / 60)).padStart(2, "0") + ":" + String(safe % 60).padStart(2, "0");
    }

    function clampSelection() {
        if (root.countdowns.length === 0) {
            root.selectedIndex = -1;
            return;
        }
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.countdowns.length - 1));
    }

    function navigateUp(): bool {
        if (root.selectedIndex <= 0)
            return false;
        root.selectedIndex--;
        countdownList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateDown(): bool {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.countdowns.length - 1)
            return false;
        root.selectedIndex++;
        countdownList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function activateSelected(): bool {
        if (root.selectedCountdown) {
            TimerService.removeCountdown(root.selectedCountdown.id);
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            return true;
        }
        TimerService.togglePomodoro();
        return true;
    }

    function createFromQuery(): bool {
        const match = root.searchQuery.trim().match(/^(\d+)\s*(m|min|mins|minute|minutes)?$/i);
        if (!match)
            return false;
        TimerService.addCountdown(Number(match[1]));
        root.searchQuery = "";
        return true;
    }

    function focusInput(): bool {
        return false;
    }

    onCountdownsChanged: root.clampSelection()

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Timers")
        icon: "timer"
        accent: true
        statusText: root.statusText
        primaryHint: ({ label: root.selectedCountdown ? Translation.tr("Dismiss") : (TimerService.pomodoroRunning ? Translation.tr("Pause") : Translation.tr("Start")), keys: ["↵"] })
        hints: [{ label: Translation.tr("Create typed minutes"), keys: ["Ctrl", "N"] }]

        ColumnLayout {
            width: parent.width
            spacing: Appearance.sizes.elevationMargin

            RowLayout {
                Layout.fillWidth: true
                visible: Config.options.search.modules.timers.showPomodoro
                spacing: Appearance.sizes.elevationMargin

                Item {
                    Layout.preferredWidth: Appearance.sizes.elevationMargin * 7
                    Layout.preferredHeight: Appearance.sizes.elevationMargin * 7

                    CircularProgress {
                        anchors.centerIn: parent
                        implicitSize: parent.width
                        lineWidth: Appearance.sizes.elevationMargin / 2
                        value: TimerService.pomodoroLapDuration > 0
                            ? TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration
                            : 0
                        colPrimary: Appearance.colors.colPrimary
                        colSecondary: Appearance.colors.colSurfaceContainerHigh
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: root.formatSeconds(TimerService.pomodoroSecondsLeft)
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurface
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: TimerService.pomodoroLongBreak
                            ? Translation.tr("Long break")
                            : (TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Pomodoro · Focus"))
                        color: Appearance.colors.colOnSurface
                    }

                    StyledText {
                        text: Translation.tr("Cycle %1 of %2").arg(String(TimerService.pomodoroCycle + 1)).arg(String(TimerService.cyclesBeforeLongBreak))
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                RippleButton {
                    implicitWidth: pomodoroLabel.implicitWidth + Appearance.sizes.elevationMargin * 2
                    implicitHeight: pomodoroLabel.implicitHeight + Appearance.sizes.elevationMargin
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    onClicked: TimerService.togglePomodoro()

                    StyledText {
                        id: pomodoroLabel
                        anchors.centerIn: parent
                        text: TimerService.pomodoroRunning ? Translation.tr("Pause") : Translation.tr("Start")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Config.options.search.modules.timers.quickPresets.length > 0
                spacing: Appearance.sizes.elevationMargin / 2

                Repeater {
                    model: Config.options.search.modules.timers.quickPresets

                    delegate: RippleButton {
                        required property int index
                        required property int modelData
                        implicitWidth: presetLabel.implicitWidth + Appearance.sizes.elevationMargin * 2
                        implicitHeight: presetLabel.implicitHeight + Appearance.sizes.elevationMargin
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colSurfaceContainerHigh
                        colBackgroundHover: Appearance.colors.colSurfaceContainerHighHover
                        colRipple: Appearance.colors.colSurfaceContainerHighActive
                        onClicked: TimerService.addCountdown(modelData)

                        StyledText {
                            id: presetLabel
                            anchors.centerIn: parent
                            text: Translation.tr("%1m").arg(String(modelData))
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnSurface
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Config.options.search.modules.timers.showStopwatch
                spacing: Appearance.sizes.elevationMargin

                MaterialSymbol {
                    text: "timer"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.formatSeconds(Math.floor(TimerService.stopwatchTime / 100))
                    color: Appearance.colors.colOnSurface
                }

                RippleButton {
                    implicitWidth: stopwatchLabel.implicitWidth + Appearance.sizes.elevationMargin * 2
                    implicitHeight: stopwatchLabel.implicitHeight + Appearance.sizes.elevationMargin
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSurfaceContainerHigh
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHighHover
                    colRipple: Appearance.colors.colSurfaceContainerHighActive
                    onClicked: TimerService.toggleStopwatch()

                    StyledText {
                        id: stopwatchLabel
                        anchors.centerIn: parent
                        text: TimerService.stopwatchRunning ? Translation.tr("Pause") : Translation.tr("Start")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnSurface
                    }
                }
            }

            ListView {
                id: countdownList
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.sizes.elevationMargin * 14
                clip: true
                spacing: Appearance.sizes.elevationMargin / 2
                model: root.countdowns

                delegate: RippleButton {
                    required property int index
                    required property var modelData
                    width: countdownList.width
                    implicitHeight: countdownContent.implicitHeight + Appearance.sizes.elevationMargin * 2
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
                        id: countdownContent
                        anchors.fill: parent
                        anchors.margins: Appearance.sizes.elevationMargin

                        MaterialSymbol {
                            text: modelData.notified ? "notifications_off" : "timer"
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.label
                            elide: Text.ElideRight
                            color: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }

                        StyledText {
                            text: root.formatSeconds(TimerService.countdownSecondsLeft(modelData))
                            color: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colSubtext
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.countdowns.length === 0
                    text: Translation.tr("Choose a quick timer or type minutes and press Ctrl+N")
                    color: Appearance.colors.colSubtext
                }
            }

            Repeater {
                model: Config.options.search.modules.timers.showAlarms
                    ? Array.from(AlarmService.alarms ?? []).slice(0, 2)
                    : []

                delegate: RippleButton {
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: alarmContent.implicitHeight + Appearance.sizes.elevationMargin
                    buttonRadius: Appearance.rounding.normal
                    colBackground: Appearance.colors.colSurfaceContainerHigh
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHighHover
                    colRipple: Appearance.colors.colSurfaceContainerHighActive
                    onClicked: AlarmService.toggleAlarm(index)

                    RowLayout {
                        id: alarmContent
                        anchors.fill: parent
                        anchors.margins: Appearance.sizes.elevationMargin / 2

                        MaterialSymbol {
                            text: modelData.enabled ? "alarm" : "alarm_off"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${modelData.time} · ${modelData.label}`
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnSurface
                        }
                    }
                }
            }
        }
    }
}
