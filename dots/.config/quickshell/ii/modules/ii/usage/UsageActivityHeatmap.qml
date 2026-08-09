import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Contribution-style activity heatmap. Cells are supplied in week-major order
 * and the grid sizes itself to the available card width.
 */
Item {
    id: root

    required property list<var> cells
    property list<string> weekLabels: []
    property list<string> dayLabels: []
    property color activeColor: Appearance.colors.colPrimary
    property color midColor: Appearance.colors.colTertiary
    property color emptyColor: Appearance.colors.colLayer2
    property int weekCount: 6
    property int dayCount: 7
    property real cellSize: 0
    property real minCellWidth: 14
    property real minCellHeight: 14
    property real maxCellWidth: 28
    property real maxCellHeight: 28
    property real cellSpacing: 4
    property real labelWidth: 30

    readonly property real resolvedCellSize: root.cellSize > 0
        ? root.cellSize
        : Math.max(Math.max(root.minCellWidth, root.minCellHeight),
            Math.min(root.maxCellWidth, root.maxCellHeight,
                (root.width - root.labelWidth - (root.weekCount - 1) * root.cellSpacing)
                    / Math.max(1, root.weekCount),
                (root.height - Appearance.font.pixelSize.normal - 8
                    - (root.dayCount - 1) * root.cellSpacing)
                    / Math.max(1, root.dayCount)))
    readonly property real resolvedCellWidth: root.resolvedCellSize
    readonly property real resolvedCellHeight: root.resolvedCellSize
    readonly property real gridContentWidth: root.weekCount * root.resolvedCellWidth
        + Math.max(0, root.weekCount - 1) * root.cellSpacing
    readonly property real heatmapContentWidth: root.labelWidth + root.cellSpacing + root.gridContentWidth

    readonly property real maxValue: {
        let max = 0;
        for (const cell of root.cells)
            max = Math.max(max, Number(cell?.value || 0));
        return max;
    }

    implicitHeight: Appearance.font.pixelSize.normal + 8
        + root.dayCount * Math.max(root.minCellWidth, root.minCellHeight)
        + (root.dayCount - 1) * root.cellSpacing

    function cellColor(value) {
        const amount = Math.max(0, Number(value || 0));
        if (root.maxValue <= 0 || amount <= 0)
            return root.emptyColor;
        const intensity = Math.max(0, Math.min(1, amount / root.maxValue));
        if (intensity < 0.34)
            return ColorUtils.mix(root.emptyColor, root.midColor, intensity / 0.34);
        if (intensity < 0.72)
            return ColorUtils.mix(root.midColor, root.activeColor, (intensity - 0.34) / 0.38);
        return root.activeColor;
    }

    function shouldTexture(value): bool {
        const amount = Math.max(0, Number(value || 0));
        if (amount <= 0 || root.maxValue <= 0)
            return true;
        return amount / root.maxValue < 0.72;
    }

    function textureOpacity(value): real {
        return Number(value || 0) <= 0 ? 0.22 : 0.28;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.preferredWidth: root.heatmapContentWidth
            Layout.alignment: Qt.AlignHCenter
            spacing: root.cellSpacing

            Item { Layout.preferredWidth: root.labelWidth }

            Repeater {
                model: root.weekLabels

                delegate: StyledText {
                    required property string modelData
                    Layout.preferredWidth: root.resolvedCellWidth
                    Layout.minimumWidth: root.resolvedCellWidth
                    Layout.maximumWidth: root.resolvedCellWidth
                    text: modelData
                    color: Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone
                    maximumLineCount: 1
                }
            }
        }

        RowLayout {
            Layout.preferredWidth: root.heatmapContentWidth
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            spacing: root.cellSpacing

            ColumnLayout {
                Layout.preferredWidth: root.labelWidth
                Layout.minimumWidth: root.labelWidth
                Layout.maximumWidth: root.labelWidth
                Layout.fillHeight: true
                spacing: root.cellSpacing

                Repeater {
                    model: root.dayLabels

                    delegate: StyledText {
                        required property string modelData
                        Layout.preferredHeight: root.resolvedCellHeight
                        Layout.minimumHeight: root.resolvedCellHeight
                        Layout.maximumHeight: root.resolvedCellHeight
                        Layout.fillWidth: true
                        text: modelData
                        color: Appearance.colors.colSubtext
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }

            GridLayout {
                id: cellGrid
                Layout.preferredWidth: root.gridContentWidth
                Layout.fillHeight: true
                rows: root.dayCount
                columns: root.weekCount
                rowSpacing: root.cellSpacing
                columnSpacing: root.cellSpacing
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

                Repeater {
                    model: root.cells

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        // Cells are supplied week-major: seven consecutive
                        // entries belong to the same week/column.
                        Layout.row: index % root.dayCount
                        Layout.column: Math.floor(index / root.dayCount)
                        Layout.minimumWidth: root.resolvedCellWidth
                        Layout.maximumWidth: root.resolvedCellWidth
                        Layout.preferredWidth: root.resolvedCellWidth
                        Layout.preferredHeight: root.resolvedCellHeight
                        Layout.minimumHeight: root.resolvedCellHeight
                        Layout.maximumHeight: root.resolvedCellHeight
                        visible: modelData?.inRange !== false
                        color: root.cellColor(modelData?.value)
                        radius: Math.min(Appearance.rounding.verysmall, height / 4)
                        clip: true

                        Canvas {
                            id: cellTexture
                            anchors.fill: parent
                            clip: true
                            visible: root.shouldTexture(modelData?.value)
                            opacity: root.textureOpacity(modelData?.value)
                            property color textureColor: Appearance.colors.colSubtext

                            function paintTexture() {
                                const context = getContext("2d");
                                context.clearRect(0, 0, width, height);
                                context.save();
                                context.beginPath();
                                const cornerRadius = Math.min(parent.radius, width / 2, height / 2);
                                context.moveTo(cornerRadius, 0);
                                context.lineTo(width - cornerRadius, 0);
                                context.quadraticCurveTo(width, 0, width, cornerRadius);
                                context.lineTo(width, height - cornerRadius);
                                context.quadraticCurveTo(width, height, width - cornerRadius, height);
                                context.lineTo(cornerRadius, height);
                                context.quadraticCurveTo(0, height, 0, height - cornerRadius);
                                context.lineTo(0, cornerRadius);
                                context.quadraticCurveTo(0, 0, cornerRadius, 0);
                                context.clip();
                                context.strokeStyle = textureColor;
                                context.lineWidth = Math.max(1, Math.min(2, Math.min(width, height) / 5));
                                const textureSpacing = Math.max(4, Math.min(9, height * 0.42));
                                for (let x = -height; x < width + height; x += textureSpacing) {
                                    context.beginPath();
                                    context.moveTo(x, height);
                                    context.lineTo(x + height, 0);
                                    context.stroke();
                                }
                                context.restore();
                            }

                            onPaint: paintTexture()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onTextureColorChanged: requestPaint()
                        }

                        MouseArea {
                            id: cellArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            StyledToolTip {
                                extraVisibleCondition: cellArea.containsMouse
                                text: modelData?.tooltip || ""
                            }
                        }
                    }
                }
            }
        }
    }
}
