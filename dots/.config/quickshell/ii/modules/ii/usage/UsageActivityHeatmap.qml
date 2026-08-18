import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Calendar-style activity heatmap. Cells are supplied in week-major order
 * (seven consecutive day entries per week) and the grid keeps square cells.
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
    property real minCellWidth: 0
    property real minCellHeight: 0
    property real maxCellWidth: 46
    property real maxCellHeight: 46
    property real cellSpacing: 4
    property int hoveredIndex: -1

    // Keep the item from contributing an implicit minimum width to its parent
    // layout; the parent card owns the available width.
    implicitWidth: 0

    readonly property real resolvedCellSpacing: root.width > 0
        ? Math.min(root.cellSpacing, root.width / Math.max(1, root.dayCount - 1))
        : 0
    readonly property real resolvedCellSize: root.cellSize > 0
        ? root.cellSize
        : Math.max(Math.max(root.minCellWidth, root.minCellHeight),
            Math.min(root.maxCellWidth, root.maxCellHeight,
                (root.width - (root.dayCount - 1) * root.resolvedCellSpacing)
                    / Math.max(1, root.dayCount),
                (root.height - Appearance.font.pixelSize.normal - 8
                    - (root.weekCount - 1) * root.resolvedCellSpacing)
                    / Math.max(1, root.weekCount)))
    readonly property real resolvedCellWidth: root.resolvedCellSize
    readonly property real resolvedCellHeight: root.resolvedCellSize
    readonly property real gridContentWidth: root.dayCount * root.resolvedCellWidth
        + Math.max(0, root.dayCount - 1) * root.resolvedCellSpacing
    readonly property real gridContentHeight: root.weekCount * root.resolvedCellHeight
        + Math.max(0, root.weekCount - 1) * root.resolvedCellSpacing
    readonly property real heatmapContentWidth: root.gridContentWidth

    readonly property real maxValue: {
        let max = 0;
        for (const cell of root.cells)
            max = Math.max(max, Number(cell?.value || 0));
        return max;
    }

    implicitHeight: Appearance.font.pixelSize.normal + 8
        + root.weekCount * Math.max(root.minCellWidth, root.minCellHeight)
        + (root.weekCount - 1) * root.resolvedCellSpacing

    function cellColor(value) {
        const amount = Math.max(0, Number(value || 0));
        if (root.maxValue <= 0 || amount <= 0)
            return root.emptyColor;
        const intensity = Math.max(0, Math.min(1, amount / root.maxValue));
        if (intensity < 0.34)
            return ColorUtils.mix(root.emptyColor, root.midColor, intensity / 0.34);
        if (intensity < 0.72)
            return ColorUtils.mix(root.midColor, root.activeColor, (intensity - 0.34) / 0.38);
        if (intensity < 0.9)
            return ColorUtils.mix(root.activeColor, root.midColor, 0.14);
        return root.activeColor;
    }

    function shouldTexture(value): bool {
        const amount = Math.max(0, Number(value || 0));
        if (amount <= 0 || root.maxValue <= 0)
            return true;
        return amount / root.maxValue < 0.72;
    }

    function textureOpacity(value): real {
        const amount = Math.max(0, Number(value || 0));
        if (amount <= 0 || root.maxValue <= 0)
            return 0.18;
        return amount / root.maxValue < 0.34 ? 0.18 : 0.30;
    }

    function textureSpacing(value): real {
        const amount = Math.max(0, Number(value || 0));
        const intensity = root.maxValue > 0 ? amount / root.maxValue : 0;
        return intensity < 0.34 ? 9 : 5;
    }

    function textureLineWidth(value): real {
        const amount = Math.max(0, Number(value || 0));
        const intensity = root.maxValue > 0 ? amount / root.maxValue : 0;
        return intensity < 0.34 ? 1 : 2;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Item {
            Layout.fillWidth: true
            implicitHeight: Appearance.font.pixelSize.normal

            RowLayout {
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                width: root.heatmapContentWidth
                height: parent.height
                spacing: root.resolvedCellSpacing

                Repeater {
                    model: root.dayLabels

                    delegate: StyledText {
                        required property string modelData
                        Layout.preferredWidth: root.resolvedCellWidth
                        Layout.minimumWidth: root.resolvedCellWidth
                        Layout.maximumWidth: root.resolvedCellWidth
                        text: modelData
                        color: Appearance.colors.colSubtext
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideNone
                        maximumLineCount: 1
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GridLayout {
                id: cellGrid
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                width: root.gridContentWidth
                height: root.gridContentHeight
                rows: root.weekCount
                columns: root.dayCount
                rowSpacing: root.resolvedCellSpacing
                columnSpacing: root.resolvedCellSpacing

                Repeater {
                    model: root.cells

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        // Cells are supplied week-major: seven consecutive
                        // entries belong to the same calendar week/row.
                        Layout.row: Math.floor(index / root.dayCount)
                        Layout.column: index % root.dayCount
                        Layout.minimumWidth: root.resolvedCellWidth
                        Layout.maximumWidth: root.resolvedCellWidth
                        Layout.preferredWidth: root.resolvedCellWidth
                        Layout.preferredHeight: root.resolvedCellHeight
                        Layout.minimumHeight: root.resolvedCellHeight
                        Layout.maximumHeight: root.resolvedCellHeight
                        visible: true
                        opacity: (modelData?.inRange === false ? 0.24 : 1.0)
                            * (root.hoveredIndex < 0 || root.hoveredIndex === index ? 1.0 : 0.34)
                        color: root.cellColor(modelData?.value)
                        radius: Math.min(Appearance.rounding.verysmall, height / 4)
                        clip: true

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
                                context.lineWidth = root.textureLineWidth(modelData?.value);
                                const textureSpacing = root.textureSpacing(modelData?.value);
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

                            onContainsMouseChanged: {
                                if (containsMouse)
                                    root.hoveredIndex = index;
                                else if (root.hoveredIndex === index)
                                    root.hoveredIndex = -1;
                            }

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
