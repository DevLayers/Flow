import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

RippleButton {
    id: root

    required property string mode
    required property string title
    required property string classification
    required property string detailOne
    required property string detailTwo
    required property string modeIcon
    property bool selected: false

    signal modeSelected()

    implicitHeight: Appearance.rounding.verylarge * 4 + Appearance.rounding.normal
    buttonRadius: Appearance.rounding.large
    opacity: root.enabled ? 1 : 0.48

    colBackground: root.selected
        ? ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colPrimaryContainer, 0.24)
        : Appearance.colors.colLayer1
    colBackgroundHover: root.selected
        ? ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colPrimaryContainerHover, 0.32)
        : Appearance.colors.colLayer2Hover
    colBackgroundActive: root.selected
        ? ColorUtils.mix(Appearance.colors.colLayer1Active, Appearance.colors.colPrimaryContainerActive, 0.38)
        : Appearance.colors.colLayer1Active
    colRipple: root.selected
        ? Appearance.colors.colPrimaryContainerActive
        : Appearance.colors.colLayer1Active

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.rounding.normal
        spacing: Appearance.rounding.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.rounding.small

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.modeIcon
                shape: root.selected
                    ? MaterialShape.Shape.Cookie9Sided
                    : MaterialShape.Shape.Clover4Leaf
                iconSize: Appearance.font.pixelSize.large
                padding: Appearance.rounding.small
                fill: 1
                color: root.selected
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colSecondaryContainer
                colSymbol: root.selected
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnSecondaryContainer
                scale: root.selected ? 1.04 : 1

                Behavior on scale {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.classification
                    color: root.selected
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    font.letterSpacing: 0.7
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    color: Appearance.colors.colOnLayer1
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.variableAxes: Appearance.font.variableAxes.titleRounded
                    font.weight: Font.Bold
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignTop
                text: "check_circle"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colPrimary
                opacity: root.selected ? 1 : 0
                scale: root.selected ? 1 : 0.82

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on scale {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.rounding.verysmall
            spacing: Appearance.rounding.verysmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.rounding.small

                StyledText {
                    text: "•"
                    color: root.selected
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Bold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.detailOne
                    color: Appearance.colors.colOnLayer2
                    opacity: 0.82
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.rounding.small

                StyledText {
                    text: "•"
                    color: root.selected
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Bold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.detailTwo
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Appearance.rounding.large
            spacing: Appearance.rounding.verysmall
            opacity: root.selected ? 1 : 0.82

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: root.mode === "connect" ? 2 : 1
                Layout.fillHeight: true
                radius: Appearance.rounding.verysmall
                color: root.selected
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colSecondaryContainer
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: root.mode === "connect" ? 1 : 2
                Layout.fillHeight: true
                radius: Appearance.rounding.verysmall
                color: root.selected
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colLayer2
            }

            Rectangle {
                Layout.preferredWidth: Appearance.rounding.large
                Layout.fillHeight: true
                radius: Appearance.rounding.verysmall
                color: Appearance.colors.colSecondaryContainer
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    onClicked: root.modeSelected()
}
