import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import "."
import "TimetableHelpers.js" as H

Row {
    id: headerRow
    
    property real headerHeight
    property real itemSpacing
    property int timeColumnWidth
    property real dayColumnWidth
    property var days
    property int currentDayIndex
    property int allDayChipHeight
    property int allDayChipSpacing
    property bool createEnabled: true

    signal createRequested
    signal dayActivated(var date)
    signal sportsDayActivated(var date)

    height: headerHeight
    spacing: itemSpacing

    Item {
        width: timeColumnWidth
        height: headerHeight

        FloatingActionButton {
            id: createFab
            anchors.centerIn: parent
            baseSize: 48
            buttonRadius: Appearance.rounding.full
            iconText: "add"
            enabled: headerRow.createEnabled
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colRipple: Appearance.colors.colPrimaryActive
            colOnBackground: Appearance.colors.colOnPrimary
            onClicked: headerRow.createRequested()

            StyledToolTip {
                extraVisibleCondition: createFab.hovered
                text: CalendarService.khalAvailable ? Translation.tr("New event") : Translation.tr("Calendar service unavailable")
            }
        }
    }

    Repeater {
        model: days
        delegate: Item {
            id: dayDelegate
            width: dayColumnWidth
            height: headerHeight

            readonly property var allDayEvents: H.getAllDayEvents(modelData.events)
            readonly property int sportsCount: Number(modelData.sportsCount ?? 0)
            readonly property date sportsDate: modelData.sportsDate ?? new Date()
            readonly property bool hasHeaderChips: dayDelegate.allDayEvents.length > 0 || dayDelegate.sportsCount > 0

            RippleButton {
                id: dayTitleButton
                readonly property bool isToday: H.sameDate(dayDelegate.sportsDate, DateTime.clock.date)

                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                height: 56
                buttonRadius: Appearance.rounding.normal
                colBackgroundHover: Appearance.colors.colSurfaceContainerHigh
                colBackgroundActive: Appearance.colors.colSurfaceContainerHighest
                onClicked: headerRow.dayActivated(dayDelegate.sportsDate)

                contentItem: Column {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(dayDelegate.sportsDate, "ddd").toUpperCase()
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnSurfaceVariant
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(Appearance.font.pixelSize.large + 8, dayNumber.implicitWidth + 12)
                        height: Appearance.font.pixelSize.large + 8
                        radius: Appearance.rounding.full
                        color: dayTitleButton.isToday ? Appearance.colors.colPrimary : H.withOpacity(Appearance.colors.colSurface, 0)

                        StyledText {
                            id: dayNumber
                            anchors.centerIn: parent
                            text: String(dayDelegate.sportsDate.getDate())
                            font.family: Appearance.font.family.numbers
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: dayTitleButton.isToday ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                        }
                    }
                }

                StyledToolTip {
                    extraVisibleCondition: dayTitleButton.hovered
                    text: Qt.formatDate(dayDelegate.sportsDate, "dddd, d MMMM")
                }
            }

            Column {
                anchors.top: dayTitleButton.bottom
                anchors.topMargin: allDayChipSpacing
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 4
                spacing: allDayChipSpacing

                RippleButtonWithIcon {
                    id: sportsDayChip
                    visible: dayDelegate.sportsCount > 0
                    width: parent.width
                    height: allDayChipHeight
                    buttonRadius: Appearance.rounding.verysmall
                    centerContent: true
                    materialIcon: "sports_score"
                    mainText: Translation.tr("Sports") + " · " + String(dayDelegate.sportsCount)
                    iconPixelSize: Appearance.font.pixelSize.smallie
                    textPixelSize: Appearance.font.pixelSize.smallest
                    colText: Appearance.colors.colOnTertiaryContainer
                    colBackground: Appearance.colors.colTertiaryContainer
                    colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                    colBackgroundActive: Appearance.colors.colTertiaryActive
                    onClicked: headerRow.sportsDayActivated(dayDelegate.sportsDate)

                    StyledToolTip {
                        extraVisibleCondition: sportsDayChip.hovered
                        text: Translation.tr("Sports") + " · " + Qt.formatDate(dayDelegate.sportsDate, "dddd, d MMMM")
                    }
                }

                Repeater {
                    model: dayDelegate.allDayEvents
                    delegate: Rectangle {
                        width: parent.width
                        height: allDayChipHeight
                        color: Appearance.colors.colSecondaryContainer
                        radius: Appearance.rounding.verysmall
                        border.width: 1
                        border.color: H.withOpacity(Appearance.colors.colOnSecondaryContainer, 0.1)

                        StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.title
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSecondaryContainer
                            elide: Text.ElideRight
                        }

                        StyledToolTip {
                            extraVisibleCondition: allDayChipHover.hovered
                            text: Translation.tr("All day event:") + "\n" + modelData.title
                        }

                        HoverHandler {
                            id: allDayChipHover
                        }
                    }
                }
            }
        }
    }
}
