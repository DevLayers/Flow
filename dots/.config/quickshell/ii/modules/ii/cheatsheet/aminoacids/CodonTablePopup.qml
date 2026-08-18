pragma ComponentBehavior: Bound

import "amino_acids.js" as AA
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property string schemeName
    property string highlightLetter: ""
    signal closeRequested

    focus: true
    Component.onCompleted: root.forceActiveFocus()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        }
    }

    readonly property var bases: ["U", "C", "A", "G"]
    readonly property var blocks: AA.codonRows()
    readonly property real cellWidth: 190
    readonly property real rowHeaderWidth: 26

    function accentOf(letter) {
        const aa = AA.lookup(letter);
        if (!aa)
            return Appearance.colors.colSubtext;
        const info = AA.classInfo(root.schemeName, AA.classOf(aa, root.schemeName));
        return ColorUtils.categoryAccent(info.hueOffset, info.shade, Appearance.m3colors.m3primary);
    }

    // ── One codon of a block ─────────────────────────────────────────────────
    component CodonEntry: Rectangle {
        id: entry
        required property var cell

        readonly property color accent: root.accentOf(entry.cell.letter)
        readonly property bool highlighted: root.highlightLetter !== "" && entry.cell.letter === root.highlightLetter

        implicitHeight: entryRow.implicitHeight + 7
        radius: Appearance.rounding.verysmall
        color: entry.highlighted ? ColorUtils.transparentize(entry.accent, 0.5) : "transparent"

        RowLayout {
            id: entryRow
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 8
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            StyledText {
                text: entry.cell.codon
                color: Appearance.colors.colSubtext
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Rectangle {
                implicitWidth: 8
                implicitHeight: 8
                radius: Appearance.rounding.full
                visible: !entry.cell.stop
                color: entry.accent
            }

            StyledText {
                Layout.fillWidth: true
                text: entry.cell.three
                elide: Text.ElideRight
                color: entry.cell.stop ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: entry.highlighted ? Font.DemiBold : Font.Normal
            }
        }
    }

    // ── The four codons sharing a first and second base ──────────────────────
    component CodonBlock: Rectangle {
        id: block
        required property var cells

        implicitWidth: root.cellWidth
        implicitHeight: blockColumn.implicitHeight + 8
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        Column {
            id: blockColumn
            anchors.centerIn: parent
            width: parent.width - 8
            spacing: 1

            Repeater {
                model: block.cells

                delegate: CodonEntry {
                    required property var modelData
                    width: blockColumn.width
                    cell: modelData
                }
            }
        }
    }

    component BaseLabel: StyledText {
        color: Appearance.colors.colSubtext
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.normal
        font.weight: Font.DemiBold
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    StyledRectangularShadow {
        target: card
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, content.implicitWidth + 40)
        height: Math.min(parent.height - 40, content.implicitHeight + 40)
        radius: Appearance.rounding.windowRounding
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: "table_chart"
                    iconSize: 24
                    color: Appearance.colors.colOnLayer1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Translation.tr("The genetic code")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.title
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: Translation.tr("Standard code, mRNA read 5′ → 3′")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }

                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    onClicked: root.closeRequested()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 22
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }

            // Second-base header
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Item {
                    implicitWidth: root.rowHeaderWidth
                }

                Repeater {
                    model: root.bases

                    delegate: BaseLabel {
                        required property string modelData
                        Layout.preferredWidth: root.cellWidth
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                    }
                }

                Item {
                    implicitWidth: root.rowHeaderWidth
                }
            }

            // One row per first base
            Repeater {
                model: root.bases

                delegate: RowLayout {
                    id: baseRow
                    required property string modelData
                    required property int index

                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    BaseLabel {
                        Layout.preferredWidth: root.rowHeaderWidth
                        horizontalAlignment: Text.AlignHCenter
                        text: baseRow.modelData
                    }

                    Repeater {
                        model: 4

                        delegate: CodonBlock {
                            required property int index
                            cells: root.blocks[baseRow.index * 4 + index].cells
                        }
                    }

                    // Third-base legend
                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Repeater {
                            model: root.bases

                            delegate: StyledText {
                                required property string modelData
                                width: root.rowHeaderWidth
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Appearance.colors.colSubtext
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.preferredWidth: root.rowHeaderWidth * 2 + root.cellWidth * 4 + 16
                Layout.maximumWidth: root.rowHeaderWidth * 2 + root.cellWidth * 4 + 16
                text: Translation.tr("UGA and UAG are read as selenocysteine and pyrrolysine only when a SECIS or PYLIS element follows in the same mRNA.")
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
