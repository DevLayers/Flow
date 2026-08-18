import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Which day, week or month is on screen, and the arrows that walk between them.
 *
 * Shared by the app and battery views rather than written twice: they are two
 * readings of the same period, and a stepper that behaved differently in one of
 * them would read as a bug in the data.
 *
 * Nothing here changes its own state. The two views hold the period themselves —
 * moving it also has to clear whatever they had filtered or selected — so this
 * asks, and they decide.
 */
RowLayout {
    id: root

    /// Calendar periods rather than a rolling window. A week is always the same
    /// seven days and a month the same month however long ago it is asked about,
    /// which is the only way two of them can be put side by side.
    readonly property var granularities: [
        {
            "key": "day",
            "name": Translation.tr("Day")
        },
        {
            "key": "week",
            "name": Translation.tr("Week")
        },
        {
            "key": "month",
            "name": Translation.tr("Month")
        }
    ]

    property int granularityIndex: 0
    /// Periods back from the current one: 0 is today / this week / this month.
    /// Never positive — there is nothing ahead of now to look at.
    property int periodOffset: 0

    readonly property string granularity: root.granularities[root.granularityIndex]?.key ?? "day"
    readonly property bool canGoBack: AppStats.hasEarlierPeriod(root.granularity, root.periodOffset)
    readonly property bool canGoForward: root.periodOffset < 0

    signal granularityPicked(int index)
    signal stepped(int delta)
    signal periodReset

    spacing: 10

    /// One step through the timeline. Dimmed rather than hidden at either end, so
    /// the control keeps its place and says why it will not move.
    component StepButton: RippleButton {
        id: step

        required property string symbol
        property string tooltip: ""

        implicitWidth: 32
        implicitHeight: 32
        buttonRadius: Appearance.rounding.full
        opacity: step.enabled ? 1 : 0.35

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: step.symbol
            iconSize: 20
            color: Appearance.colors.colOnLayer0
        }

        StyledToolTip {
            text: step.tooltip
        }
    }

    ButtonGroup {
        spacing: 4
        padding: 0

        Repeater {
            model: root.granularities

            delegate: SelectionGroupButton {
                required property var modelData
                required property int index

                buttonText: modelData.name
                toggled: root.granularityIndex === index
                leftmost: index === 0
                rightmost: index === root.granularities.length - 1
                onClicked: root.granularityPicked(index)
            }
        }
    }

    // The arrows stop where the data does rather than walking into periods
    // retention has already dropped.
    RowLayout {
        spacing: 2

        StepButton {
            symbol: "chevron_left"
            enabled: root.canGoBack
            tooltip: Translation.tr("Previous period")
            onClicked: root.stepped(-1)
        }

        ColumnLayout {
            Layout.minimumWidth: 150
            spacing: 0

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: AppStats.periodLabel(root.granularity, root.periodOffset)
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer0
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: AppStats.periodRangeLabel(root.granularity, root.periodOffset)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        StepButton {
            symbol: "chevron_right"
            enabled: root.canGoForward
            tooltip: Translation.tr("Next period")
            onClicked: root.stepped(1)
        }
    }

    RippleButton {
        visible: root.periodOffset < 0
        implicitHeight: 30
        buttonRadius: Appearance.rounding.full
        horizontalPadding: 12
        onClicked: root.periodReset()

        contentItem: StyledText {
            text: Translation.tr("Now")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }
    }
}
