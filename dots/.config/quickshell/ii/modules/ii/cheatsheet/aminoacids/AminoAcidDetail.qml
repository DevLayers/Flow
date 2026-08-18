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

    required property var aa
    required property string schemeName
    signal closeRequested

    focus: true
    Component.onCompleted: root.forceActiveFocus()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        }
    }

    readonly property var klass: root.aa ? AA.classInfo(root.schemeName, AA.classOf(root.aa, root.schemeName)) : null
    readonly property real hueOffset: root.klass ? root.klass.hueOffset : 0
    readonly property real shade: root.klass ? root.klass.shade : 0
    readonly property color tint: ColorUtils.categoryAccent(root.hueOffset, root.shade, Appearance.m3colors.m3primary)
    readonly property color onTint: ColorUtils.categoryOnColor(root.tint)

    function fmt(v, digits, prefix) {
        if (v === null || v === undefined)
            return "—";
        return (prefix ?? "") + v.toFixed(digits ?? 2);
    }

    readonly property string essentialText: {
        switch (root.aa?.essential) {
        case "yes":
            return Translation.tr("Essential");
        case "conditional":
            return Translation.tr("Conditionally essential");
        case "no":
            return Translation.tr("Non-essential");
        default:
            return Translation.tr("Non-canonical, recoded");
        }
    }

    // Scrim
    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    component InfoRow: RowLayout {
        id: infoRow
        required property string label
        required property string value
        Layout.fillWidth: true
        spacing: 8

        StyledText {
            text: infoRow.label
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }
        Item {
            Layout.fillWidth: true
        }
        StyledText {
            text: infoRow.value
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
        }
    }

    StyledRectangularShadow {
        target: card
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 60, 1000)
        height: Math.min(parent.height - 40, contentColumn.implicitHeight + 44)
        radius: Appearance.rounding.windowRounding
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 44
                spacing: 14

                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: Appearance.rounding.full
                    color: root.tint

                    StyledText {
                        anchors.centerIn: parent
                        text: root.aa?.one ?? ""
                        color: root.onTint
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: root.aa?.name ?? ""
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.title
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: `${root.aa?.three ?? ""} · ${root.klass?.name ?? ""} · ${root.essentialText}`
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            // ── Structure + numbers ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 18

                Rectangle {
                    // Without an explicit minimum the sibling ColumnLayout — which
                    // defaults to Layout.fillWidth: true — starves this to zero.
                    Layout.fillWidth: true
                    Layout.minimumWidth: 380
                    Layout.minimumHeight: 300
                    Layout.preferredHeight: 300
                    radius: Appearance.rounding.normal
                    color: ColorUtils.mix(root.tint, Appearance.colors.colLayer2, 0.07)

                    MoleculeStructure {
                        anchors.fill: parent
                        anchors.margins: 20
                        structure: root.aa?.structure ?? null
                        bondLength: 48
                        lineWidth: 2.2
                        wedgeWidth: 11
                        labelSize: Appearance.font.pixelSize.large
                        colMain: Appearance.colors.colOnLayer2
                        colAccent: root.tint
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: false
                    Layout.preferredWidth: 300
                    Layout.minimumWidth: 300
                    Layout.alignment: Qt.AlignTop
                    spacing: 7

                    InfoRow {
                        label: Translation.tr("Formula")
                        value: root.aa?.formula ?? ""
                    }
                    InfoRow {
                        label: Translation.tr("Molar mass")
                        value: root.aa ? `${root.aa.mw.toFixed(2)} g·mol⁻¹` : ""
                    }
                    InfoRow {
                        label: Translation.tr("Residue mass")
                        value: root.aa ? `${root.aa.residue.toFixed(2)} g·mol⁻¹` : ""
                    }
                    InfoRow {
                        label: Translation.tr("Isoelectric point")
                        value: root.fmt(root.aa?.pI, 2)
                    }
                    InfoRow {
                        label: Translation.tr("Hydropathy (KD)")
                        value: root.aa?.kd === null || root.aa?.kd === undefined ? "—" : (root.aa.kd > 0 ? "+" : "") + root.aa.kd.toFixed(1)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.bottomMargin: 2
                        implicitHeight: 1
                        color: Appearance.colors.colLayer0Border
                    }

                    StyledText {
                        text: root.aa?.pKaApprox ? Translation.tr("pKa (approximate)") : Translation.tr("pKa")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }

                    InfoRow {
                        label: "α-COOH"
                        value: root.fmt(root.aa?.pKa?.cooh, 2)
                    }
                    InfoRow {
                        label: "α-NH₃⁺"
                        value: root.fmt(root.aa?.pKa?.nh3, 2)
                    }
                    InfoRow {
                        label: Translation.tr("Side chain")
                        value: root.fmt(root.aa?.pKa?.side, 2)
                    }
                }
            }

            // ── Codons ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: Translation.tr("Codons")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.aa?.codons ?? []

                        delegate: Rectangle {
                            required property string modelData
                            implicitWidth: codonText.implicitWidth + 14
                            implicitHeight: codonText.implicitHeight + 6
                            radius: Appearance.rounding.small
                            color: ColorUtils.transparentize(root.tint, 0.8)

                            StyledText {
                                id: codonText
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: Appearance.colors.colOnLayer1
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.aa?.note ?? ""
                wrapMode: Text.WordWrap
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        RippleButton {
            id: closeButton
            z: 1
            anchors {
                top: card.top
                right: card.right
                topMargin: 14
                rightMargin: 14
            }
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
}
