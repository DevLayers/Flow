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
    property var birthdays: []
    property var holidays: []
    property bool sportsEnabled: false
    property bool dropTarget: false
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

    readonly property bool moonEnabled: Config.options.calendar.timetable.moonPhases?.enable ?? false
    readonly property var moonInfo: H.moonPhaseInfo(root.cellData?.date)
    readonly property string moonPhaseLabel: {
        const info = root.moonInfo;
        if (!info)
            return "";
        switch (info.index) {
        case 0: return Translation.tr("New Moon");
        case 1: return Translation.tr("Waxing Crescent");
        case 2: return Translation.tr("First Quarter");
        case 3: return Translation.tr("Waxing Gibbous");
        case 4: return Translation.tr("Full Moon");
        case 5: return Translation.tr("Waning Gibbous");
        case 6: return Translation.tr("Last Quarter");
        default: return Translation.tr("Waning Crescent");
        }
    }
    readonly property var sportEvents: root.sportsEnabled ? SportsService.gamesForDate(root.cellData?.date) : []

    readonly property real headerHeight: 30
    readonly property real headerEventSpacing: 4
    readonly property real chipSpacing: 3
    readonly property real cellPadding: 7
    readonly property bool compactChips: root.height < 96
    readonly property real chipHeight: root.compactChips ? 20 : 24
    readonly property real chipAreaHeight: Math.max(0, root.height - root.headerHeight - root.headerEventSpacing - root.cellPadding)
    readonly property int chipCapacity: Math.max(0, Math.floor((root.chipAreaHeight + root.chipSpacing) / (root.chipHeight + root.chipSpacing)))
    // Keep events and tasks in one capacity calculation. Otherwise a busy day
    // could silently overflow below the cell after task integration.
    readonly property var entries: {
        const result = [];
        for (const eventData of (root.events ?? []))
            result.push({ kind: "event", data: eventData });
        for (const birthdayData of (root.birthdays ?? []))
            result.push({ kind: "birthday", data: birthdayData });
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

        Image {
            id: weatherIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: moonIcon.left
            anchors.rightMargin: 4
            width: Appearance.font.pixelSize.normal
            height: width
            visible: root.inMonth && root.forecast !== null && root.width > 92
            source: WeatherIcons.getWeatherIcon(root.forecast?.code ?? 113, false)
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectFit

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

        Text {
            id: moonIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: addButton.left
            anchors.rightMargin: 4
            width: Appearance.font.pixelSize.normal
            height: width
            visible: root.inMonth && root.moonEnabled && root.moonInfo !== null && root.width > 92
            text: H.moonGlyphFor(root.moonInfo?.index ?? 0)
            font.family: Appearance.font.family.iconNerd
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            HoverHandler {
                id: moonHover
            }

            StyledToolTip {
                extraVisibleCondition: moonHover.hovered
                text: {
                    const info = root.moonInfo;
                    if (!info)
                        return "";
                    return root.moonPhaseLabel + " · " + String(Math.round(info.illumination * 100)) + "% " + Translation.tr("illuminated");
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
            topMargin: root.headerEventSpacing
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
                        if (parent.modelData.data?.sportEvent === true || parent.modelData.data?.readOnly !== true)
                            root.eventActivated(parent.modelData.data);
                    }
                    onDragBegan: (evt, x, y, w, h) => root.eventDragBegan(evt, x, y, w, h)
                    onDragMoved: (x, y) => root.eventDragMoved(x, y)
                    onDragEnded: root.eventDragEnded()
                    onDragCanceled: root.eventDragCanceled()
                }

                BirthdayChip {
                    anchors.fill: parent
                    visible: parent.modelData.kind === "birthday"
                    birthdayData: parent.modelData.data
                    compact: root.compactChips
                    opacity: root.inMonth ? 1 : 0.6
                    onActivated: birthday => root.eventActivated(birthday)
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

}
