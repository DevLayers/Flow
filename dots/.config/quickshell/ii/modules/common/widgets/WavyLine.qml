pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common

Canvas {
    id: root
    property real amplitudeMultiplier: 0.5
    property real frequency: 6
    property color color: Appearance?.colors.colPrimary ?? "#685496"
    property real lineWidth: 4
    property real fullLength: width
    property bool animateWave: false

    property real phase: 0.0

    renderTarget: Canvas.Image

    onPaint: {
        if (width <= 0 || height <= 0)
            return;

        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        var centerY = height / 2;
        var startX = root.lineWidth / 2;
        var endX = root.width - (root.lineWidth / 2);

        if (endX <= startX)
            return;

        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();

        var amplitude = root.lineWidth * root.amplitudeMultiplier;
        if (amplitude <= 0.01) {
            ctx.moveTo(startX, centerY);
            ctx.lineTo(endX, centerY);
            ctx.stroke();
            return;
        }

        var len = Math.max(1, root.fullLength);
        var k = (root.frequency * 2 * Math.PI) / len;
        var currentPhase = root.phase;

        ctx.moveTo(startX, centerY + amplitude * Math.sin(k * startX + currentPhase));
        for (var x = startX + 2; x < endX; x += 2) {
            ctx.lineTo(x, centerY + amplitude * Math.sin(k * x + currentPhase));
        }
        ctx.lineTo(endX, centerY + amplitude * Math.sin(k * endX + currentPhase));
        ctx.stroke();
    }

    Timer {
        id: animTimer
        interval: 33 // ~30 FPS for silky-smooth wave animation with ultra-low CPU load
        running: root.animateWave && root.visible && root.amplitudeMultiplier > 0.01
        repeat: true
        onTriggered: {
            root.phase += 0.09;
            if (root.phase > 6.2831853) {
                root.phase -= 6.2831853;
            }
            root.requestPaint();
        }
    }

    onAnimateWaveChanged: {
        if (!animateWave) {
            root.phase = 0;
            root.requestPaint();
        }
    }

    onWidthChanged: root.requestPaint()
    onHeightChanged: root.requestPaint()
    onColorChanged: root.requestPaint()
    onLineWidthChanged: root.requestPaint()
    onAmplitudeMultiplierChanged: root.requestPaint()
    onFullLengthChanged: root.requestPaint()
    onFrequencyChanged: root.requestPaint()
}
