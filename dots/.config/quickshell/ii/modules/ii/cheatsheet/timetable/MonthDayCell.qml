import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import "TimetableHelpers.js" as H

/**
 * A single day of the month grid.
 *
 * Owns nothing but presentation: the month view decides which events belong
 * here, which cell a drag is hovering, and what a click means. Overflowing
 * events collapse into a counter instead of scrolling, so the grid never nests
 * a scrollable area inside another one.
 */
Item {
    id: root

    required property var cellData
    property var events: []
    property var tasks: []
    property var holidays: []
    property bool dropTarget: false
    property bool selected: false
    property int entranceKey: 0

    signal createRequested(var date)
    signal dayActivated(var date)
    signal eventActivated(var eventData)
    signal taskCompletionRequested(var task)
    signal eventDragBegan(var eventData, real x, real y, real w, real h)
    signal eventDragMoved(real x, real y)
    signal eventDragEnded
    signal eventDragCanceled

    property Item coordinateRoot: null
    property var draggedEvent: null

    readonly property bool isToday: root.cellData?.isToday ?? false
    readonly property bool inMonth: root.cellData?.inMonth ?? true
    readonly property bool isWeekend: root.cellData?.isWeekend ?? false
    readonly property bool isHoliday: (root.holidays?.length ?? 0) > 0
    readonly property string holidayLabel: root.isHoliday ? (root.holidays[0].localName || root.holidays[0].name || "") : ""
    readonly property var forecast: {
        const key = H.dayKeyOf(root.cellData?.date);
        return (Weather.forecastData ?? []).find(day => String(day?.date ?? "") === key) ?? null;
    }
    readonly property var sportEvents: {
        const result = [];
        for (const game of (SportsService.allGames ?? [])) {
            const start = new Date(game?.date);
            if (isNaN(start.getTime()) || !H.sameDate(start, root.cellData?.date))
                continue;
            result.push({
                content: String(game?.name ?? Translation.tr("Sport")),
                description: String(game?.league ?? ""),
                startDate: start,
                endDate: new Date(start.getTime() + 2 * 60 * 60 * 1000),
                calendar: Translation.tr("Sports"),
                colorToken: "tertiary",
                readOnly: true,
                sportEvent: true,
                allDay: false
            });
        }
        return result;
    }

    function weatherSymbol(code) {
        const value = Number(code);
        if (value === 113)
            return "wb_sunny";
        if (value === 116)
            return "partly_cloudy_day";
        if ([119, 122, 143, 248].includes(value))
            return "cloud";
        if ([326, 332, 338, 368].includes(value))
            return "weather_snowy";
        if ([386, 389].includes(value))
            return "thunderstorm";
        return "rainy";
    }

    readonly property real headerHeight: 30
    readonly property real chipSpacing: 3
    readonly property real cellPadding: 7
    readonly property bool compactChips: root.height < 96
    readonly property real chipHeight: root.compactChips ? 20 : 24
    readonly property real chipAreaHeight: Math.max(0, root.height - root.headerHeight - root.cellPadding)
    readonly property int chipCapacity: Math.max(0, Math.floor((root.chipAreaHeight + root.chipSpacing) / (root.chipHeight + root.chipSpacing)))
    // Keep events and tasks in one capacity calculation. Otherwise a busy day
    // could silently overflow below the cell after task integration.
    readonly property var entries: {
        const result = [];
        for (const eventData of (root.events ?? []))
            result.push({ kind: "event", data: eventData });
        for (const sportData of root.sportEvents)
            result.push({ kind: "sport", data: sportData });
        for (const taskData of (root.tasks ?? []))
            result.push({ kind: "task", data: taskData });
        return result;
    }
    readonly property int entryCount: root.entries.length
    readonly property bool overflowing: root.entryCount > root.chipCapacity
    readonly property int visibleCount: root.overflowing ? Math.max(0, root.chipCapacity - 1) : root.entryCount
    readonly property int hiddenCount: root.entryCount - root.visibleCount

    readonly property var visibleEntries: root.visibleCount >= root.entryCount ? root.entries : root.entries.slice(0, root.visibleCount)

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: {
            const base = root.isWeekend ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1;
            if (root.dropTarget)
                return ColorUtils.mix(Appearance.colors.colPrimaryContainer, base, 0.75);
            if (!root.inMonth)
                return ColorUtils.applyAlpha(base, 0.32);
            if (root.isToday)
                return ColorUtils.mix(Appearance.colors.colPrimaryContainer, base, 0.4);
            if (root.isHoliday)
                return ColorUtils.mix(Appearance.colors.colTertiaryContainer, base, 0.24);
            if (cellPointer.containsMouse)
                return root.isWeekend ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1Hover;
            return base;
        }

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(surface)
        }
    }

    // A drop target reads as a lifted plate rather than a coloured box.
    scale: root.dropTarget ? 1.02 : 1.0
    Behavior on scale {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }

    MouseArea {
        id: cellPointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.createRequested(root.cellData.date)
    }

    // ─── Header: day number, holiday, add affordance ───
    Item {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 4
            leftMargin: root.cellPadding - 1
            rightMargin: 4
        }
        height: root.headerHeight - 4

        Rectangle {
            id: dayBadge
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: Math.max(height, dayNumber.implicitWidth + 12)
            height: 26
            radius: Appearance.rounding.full
            color: root.isToday ? Appearance.colors.colPrimary : (dayHover.hovered ? Appearance.colors.colLayer3 : "transparent")

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(dayBadge)
            }

            StyledText {
                id: dayNumber
                anchors.centerIn: parent
                text: String(root.cellData?.day ?? "")
                font.pixelSize: root.isToday ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.normal
                font.weight: root.isToday ? Font.Bold : (root.inMonth ? Font.DemiBold : Font.Medium)
                color: {
                    if (root.isToday)
                        return Appearance.colors.colOnPrimary;
                    if (!root.inMonth)
                        return Appearance.colors.colOnLayer1Inactive;
                    if (root.isHoliday)
                        return Appearance.colors.colOnTertiaryContainer;
                    return Appearance.colors.colOnSurface;
                }

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(dayNumber)
                }
            }

            HoverHandler {
                id: dayHover
            }

            TapHandler {
                onTapped: root.dayActivated(root.cellData.date)
            }

            StyledToolTip {
                extraVisibleCondition: dayHover.hovered
                text: Qt.formatDate(root.cellData?.date ?? new Date(), Locale.LongFormat)
            }
        }

        StyledText {
            id: holidayText
            visible: root.isHoliday && root.width > 96
            anchors {
                left: dayBadge.right
                right: weatherIcon.left
                leftMargin: 6
                rightMargin: 4
                verticalCenter: parent.verticalCenter
            }
            text: root.holidayLabel
            elide: Text.ElideRight
            maximumLineCount: 1
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Bold
            color: Appearance.colors.colOnTertiaryContainer
            opacity: root.inMonth ? 1 : 0.55
        }

        MaterialSymbol {
            id: weatherIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: addButton.left
            anchors.rightMargin: 4
            visible: root.inMonth && root.forecast !== null && root.width > 92
            text: root.weatherSymbol(root.forecast?.code)
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnSurfaceVariant

            HoverHandler {
                id: weatherHover
            }

            StyledToolTip {
                extraVisibleCondition: weatherHover.hovered
                text: {
                    const forecast = root.forecast;
                    if (!forecast)
                        return "";
                    return Translation.tr("Forecast · %1° / %2°")
                        .arg(String(forecast.minC ?? ""))
                        .arg(String(forecast.maxC ?? ""));
                }
            }
        }

        RippleButton {
            id: addButton
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            implicitWidth: 24
            implicitHeight: 24
            buttonRadius: Appearance.rounding.full
            colBackground: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16)
            colBackgroundHover: Appearance.colors.colPrimary
            opacity: cellPointer.containsMouse || addButton.hovered ? 1 : 0
            visible: opacity > 0.01
            onClicked: root.createRequested(root.cellData.date)

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(addButton)
            }

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "add"
                iconSize: Appearance.font.pixelSize.small
                color: addButton.hovered ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
            }

            StyledToolTip {
                extraVisibleCondition: addButton.hovered
                text: Translation.tr("New event")
            }
        }
    }

    // ─── Events and tasks ───
    Column {
        id: chipColumn
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            topMargin: 1
            leftMargin: root.cellPadding - 2
            rightMargin: root.cellPadding - 2
        }
        spacing: root.chipSpacing

        Repeater {
            model: root.visibleEntries

            delegate: Item {
                required property var modelData
                required property int index

                width: chipColumn.width
                height: root.chipHeight

                MonthEventChip {
                    anchors.fill: parent
                    visible: parent.modelData.kind === "event" || parent.modelData.kind === "sport"
                    eventData: parent.modelData.data
                    allDay: CalendarService.isAllDayEvent(parent.modelData.data)
                    compact: root.compactChips
                    dragEnabled: parent.modelData.data?.readOnly !== true
                    coordinateRoot: root.coordinateRoot
                    dragging: root.draggedEvent === parent.modelData.data
                    entranceKey: root.entranceKey
                    entranceIndex: parent.index
                    opacity: root.inMonth ? 1 : 0.6

                    onActivated: {
                        if (parent.modelData.data?.readOnly !== true)
                            root.eventActivated(parent.modelData.data);
                    }
                    onDragBegan: (evt, x, y, w, h) => root.eventDragBegan(evt, x, y, w, h)
                    onDragMoved: (x, y) => root.eventDragMoved(x, y)
                    onDragEnded: root.eventDragEnded()
                    onDragCanceled: root.eventDragCanceled()
                }

                TaskChip {
                    anchors.fill: parent
                    visible: parent.modelData.kind === "task"
                    taskData: parent.modelData.data
                    compact: root.compactChips
                    opacity: root.inMonth ? 1 : 0.6
                    onCompletionRequested: task => root.taskCompletionRequested(task)
                }
            }
        }

        RippleButton {
            visible: root.hiddenCount > 0
            width: chipColumn.width
            implicitHeight: root.chipHeight
            buttonRadius: Math.min(root.chipHeight / 2, Appearance.rounding.small)
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer3Hover
            onClicked: root.dayActivated(root.cellData.date)

            contentItem: StyledText {
                anchors.fill: parent
                anchors.leftMargin: 11
                text: Translation.tr("%1 more").arg(String(root.hiddenCount))
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Bold
                color: Appearance.colors.colPrimary
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }

    // Tasks deliberately use a compact rectangular plate and a square checkbox
    // rather than an event band. This preserves the meaning of the all-day
    // event colour while making incomplete work scannable at a glance.
    component TaskChip: Item {
        id: taskChip

        required property var taskData
        property bool compact: false

        readonly property bool completed: taskChip.taskData?.done === true
        readonly property date dueDate: taskChip.taskData?.date ? new Date(taskChip.taskData.date) : new Date()
        readonly property bool overdue: taskChip.taskData?.hasDate === true
            && !taskChip.completed
            && !isNaN(taskChip.dueDate.getTime())
            && H.startOfDay(taskChip.dueDate).getTime() < H.startOfDay(DateTime.clock.date).getTime()
        readonly property string titleText: String(taskChip.taskData?.content ?? taskChip.taskData?.title ?? Translation.tr("Task"))

        signal completionRequested(var task)

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.verysmall
            color: {
                if (taskChip.completed)
                    return Appearance.colors.colLayer3;
                return taskChip.overdue ? Appearance.colors.colErrorContainer : Appearance.colors.colSecondaryContainer;
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 3
                anchors.rightMargin: 6
                spacing: 3

                RippleButton {
                    id: completeButton
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: Math.min(parent.height, 22)
                    implicitHeight: implicitWidth
                    buttonRadius: Appearance.rounding.verysmall
                    enabled: !taskChip.completed
                    colBackground: "transparent"
                    colBackgroundHover: taskChip.overdue ? Appearance.colors.colErrorContainerHover : Appearance.colors.colSecondaryContainerHover
                    onClicked: taskChip.completionRequested(taskChip.taskData)

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: taskChip.completed ? "check_box" : "check_box_outline_blank"
                        iconSize: taskChip.compact ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.normal
                        color: taskChip.completed
                            ? Appearance.colors.colOnLayer3
                            : (taskChip.overdue ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer)
                    }

                    StyledToolTip {
                        extraVisibleCondition: completeButton.hovered
                        text: taskChip.completed ? Translation.tr("Completed") : Translation.tr("Mark as completed")
                    }
                }

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: taskChip.overdue && !taskChip.compact
                    text: "priority_high"
                    iconSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnErrorContainer
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - x)
                    text: taskChip.titleText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: taskChip.compact ? Appearance.font.pixelSize.smallest : Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.strikeout: taskChip.completed
                    color: {
                        if (taskChip.completed)
                            return Appearance.colors.colOnLayer3;
                        return taskChip.overdue ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer;
                    }
                }
            }
        }

        StyledToolTip {
            extraVisibleCondition: taskPointer.hovered
            text: taskChip.overdue
                ? Translation.tr("Overdue · %1").arg(Qt.formatDate(taskChip.dueDate, Locale.ShortFormat))
                : taskChip.titleText
        }

        HoverHandler {
            id: taskPointer
        }
    }
}
