import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.rounding.small

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 430
            Layout.preferredWidth: 3
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1
            clip: true

            ConfigWallpaperSelector {
                anchors.fill: parent
                anchors.margins: Appearance.rounding.small
                text: Translation.tr("Wallpaper")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 360
            Layout.preferredWidth: 2
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.rounding.normal
                spacing: Appearance.rounding.small

                WelcomeLightDarkToggle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: toggleHeight
                    Layout.preferredHeight: toggleHeight
                    Layout.maximumHeight: toggleHeight
                }

                StyledFlickable {
                    id: colorSchemesFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: colorSchemesContent.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: colorSchemesContent
                        width: colorSchemesFlickable.width
                        spacing: Appearance.rounding.small

                        ContentSubsectionLabel {
                            text: Translation.tr("Generated palettes")
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.family: Appearance.font.family.title
                            font.variableAxes: Appearance.font.variableAxes.titleRounded
                            font.weight: Font.Bold
                        }

                        WelcomeColorPreviewGrid {
                            id: generatedColorGrid
                            Layout.fillWidth: true
                            columns: 3
                            customTheme: false
                            builtInTheme: false
                        }

                        ContentSubsectionLabel {
                            text: Translation.tr("Built-in palettes")
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.family: Appearance.font.family.title
                            font.variableAxes: Appearance.font.variableAxes.titleRounded
                            font.weight: Font.Bold
                        }

                        WelcomeColorPreviewGrid {
                            id: builtInColorGrid
                            Layout.fillWidth: true
                            columns: 3
                            customTheme: false
                            builtInTheme: true
                        }

                        ContentSubsectionLabel {
                            visible: Config.options.appearance.customColorSchemes.length > 0
                            text: Translation.tr("Custom palettes")
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.family: Appearance.font.family.title
                            font.variableAxes: Appearance.font.variableAxes.titleRounded
                            font.weight: Font.Bold
                        }

                        WelcomeColorPreviewGrid {
                            id: customColorGrid
                            Layout.fillWidth: true
                            columns: 3
                            customTheme: true
                            builtInTheme: false
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.font.pixelSize.larger + Appearance.rounding.small

                    StyledText {
                        id: paletteLabel
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Appearance.rounding.small
                        text: generatedColorGrid.hoveredColorSchemeDisplayName
                            || builtInColorGrid.hoveredColorSchemeDisplayName
                            || customColorGrid.hoveredColorSchemeDisplayName
                            || generatedColorGrid.selectedColorSchemeDisplayName
                            || builtInColorGrid.selectedColorSchemeDisplayName
                            || customColorGrid.selectedColorSchemeDisplayName
                        color: Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.title
                        font.variableAxes: Appearance.font.variableAxes.titleRounded
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        opacity: text !== "" ? 1 : 0
                        y: text !== "" ? 0 : Appearance.rounding.verysmall

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on y {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                }
            }
        }
    }
}
