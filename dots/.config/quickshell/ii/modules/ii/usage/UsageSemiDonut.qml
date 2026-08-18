import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions

/**
 * Token-driven semi-circular storage chart.
 *
 * Each segment is rendered independently so hover can keep the focused slice
 * crisp while softly blurring the other slices, matching the dashboard's
 * focus treatment without changing layout bounds or using scale transforms.
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
    property real radiusScale: 1.0
    property real segmentCornerRadius: Appearance.rounding.small
    property int hoveredIndex: -1

    readonly property real total: root.values.reduce((sum, value) => sum + Math.max(0, Number(value || 0)), 0)

    implicitWidth: 260
    implicitHeight: 122

    function positiveEntries(): list<var> {
        const entries = [];
        for (let index = 0; index < root.values.length; ++index) {
            const value = Math.max(0, Number(root.values[index] || 0));
            if (value > 0)
                entries.push({ value: value, index: index });
        }
        return entries;
    }

    function lineWidth(): real {
        return Math.min(root.thickness, Math.max(2, root.height * 0.30));
    }

    function arcRadius(): real {
        const widthRadius = root.width / 2 - root.lineWidth() / 2;
        const heightRadius = root.height - root.lineWidth();
        const availableRadius = Math.max(1, Math.min(widthRadius, heightRadius));
        return availableRadius * Math.max(0.2, Math.min(1.0, root.radiusScale));
    }

    function centerY(): real {
        return root.height - root.lineWidth() / 2;
    }

    function effectiveGapRadians(): real {
        return Math.max(0, root.gapRadians);
    }

    function outerRadius(): real {
        return root.arcRadius() + root.lineWidth() / 2;
    }

    function innerRadius(): real {
        return Math.max(1, root.arcRadius() - root.lineWidth() / 2);
    }

    function pointAt(radius: real, angle: real): var {
        return ({
            x: root.width / 2 + Math.cos(angle) * radius,
            y: root.centerY() + Math.sin(angle) * radius
        });
    }

    function resolvedCornerRadius(segmentSweep: real): real {
        // Keep corners proportional on the minimum-size slices. Large slices use
        // the design-system token exactly; narrow slices reduce it just enough
        // to avoid overlapping their own inner-arc corners.
        return Math.max(0, Math.min(
            root.segmentCornerRadius,
            root.lineWidth() / 2,
            segmentSweep * root.innerRadius() * 0.45
        ));
    }

    function drawSegment(context: var, start: real, sweep: real, fillColor: color) {
        const end = start + sweep;
        const outer = root.outerRadius();
        const inner = root.innerRadius();
        const corner = root.resolvedCornerRadius(sweep);
        const outerDelta = corner > 0 ? corner / outer : 0;
        const innerDelta = corner > 0 ? corner / inner : 0;
        const outerStart = root.pointAt(outer, start + outerDelta);
        const outerEndRadial = root.pointAt(outer - corner, end);
        const innerEndRadial = root.pointAt(inner + corner, end);
        const innerEnd = root.pointAt(inner, end - innerDelta);
        const innerStart = root.pointAt(inner, start + innerDelta);
        const innerStartRadial = root.pointAt(inner + corner, start);
        const outerStartRadial = root.pointAt(outer - corner, start);
        const outerEndCorner = root.pointAt(outer, end);
        const innerEndCorner = root.pointAt(inner, end);
        const innerStartCorner = root.pointAt(inner, start);
        const outerStartCorner = root.pointAt(outer, start);

        context.fillStyle = fillColor;
        context.beginPath();
        context.moveTo(outerStart.x, outerStart.y);
        context.arc(root.width / 2, root.centerY(), outer,
            start + outerDelta, end - outerDelta, false);
        context.quadraticCurveTo(outerEndCorner.x, outerEndCorner.y,
            outerEndRadial.x, outerEndRadial.y);
        context.lineTo(innerEndRadial.x, innerEndRadial.y);
        context.quadraticCurveTo(innerEndCorner.x, innerEndCorner.y,
            innerEnd.x, innerEnd.y);
        context.arc(root.width / 2, root.centerY(), inner,
            end - innerDelta, start + innerDelta, true);
        context.quadraticCurveTo(innerStartCorner.x, innerStartCorner.y,
            innerStartRadial.x, innerStartRadial.y);
        context.lineTo(outerStartRadial.x, outerStartRadial.y);
        context.quadraticCurveTo(outerStartCorner.x, outerStartCorner.y,
            outerStart.x, outerStart.y);
        context.closePath();
        context.fill();
    }

    function segmentGeometry(index: int): var {
        const entries = root.positiveEntries();
        if (entries.length === 0 || root.total <= 0)
            return ({ start: root.startAngle, sweep: 0 });

        const availableSweep = Math.max(0,
            root.sweepRadians - Math.max(0, entries.length - 1) * root.effectiveGapRadians());
        const rawSweeps = entries.map(entry => availableSweep * entry.value / root.total);
        const smallCount = rawSweeps.filter(sweep => sweep < root.minimumSegmentRadians).length;
        const reservedSweep = Math.min(availableSweep,
            smallCount * root.minimumSegmentRadians);
        const largeRawTotal = rawSweeps.reduce((sum, sweep) =>
            sum + (sweep >= root.minimumSegmentRadians ? sweep : 0), 0);
        let cursor = root.startAngle;

        for (let entryIndex = 0; entryIndex < entries.length; ++entryIndex) {
            const rawSweep = rawSweeps[entryIndex];
            const sweep = rawSweep < root.minimumSegmentRadians
                ? root.minimumSegmentRadians
                : largeRawTotal > 0
                    ? rawSweep / largeRawTotal * Math.max(0, availableSweep - reservedSweep)
                    : rawSweep;
            if (entries[entryIndex].index === index)
                return ({ start: cursor, sweep: sweep });
            cursor += sweep + root.effectiveGapRadians();
        }
        return ({ start: root.startAngle, sweep: 0 });
    }

    function updateHoverAt(x: real, y: real) {
        const distanceX = x - root.width / 2;
        const distanceY = y - root.centerY();
        const distance = Math.sqrt(distanceX * distanceX + distanceY * distanceY);
        const radialTolerance = root.lineWidth() * 0.9;
        if (Math.abs(distance - root.arcRadius()) > radialTolerance) {
            root.hoveredIndex = -1;
            return;
        }

        let angle = Math.atan2(distanceY, distanceX);
        while (angle < root.startAngle)
            angle += Math.PI * 2;
        while (angle > root.startAngle + Math.PI * 2)
            angle -= Math.PI * 2;
        if (angle < root.startAngle || angle > root.startAngle + root.sweepRadians) {
            root.hoveredIndex = -1;
            return;
        }

        root.hoveredIndex = -1;
        for (const entry of root.positiveEntries()) {
            const geometry = root.segmentGeometry(entry.index);
            if (angle >= geometry.start && angle <= geometry.start + geometry.sweep) {
                root.hoveredIndex = entry.index;
                return;
            }
        }
    }

    Canvas {
        id: arcCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width <= 0 || height <= 0 || root.trackColor.a <= 0)
                return;

            ctx.lineWidth = root.lineWidth();
            ctx.lineCap = "butt";
            ctx.strokeStyle = ColorUtils.transparentize(root.trackColor, 0.68);
            ctx.beginPath();
            ctx.arc(width / 2, root.centerY(), root.arcRadius(),
                root.startAngle, root.startAngle + root.sweepRadians, false);
            ctx.stroke();
        }

        Component.onCompleted: requestPaint()
        Connections {
            target: root
            function onTrackColorChanged() { arcCanvas.requestPaint(); }
            function onThicknessChanged() { arcCanvas.requestPaint(); }
            function onStartAngleChanged() { arcCanvas.requestPaint(); }
            function onSweepRadiansChanged() { arcCanvas.requestPaint(); }
            function onRadiusScaleChanged() { arcCanvas.requestPaint(); }
            function onWidthChanged() { arcCanvas.requestPaint(); }
            function onHeightChanged() { arcCanvas.requestPaint(); }
        }
    }

    Repeater {
        model: root.values

        delegate: Item {
            required property real modelData
            required property int index
            anchors.fill: parent
            visible: modelData > 0
            opacity: root.hoveredIndex < 0 || root.hoveredIndex === index ? 1.0 : 0.34

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            layer.enabled: root.hoveredIndex >= 0 && root.hoveredIndex !== index
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 8
                blur: 0.45
            }

            Canvas {
                id: segmentCanvas
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (width <= 0 || height <= 0 || modelData <= 0)
                        return;

                    const geometry = root.segmentGeometry(index);
                    if (geometry.sweep <= 0)
                        return;
                    root.drawSegment(ctx, geometry.start, geometry.sweep,
                        root.segmentColors[index % root.segmentColors.length]);
                }

                Component.onCompleted: requestPaint()
                Connections {
                    target: root
                    function onValuesChanged() { segmentCanvas.requestPaint(); }
                    function onSegmentColorsChanged() { segmentCanvas.requestPaint(); }
                    function onThicknessChanged() { segmentCanvas.requestPaint(); }
                    function onGapRadiansChanged() { segmentCanvas.requestPaint(); }
                    function onMinimumSegmentRadiansChanged() { segmentCanvas.requestPaint(); }
                    function onStartAngleChanged() { segmentCanvas.requestPaint(); }
                    function onSweepRadiansChanged() { segmentCanvas.requestPaint(); }
                    function onRadiusScaleChanged() { segmentCanvas.requestPaint(); }
                    function onSegmentCornerRadiusChanged() { segmentCanvas.requestPaint(); }
                    function onWidthChanged() { segmentCanvas.requestPaint(); }
                    function onHeightChanged() { segmentCanvas.requestPaint(); }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: root.hoveredIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPositionChanged: (mouse) => root.updateHoverAt(mouse.x, mouse.y)
        onEntered: root.updateHoverAt(mouseX, mouseY)
        onExited: root.hoveredIndex = -1
    }
}
