pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.modes
import QtQuick
import QtQuick.Layouts
import "../../../../services/modes/ModeSchema.js" as ModeSchema

/**
 * Parameters of the `schedule` condition. `row` is the TriggerRow this form
 * unfolds from; every change goes back through it.
 */
ColumnLayout {
    required property var row

    spacing: 10

    RowLayout {
        spacing: 10

        FormLabel {
            text: Translation.tr("From")
        }

        TimeField {
            value: row.trigger.from
            onCommitted: v => row.set({ from: v })
        }

        FormLabel {
            text: Translation.tr("to")
        }

        TimeField {
            value: row.trigger.to
            onCommitted: v => row.set({ to: v })
        }

        StyledText {
            visible: ModeSchema.timeToMinutes(row.trigger.from) >= ModeSchema.timeToMinutes(row.trigger.to)
            text: Translation.tr("overnight")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }

    RowLayout {
        spacing: 4

        Repeater {
            model: 7

            delegate: RippleButton {
                id: dayButton
                required property int index
                readonly property int day: dayButton.index + 1
                readonly property bool on: ModeSchema.toArray(row.trigger.days).indexOf(dayButton.day) !== -1

                implicitWidth: 44
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                colBackground: on ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                colBackgroundHover: on ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer3Hover
                colRipple: on ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer3Active
                onClicked: {
                    const days = ModeSchema.toArray(row.trigger.days).map(Number);
                    const idx = days.indexOf(dayButton.day);
                    if (idx === -1)
                        days.push(dayButton.day);
                    else if (days.length > 1)
                        days.splice(idx, 1);
                    row.set({ days: days.sort((a, b) => a - b) });
                }

                contentItem: StyledText {
                    text: ModeUi.dayShort[dayButton.index]
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: dayButton.on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                }
            }
        }
    }
}
