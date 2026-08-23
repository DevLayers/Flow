import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import "TimetableHelpers.js" as H

/**
 * Left rail of the month view: today at a glance, then every day that has
 * something on it within the horizon. Read-only apart from opening an event —
 * the grid stays the place where things are created and moved.
 */
Item {
    id: root

    property int horizonDays: 60
    property int maxRows: 90
    property int entranceKey: 0

    signal eventActivated(var eventData)
    signal dateActivated(var date)

    readonly property date todayDate: DateTime.clock.date

    readonly property var todayEvents: {
        const key = H.dayKeyOf(root.todayDate);
        return CalendarService.eventsByDay[key] ?? [];
    }
    readonly property var overdueTasks: Todo.getOverdueTasks(root.todayDate)
    readonly property var todayTasks: Todo.getTasksByDate(root.todayDate).filter(task => !root.overdueTasks.some(overdue => overdue === task || String(overdue?.id ?? "") === String(task?.id ?? "")))

    readonly property var rows: {
        const out = [];
        const now = DateTime.clock.date;
        const today = H.startOfDay(now);
        const holidayMap = (Config.options.calendar.holidays.enable && Config.options.calendar.holidays.showInMonthView) ? Holidays.byDayKey : ({});

        for (let offset = 0; offset < root.horizonDays; offset++) {
            const date = H.addDays(today, offset);
            const key = H.dayKeyOf(date);
            const dayHolidays = holidayMap[key] ?? [];
            let dayEvents = CalendarService.eventsByDay[key] ?? [];
            const overdueTasks = Todo.getOverdueTasks(today);
            const dayTasks = Todo.getTasksByDate(date).filter(task => !overdueTasks.some(overdue => overdue === task || String(overdue?.id ?? "") === String(task?.id ?? "")));

            // Today's list is about what is left of today, not what already ran.
            if (offset === 0)
                dayEvents = dayEvents.filter(evt => CalendarService.isAllDayEvent(evt) || (evt.endDate && evt.endDate.getTime() >= now.getTime()));

            if (dayEvents.length === 0 && dayHolidays.length === 0 && dayTasks.length === 0)
                continue;

            out.push({
                rowType: "day",
                rowKey: "day:" + key,
                date: date,
                offset: offset,
                count: dayEvents.length + dayTasks.length
            });

            for (let i = 0; i < dayHolidays.length; i++) {
                out.push({
                    rowType: "holiday",
                    rowKey: "hol:" + key + ":" + i,
                    date: date,
                    label: dayHolidays[i].localName || dayHolidays[i].name || ""
                });
            }
            for (let i = 0; i < dayEvents.length; i++) {
                out.push({
                    rowType: "event",
                    rowKey: "evt:" + key + ":" + (dayEvents[i].uid || dayEvents[i].content || i),
                    date: date,
                    event: dayEvents[i]
                });
            }
            for (let i = 0; i < dayTasks.length; i++) {
                out.push({
                    rowType: "task",
                    rowKey: "task:" + key + ":" + (dayTasks[i].id || dayTasks[i].content || i),
                    date: date,
                    task: dayTasks[i]
                });
            }

            if (out.length >= root.maxRows)
                break;
        }
        return out;
    }

    readonly property int upcomingCount: root.rows.filter(row => row.rowType === "event" || row.rowType === "task").length

    onEntranceKeyChanged: heroAnim.restart()

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ─── Today hero ───
        Rectangle {
            id: hero
            Layout.fillWidth: true
            Layout.preferredHeight: heroContent.implicitHeight + 32
            radius: Appearance.rounding.large
            color: Appearance.colors.colPrimaryContainer

            opacity: 0
            transform: Translate {
                id: heroTranslate
                y: 14
            }

            ParallelAnimation {
                id: heroAnim
                running: true
                NumberAnimation {
                    target: hero
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: heroTranslate
                    property: "y"
                    from: 14
                    to: 0
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dateActivated(root.todayDate)
            }

            ColumnLayout {
                id: heroContent
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.todayDate, "dddd").toUpperCase()
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.75)
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: String(root.todayDate.getDate())
                        font.family: Appearance.font.family.title
                        font.pixelSize: 44
                        font.weight: Font.Bold
                        font.variableAxes: Appearance.font.variableAxes.title
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 8
                        text: Qt.formatDate(root.todayDate, "MMMM yyyy")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.85)
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.todayEvents.length + root.todayTasks.length === 0
                        ? Translation.tr("Nothing scheduled today")
                        : Translation.tr("%1 item(s) today").arg(String(root.todayEvents.length + root.todayTasks.length))
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    font.weight: Font.Medium
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.8)
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.overdueTasks.length > 0
                    text: Translation.tr("Overdue")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Bold
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.75)
                }

                Repeater {
                    model: root.overdueTasks

                    delegate: TaskChip {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        taskData: modelData
                        compact: true
                        onCompletionRequested: task => Todo.markDone(task)
                    }
                }
            }
        }

        // ─── Section label ───
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.topMargin: 2
            spacing: 8

            StyledText {
                text: Translation.tr("Upcoming")
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Bold
                color: Appearance.colors.colOnSurface
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                visible: root.upcomingCount > 0
                implicitWidth: countText.implicitWidth + 16
                implicitHeight: 22
                radius: Appearance.rounding.full
                color: Appearance.colors.colSecondaryContainer

                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: String(root.upcomingCount)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }
        }

        // ─── List ───
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            PagePlaceholder {
                shown: root.rows.length === 0
                icon: "event_available"
                shape: "Cookie9Sided"
                title: Translation.tr("All clear")
                description: Translation.tr("No events or tasks in the next %1 days").arg(String(root.horizonDays))
                titlePixelSize: Appearance.font.pixelSize.normal
                descriptionPixelSize: Appearance.font.pixelSize.smallie
                iconSize: 34
                iconPadding: 9
            }

            StyledListView {
                id: list
                anchors.fill: parent
                visible: root.rows.length > 0
                clip: true
                spacing: 3
                popin: false
                animatePopulate: true
                animateAppearance: true
                staggerStep: 22
                model: root.rows
                cacheBuffer: 400

                delegate: Item {
                    id: rowItem
                    required property var modelData
                    required property int index

                    readonly property string rowType: rowItem.modelData?.rowType ?? "day"

                    width: list.width
                    implicitHeight: rowItem.rowType === "day" ? 30 : 40
                    height: implicitHeight

                    // ─── Day separator ───
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        anchors.topMargin: 8
                        visible: rowItem.rowType === "day"
                        spacing: 8

                        StyledText {
                            text: {
                                if (rowItem.rowType !== "day")
                                    return "";
                                if (rowItem.modelData.offset === 0)
                                    return Translation.tr("Today");
                                if (rowItem.modelData.offset === 1)
                                    return Translation.tr("Tomorrow");
                                return Qt.formatDate(rowItem.modelData.date, "ddd, d MMM");
                            }
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: rowItem.rowType === "day" && rowItem.modelData.offset === 0 ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 2
                            radius: 1
                            color: ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.6)
                        }
                    }

                    // ─── Holiday row ───
                    Rectangle {
                        anchors.fill: parent
                        visible: rowItem.rowType === "holiday"
                        radius: Appearance.rounding.small
                        color: ColorUtils.mix(Appearance.colors.colTertiaryContainer, Appearance.colors.colLayer1, 0.55)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            MaterialSymbol {
                                text: "celebration"
                                iconSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colOnTertiaryContainer
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: rowItem.modelData?.label ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnTertiaryContainer
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // ─── Event row ───
                    Loader {
                        anchors.fill: parent
                        active: rowItem.rowType === "event"
                        sourceComponent: RippleButton {
                            id: eventButton
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colLayer1
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: root.eventActivated(rowItem.modelData.event)

                            readonly property color accent: H.chipColor(rowItem.modelData.event, Appearance.colors)
                            readonly property bool allDay: CalendarService.isAllDayEvent(rowItem.modelData.event)

                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 12
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 4
                                    Layout.fillHeight: true
                                    Layout.topMargin: 7
                                    Layout.bottomMargin: 7
                                    radius: 2
                                    color: eventButton.accent
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: rowItem.modelData.event.content
                                        font.pixelSize: Appearance.font.pixelSize.smallie
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colOnSurface
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: eventButton.allDay ? Translation.tr("All day") : H.eventRangeText(rowItem.modelData.event, Config.options?.time.format)
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnSurfaceVariant
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: rowItem.rowType === "task"
                        sourceComponent: TaskChip {
                            taskData: rowItem.modelData.task
                            compact: false
                            onCompletionRequested: task => Todo.markDone(task)
                        }
                    }
                }
            }

            ScrollEdgeFade {
                target: list
                color: Appearance.colors.colSurfaceContainer
                visible: root.rows.length > 0
            }
        }
    }
}
