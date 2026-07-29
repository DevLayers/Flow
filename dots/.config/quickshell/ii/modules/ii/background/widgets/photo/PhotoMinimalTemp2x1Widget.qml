import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "photo_minimal_temp_2x1"

    implicitWidth: 492
    implicitHeight: 240

    readonly property var currentData: Weather.data

    StyledDropShadow {
        id: shadowEffect
        target: mainCard
        visible: Config.options.background.widgets.enableShadows ?? true
    }

    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: Appearance.rounding.windowRounding
        color: WidgetColorScheme.cardBgColor

        Item {
            id: innerContent
            anchors.fill: parent
            anchors.margins: 4

            Rectangle {
                id: maskShape
                anchors.fill: parent
                radius: Appearance.rounding.windowRounding - 4
                visible: false
            }

            Rectangle {
                id: fallbackBg
                anchors.fill: parent
                radius: maskShape.radius
                color: WidgetColorScheme.innerShapeColor
            }

            Image {
                id: photoImage
                anchors.fill: parent
                source: {
                    let entry = Config.options.background.widgets[root.configEntryName];
                    let path = (entry && entry.imagePath && entry.imagePath !== "") ? entry.imagePath : Config.options.background.widgets.photo.imagePath;
                    if (!path || path === "") return "";
                    return path.startsWith("file://") ? path : ("file://" + path);
                }
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            // Crisp clear image layer
            OpacityMask {
                id: maskedImage
                anchors.fill: parent
                source: photoImage
                maskSource: maskShape
                visible: photoImage.status === Image.Ready
            }

            // Bottom-right temp badge
            Item {
                id: tempBadgeContainer
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                height: 48
                width: tempRow.implicitWidth + 32
                visible: {
                    let entry = Config.options.background.widgets[root.configEntryName];
                    return entry && entry.showOverlay !== undefined ? entry.showOverlay : true;
                }

                Rectangle {
                    id: tempMask
                    anchors.fill: parent
                    radius: Appearance.rounding.windowRounding
                    visible: false
                }

                // Blur layer (using technique from BarGradientOverlay.qml)
                Item {
                    anchors.fill: parent
                    layer.enabled: photoImage.status === Image.Ready
                    layer.effect: OpacityMask {
                        maskSource: tempMask
                    }

                    ShaderEffectSource {
                        id: tempShaderSource
                        anchors.fill: parent
                        sourceItem: maskedImage
                        sourceRect: Qt.rect(tempBadgeContainer.x, tempBadgeContainer.y, tempBadgeContainer.width, tempBadgeContainer.height)
                        live: false
                        hideSource: false
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: tempShaderSource
                        blurEnabled: true
                        blurMax: 64
                        blur: 0.65
                    }
                }

                // Semi-transparent color overlay over the blurred region
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Qt.rgba(WidgetColorScheme.cardBgColor.r, WidgetColorScheme.cardBgColor.g, WidgetColorScheme.cardBgColor.b, 0.55)
                }

                RowLayout {
                    id: tempRow
                    anchors.centerIn: parent
                    spacing: 4

                    StyledText {
                        text: (root.currentData && root.currentData.temp) ? root.currentData.temp : "--°C"
                        color: WidgetColorScheme.textColorOnBg
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}
