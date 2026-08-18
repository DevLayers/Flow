pragma ComponentBehavior: Bound

import "amino_acids.js" as AA
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Fills the trailing slots of the grid with a running summary of the set:
 * how many amino acids fall in each class, how many are dietarily essential,
 * and the mass range. Laid out in two columns, because the card is as wide as
 * the slots it spans but no taller than a single card.
 */
Rectangle {
    id: root

    required property string schemeName

    readonly property var classes: AA.scheme(root.schemeName).classes

    readonly property var counts: {
        const m = {};
        for (let i = 0; i < AA.aminoAcids.length; i++) {
            const key = AA.classOf(AA.aminoAcids[i], root.schemeName);
            m[key] = (m[key] ?? 0) + 1;
        }
        return m;
    }

    readonly property int essentialCount: AA.aminoAcids.filter(a => a.essential === "yes").length
    readonly property int conditionalCount: AA.aminoAcids.filter(a => a.essential === "conditional").length

    readonly property var lightest: AA.aminoAcids.reduce((a, b) => b.mw < a.mw ? b : a)
    readonly property var heaviest: AA.aminoAcids.reduce((a, b) => b.mw > a.mw ? b : a)

    implicitWidth: 280
    implicitHeight: 170
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    component StatRow: RowLayout {
        id: statRow
        required property string label
        required property string value
        Layout.fillWidth: true
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: statRow.label
            elide: Text.ElideRight
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }

        StyledText {
            text: statRow.value
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            MaterialSymbol {
                text: "biotech"
                iconSize: 18
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("%1 proteinogenic").arg(AA.aminoAcids.length)
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18

            // Class breakdown. Flows into a second sub-column past five entries
            // so the seven-class scheme still fits the height of one card.
            GridLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                flow: GridLayout.TopToBottom
                rows: Math.min(5, root.classes.length)
                rowSpacing: 3
                columnSpacing: 14

                Repeater {
                    model: root.classes

                    delegate: RowLayout {
                        id: classRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 7

                        Rectangle {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: Appearance.rounding.full
                            color: ColorUtils.categoryAccent(classRow.modelData.hueOffset, classRow.modelData.shade, Appearance.m3colors.m3primary)
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: classRow.modelData.name
                            elide: Text.ElideRight
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {
                            text: root.counts[classRow.modelData.key] ?? 0
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: Appearance.colors.colLayer0Border
            }

            // Dietary need and mass range
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 3

                StatRow {
                    label: Translation.tr("Essential")
                    value: String(root.essentialCount)
                }

                StatRow {
                    label: Translation.tr("Conditionally")
                    value: String(root.conditionalCount)
                }

                StatRow {
                    label: Translation.tr("Lightest")
                    value: `${root.lightest.three} ${root.lightest.mw.toFixed(2)}`
                }

                StatRow {
                    label: Translation.tr("Heaviest")
                    value: `${root.heaviest.three} ${root.heaviest.mw.toFixed(2)}`
                }
            }
        }
    }
}
