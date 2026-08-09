import QtQuick
import qs.modules.common
import qs.modules.common.functions

/**
 * Token-driven semi-circular storage chart.
 *
 * The canvas is intentionally limited to the arc geometry; labels and legends
 * stay in the consuming card so the component remains reusable for other
 * segmented summaries.
 */
Item {
    id: root

    required property list<real> values
    property list<color> segmentColors: [
        Appearance.colors.colPrimary,
        Appearance.colors.colSecondaryContainer,
        Appearance.colors.colTertiary
    ]
    property color trackColor: Appearance.colors.colLayer2
    property real thickness: 22
    property real gapRadians: 0.075
    property real minimumSegmentRadians: 0.035
    property real startAngle: Math.PI
    property real sweepRadians: Math.PI

    readonly property real total: root.values.reduce((sum, value) => sum + Math.max(0, Number(value || 0)), 0)

    implicitWidth: 260
    implicitHeight: 122

    Canvas {
        id: arcCanvas
        anchors.fill: parent
        antialiasing: true

        function repaint() {
            arcCanvas.requestPaint();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width <= 0 || height <= 0)
                return;

            const lineWidth = Math.min(root.thickness, Math.max(2, height * 0.22));
            // Reserve half a stroke on every edge. Using height - lineWidth / 2
            // placed the arc centerline at y=0 and clipped the rounded cap.
            const radius = Math.max(1, Math.min(width / 2 - lineWidth / 2, height - lineWidth));
            const centerX = width / 2;
            const centerY = height - lineWidth / 2;

            ctx.lineWidth = lineWidth;
            ctx.lineCap = "round";
            ctx.strokeStyle = ColorUtils.transparentize(root.trackColor, 0.68);
            ctx.beginPath();
            // Canvas angles increase clockwise in the scene's y-down space;
            // the π → 2π sweep passes over the upper half of the arc.
            ctx.arc(centerX, centerY, radius, root.startAngle, root.startAngle + root.sweepRadians, false);
            ctx.stroke();

            if (root.total <= 0)
                return;

            const positiveValues = root.values
                .map((value, index) => ({ value: Math.max(0, Number(value || 0)), index: index }))
                .filter(entry => entry.value > 0);
            const positiveCount = positiveValues.length;
            const availableSweep = Math.max(0,
                root.sweepRadians - Math.max(0, positiveCount - 1) * root.gapRadians);
            const rawSweeps = positiveValues.map(entry => availableSweep * entry.value / root.total);
            const smallCount = rawSweeps.filter(sweep => sweep < root.minimumSegmentRadians).length;
            const reservedSweep = Math.min(availableSweep,
                smallCount * root.minimumSegmentRadians);
            const largeRawTotal = rawSweeps.reduce((sum, sweep) =>
                sum + (sweep >= root.minimumSegmentRadians ? sweep : 0), 0);
            let cursor = root.startAngle;
            for (let i = 0; i < positiveValues.length; ++i) {
                const rawSweep = rawSweeps[i];
                const segmentSweep = rawSweep < root.minimumSegmentRadians
                    ? root.minimumSegmentRadians
                    : largeRawTotal > 0
                        ? rawSweep / largeRawTotal * Math.max(0, availableSweep - reservedSweep)
                        : rawSweep;
                const segmentStart = cursor;
                const segmentEnd = cursor + segmentSweep;
                if (segmentEnd > segmentStart) {
                    ctx.strokeStyle = root.segmentColors[positiveValues[i].index % root.segmentColors.length];
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, segmentStart, segmentEnd, false);
                    ctx.stroke();
                }
                cursor += segmentSweep + root.gapRadians;
            }
        }

        Component.onCompleted: requestPaint()
        Connections {
            target: root
            function onValuesChanged() { arcCanvas.repaint(); }
            function onSegmentColorsChanged() { arcCanvas.repaint(); }
            function onTrackColorChanged() { arcCanvas.repaint(); }
            function onThicknessChanged() { arcCanvas.repaint(); }
            function onGapRadiansChanged() { arcCanvas.repaint(); }
            function onMinimumSegmentRadiansChanged() { arcCanvas.repaint(); }
            function onWidthChanged() { arcCanvas.repaint(); }
            function onHeightChanged() { arcCanvas.repaint(); }
        }
    }
}
