import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root

    forceWidth: false
    property bool showBackButton: false
    signal goBack()

    function toggleOffset(offset, checked) {
        const current = Array.from(Config.options.calendar.timetable.notifications.offsets ?? []);
        const index = current.indexOf(offset);
        if (checked && index < 0)
            current.push(offset);
        if (!checked && index >= 0)
            current.splice(index, 1);
        Config.options.calendar.timetable.notifications.offsets = current;
    }

    RowLayout {
        visible: root.showBackButton
        spacing: 12

        RippleButton {
            implicitWidth: implicitHeight
            implicitHeight: 40
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive
            onClicked: root.goBack()

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        StyledText {
            text: Translation.tr("Timetable notifications")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        icon: "notifications_active"
        title: Translation.tr("Event reminders")

        ConfigSwitch {
            buttonIcon: "notifications"
            text: Translation.tr("Enable timetable notifications")
            checked: Config.options.calendar.timetable.notifications.enable
            onCheckedChanged: Config.options.calendar.timetable.notifications.enable = checked
        }

        ConfigSwitch {
            enabled: Config.options.calendar.timetable.notifications.enable
            buttonIcon: "today"
            text: Translation.tr("Notify all-day events")
            checked: Config.options.calendar.timetable.notifications.notifyAllDay
            onCheckedChanged: Config.options.calendar.timetable.notifications.notifyAllDay = checked
        }

        ConfigSwitch {
            enabled: Config.options.calendar.timetable.notifications.enable
            buttonIcon: "volume_up"
            text: Translation.tr("Play notification sound")
            checked: Config.options.calendar.timetable.notifications.sound
            onCheckedChanged: Config.options.calendar.timetable.notifications.sound = checked
        }

        ContentSubsectionLabel {
            text: Translation.tr("Default reminder offsets")
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Event-specific calendar alarms take precedence over these defaults.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            enabled: Config.options.calendar.timetable.notifications.enable
            spacing: 4

            Repeater {
                model: [
                    ["0m", Translation.tr("At start time")],
                    ["-5m", Translation.tr("5 minutes before")],
                    ["-15m", Translation.tr("15 minutes before")],
                    ["-1h", Translation.tr("1 hour before")],
                    ["-1d", Translation.tr("1 day before")]
                ]

                delegate: ConfigSwitch {
                    required property var modelData
                    buttonIcon: "alarm"
                    text: modelData[1]
                    checked: (Config.options.calendar.timetable.notifications.offsets ?? []).includes(modelData[0])
                    onCheckedChanged: root.toggleOffset(modelData[0], checked)
                }
            }
        }
    }

    ContentSection {
        icon: "summarize"
        title: Translation.tr("Daily summary")

        ConfigSwitch {
            buttonIcon: "today"
            text: Translation.tr("Send a daily calendar summary")
            checked: Config.options.calendar.timetable.notifications.dailySummary
            onCheckedChanged: Config.options.calendar.timetable.notifications.dailySummary = checked
        }

        ConfigTextField {
            enabled: Config.options.calendar.timetable.notifications.dailySummary
            icon: "schedule"
            text: Translation.tr("Summary time")
            placeholderText: Translation.tr("08:00")
            inputText: Config.options.calendar.timetable.notifications.dailySummaryTime
            textField.onEditingFinished: {
                const value = textField.text.trim();
                if (/^\d{2}:\d{2}$/.test(value))
                    Config.options.calendar.timetable.notifications.dailySummaryTime = value;
            }
        }
    }

    ContentSection {
        icon: "palette"
        title: Translation.tr("Calendar colors")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Calendar colors are stored as khal ANSI names and rendered with the matching Material You token.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            wrapMode: Text.Wrap
        }

        Repeater {
            model: CalendarService.calendars.filter(calendar => !calendar.readOnly)

            delegate: ContentSubsection {
                required property var modelData
                Layout.fillWidth: true
                title: modelData.name
                icon: "calendar_month"

                ConfigSelectionArray {
                    currentValue: modelData.color ?? ""
                    onSelected: color => CalendarService.setCalendarColor(modelData.name, color)
                    options: [
                        { displayName: Translation.tr("No calendar color"), value: "" },
                        { displayName: Translation.tr("Primary"), value: "light blue" },
                        { displayName: Translation.tr("Secondary"), value: "light green" },
                        { displayName: Translation.tr("Tertiary"), value: "light magenta" },
                        { displayName: Translation.tr("Error"), value: "light red" },
                        { displayName: Translation.tr("Cyan"), value: "light cyan" },
                        { displayName: Translation.tr("Yellow"), value: "yellow" }
                    ]
                }
            }
        }
    }
}
