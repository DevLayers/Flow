import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings for the per-app usage history.
 *
 * Split by what a change costs: the display options take effect the next time the
 * overlay is opened, while everything under Collection is a command-line flag the
 * sampler reads once, so touching one relaunches it. That is stated on the section
 * rather than left to be discovered.
 */
ContentPage {
    id: page
    forceWidth: false

    readonly property var opts: Config.options.appStats

    function humanBytes(bytes) {
        if (bytes < 0)
            return "—";
        if (bytes < 1024)
            return `${bytes} B`;
        if (bytes < 1024 * 1024)
            return `${Math.round(bytes / 1024)} KiB`;
        return `${(bytes / 1048576).toFixed(1)} MiB`;
    }

    Component.onCompleted: AppStats.measureStorage()

    KeyboardShortcutBox {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        text: Translation.tr("Toggle app usage stats")
        keys: ["Super", "U"]
    }

    ContentSection {
        title: Translation.tr("General")
        icon: "bar_chart"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "monitoring"
                text: Translation.tr("Collect usage statistics")
                checked: page.opts.enable
                onCheckedChanged: {
                    Config.options.appStats.enable = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Turning this off stops the sampler but keeps the history already recorded")
                }
            }

            ConfigSwitch {
                buttonIcon: "dashboard"
                text: Translation.tr("Load the usage overlay")
                checked: page.opts.overlayEnabled
                onCheckedChanged: {
                    Config.options.appStats.overlayEnabled = checked;
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Overlay")
        icon: "tune"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "history"
                text: Translation.tr("Reopen on the last view used")
                checked: page.opts.rememberLastView
                onCheckedChanged: {
                    Config.options.appStats.rememberLastView = checked;
                }

                StyledToolTip {
                    text: Translation.tr("The period and metric are remembered; the overlay always opens on the current day, week or month")
                }
            }

            ConfigSwitch {
                buttonIcon: "select_check_box"
                text: Translation.tr("Keep the selected app between openings")
                checked: page.opts.keepSelection
                onCheckedChanged: {
                    Config.options.appStats.keepSelection = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "calendar_view_week"
                text: Translation.tr("Weeks start on Monday")
                checked: page.opts.weekStartsMonday
                onCheckedChanged: {
                    Config.options.appStats.weekStartsMonday = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "trending_up"
                text: Translation.tr("Compare with the previous period")
                checked: page.opts.showComparison
                onCheckedChanged: {
                    Config.options.appStats.showComparison = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Adds a percent change under the headline figure. Reads the period before the one on screen as well, which doubles the files a month view parses")
                }
            }

            ConfigSwitch {
                buttonIcon: "terminal"
                text: Translation.tr("Count background services")
                checked: page.opts.showHeadless
                onCheckedChanged: {
                    Config.options.appStats.showHeadless = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Processes owning no window. Recorded either way; this decides whether they appear in the list and the totals")
                }
            }
        }

        Item {
            Layout.preferredHeight: 8
        }

        ContentSubsection {
            title: Translation.tr("Opens on")
            icon: "calendar_month"
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: page.opts.defaultGranularity
                onSelected: newValue => {
                    Config.options.appStats.defaultGranularity = newValue;
                }
                options: [
                    {
                        "displayName": Translation.tr("Day"),
                        "value": "day"
                    },
                    {
                        "displayName": Translation.tr("Week"),
                        "value": "week"
                    },
                    {
                        "displayName": Translation.tr("Month"),
                        "value": "month"
                    }
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Opens showing")
            icon: "leaderboard"
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: page.opts.defaultMetric
                onSelected: newValue => {
                    Config.options.appStats.defaultMetric = newValue;
                }
                options: [
                    {
                        "displayName": Translation.tr("Screen time"),
                        "value": "fg"
                    },
                    {
                        "displayName": Translation.tr("Focused"),
                        "value": "focus"
                    },
                    {
                        "displayName": Translation.tr("Energy"),
                        "value": "energy"
                    },
                    {
                        "displayName": Translation.tr("CPU"),
                        "value": "cpu"
                    },
                    {
                        "displayName": Translation.tr("GPU"),
                        "value": "gpu"
                    }
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("List")
            icon: "filter_alt"
            Layout.fillWidth: true

            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Hide apps under (seconds)")
                value: page.opts.minDurationSec
                from: 0
                to: 3600
                stepSize: 30
                onValueChanged: {
                    Config.options.appStats.minDurationSec = value;
                }

                StyledToolTip {
                    text: Translation.tr("Applies to the list only, and only to the metrics measured in time. The totals still count every app")
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("History")
        icon: "database"

        ContentSubsection {
            title: Translation.tr("How long data is kept")
            icon: "auto_delete"
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: page.opts.retentionMode
                onSelected: newValue => {
                    Config.options.appStats.retentionMode = newValue;
                }
                options: [
                    {
                        "displayName": Translation.tr("Keep the previous month"),
                        "value": "previousMonth"
                    },
                    {
                        "displayName": Translation.tr("Fixed number of days"),
                        "value": "fixed"
                    }
                ]
            }

            ConfigSpinBox {
                icon: "event_repeat"
                text: page.opts.retentionMode === "previousMonth" ? Translation.tr("At least this many days") : Translation.tr("Days kept")
                value: page.opts.retentionDays
                from: 1
                to: 365
                stepSize: 1
                onValueChanged: {
                    Config.options.appStats.retentionDays = value;
                }
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: {
                    const oldest = AppStats.oldestDate();
                    if (page.opts.retentionMode !== "previousMonth")
                        return Translation.tr("Keeping from %1 onwards.").arg(oldest);
                    return Translation.tr("Keeping from %1 onwards — enough that last month is always whole, so the window slides between 31 and 62 days.").arg(oldest);
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Stored right now")
            icon: "folder_open"
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                text: AppStats.storedDays < 0 ? Translation.tr("Measuring…") : Translation.tr("%1 days, %2").arg(AppStats.storedDays).arg(page.humanBytes(AppStats.storedBytes))
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButton {
                    implicitHeight: 34
                    horizontalPadding: 16
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    buttonText: Translation.tr("Write now")
                    onClicked: {
                        AppStats.refresh();
                        AppStats.measureStorage();
                    }

                    StyledToolTip {
                        text: Translation.tr("Flush the current hour to disk instead of waiting for the next write")
                    }
                }

                RippleButton {
                    implicitHeight: 34
                    horizontalPadding: 16
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    buttonText: Translation.tr("Open folder")
                    onClicked: AppStats.openStateDir()
                }

                RippleButton {
                    implicitHeight: 34
                    horizontalPadding: 16
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    buttonText: Translation.tr("Delete history")
                    onClicked: deleteDialog.show = true
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Collection")
        icon: "settings_input_component"
        tooltip: Translation.tr("The sampler reads these once when it starts, so changing any of them restarts it")

        ContentSubsection {
            title: Translation.tr("Energy source")
            icon: "bolt"
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: page.opts.energySource
                onSelected: newValue => {
                    Config.options.appStats.energySource = newValue;
                }
                options: [
                    {
                        "displayName": Translation.tr("Automatic"),
                        "value": "auto"
                    },
                    {
                        "displayName": Translation.tr("RAPL counters"),
                        "value": "rapl"
                    },
                    {
                        "displayName": Translation.tr("Battery drain"),
                        "value": "battery"
                    },
                    {
                        "displayName": Translation.tr("None"),
                        "value": "none"
                    }
                ]
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: Translation.tr("RAPL needs the udev rule from the sampler's README. Battery drain is much cruder and reads zero on AC.")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Sample every (ms)")
                value: page.opts.sampleIntervalMs
                from: 1000
                to: 60000
                stepSize: 1000
                onValueChanged: {
                    Config.options.appStats.sampleIntervalMs = value;
                }

                StyledToolTip {
                    text: Translation.tr("How often the counters are read. Shorter means finer window attribution and more CPU")
                }
            }

            ConfigSpinBox {
                icon: "save"
                text: Translation.tr("Write to disk every (ms)")
                value: page.opts.flushIntervalMs
                from: 5000
                to: 600000
                stepSize: 5000
                onValueChanged: {
                    Config.options.appStats.flushIntervalMs = value;
                }
            }

            ConfigSpinBox {
                icon: "motion_sensor_idle"
                text: Translation.tr("Pause after idle for (seconds)")
                value: page.opts.idleTimeoutSec
                from: 0
                to: 3600
                stepSize: 30
                onValueChanged: {
                    Config.options.appStats.idleTimeoutSec = value;
                }

                StyledToolTip {
                    text: Translation.tr("Foreground time stops accruing once there has been no input for this long. 0 keeps it running")
                }
            }

            ConfigSpinBox {
                icon: "stadia_controller"
                text: Translation.tr("Full GPU rescan every (samples)")
                value: page.opts.gpuFullEvery
                from: 1
                to: 600
                stepSize: 5
                onValueChanged: {
                    Config.options.appStats.gpuFullEvery = value;
                }

                StyledToolTip {
                    text: Translation.tr("Only a backstop — a new window forces a rescan immediately. Lower values cost a full sweep of every process's file descriptors")
                }
            }

            ConfigSwitch {
                buttonIcon: "terminal"
                text: Translation.tr("Record background services")
                checked: page.opts.trackHeadless
                onCheckedChanged: {
                    Config.options.appStats.trackHeadless = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Off means processes with no window are never written down, and cannot be shown later")
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Sampler")
            icon: "monitor_heart"
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                text: {
                    if (!AppStats.enabled)
                        return Translation.tr("Turned off.");
                    if (!AppStats.running)
                        return Translation.tr("Not running — check that the binary is built at scripts/appStats/app_stats.");
                    switch (AppStats.source) {
                    case "rapl":
                        return Translation.tr("Running, reading energy from RAPL counters.");
                    case "battery":
                        return Translation.tr("Running, estimating energy from battery drain.");
                    default:
                        return Translation.tr("Running without an energy source; watt-hours will stay empty.");
                    }
                }
            }
        }
    }

    WindowDialog {
        id: deleteDialog
        parent: page.parent ? page.parent : page
        anchors.fill: parent
        show: false
        backgroundWidth: 360
        onDismiss: show = false
        z: 100000

        WindowDialogTitle {
            text: Translation.tr("Delete usage history?")
        }

        WindowDialogParagraph {
            text: Translation.tr("Every day file is removed. Collection carries on, so today's starts filling again at the next write.")
        }

        WindowDialogButtonRow {
            DialogButton {
                buttonText: Translation.tr("Cancel")
                onClicked: deleteDialog.show = false
            }
            DialogButton {
                buttonText: Translation.tr("Delete")
                onClicked: {
                    AppStats.clearHistory();
                    deleteDialog.show = false;
                }
            }
        }
    }
}
