import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * The usage histogram: one bar per hour of day, or per day of the range.
 *
 * Bars are plain Rectangles rather than a Canvas so each one can carry its own
 * hover state and tooltip — with 24 or 30 buckets that is cheaper than repainting
 * a canvas on every mouse move, and it keeps the M3 rounding for free.
 */
Item {
    id: root

    required property var values
    required property var labels
    /// Names the buckets in the tooltip, where there is room to be unambiguous —
    /// the axis is stuck with a bare day number that repeats every month.
    property var tooltipLabels: root.labels
    /// Marks now: the current hour, or today's column in a multi-day range.
    property int highlightIndex: -1
    /// Only every `labelStride`-th label is drawn, so a 30-day axis stays readable.
    property int labelStride: 1
    /// Turns a bucket value into the tooltip figure.
    property var formatValue: (value) => {
        return `${value}`;
    }
    /// The vertical axis gives each tick a narrow gutter, so it gets the shorter
    /// form of the same figure.
    property var formatTick: root.formatValue
    /// Durations round up to 5 min, 1 h, 6 h rather than to 1-2-5 x 10ⁿ, which
    /// would label the axis with two thousand seconds.
    property bool timeScale: false
    property int tickCount: 4

    property color barColor: Appearance.colors.colPrimary
    property color emptyColor: Appearance.colors.colLayer2
    property real barSpacing: 3

    readonly property real maxValue: {
        let max = 0;
        for (const value of root.values) max = Math.max(max, value)
        return max;
    }
    readonly property bool hasData: root.maxValue > 0
    readonly property real tickStep: root.hasData ? root.niceStep(root.maxValue / root.tickCount) : 0
    /// Bars are measured against a rounded-up ceiling rather than against the
    /// tallest bar, so the top of the axis is a figure worth reading and a given
    /// bar height means the same thing from one range to the next.
    readonly property real axisMax: root.tickStep > 0 ? Math.ceil(root.maxValue / root.tickStep) * root.tickStep : 0
    readonly property var ticks: {
        const out = [];
        if (root.tickStep <= 0)
            return out;
        for (let value = root.tickStep; value <= root.axisMax + 1e-6; value += root.tickStep) out.push(value);
        return out;
    }

    /// Bars grow into place the first time the chart appears, then hold still. A
    /// range, metric or selection change replaces every value at once, and
    /// replaying the reveal there reads as the chart redrawing itself rather than
    /// as the numbers having changed.
    property bool revealing: true

    implicitHeight: 160

    /// Smallest step at or above `target` that a person would have picked.
    function niceStep(target) {
        if (root.timeScale) {
            const steps = [1, 5, 15, 30, 60, 120, 300, 600, 900, 1800, 3600, 7200, 10800, 21600, 43200, 86400];
            for (const step of steps) {
                if (step >= target)
                    return step;
            }
            return steps[steps.length - 1];
        }
        const magnitude = Math.pow(10, Math.floor(Math.log10(Math.max(target, 1e-9))));
        for (const multiple of [1, 2, 5]) {
            if (magnitude * multiple >= target)
                return magnitude * multiple;
        }
        return magnitude * 10;
    }

    Timer {
        id: revealTimer

        interval: 400
        running: true
        onTriggered: root.revealing = false
    }

    // Sized off the topmost tick, which is the longest label for every scale here
    // but one: "1h30" beats "2h". The labels hang off the right edge rather than
    // filling the gutter, so the odd wide one leans into the card padding instead
    // of being elided.
    TextMetrics {
        id: tickMetrics

        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smallest
        text: root.ticks.length > 0 ? root.formatTick(root.ticks[root.ticks.length - 1]) : ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Item {
                id: axis

                Layout.fillHeight: true
                Layout.preferredWidth: root.hasData ? tickMetrics.width : 0

                Repeater {
                    model: root.ticks

                    delegate: StyledText {
                        required property var modelData

                        anchors.right: parent.right
                        y: axis.height - axis.height * (modelData / root.axisMax) - height / 2
                        text: root.formatTick(modelData)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            Item {
                id: plot

                Layout.fillWidth: true
                Layout.fillHeight: true

                Repeater {
                    model: root.ticks

                    delegate: Rectangle {
                        required property var modelData

                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        y: plot.height - plot.height * (modelData / root.axisMax)
                        height: 1
                        color: Appearance.colors.colOutlineVariant
                        opacity: 0.35
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: root.barSpacing

                    // Indexed rather than handed the values directly: keeping one
                    // delegate per bucket alive across a metric switch is what lets
                    // the bars change height instead of being built from scratch.
                    Repeater {
                        model: root.values.length

                        delegate: Item {
                            id: bucket

                            required property int index
                            readonly property real value: root.values[bucket.index] ?? 0
                            readonly property bool isHighlighted: bucket.index === root.highlightIndex
                            readonly property real fraction: root.axisMax > 0 ? bucket.value / root.axisMax : 0

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                id: bar

                                // A bucket with data always shows something; an empty one keeps
                                // a faint stub so the axis stays legible as a row of slots.
                                height: bucket.value > 0 ? Math.max(3, parent.height * bucket.fraction) : 2
                                radius: Appearance.rounding.verysmall
                                color: {
                                    if (bucket.value <= 0)
                                        return root.emptyColor;

                                    if (barArea.containsMouse)
                                        return Appearance.colors.colPrimaryHover;

                                    return bucket.isHighlighted ? Appearance.colors.colTertiary : root.barColor;
                                }
                                opacity: bucket.value > 0 ? 1 : 0.6

                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }

                                Behavior on height {
                                    enabled: root.revealing

                                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                }

                                Behavior on color {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }
                            }

                            MouseArea {
                                id: barArea

                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            StyledToolTip {
                                extraVisibleCondition: barArea.containsMouse && bucket.value > 0
                                text: `${root.tooltipLabels[bucket.index]} · ${root.formatValue(bucket.value)}`
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Holds the label row in step with the plot, past the tick gutter.
            Item {
                Layout.preferredWidth: axis.width
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.barSpacing

                Repeater {
                    model: root.labels.length

                    // The label sits in a zero-implicit-width cell and is allowed to
                    // overflow it. Laying the text out directly would give a cell that
                    // carries text more width than an empty one, and the axis would
                    // drift out of step with the bars above it.
                    delegate: Item {
                        id: slot

                        required property int index

                        Layout.fillWidth: true
                        implicitWidth: 0
                        implicitHeight: label.implicitHeight

                        StyledText {
                            id: label

                            anchors.centerIn: parent
                            elide: Text.ElideNone
                            text: slot.index % root.labelStride === 0 ? root.labels[slot.index] : ""
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: slot.index === root.highlightIndex ? Appearance.colors.colTertiary : Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: !root.hasData
        text: Translation.tr("Nothing recorded yet")
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.small
    }
}
