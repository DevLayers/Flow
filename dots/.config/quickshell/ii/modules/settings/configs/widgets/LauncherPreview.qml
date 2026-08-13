pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property real baseWidth: 580
    property real maxHeight: 500
    property bool centered: false
    property real verticalRatio: 0.3

    readonly property real widthProgress: Math.max(0, Math.min(1, (root.baseWidth - 360) / 640))
    readonly property real heightProgress: Math.max(0, Math.min(1, (root.maxHeight - 300) / 600))

    implicitHeight: 286

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "preview"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Launcher preview")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: root.centered ? Translation.tr("Centered") : Translation.tr("Bar edge")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                id: viewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer0
                clip: true

                readonly property real previewWidth: Math.max(220, Math.min(width - 16, 220 + root.widthProgress * Math.max(0, width - 236)))
                readonly property real previewHeight: Math.max(132, Math.min(height - 12, 132 + root.heightProgress * 82))

                Rectangle {
                    id: searchSurface
                    width: viewport.previewWidth
                    height: viewport.previewHeight
                    x: (viewport.width - width) / 2
                    y: root.centered
                        ? Math.max(6, Math.min(viewport.height - height - 6, viewport.height * root.verticalRatio - height / 2))
                        : 6
                    radius: Appearance.rounding.large
                    color: Appearance.colors.colBackgroundSurfaceContainer
                    clip: true

                    Behavior on width {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    Behavior on height {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    Behavior on y {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            spacing: 7

                            MaterialShapeWrappedMaterialSymbol {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                Layout.alignment: Qt.AlignVCenter
                                text: "search"
                                iconSize: Appearance.font.pixelSize.large
                                padding: 7
                                shape: MaterialShape.Shape.Cookie7Sided
                                color: Appearance.colors.colSecondaryContainer
                                colSymbol: Appearance.colors.colOnSecondaryContainer
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colLayer1

                                StyledText {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    text: Translation.tr("Search, calculate or run")
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4

                            Repeater {
                                model: [
                                    {
                                        "icon": "apps",
                                        "label": Translation.tr("Applications"),
                                        "detail": Translation.tr("Open apps and commands")
                                    },
                                    {
                                        "icon": "calculate",
                                        "label": Translation.tr("Calculator"),
                                        "detail": Translation.tr("Math and unit conversions")
                                    },
                                    {
                                        "icon": "travel_explore",
                                        "label": Translation.tr("Search the web"),
                                        "detail": Translation.tr("Use the default browser")
                                    }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    visible: index < 1 + Math.round(root.heightProgress * 2)
                                    radius: Appearance.rounding.small
                                    color: index === 0
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colSurfaceContainerHigh

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        MaterialShape {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            Layout.alignment: Qt.AlignVCenter
                                            implicitSize: 24
                                            shape: MaterialShape.Shape.Cookie7Sided
                                            color: index === 0
                                                ? Appearance.colors.colPrimaryContainer
                                                : Appearance.colors.colSurfaceContainerHighest

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                iconSize: Appearance.font.pixelSize.small
                                                color: index === 0
                                                    ? Appearance.colors.colOnPrimaryContainer
                                                    : Appearance.colors.colOnSurface
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.label
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                font.weight: Font.DemiBold
                                                color: index === 0
                                                    ? Appearance.colors.colOnPrimary
                                                    : Appearance.colors.colOnSurface
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.detail
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: index === 0
                                                    ? Appearance.colors.colOnPrimary
                                                    : Appearance.colors.colSubtext
                                                opacity: 0.8
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
