import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

// Focused five-row lyrics presentation used exclusively by the background Media Mode.
// Blur follows physical distance from the viewport center, keeping retargets coherent.
// Row motion mirrors PixelPlayer: timed FastOutSlowIn scroll plus cubic parallax.
Item {
    id: root

    clip: true

    property real largeFontSize: Appearance.font.pixelSize.hugeass * 1.8
    property color activeColor: Appearance.colors.colPrimary
    property int rowTransitionDuration: 2000
    property int minimumRowTransitionDuration: 250
    property real nearBlurRadius: 10
    property real farBlurRadius: 32
    property real rowSpacingFactor: 0.94
    property real focusedFontSizeMultiplier: 1.06
    property real baseFontWeight: 660
    property real focusedFontGrade: 100
    property int activeRowTransitionDuration: rowTransitionDuration
    property real focusReveal: hasCurrentLine ? 1 : 0
    property real waveProgress: 1
    property int waveTargetIndex: -1
    property int lastWaveIndex: -1
    property int waveAnimationDuration: 700
    property real waveDurationMultiplier: 1.2
    property real waveMagnificationStrength: 0.022
    property real waveBandWidth: 0.065
    property real waveColorStrength: 0.08

    readonly property int halfVisibleLines: 2
    readonly property int visibleLineCount: halfVisibleLines * 2 + 1
    readonly property int currentIndex: LyricsService.currentIndex
    readonly property bool hasCurrentLine: currentIndex >= 0
    readonly property real rowHeight: height / visibleLineCount * rowSpacingFactor
    readonly property real viewportEdgePadding: Math.max(0, height / 2 - rowHeight / 2)
    readonly property real parallaxMaximum: Appearance.font.pixelSize.hugeass * 1.75
    readonly property real waveLift: Appearance.font.pixelSize.normal * 0.075
    readonly property bool waveRunning: waveAnimation.running
    readonly property int blurMaximum: Math.max(2, Math.ceil(farBlurRadius))
    readonly property color focusedTextColor: ColorUtils.mix(
        Appearance.colors.colOnLayer0,
        activeColor,
        0.82
    )

    function blurForDistance(distanceInRows) {
        const distance = Math.max(0, distanceInRows);
        if (distance <= 1)
            return root.nearBlurRadius * distance;
        if (distance <= 2)
            return root.nearBlurRadius
                + (root.farBlurRadius - root.nearBlurRadius) * (distance - 1);
        return root.farBlurRadius;
    }

    function targetContentY(index) {
        if (index < 0 || root.rowHeight <= 0)
            return lyricsList.originY;

        const lastIndex = Math.max(0, LyricsService.syncedLines.length - 1);
        return lyricsList.originY + Math.min(lastIndex, index) * root.rowHeight;
    }

    function transitionDurationForIndex(index) {
        const line = LyricsService.syncedLines[index];
        const nextLine = LyricsService.syncedLines[index + 1];
        if (!line || !nextLine)
            return Math.max(root.minimumRowTransitionDuration,
                Math.min(root.rowTransitionDuration, 1000));

        const lineDurationMs = (nextLine.time - line.time) * 1000;
        if (!isFinite(lineDurationMs))
            return Math.max(root.minimumRowTransitionDuration,
                Math.min(root.rowTransitionDuration, 1000));

        return Math.max(
            root.minimumRowTransitionDuration,
            Math.min(root.rowTransitionDuration, lineDurationMs)
        );
    }

    function effectiveTransitionDuration(baseDuration) {
        if (root.rowTransitionDuration <= 0 || Appearance.animMultiplier <= 0)
            return 0;

        return Math.round(Math.max(
            root.minimumRowTransitionDuration,
            Math.min(root.rowTransitionDuration, baseDuration * Appearance.animMultiplier)
        ));
    }

    function textDirection(text) {
        const firstStrong = String(text ?? "").match(
            /[A-Za-z\u00c0-\u052f\u0590-\u08ff\ufb1d-\ufdff\ufe70-\ufefc]/
        );
        if (!firstStrong)
            return 1;
        return /[\u0590-\u08ff\ufb1d-\ufdff\ufe70-\ufefc]/.test(firstStrong[0])
            ? -1 : 1;
    }

    function cancelMagnificationWave() {
        waveAnimation.stop();
        root.waveProgress = 1;
        root.waveTargetIndex = -1;
    }

    function scheduleMagnificationWave() {
        root.cancelMagnificationWave();

        if (!root.hasCurrentLine) {
            root.lastWaveIndex = -1;
            return;
        }

        const previousIndex = root.lastWaveIndex;
        root.lastWaveIndex = root.currentIndex;
        if (previousIndex < 0)
            return;

        const jumpDistance = Math.abs(root.currentIndex - previousIndex);

        const transitionDuration = root.effectiveTransitionDuration(
            root.activeRowTransitionDuration
        );
        if (!rowMoveAnimation.running
                || jumpDistance > root.halfVisibleLines
                || transitionDuration < 450)
            return;

        root.waveTargetIndex = root.currentIndex;
        root.waveAnimationDuration = Math.round(
            transitionDuration * root.waveDurationMultiplier
        );
        root.waveProgress = 0;
        waveAnimation.restart();
    }

    function centerCurrentLine(animated) {
        rowMoveAnimation.stop();

        if (root.rowHeight <= 0)
            return;

        if (!root.hasCurrentLine) {
            root.activeRowTransitionDuration = root.rowTransitionDuration;
            lyricsList.contentY = lyricsList.originY;
            return;
        }

        const targetY = root.targetContentY(root.currentIndex);

        if (!animated || root.rowTransitionDuration <= 0 || Appearance.animMultiplier <= 0) {
            root.activeRowTransitionDuration = root.rowTransitionDuration;
            lyricsList.contentY = targetY;
            return;
        }

        let deltaY = targetY - lyricsList.contentY;
        let distanceInRows = Math.abs(deltaY) / root.rowHeight;

        if (distanceInRows > root.halfVisibleLines) {
            const direction = deltaY > 0 ? 1 : -1;
            lyricsList.contentY = targetY - direction * root.rowHeight;
            deltaY = targetY - lyricsList.contentY;
            distanceInRows = Math.abs(deltaY) / root.rowHeight;
        }

        if (distanceInRows < 0.001) {
            root.activeRowTransitionDuration = root.rowTransitionDuration;
            lyricsList.contentY = targetY;
            return;
        }

        root.activeRowTransitionDuration = root.transitionDurationForIndex(root.currentIndex);
        rowMoveAnimation.to = targetY;
        rowMoveAnimation.restart();
    }

    Component.onCompleted: {
        LyricsService.initiliazeLyrics();
        Qt.callLater(function() {
            root.centerCurrentLine(false);
        });
    }

    onCurrentIndexChanged: {
        root.centerCurrentLine(true);
        root.scheduleMagnificationWave();
    }
    onRowHeightChanged: {
        root.cancelMagnificationWave();
        Qt.callLater(function() {
            root.centerCurrentLine(false);
        });
    }

    Behavior on focusReveal {
        NumberAnimation {
            duration: root.rowTransitionDuration <= 0 || Appearance.animMultiplier <= 0
                ? 0 : Math.round(Math.max(
                root.minimumRowTransitionDuration,
                Math.min(root.rowTransitionDuration, 400 * Appearance.animMultiplier)
            ))
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
        }
    }

    Connections {
        target: LyricsService

        function onSyncedLinesChanged() {
            root.cancelMagnificationWave();
            Qt.callLater(function() {
                root.centerCurrentLine(false);
            });
        }
    }

    NumberAnimation {
        id: rowMoveAnimation

        target: lyricsList
        property: "contentY"
        duration: Appearance.animMultiplier <= 0 ? 0 : Math.round(Math.max(
            root.minimumRowTransitionDuration,
            Math.min(root.rowTransitionDuration,
                root.activeRowTransitionDuration * Appearance.animMultiplier)
        ))
        // Jetpack Compose FastOutSlowInEasing, used by PixelPlayer's lyric scroll.
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
    }

    NumberAnimation {
        id: waveAnimation

        target: root
        property: "waveProgress"
        from: 0
        to: 1
        duration: root.waveAnimationDuration
        easing.type: Easing.InOutSine
        onFinished: root.waveTargetIndex = -1
    }

    ListView {
        id: lyricsList

        anchors.fill: parent
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        currentIndex: -1
        model: LyricsService.syncedLines.length

        header: Item {
            width: lyricsList.width
            height: root.viewportEdgePadding
        }

        footer: Item {
            width: lyricsList.width
            height: root.viewportEdgePadding
        }

        delegate: Item {
            id: lyricRow

            required property int index

            readonly property real centerYInViewport: y - lyricsList.contentY + height / 2
            readonly property real signedDistanceRatio: root.height > 0
                ? Math.max(-1, Math.min(1,
                    (centerYInViewport - root.height / 2) / (root.height / 2)))
                : 0
            readonly property real parallaxTranslation: signedDistanceRatio
                * signedDistanceRatio * signedDistanceRatio * root.parallaxMaximum
            readonly property real distanceInRows: root.rowHeight > 0
                ? Math.abs(centerYInViewport - root.height / 2) / root.rowHeight
                : 0
            readonly property real focusedBlurRadius: root.blurForDistance(distanceInRows)
            readonly property real blurRadius: root.farBlurRadius
                + (focusedBlurRadius - root.farBlurRadius) * root.focusReveal
            readonly property real focusFactor: Math.max(0,
                Math.min(1, 1 - distanceInRows)) * root.focusReveal
            readonly property string lineText: LyricsService.syncedLines[lyricRow.index]
                ? LyricsService.syncedLines[lyricRow.index].text
                : ""
            readonly property bool waveActive: lyricRow.index === root.waveTargetIndex
                && root.waveRunning
            readonly property real waveDirection: root.textDirection(lineText)

            width: lyricsList.width
            height: root.rowHeight

            Item {
                id: blurLayer

                anchors.fill: parent
                transform: Translate {
                    y: lyricRow.parallaxTranslation
                }
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: root.blurMaximum
                    blur: Math.min(1, lyricRow.blurRadius / root.blurMaximum)
                }

                StyledText {
                    id: lyricText

                    property real firstVisualLineSpan: 1
                    property real secondVisualLineSpan: 1

                    anchors.fill: parent
                    anchors.leftMargin: root.farBlurRadius + Appearance.font.pixelSize.normal
                    anchors.rightMargin: root.farBlurRadius + Appearance.font.pixelSize.normal
                    text: lyricRow.lineText
                    color: ColorUtils.mix(
                        root.focusedTextColor,
                        Appearance.colors.colSubtext,
                        lyricRow.focusFactor
                    )
                    font.family: Appearance.font.family.main
                    // Layout always uses the focused metrics. A real transform supplies
                    // the visual size transition without relayout or integer pixel steps.
                    font.pixelSize: root.largeFontSize * root.focusedFontSizeMultiplier
                    font.variableAxes: ({
                        "wght": root.baseFontWeight,
                        "wdth": 100,
                        "opsz": root.largeFontSize * root.focusedFontSizeMultiplier,
                        // GRAD changes stroke emphasis without changing glyph advances.
                        "GRAD": root.focusedFontGrade * lyricRow.focusFactor,
                        "ROND": Config.options.appearance.fonts.roundnessFull ? 100 : 0
                    })
                    scale: (1 + (root.focusedFontSizeMultiplier - 1)
                        * lyricRow.focusFactor) / root.focusedFontSizeMultiplier
                    transformOrigin: Item.Center
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    onTextChanged: {
                        firstVisualLineSpan = 1;
                        secondVisualLineSpan = 1;
                    }
                    onLineLaidOut: line => {
                        const span = Math.max(0.05, Math.min(1,
                            line.implicitWidth / Math.max(1, lyricText.width)));
                        if (line.number === 0)
                            firstVisualLineSpan = span;
                        else if (line.number === 1)
                            secondVisualLineSpan = span;
                    }

                    // The extra texture exists only during the one-shot focus wave. The
                    // outer row layer continues to own the distance-based blur.
                    layer.enabled: lyricRow.waveActive
                    layer.smooth: true
                    layer.effect: ShaderEffect {
                        property real waveProgress: root.waveProgress
                        property real waveStrength: root.waveMagnificationStrength
                        property real waveWidth: root.waveBandWidth
                        property real waveLift: root.waveLift / Math.max(1, lyricText.height)
                        property real lineCountValue: lyricText.lineCount
                        property real firstLineSpan: lyricText.firstVisualLineSpan
                        property real secondLineSpan: lyricText.secondVisualLineSpan
                        property real waveDirection: lyricRow.waveDirection
                        property real colorStrength: root.waveColorStrength
                        property color waveColor: root.activeColor

                        fragmentShader: "shaders/lyricsMagnificationWave.frag.qsb"
                    }
                }
            }

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: LyricsService.changeDurationToIndex(lyricRow.index)
            }
        }
    }
}
