import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import "TimetableHelpers.js" as H

/**
 * Right rail: a day, an event, or the editor for one.
 *
 * Replaces the modal sheets the month view used to raise. A panel that takes
 * room from the grid instead of covering it keeps the date you are working on
 * visible, which is the whole point of editing from a calendar.
 *
 * Time and date are never typed here: the rows open pickers, which the month
 * view owns so they can centre over the whole view rather than over this rail.
 * The three pages are inline rather than reusable components on purpose — the
 * editor's inputs have to be written imperatively when a page opens, and an
 * inline component would put their ids out of reach.
 */
Item {
    id: root

    /** "" (closed) | "day" | "details" | "edit" | "create" */
    property string mode: ""
    property var event: null
    property date day: new Date()

    readonly property bool editing: root.mode === "edit" || root.mode === "create"
    readonly property bool open: root.mode !== ""

    // ─── Editor state ───
    property date formDate: new Date()
    property string formTitle: ""
    property string formDescription: ""
    property int formStartMinutes: 9 * 60
    property int formEndMinutes: 10 * 60
    property bool formAllDay: false

    readonly property bool rangeValid: root.formAllDay || root.formEndMinutes > root.formStartMinutes
    readonly property bool canSave: root.formTitle.trim().length > 0 && root.rangeValid

    signal saveRequested(var payload)
    signal deleteRequested(var eventData)
    signal moveRequested(var eventData, var newDate)
    signal closeRequested
    signal timePickerRequested(string which, int startHour, int startMinute)
    signal datePickerRequested(string purpose, var date)

    // ─── Entry points ───
    function showDay(date) {
        root.day = H.startOfDay(date);
        root.event = null;
        root.setMode("day");
    }

    function showEvent(eventData) {
        if (!eventData)
            return;
        root.event = eventData;
        root.day = H.startOfDay(eventData.startDate);
        root.setMode("details");
    }

    function startCreate(date) {
        const now = DateTime.clock.date;
        const startHour = H.sameDate(date, now) ? Math.min(22, now.getHours() + 1) : 9;
        root.event = null;
        root.formDate = H.startOfDay(date);
        root.formAllDay = false;
        root.formStartMinutes = startHour * 60;
        root.formEndMinutes = Math.min(24 * 60, (startHour + 1) * 60);
        titleInput.text = "";
        notesInput.text = "";
        root.setMode("create");
        titleInput.forceActiveFocus();
    }

    function startEdit(eventData) {
        if (!eventData)
            return;
        root.event = eventData;
        root.formDate = H.startOfDay(eventData.startDate);
        root.formAllDay = CalendarService.isAllDayEvent(eventData);
        root.formStartMinutes = eventData.startDate.getHours() * 60 + eventData.startDate.getMinutes();
        root.formEndMinutes = eventData.endDate.getHours() * 60 + eventData.endDate.getMinutes();
        if (root.formEndMinutes <= root.formStartMinutes)
            root.formEndMinutes = Math.min(24 * 60, root.formStartMinutes + 60);
        titleInput.text = eventData.content ?? "";
        notesInput.text = eventData.description ?? "";
        root.setMode("edit");
    }

    function close() {
        root.setMode("");
        root.closeRequested();
    }

    /** Fade the outgoing page, swap, slide the incoming one in from the right. */
    function setMode(next) {
        if (next === root.mode)
            return;
        root.mode = next;
        if (next === "")
            return;
        pageAnim.stop();
        root.pageShift = 28;
        root.pageOpacity = 0;
        pageAnim.start();
    }

    property real pageShift: 0
    property real pageOpacity: 1

    ParallelAnimation {
        id: pageAnim

        NumberAnimation {
            target: root
            property: "pageShift"
            to: 0
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
        }

        NumberAnimation {
            target: root
            property: "pageOpacity"
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.OutCubic
        }
    }

    // ─── Picker results ───
    function applyPickedTime(which, pickedHour, pickedMinute) {
        const value = Math.max(0, Math.min(24 * 60, pickedHour * 60 + pickedMinute));
        if (which === "start") {
            const span = Math.max(15, root.formEndMinutes - root.formStartMinutes);
            root.formStartMinutes = value;
            root.formEndMinutes = Math.min(24 * 60, value + span);
            return;
        }
        root.formEndMinutes = value;
    }

    function applyPickedDate(purpose, date) {
        if (purpose === "reschedule") {
            root.moveRequested(root.event, date);
            root.close();
            return;
        }
        root.formDate = H.startOfDay(date);
    }

    function setDuration(minutes) {
        root.formAllDay = false;
        root.formEndMinutes = Math.min(24 * 60, root.formStartMinutes + minutes);
    }

    function submit() {
        if (!root.canSave)
            return;
        root.saveRequested({
            editMode: root.mode === "edit",
            event: root.event,
            date: root.formDate,
            title: root.formTitle.trim(),
            description: root.formDescription.trim(),
            allDay: root.formAllDay,
            start: H.minutesToKhalTimeStr(root.formStartMinutes),
            end: H.minutesToKhalTimeStr(root.formEndMinutes)
        });
        root.close();
    }

    // ─── Derived ───
    readonly property var dayEvents: CalendarService.eventsByDay[H.dayKeyOf(root.day)] ?? []
    readonly property var dayHolidays: (Config.options.calendar.holidays.enable && Config.options.calendar.holidays.showInMonthView) ? (Holidays.byDayKey[H.dayKeyOf(root.day)] ?? []) : []
    readonly property color accent: root.event ? H.chipColor(root.event, Appearance.colors) : Appearance.colors.colPrimary
    readonly property bool isDayToday: H.sameDate(root.day, DateTime.clock.date)

    readonly property bool eventAllDay: root.event ? CalendarService.isAllDayEvent(root.event) : false
    readonly property int eventStartMinutes: root.event ? root.event.startDate.getHours() * 60 + root.event.startDate.getMinutes() : 0
    readonly property int eventEndMinutes: root.event ? root.event.endDate.getHours() * 60 + root.event.endDate.getMinutes() : 0

    readonly property string headerTitle: {
        switch (root.mode) {
        case "create":
            return Translation.tr("New event");
        case "edit":
            return Translation.tr("Edit event");
        case "details":
            return Translation.tr("Event details");
        default:
            return Qt.formatDate(root.day, "MMMM yyyy");
        }
    }

    function timeLabel(minutes) {
        return H.minutesToTimeStr(minutes, Config.options?.time.format);
    }

    function durationLabel(minutes) {
        const total = Math.max(0, minutes);
        const hours = Math.floor(total / 60);
        const rest = total % 60;
        if (hours === 0)
            return Translation.tr("%1 min").arg(String(rest));
        if (rest === 0)
            return Translation.tr("%1 h").arg(String(hours));
        return Translation.tr("%1 h %2 min").arg(String(hours)).arg(String(rest));
    }

    // ─── Surface ───
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.m3colors.m3surfaceContainerHigh
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // ─── Header ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                RippleButton {
                    implicitWidth: 38
                    implicitHeight: 38
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                    onClicked: root.close()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.headerTitle
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }

                RippleButton {
                    id: backToDetails
                    visible: root.mode === "details" && root.dayEvents.length > 1
                    implicitWidth: 38
                    implicitHeight: 38
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                    onClicked: root.showDay(root.day)

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "list"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    StyledToolTip {
                        extraVisibleCondition: backToDetails.hovered
                        text: Translation.tr("All events this day")
                    }
                }

                RippleButton {
                    id: deleteButton
                    visible: root.mode === "details" || root.mode === "edit"
                    implicitWidth: 38
                    implicitHeight: 38
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colErrorContainer
                    onClicked: {
                        root.deleteRequested(root.event);
                        root.close();
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "delete"
                        iconSize: Appearance.font.pixelSize.larger
                        color: deleteButton.hovered ? Appearance.colors.colOnErrorContainer : Appearance.colors.colError
                    }

                    StyledToolTip {
                        extraVisibleCondition: deleteButton.hovered
                        text: Translation.tr("Delete event")
                    }
                }
            }

            // ─── Pages ───
            Item {
                id: pageHost
                Layout.fillWidth: true
                Layout.fillHeight: true

                opacity: root.pageOpacity
                transform: Translate {
                    x: root.pageShift
                }

                // ══ Day ══
                Item {
                    anchors.fill: parent
                    visible: root.mode === "day"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 62
                                Layout.preferredHeight: 62
                                radius: Appearance.rounding.normal
                                color: root.isDayToday ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceContainerHighest

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: -4

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Qt.formatDate(root.day, "ddd").toUpperCase()
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.weight: Font.Bold
                                        color: root.isDayToday ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: String(root.day.getDate())
                                        font.family: Appearance.font.family.numbers
                                        font.pixelSize: 30
                                        font.weight: Font.Bold
                                        color: root.isDayToday ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.dayEvents.length === 0 ? Translation.tr("Nothing scheduled") : Translation.tr("%1 event(s)").arg(String(root.dayEvents.length))
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Qt.formatDate(root.day, "dddd, d MMMM")
                                    font.pixelSize: Appearance.font.pixelSize.smallie
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnSurfaceVariant
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Repeater {
                            model: root.dayHolidays

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colTertiaryContainer

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    MaterialSymbol {
                                        text: "celebration"
                                        iconSize: Appearance.font.pixelSize.large
                                        color: Appearance.colors.colOnTertiaryContainer
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.localName || modelData.name || ""
                                        font.pixelSize: Appearance.font.pixelSize.smallie
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnTertiaryContainer
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            visible: root.dayEvents.length > 0
                            text: Translation.tr("Appointments").toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        StyledListView {
                            id: dayList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.dayEvents.length > 0
                            clip: true
                            spacing: 6
                            popin: false
                            staggerStep: 26
                            model: root.dayEvents

                            delegate: RippleButton {
                                id: dayRow
                                required property var modelData

                                width: dayList.width
                                implicitHeight: 62
                                buttonRadius: Appearance.rounding.small
                                colBackground: Appearance.m3colors.m3surfaceContainerHighest
                                colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                                onClicked: root.showEvent(dayRow.modelData)

                                readonly property bool rowAllDay: CalendarService.isAllDayEvent(dayRow.modelData)

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 4
                                        Layout.fillHeight: true
                                        Layout.topMargin: 10
                                        Layout.bottomMargin: 10
                                        radius: 2
                                        color: H.chipColor(dayRow.modelData, Appearance.colors)
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: dayRow.modelData.content
                                            font.pixelSize: Appearance.font.pixelSize.smallie
                                            font.weight: Font.Bold
                                            color: Appearance.colors.colOnSurface
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: dayRow.rowAllDay ? Translation.tr("All day") : H.eventRangeText(dayRow.modelData, Config.options?.time.format)
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnSurfaceVariant
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }

                                    MaterialSymbol {
                                        text: "chevron_right"
                                        iconSize: Appearance.font.pixelSize.large
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.dayEvents.length === 0

                            PagePlaceholder {
                                icon: "event_available"
                                shape: "Cookie9Sided"
                                title: Translation.tr("Free day")
                                description: Translation.tr("Nothing here yet")
                                titlePixelSize: Appearance.font.pixelSize.normal
                                descriptionPixelSize: Appearance.font.pixelSize.smallie
                                iconSize: 32
                                iconPadding: 9
                            }
                        }

                        PrimaryAction {
                            label: Translation.tr("New event")
                            symbol: "add"
                            onTriggered: root.startCreate(root.day)
                        }
                    }
                }

                // ══ Details ══
                Item {
                    anchors.fill: parent
                    visible: root.mode === "details"

                    StyledFlickable {
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            bottom: detailsActions.top
                            bottomMargin: 12
                        }
                        clip: true
                        contentWidth: width
                        contentHeight: detailsColumn.implicitHeight

                        ColumnLayout {
                            id: detailsColumn
                            width: parent.width
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                MaterialShapeWrappedMaterialSymbol {
                                    text: "event"
                                    iconSize: 26
                                    padding: 11
                                    shape: MaterialShape.Shape.Clover4Leaf
                                    color: root.accent
                                    colSymbol: ColorUtils.getContrastingTextColor(root.accent)
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.event?.content ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.huge
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurface
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                InfoChip {
                                    symbol: "calendar_month"
                                    label: Qt.formatDate(root.event?.startDate ?? root.day, "ddd, d MMM yyyy")
                                }

                                InfoChip {
                                    symbol: "schedule"
                                    label: root.eventAllDay ? Translation.tr("All day") : root.timeLabel(root.eventStartMinutes) + " – " + root.timeLabel(root.eventEndMinutes)
                                }

                                InfoChip {
                                    visible: !root.eventAllDay
                                    symbol: "timelapse"
                                    label: root.durationLabel(root.eventEndMinutes - root.eventStartMinutes)
                                }
                            }

                            InfoRow {
                                Layout.fillWidth: true
                                visible: (root.event?.calendar ?? "").length > 0
                                symbol: "folder"
                                caption: Translation.tr("Calendar")
                                value: root.event?.calendar ?? ""
                            }

                            InfoRow {
                                Layout.fillWidth: true
                                visible: (root.event?.description ?? "").length > 0
                                symbol: "notes"
                                caption: Translation.tr("Notes")
                                value: root.event?.description ?? ""
                                multiline: true
                            }
                        }
                    }

                    ColumnLayout {
                        id: detailsActions
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        spacing: 8

                        SecondaryAction {
                            label: Translation.tr("Reschedule")
                            symbol: "event_repeat"
                            onTriggered: root.datePickerRequested("reschedule", root.event?.startDate ?? root.day)
                        }

                        PrimaryAction {
                            label: Translation.tr("Edit event")
                            symbol: "edit"
                            onTriggered: root.startEdit(root.event)
                        }
                    }
                }

                // ══ Editor ══
                Item {
                    anchors.fill: parent
                    visible: root.editing

                    StyledFlickable {
                        id: editorFlick
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            bottom: editorActions.top
                            bottomMargin: 12
                        }
                        clip: true
                        contentWidth: width
                        contentHeight: editorColumn.implicitHeight

                        ColumnLayout {
                            id: editorColumn
                            width: editorFlick.width
                            spacing: 10

                            // Title
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 66
                                radius: Appearance.rounding.small
                                color: Appearance.m3colors.m3surfaceContainerHighest

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    MaterialShapeWrappedMaterialSymbol {
                                        text: "title"
                                        iconSize: 18
                                        padding: 9
                                        shape: MaterialShape.Shape.Cookie7Sided
                                        color: Appearance.colors.colPrimaryContainer
                                        colSymbol: Appearance.colors.colOnPrimaryContainer
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: Translation.tr("Title")
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            font.weight: Font.Bold
                                            color: Appearance.colors.colOnSurfaceVariant
                                        }

                                        StyledTextInput {
                                            id: titleInput
                                            Layout.fillWidth: true
                                            clip: true
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            font.weight: Font.Bold
                                            color: Appearance.colors.colOnSurface
                                            onTextChanged: root.formTitle = text
                                            onAccepted: root.submit()
                                            Keys.onEscapePressed: root.close()

                                            StyledText {
                                                anchors.fill: parent
                                                visible: titleInput.text.length === 0
                                                verticalAlignment: Text.AlignVCenter
                                                text: Translation.tr("What is happening?")
                                                font.pixelSize: Appearance.font.pixelSize.normal
                                                color: Appearance.colors.colOnLayer1Inactive
                                            }
                                        }
                                    }
                                }
                            }

                            // All day
                            Rectangle {
                                id: allDayRow
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                radius: Appearance.rounding.small
                                color: root.formAllDay ? Appearance.colors.colSecondaryContainer : Appearance.m3colors.m3surfaceContainerHighest

                                Behavior on color {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(allDayRow)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.formAllDay = !root.formAllDay
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    MaterialShapeWrappedMaterialSymbol {
                                        text: "brightness_5"
                                        iconSize: 18
                                        padding: 9
                                        shape: MaterialShape.Shape.Sunny
                                        color: root.formAllDay ? Appearance.colors.colTertiary : Appearance.colors.colPrimaryContainer
                                        colSymbol: root.formAllDay ? Appearance.colors.colOnTertiary : Appearance.colors.colOnPrimaryContainer
                                        rotation: root.formAllDay ? 30 : 0
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("All day")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Bold
                                        color: root.formAllDay ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
                                        elide: Text.ElideRight
                                    }

                                    StyledSwitch {
                                        checked: root.formAllDay
                                        onToggled: root.formAllDay = checked
                                    }
                                }
                            }

                            // Date
                            PickerRow {
                                Layout.fillWidth: true
                                symbol: "calendar_month"
                                shapeKind: MaterialShape.Shape.Cookie12Sided
                                caption: Translation.tr("Date")
                                value: Qt.formatDate(root.formDate, "dddd, d MMMM yyyy")
                                onTriggered: root.datePickerRequested("form", root.formDate)
                            }

                            // Times
                            RowLayout {
                                id: timeRow
                                Layout.fillWidth: true
                                spacing: 8
                                opacity: root.formAllDay ? 0.35 : 1
                                enabled: !root.formAllDay

                                Behavior on opacity {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(timeRow)
                                }

                                TimeTile {
                                    Layout.fillWidth: true
                                    caption: Translation.tr("Starts")
                                    value: root.timeLabel(root.formStartMinutes)
                                    invalid: !root.rangeValid
                                    onTriggered: root.timePickerRequested("start", Math.floor(root.formStartMinutes / 60), root.formStartMinutes % 60)
                                }

                                TimeTile {
                                    Layout.fillWidth: true
                                    caption: Translation.tr("Ends")
                                    value: root.timeLabel(root.formEndMinutes)
                                    invalid: !root.rangeValid
                                    onTriggered: root.timePickerRequested("end", Math.floor(root.formEndMinutes / 60), root.formEndMinutes % 60)
                                }
                            }

                            // Quick durations
                            Flow {
                                id: durationFlow
                                Layout.fillWidth: true
                                spacing: 6
                                opacity: root.formAllDay ? 0.35 : 1
                                enabled: !root.formAllDay

                                Behavior on opacity {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(durationFlow)
                                }

                                Repeater {
                                    model: [
                                        {
                                            "minutes": 30,
                                            "label": "30m"
                                        },
                                        {
                                            "minutes": 60,
                                            "label": "1h"
                                        },
                                        {
                                            "minutes": 90,
                                            "label": "1h30"
                                        },
                                        {
                                            "minutes": 120,
                                            "label": "2h"
                                        }
                                    ]

                                    delegate: DurationChip {
                                        required property var modelData

                                        label: modelData.label
                                        selected: root.formEndMinutes - root.formStartMinutes === modelData.minutes
                                        onTriggered: root.setDuration(modelData.minutes)
                                    }
                                }
                            }

                            // Notes
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 116
                                radius: Appearance.rounding.small
                                color: Appearance.m3colors.m3surfaceContainerHighest

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    MaterialShapeWrappedMaterialSymbol {
                                        Layout.alignment: Qt.AlignTop
                                        text: "notes"
                                        iconSize: 18
                                        padding: 9
                                        shape: MaterialShape.Shape.Pill
                                        color: Appearance.colors.colPrimaryContainer
                                        colSymbol: Appearance.colors.colOnPrimaryContainer
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: Translation.tr("Notes")
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            font.weight: Font.Bold
                                            color: Appearance.colors.colOnSurfaceVariant
                                        }

                                        StyledFlickable {
                                            id: notesFlick
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            contentWidth: width
                                            contentHeight: notesInput.implicitHeight

                                            StyledTextArea {
                                                id: notesInput
                                                width: notesFlick.width
                                                placeholderText: Translation.tr("Add details (optional)")
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Appearance.colors.colOnSurface
                                                wrapMode: TextEdit.Wrap
                                                padding: 0
                                                background: null
                                                onTextChanged: root.formDescription = text
                                                Keys.onEscapePressed: root.close()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: editorActions
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        spacing: 8

                        SecondaryAction {
                            label: Translation.tr("Cancel")
                            symbol: "close"
                            onTriggered: {
                                if (root.mode === "edit" && root.event)
                                    root.showEvent(root.event);
                                else
                                    root.close();
                            }
                        }

                        PrimaryAction {
                            label: root.mode === "edit" ? Translation.tr("Save changes") : Translation.tr("Create event")
                            symbol: root.mode === "edit" ? "check" : "add"
                            enabled: root.canSave
                            onTriggered: root.submit()
                        }
                    }
                }
            }
        }
    }

    // ─── Local pieces ───
    // Both actions ride on RippleButtonWithIcon rather than setting their own
    // contentItem: a Control stretches whatever it is given to the full content
    // width, so a bare RowLayout ends up with the icon pinned left and the
    // label adrift. `centerContent` is the wrapper that keeps the pair tight
    // and centred.
    component PrimaryAction: RippleButtonWithIcon {
        id: primaryAction
        property string label: ""
        property string symbol: ""

        signal triggered

        Layout.fillWidth: true
        implicitHeight: 48
        buttonRadius: Appearance.rounding.full
        centerContent: true
        materialIcon: primaryAction.symbol
        materialIconFill: false
        mainText: primaryAction.label
        iconPixelSize: Appearance.font.pixelSize.larger
        textPixelSize: Appearance.font.pixelSize.small
        mainTextWeight: Font.Bold
        colText: Appearance.colors.colOnPrimary
        colBackground: Appearance.colors.colPrimary
        colBackgroundHover: Appearance.colors.colPrimaryHover
        colBackgroundActive: Appearance.colors.colPrimaryActive
        onClicked: primaryAction.triggered()
    }

    component SecondaryAction: RippleButtonWithIcon {
        id: secondaryAction
        property string label: ""
        property string symbol: ""

        signal triggered

        Layout.fillWidth: true
        implicitHeight: 46
        buttonRadius: Appearance.rounding.full
        centerContent: true
        materialIcon: secondaryAction.symbol
        materialIconFill: false
        mainText: secondaryAction.label
        iconPixelSize: Appearance.font.pixelSize.large
        textPixelSize: Appearance.font.pixelSize.small
        mainTextWeight: Font.DemiBold
        colText: Appearance.colors.colPrimary
        colBackground: "transparent"
        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
        colBackgroundActive: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.2)
        onClicked: secondaryAction.triggered()

        DashedBorder {
            anchors.fill: parent
            color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.7)
            borderWidth: 1
            dashLength: 5
            gapLength: 4
            radius: Appearance.rounding.full
        }
    }

    component DurationChip: Rectangle {
        id: durationChip
        property string label: ""
        property bool selected: false

        signal triggered

        implicitWidth: durationChipLabel.implicitWidth + 26
        implicitHeight: 34
        width: implicitWidth
        height: implicitHeight
        radius: Appearance.rounding.full
        color: durationChip.selected ? Appearance.colors.colSecondaryContainer : "transparent"

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(durationChip)
        }

        DashedBorder {
            anchors.fill: parent
            visible: !durationChip.selected
            color: ColorUtils.applyAlpha(Appearance.colors.colOutline, 0.8)
            borderWidth: 1
            dashLength: 4
            gapLength: 3
            radius: Appearance.rounding.full
        }

        StyledText {
            id: durationChipLabel
            anchors.centerIn: parent
            text: durationChip.label
            font.pixelSize: Appearance.font.pixelSize.smallie
            font.weight: Font.Bold
            color: durationChip.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: durationChip.triggered()
        }
    }

    component PickerRow: Rectangle {
        id: pickerRow
        property string symbol: ""
        property int shapeKind: MaterialShape.Shape.Circle
        property string caption: ""
        property string value: ""

        signal triggered

        implicitHeight: 62
        radius: Appearance.rounding.small
        color: pickerPointer.containsMouse ? Appearance.colors.colSurfaceContainerHighestHover : Appearance.m3colors.m3surfaceContainerHighest

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(pickerRow)
        }

        MouseArea {
            id: pickerPointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pickerRow.triggered()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 10

            MaterialShapeWrappedMaterialSymbol {
                text: pickerRow.symbol
                iconSize: 18
                padding: 9
                shape: pickerRow.shapeKind
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colOnPrimaryContainer
                rotation: pickerPointer.containsMouse ? 18 : 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: pickerRow.caption
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: pickerRow.value
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                text: "chevron_right"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    component TimeTile: Rectangle {
        id: timeTile
        property string caption: ""
        property string value: ""
        property bool invalid: false

        signal triggered

        implicitHeight: 74
        radius: Appearance.rounding.small
        color: {
            if (timeTile.invalid)
                return ColorUtils.mix(Appearance.colors.colErrorContainer, Appearance.m3colors.m3surfaceContainerHighest, 0.35);
            if (timePointer.containsMouse)
                return Appearance.colors.colPrimaryContainer;
            return Appearance.m3colors.m3surfaceContainerHighest;
        }

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(timeTile)
        }

        MouseArea {
            id: timePointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: timeTile.triggered()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                MaterialSymbol {
                    text: "schedule"
                    iconSize: Appearance.font.pixelSize.smallie
                    color: timePointer.containsMouse ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: timeTile.caption
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    color: timePointer.containsMouse ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: timeTile.value
                font.family: Appearance.font.family.numbers
                font.pixelSize: 24
                font.weight: Font.Bold
                color: timePointer.containsMouse ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                elide: Text.ElideRight
            }
        }
    }

    component InfoChip: Rectangle {
        id: infoChip
        property string symbol: ""
        property string label: ""

        implicitWidth: infoChipRow.implicitWidth + 22
        implicitHeight: 32
        width: implicitWidth
        height: implicitHeight
        radius: Appearance.rounding.full
        color: Appearance.m3colors.m3surfaceContainerHighest

        Row {
            id: infoChipRow
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: infoChip.symbol
                iconSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colPrimary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: infoChip.label
                font.pixelSize: Appearance.font.pixelSize.smallie
                font.weight: Font.Bold
                color: Appearance.colors.colOnSurface
            }
        }
    }

    component InfoRow: Rectangle {
        id: infoRow
        property string symbol: ""
        property string caption: ""
        property string value: ""
        property bool multiline: false

        implicitHeight: infoRowLayout.implicitHeight + 20
        radius: Appearance.rounding.small
        color: Appearance.m3colors.m3surfaceContainerHighest

        RowLayout {
            id: infoRowLayout
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignTop
                text: infoRow.symbol
                iconSize: 17
                padding: 8
                shape: MaterialShape.Shape.Cookie6Sided
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colOnPrimaryContainer
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: infoRow.caption
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: infoRow.value
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnSurface
                    wrapMode: infoRow.multiline ? Text.Wrap : Text.NoWrap
                    elide: Text.ElideRight
                    maximumLineCount: infoRow.multiline ? 8 : 1
                }
            }
        }
    }
}
