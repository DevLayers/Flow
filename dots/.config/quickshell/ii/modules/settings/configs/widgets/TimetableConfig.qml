import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentPage {
    id: root

    forceWidth: false
    property bool showBackButton: false
    property string subscriptionDraft: ""
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
            text: Translation.tr("Timetable Settings")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        icon: "tune"
        title: Translation.tr("General Options")

        ConfigSwitch {
            buttonIcon: "calendar_today"
            text: Translation.tr("Start with today")
            checked: Config.options.cheatsheet.timetableTodayFirst
            onCheckedChanged: {
                Config.options.cheatsheet.timetableTodayFirst = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "gradient"
            text: Translation.tr("Proximity color gradient")
            checked: Config.options.calendar.timetable.proximityColorGradient
            onCheckedChanged: {
                Config.options.calendar.timetable.proximityColorGradient = checked;
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("When enabled, Day, 3 days and Week replace synced event colors with a gradient based on distance from the next event.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
            wrapMode: Text.Wrap
        }

        ConfigSwitch {
            buttonIcon: "sports_score"
            text: Translation.tr("Show sports events")
            checked: Config.options.calendar.timetable.sportsEvents
            onCheckedChanged: {
                Config.options.calendar.timetable.sportsEvents = checked;
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Shows read-only ESPN games in the Timetable.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
            wrapMode: Text.Wrap
        }

        ConfigSwitch {
            buttonIcon: "nightlight"
            text: Translation.tr("Moon phases in month view")
            checked: Config.options.calendar.timetable.moonPhases.enable
            onCheckedChanged: {
                Config.options.calendar.timetable.moonPhases.enable = checked;
            }
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
        icon: "cake"
        title: Translation.tr("Contact birthdays")

        ConfigSwitch {
            buttonIcon: "cake"
            text: Translation.tr("Show contact birthdays")
            checked: Config.options.calendar.timetable.birthdays.enable
            onCheckedChanged: Config.options.calendar.timetable.birthdays.enable = checked

            StyledToolTip {
                text: Translation.tr("Projects birthdays from KDE Connect contacts without adding calendar events.")
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

    ContentSection {
        icon: "colorize"
        title: Translation.tr("Google event colors")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Google does not export per-event colors over CalDAV, so the synced .ics files carry none. Reading and writing them goes through the Google Calendar API, which needs its own authorization: the Google Tasks grant does not cover calendars.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RippleButtonWithIcon {
                materialIcon: GoogleCalendarService.available ? "link_off" : "link"
                mainText: GoogleCalendarService.available ? Translation.tr("Disconnect") : Translation.tr("Connect Google Calendar")
                centerContent: true
                enabled: GoogleCalendarService.credentialsConfigured && !GoogleCalendarService.authenticating
                onClicked: {
                    if (GoogleCalendarService.available)
                        GoogleCalendarService.disconnect();
                    else
                        GoogleCalendarService.startOAuth();
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: GoogleCalendarService.authenticating
                    ? Translation.tr("Waiting for the browser…")
                    : (GoogleCalendarService.available
                        ? GoogleCalendarService.activeAccountEmail
                        : (GoogleCalendarService.credentialsConfigured
                            ? Translation.tr("Not connected")
                            : Translation.tr("Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET first")))
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colOnSurfaceVariant
                wrapMode: Text.Wrap
            }
        }

        ConfigSwitch {
            buttonIcon: "palette"
            text: Translation.tr("Show Google event colors")
            checked: Config.options.calendar.timetable.googleColors.enable
            onCheckedChanged: {
                Config.options.calendar.timetable.googleColors.enable = checked;
                if (checked)
                    GoogleCalendarService.refreshColors(true);
            }
        }

        ConfigSpinBox {
            icon: "schedule"
            text: Translation.tr("Refresh interval (hours)")
            value: Config.options.calendar.timetable.googleColors.refreshHours
            from: 1
            to: 168
            stepSize: 1
            enabled: Config.options.calendar.timetable.googleColors.enable
            onValueChanged: Config.options.calendar.timetable.googleColors.refreshHours = value
        }

        NoticeBox {
            Layout.fillWidth: true
            visible: Config.options.calendar.timetable.googleColors.enable && !GoogleCalendarService.available
            materialIcon: "warning"
            text: Translation.tr("Connect a Google account to read event colors.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RippleButtonWithIcon {
                materialIcon: GoogleCalendarService.colorsSyncing ? "sync" : "refresh"
                mainText: GoogleCalendarService.colorsSyncing ? Translation.tr("Syncing…") : Translation.tr("Refresh colors")
                centerContent: true
                enabled: GoogleCalendarService.available
                    && Config.options.calendar.timetable.googleColors.enable
                    && !GoogleCalendarService.colorsSyncing
                onClicked: GoogleCalendarService.refreshColors(true)
            }

            StyledText {
                Layout.fillWidth: true
                text: GoogleCalendarService.colorsFetchedAt > 0
                    ? Translation.tr("%1 event(s) mapped").arg(String(Object.keys(GoogleCalendarService.colorByUid).length))
                    : Translation.tr("Not fetched yet")
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colOnSurfaceVariant
                wrapMode: Text.Wrap
            }
        }
    }

    ContentSection {
        icon: "calendar_add_on"
        title: Translation.tr("Subscribed calendars")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Add a public ICS URL for a read-only calendar. II manages only its own vdirsyncer and khal sections; your existing configuration stays intact.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            wrapMode: Text.Wrap
        }

        ConfigTextField {
            id: subscriptionInput
            Layout.fillWidth: true
            icon: "link"
            text: Translation.tr("Calendar ICS URL")
            placeholderText: "https://…/calendar.ics"
            inputText: root.subscriptionDraft
            textField.onTextChanged: root.subscriptionDraft = textField.text
            textField.onAccepted: addSubscriptionButton.addDraft()
        }

        WarningBox {
            Layout.fillWidth: true
            visible: CalendarSubscriptions.lastError.length > 0
            text: CalendarSubscriptions.lastError
        }

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: CalendarSubscriptions.applying
                    ? Translation.tr("Updating calendar configuration…")
                    : (CalendarSubscriptions.syncInProgress
                        ? Translation.tr("Synchronizing subscribed calendars…")
                        : Translation.tr("Subscribed calendars are always read-only."))
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                wrapMode: Text.Wrap
            }

            RippleButtonWithIcon {
                id: addSubscriptionButton
                implicitHeight: 40
                mainText: Translation.tr("Add URL")
                materialIcon: "add"
                colText: Appearance.colors.colOnPrimaryContainer
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                enabled: !CalendarSubscriptions.applying && root.subscriptionDraft.trim().length > 0

                function addDraft() {
                    if (CalendarSubscriptions.addSubscription(root.subscriptionDraft)) {
                        root.subscriptionDraft = "";
                        subscriptionInput.textField.clear();
                    }
                }

                onClicked: addDraft()
            }
        }

        Repeater {
            model: Config.options.calendar.timetable.subscriptions

            delegate: Rectangle {
                required property string modelData
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 6
                    spacing: 8

                    MaterialSymbol {
                        text: "cloud_download"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                    }

                    RippleButton {
                        id: removeSubscriptionButton
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colErrorContainer
                        onClicked: CalendarSubscriptions.removeSubscription(modelData)

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: Appearance.font.pixelSize.normal
                            color: removeSubscriptionButton.hovered ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer2
                        }

                        StyledToolTip {
                            extraVisibleCondition: removeSubscriptionButton.hovered
                            text: Translation.tr("Remove subscribed calendar")
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "event_available"
        title: Translation.tr("Outlook calendar")

        ConfigSwitch {
            buttonIcon: "calendar_add_on"
            text: Translation.tr("Enable calendar sources")
            checked: Config.options.calendar.timetable.imports.enable
            onCheckedChanged: Config.options.calendar.timetable.imports.enable = checked
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("This master switch controls local ICS imports, subscribed calendars, and Outlook sources without removing saved configuration.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            wrapMode: Text.Wrap
        }

        ConfigSwitch {
            enabled: Config.options.calendar.timetable.imports.enable
            buttonIcon: "event_available"
            text: Translation.tr("Sync Outlook calendar")
            checked: Config.options.calendar.timetable.imports.outlook.enable
            onCheckedChanged: Config.options.calendar.timetable.imports.outlook.enable = checked
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Mirrors connected Outlook events into a local read-only Timetable calendar.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            opacity: Config.options.calendar.timetable.imports.outlook.enable ? 1 : 0.7
            wrapMode: Text.Wrap
        }

        ConfigSwitch {
            enabled: Config.options.calendar.timetable.imports.enable
                && Config.options.calendar.timetable.imports.outlook.enable
            buttonIcon: "attach_email"
            text: Translation.tr("Import ICS attachments from Outlook")
            checked: Config.options.calendar.timetable.imports.outlook.icsAttachments.enable
            onCheckedChanged: Config.options.calendar.timetable.imports.outlook.icsAttachments.enable = checked
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Checks calendar attachments in the connected Outlook mailbox and imports each successful attachment only once.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            opacity: Config.options.calendar.timetable.imports.outlook.icsAttachments.enable ? 1 : 0.7
            wrapMode: Text.Wrap
        }
    }
}
