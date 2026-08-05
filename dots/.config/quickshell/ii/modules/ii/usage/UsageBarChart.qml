import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * Android-styled usage bar chart:
 * - Sloped top edges connecting adjacent bucket values continuously
 * - Dynamic width filling across the container
 * - Tight vertical scaling eliminating empty top space
 * - High-contrast text and visible grid/tick lines
 * - Dynamic time slot trimming (up to current time slot) with demarcating tick lines
 */
Item {
    id: root

    required property var values
    required property var labels
    property var tooltipLabels: root.labels
    property int highlightIndex: -1
    property int focusedIndex: -1
    signal barClicked(int index)
    property int labelStride: 1
    property bool labelAnchorEnd: false
    property var formatValue: (value) => `${value}`
    property var formatTick: root.formatValue
    property bool timeScale: false
    property real valueUnit: 1
    property int tickCount: 3

    property color barColor: Appearance.colors.colPrimary
    property color emptyColor: Appearance.colors.colLayer2
    property real barSpacing: 2

    /// Top of the axis, for values that sit on a known scale rather than however
    /// tall the tallest bucket happens to be. 0 leaves it to the data.
    property real axisCeiling: 0
    /// Colour of one bar, when the bars mean different things from each other.
    /// Left null, every bar is `barColor`.
    property var colorAt: null

    readonly property real maxValue: {
        let max = 0;
        if (root.values) {
            for (const value of root.values) max = Math.max(max, value);
        }
        return max;
    }
    readonly property bool hasData: root.maxValue > 0

    function niceStep(target) {
        if (root.timeScale && target <= 86400) {
            const steps = [1, 5, 15, 30, 60, 120, 300, 600, 900, 1800, 3600, 7200, 10800, 21600, 43200, 86400];
            for (const step of steps) {
                if (step >= target) return step;
            }
        }
        const unit = root.timeScale ? 86400 : root.valueUnit;
        const scaled = target / unit;
        const magnitude = Math.pow(10, Math.floor(Math.log10(Math.max(scaled, 1e-9))));
        for (const multiple of [1, 2, 5]) {
            if (magnitude * multiple >= scaled) return unit * magnitude * multiple;
        }
        return unit * magnitude * 10;
    }

    readonly property real axisMax: {
        if (root.axisCeiling > 0) return root.axisCeiling;
        if (root.maxValue <= 0) return 1;
        const step = root.niceStep(root.maxValue / 2);
        const max = Math.ceil(root.maxValue / step) * step;
        return max > 0 ? max : root.maxValue;
    }

    property bool revealing: true

    implicitHeight: 180

    Timer {
        id: revealTimer
        interval: 400
        running: true
        onTriggered: root.revealing = false
    }

    TextMetrics {
        id: tickMetrics
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Medium
        text: root.formatTick(root.axisMax)
    }

    function getValLeft(i) {
        const v = root.values;
        if (!v || v.length === 0) return 0;
        const N = v.length;
        if (N === 1) return v[0] || 0;
        if (i === 0) {
            if (v[0] > 0 && v[1] > 0) return Math.max(0, v[0] + (v[0] - v[1]) / 2);
            return v[0] || 0;
        }
        if (v[i - 1] > 0 && v[i] > 0) return (v[i - 1] + v[i]) / 2;
        return v[i] || 0;
    }

    function getValRight(i) {
        const v = root.values;
        if (!v || v.length === 0) return 0;
        const N = v.length;
        if (N === 1) return v[0] || 0;
        if (i === N - 1) {
            if (v[N - 1] > 0 && v[N - 2] > 0) return Math.max(0, v[N - 1] + (v[N - 1] - v[N - 2]) / 2);
            return v[N - 1] || 0;
        }
        if (v[i] > 0 && v[i + 1] > 0) return (v[i] + v[i + 1]) / 2;
        return v[i] || 0;
    }

    Item {
        anchors.fill: parent
        visible: root.hasData

        // Y-axis labels on the right
        Item {
            id: yAxis
            anchors {
                top: chartArea.top
                bottom: chartArea.bottom
                right: parent.right
            }
            width: Math.max(38, tickMetrics.width)

            StyledText {
                anchors {
                    right: parent.right
                    top: parent.top
                    topMargin: -height / 2
                }
                text: root.formatTick(root.axisMax)
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }

            StyledText {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                text: root.formatTick(root.axisMax / 2)
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }

            StyledText {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: -height / 2
                }
                text: root.formatTick(0)
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }
        }

        // Container holding plot area, baseline, and bottom labels
        Item {
            id: chartArea
            anchors {
                left: parent.left
                right: yAxis.left
                rightMargin: 10
                top: parent.top
                bottom: parent.bottom
            }

            // Plot area
            Item {
                id: plot
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: 6
                    bottom: baseline.top
                }

                // Horizontal grid lines (100%, 50%, 0%)
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 1
                    color: Appearance.colors.colOutline
                    opacity: 0.45
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    height: 1
                    color: Appearance.colors.colOutline
                    opacity: 0.45
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: root.barSpacing

                    Repeater {
                        model: root.values ? root.values.length : 0

                        delegate: Item {
                            id: bucket
                            required property int index

                            readonly property real value: root.values[bucket.index] ?? 0
                            readonly property bool isHighlighted: bucket.index === root.highlightIndex
                            readonly property bool isFocused: root.focusedIndex >= 0 ? bucket.index === root.focusedIndex : false
                            readonly property real valLeft: root.getValLeft(bucket.index)
                            readonly property real valRight: root.getValRight(bucket.index)

                            readonly property color currentColor: {
                                if (bucket.value <= 0) return root.emptyColor;
                                if (barArea.containsMouse) {
                                    return (bucket.isHighlighted || bucket.isFocused) ? Appearance.colors.colSecondaryHover : Appearance.colors.colPrimaryHover;
                                }
                                if (bucket.isHighlighted || bucket.isFocused) return Appearance.colors.colSecondary;
                                return root.colorAt ? root.colorAt(bucket.index) : root.barColor;
                            }

                            readonly property real barOpacity: {
                                if (bucket.value <= 0) return 0.4;
                                if (barArea.containsMouse) return 1.0;
                                if (root.focusedIndex >= 0) {
                                    return bucket.index === root.focusedIndex ? 1.0 : 0.3;
                                }
                                return 1.0;
                            }

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Canvas {
                                id: barCanvas
                                anchors.fill: parent
                                opacity: bucket.barOpacity

                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                }

                                readonly property real targetYLeft: bucket.value > 0 ? Math.max(2, parent.height - parent.height * (bucket.valLeft / root.axisMax)) : parent.height - 2
                                readonly property real targetYRight: bucket.value > 0 ? Math.max(2, parent.height - parent.height * (bucket.valRight / root.axisMax)) : parent.height - 2

                                property real animYLeft: targetYLeft
                                property real animYRight: targetYRight

                                Behavior on animYLeft {
                                    enabled: root.revealing
                                    NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
                                }
                                Behavior on animYRight {
                                    enabled: root.revealing
                                    NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
                                }

                                onAnimYLeftChanged: requestPaint()
                                onAnimYRightChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Connections {
                                    target: bucket
                                    function onCurrentColorChanged() { barCanvas.requestPaint(); }
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (width <= 0 || height <= 0) return;

                                    var yL = Math.max(0, Math.min(height - 2, animYLeft));
                                    var yR = Math.max(0, Math.min(height - 2, animYRight));
                                    var yB = height;

                                    var r = Math.min(6, width / 2, Math.max(2, (yB - yL) / 2), Math.max(2, (yB - yR) / 2));
                                    r = Math.max(1, r);

                                    ctx.beginPath();
                                    ctx.fillStyle = bucket.currentColor;

                                    ctx.moveTo(r, yL + (yR - yL) * (r / width));
                                    ctx.arcTo(width, yR, width, yB, r);
                                    ctx.arcTo(width, yB, 0, yB, r);
                                    ctx.arcTo(0, yB, 0, yL, r);
                                    ctx.arcTo(0, yL, width, yR, r);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }

                            MouseArea {
                                id: barArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.barClicked(bucket.index)
                            }

                            StyledToolTip {
                                extraVisibleCondition: barArea.containsMouse && bucket.value > 0
                                text: {
                                    const lbl = (root.tooltipLabels && root.tooltipLabels[bucket.index]) ? root.tooltipLabels[bucket.index] : "";
                                    return `${lbl} · ${root.formatValue(bucket.value)}`;
                                }
                            }
                        }
                    }
                }
            }

            // Baseline divider line
            Rectangle {
                id: baseline
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: bottomLabels.top
                }
                height: 1.5
                color: Appearance.colors.colOutline
                opacity: 0.65
            }

            // Bottom labels area
            Item {
                id: bottomLabels
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 28

                Repeater {
                    model: {
                        if (!root.values || root.values.length === 0) return 0;
                        return root.values.length + 1;
                    }

                    delegate: Item {
                        id: labelSlot
                        required property int index
                        anchors.fill: parent

                        readonly property int totalBuckets: root.values ? root.values.length : 1
                        readonly property bool isLast: labelSlot.index === totalBuckets

                        readonly property real posX: {
                            if (labelSlot.index === 0) return 0;
                            if (labelSlot.isLast) return bottomLabels.width;
                            const slotWidth = (bottomLabels.width - (totalBuckets - 1) * root.barSpacing) / totalBuckets;
                            return labelSlot.index * (slotWidth + root.barSpacing) - root.barSpacing / 2;
                        }

                        readonly property bool shouldShow: {
                            if (totalBuckets <= 6) return true;
                            if (labelSlot.index === 0 || labelSlot.isLast) return true;
                            const stride = root.labelStride > 0 ? root.labelStride : Math.ceil(totalBuckets / 6);
                            return labelSlot.index % stride === 0;
                        }

                        visible: shouldShow

                        // Vertical tick mark line |
                        Rectangle {
                            x: {
                                if (labelSlot.index === 0) return 0;
                                if (labelSlot.isLast) return parent.width - width;
                                return labelSlot.posX - width / 2;
                            }
                            y: 0
                            width: 1.5
                            height: 6
                            color: Appearance.colors.colOutline
                            opacity: 0.8
                        }

                        // Label Text
                        StyledText {
                            y: 7
                            text: {
                                if (labelSlot.isLast) {
                                    if (root.highlightIndex === totalBuckets - 1) return Translation.tr("now");
                                    return root.labels && root.labels[totalBuckets - 1] ? root.labels[totalBuckets - 1] : "";
                                }
                                return root.labels && root.labels[labelSlot.index] ? root.labels[labelSlot.index] : "";
                            }
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: {
                                if (labelSlot.isLast && root.highlightIndex === totalBuckets - 1) return Appearance.colors.colSecondary;
                                if (labelSlot.index === root.highlightIndex) return Appearance.colors.colSecondary;
                                return Appearance.colors.colSubtext;
                            }

                            x: {
                                if (labelSlot.index === 0) return 0;
                                if (labelSlot.isLast) return parent.width - implicitWidth;
                                return labelSlot.posX - implicitWidth / 2;
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.hasData
        spacing: 14

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            shape: MaterialShape.Shape.Cookie12Sided
            text: "bar_chart_off"
            iconSize: 48
            padding: 16
            color: Appearance.colors.colLayer2
            colSymbol: Appearance.colors.colSubtext
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Nothing recorded yet")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
        }
    }
}
