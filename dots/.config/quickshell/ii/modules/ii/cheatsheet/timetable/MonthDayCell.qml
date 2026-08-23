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
    property var holidays: []
    property bool dropTarget: false
    property bool selected: false
    property int entranceKey: 0

    signal createRequested(var date)
    signal dayActivated(var date)
    signal eventActivated(var eventData)
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

    readonly property real headerHeight: 30
    readonly property real chipSpacing: 3
    readonly property real cellPadding: 7
    readonly property bool compactChips: root.height < 96
    readonly property real chipHeight: root.compactChips ? 20 : 24
    readonly property real chipAreaHeight: Math.max(0, root.height - root.headerHeight - root.cellPadding)
    readonly property int chipCapacity: Math.max(0, Math.floor((root.chipAreaHeight + root.chipSpacing) / (root.chipHeight + root.chipSpacing)))
    readonly property int eventCount: root.events?.length ?? 0
    readonly property bool overflowing: root.eventCount > root.chipCapacity
    readonly property int visibleCount: root.overflowing ? Math.max(0, root.chipCapacity - 1) : root.eventCount
    readonly property int hiddenCount: root.eventCount - root.visibleCount

    readonly property var visibleEvents: root.visibleCount >= root.eventCount ? (root.events ?? []) : (root.events ?? []).slice(0, root.visibleCount)

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
                right: addButton.left
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

    // ─── Events ───
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
            model: root.visibleEvents

            delegate: MonthEventChip {
                required property var modelData
                required property int index

                width: chipColumn.width
                height: root.chipHeight
                eventData: modelData
                allDay: CalendarService.isAllDayEvent(modelData)
                compact: root.compactChips
                coordinateRoot: root.coordinateRoot
                dragging: root.draggedEvent === modelData
                entranceKey: root.entranceKey
                entranceIndex: index
                opacity: root.inMonth ? 1 : 0.6

                onActivated: root.eventActivated(modelData)
                onDragBegan: (evt, x, y, w, h) => root.eventDragBegan(evt, x, y, w, h)
                onDragMoved: (x, y) => root.eventDragMoved(x, y)
                onDragEnded: root.eventDragEnded()
                onDragCanceled: root.eventDragCanceled()
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
