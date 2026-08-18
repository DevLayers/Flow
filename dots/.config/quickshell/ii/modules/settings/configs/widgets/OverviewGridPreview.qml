pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Rectangle {
    id: root

    property int rows: 2
    property int columns: 5
    property bool rightToLeft: false
    property bool bottomUp: false
    property int workspaceOffset: 0
    property real autoScaleFactor: 1.0

    readonly property int safeRows: Math.max(1, Math.min(10, root.rows))
    readonly property int safeCols: Math.max(1, Math.min(10, root.columns))
    readonly property int totalWorkspaces: safeRows * safeCols

    readonly property real calculatedAutoScale: {
        const widthScale = 0.88 / safeCols;
        const heightScale = 0.74 / safeRows;
        const baseScale = Math.min(widthScale, heightScale);
        return baseScale * root.autoScaleFactor;
    }

    function getWsInCell(r: int, c: int): int {
        const normRow = root.bottomUp ? (root.safeRows - r - 1) : r;
        const normCol = root.rightToLeft ? (root.safeCols - c - 1) : c;
        return normRow * root.safeCols + normCol + 1 + root.workspaceOffset;
    }

    implicitWidth: 300
    implicitHeight: 190
    radius: Appearance.rounding.large
    color: Appearance.colors.colBackgroundSurfaceContainer
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.font.pixelSize.small
        spacing: Appearance.font.pixelSize.smallest

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.font.pixelSize.smallest

            MaterialSymbol {
                text: "grid_view"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Workspace layout preview")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }

            Rectangle {
                Layout.preferredHeight: Appearance.font.pixelSize.normal
                implicitWidth: badgeText.implicitWidth + Appearance.font.pixelSize.smallest * 3
                radius: Appearance.rounding.full
                color: Appearance.colors.colPrimaryContainer

                StyledText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: `${root.safeCols} × ${root.safeRows}`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }
        }

        // Preview canvas container
        Rectangle {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer0
            clip: true

            readonly property color cellColor: Appearance.colors.colSurfaceContainerLow
            readonly property color numColor: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.35)
            readonly property string numberFontFamily: Appearance.font.family.numbers
            readonly property int numberFontWeight: Font.DemiBold

            onCellColorChanged: canvas.requestPaint()
            onNumColorChanged: canvas.requestPaint()
            onNumberFontFamilyChanged: canvas.requestPaint()
            onNumberFontWeightChanged: canvas.requestPaint()

            Canvas {
                id: canvas
                anchors.fill: parent
                anchors.margins: Appearance.font.pixelSize.smallest

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: root
                    function onRowsChanged() { canvas.requestPaint(); }
                    function onColumnsChanged() { canvas.requestPaint(); }
                    function onRightToLeftChanged() { canvas.requestPaint(); }
                    function onBottomUpChanged() { canvas.requestPaint(); }
                    function onWorkspaceOffsetChanged() { canvas.requestPaint(); }
                }

                function drawRoundedCell(ctx, x, y, w, h, rtl, rtr, rbr, rbl) {
                    ctx.beginPath();
                    ctx.moveTo(x + rtl, y);
                    ctx.lineTo(x + w - rtr, y);
                    if (rtr > 0) ctx.arcTo(x + w, y, x + w, y + rtr, rtr);
                    ctx.lineTo(x + w, y + h - rbr);
                    if (rbr > 0) ctx.arcTo(x + w, y + h, x + w - rbr, y + h, rbr);
                    ctx.lineTo(x + rbl, y + h);
                    if (rbl > 0) ctx.arcTo(x, y + h, x, y + h - rbl, rbl);
                    ctx.lineTo(x, y + rtl);
                    if (rtl > 0) ctx.arcTo(x, y, x + rtl, y, rtl);
                    ctx.closePath();
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    const rows = root.safeRows;
                    const cols = root.safeCols;

                    const spacing = (cols >= 8 || rows >= 8) ? 3 : ((cols >= 5 || rows >= 5) ? 4 : 6);
                    const totalSpacingX = (cols - 1) * spacing;
                    const totalSpacingY = (rows - 1) * spacing;

                    const availW = Math.max(0, width - totalSpacingX);
                    const availH = Math.max(0, height - totalSpacingY);

                    const cellW = availW / cols;
                    const cellH = availH / rows;

                    if (cellW <= 0 || cellH <= 0)
                        return;

                    const largeRadius = Math.max(3, Math.min(10, Math.min(cellW, cellH) * 0.28));
                    const smallRadius = Math.max(1, Math.min(3, Math.min(cellW, cellH) * 0.08));

                    const fontSize = Math.max(5, Math.min(13, Math.min(cellW, cellH) * 0.40));
                    const fontFamily = viewport.numberFontFamily;
                    ctx.font = viewport.numberFontWeight + " " + Math.round(fontSize) + "px \"" + fontFamily + "\"";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";

                    for (let r = 0; r < rows; r++) {
                        const isTop = (r === 0);
                        const isBottom = (r === rows - 1);
                        const y = r * (cellH + spacing);

                        for (let c = 0; c < cols; c++) {
                            const isLeft = (c === 0);
                            const isRight = (c === cols - 1);
                            const x = c * (cellW + spacing);

                            const rtl = (isLeft && isTop) ? largeRadius : smallRadius;
                            const rtr = (isRight && isTop) ? largeRadius : smallRadius;
                            const rbl = (isLeft && isBottom) ? largeRadius : smallRadius;
                            const rbr = (isRight && isBottom) ? largeRadius : smallRadius;

                            // Fill cell
                            drawRoundedCell(ctx, x, y, cellW, cellH, rtl, rtr, rbr, rbl);
                            ctx.fillStyle = viewport.cellColor;
                            ctx.fill();

                            // Number text
                            const wsNum = root.getWsInCell(r, c);
                            ctx.fillStyle = viewport.numColor;
                            ctx.fillText(wsNum.toString(), x + cellW / 2, y + cellH / 2);
                        }
                    }
                }
            }
        }

        // Footer info
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.font.pixelSize.smallest

            RowLayout {
                spacing: Appearance.font.pixelSize.smallest
                MaterialSymbol {
                    text: "aspect_ratio"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: Translation.tr("Auto scale: %1%").arg((root.calculatedAutoScale * 100).toFixed(1))
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: `${root.rightToLeft ? Translation.tr("Right to left") : Translation.tr("Left to right")} · ${root.bottomUp ? Translation.tr("Bottom-up") : Translation.tr("Top-down")}`
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
}
