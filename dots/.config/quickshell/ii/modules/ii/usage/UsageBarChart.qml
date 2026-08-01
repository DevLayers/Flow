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
    property color barColor: Appearance.colors.colPrimary
    property color emptyColor: Appearance.colors.colLayer2
    property real barSpacing: 3
    readonly property real maxValue: {
        let max = 0;
        for (const value of root.values) max = Math.max(max, value)
        return max;
    }
    readonly property bool hasData: root.maxValue > 0

    implicitHeight: 160

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.barSpacing

            Repeater {
                model: root.values

                delegate: Item {
                    id: bucket

                    required property var modelData
                    required property int index
                    readonly property bool isHighlighted: bucket.index === root.highlightIndex
                    readonly property real fraction: root.maxValue > 0 ? bucket.modelData / root.maxValue : 0

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        id: bar

                        // A bucket with data always shows something; an empty one keeps
                        // a faint stub so the axis stays legible as a row of slots.
                        height: bucket.modelData > 0 ? Math.max(3, parent.height * bucket.fraction) : 2
                        radius: Appearance.rounding.verysmall
                        color: {
                            if (bucket.modelData <= 0)
                                return root.emptyColor;

                            if (barArea.containsMouse)
                                return Appearance.colors.colPrimaryHover;

                            return bucket.isHighlighted ? Appearance.colors.colTertiary : root.barColor;
                        }
                        opacity: bucket.modelData > 0 ? 1 : 0.6

                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }

                        Behavior on height {
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
                        extraVisibleCondition: barArea.containsMouse && bucket.modelData > 0
                        text: `${root.tooltipLabels[bucket.index]} · ${root.formatValue(bucket.modelData)}`
                    }

                }

            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.barSpacing

            Repeater {
                model: root.labels

                // The label sits in a zero-implicit-width cell and is allowed to
                // overflow it. Laying the text out directly would give a cell that
                // carries text more width than an empty one, and the axis would
                // drift out of step with the bars above it.
                delegate: Item {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitWidth: 0
                    implicitHeight: label.implicitHeight

                    StyledText {
                        id: label

                        anchors.centerIn: parent
                        elide: Text.ElideNone
                        text: parent.index % root.labelStride === 0 ? parent.modelData : ""
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: parent.index === root.highlightIndex ? Appearance.colors.colTertiary : Appearance.colors.colSubtext
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
