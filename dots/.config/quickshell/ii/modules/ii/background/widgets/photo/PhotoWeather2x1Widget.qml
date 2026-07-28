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

    configEntryName: "photo_weather_2x1"

    implicitWidth: 492
    implicitHeight: 240

    readonly property var currentData: Weather.data

    readonly property color cardBgColor: WidgetColorScheme.cardBgColor
    readonly property color textColorOnBg: WidgetColorScheme.textColorOnBg
    readonly property color subtextColorOnBg: WidgetColorScheme.subtextColorOnBg

    StyledDropShadow {
        id: shadowEffect
        target: outerBorder
        visible: Config.options.background.widgets.enableShadows ?? true
    }

    Rectangle {
        id: outerBorder
        anchors.fill: parent
        radius: Appearance.rounding.windowRounding
        color: "transparent"
        border.color: WidgetColorScheme.cardBgColor
        border.width: 4

        Item {
            id: innerContent
            anchors.fill: parent
            anchors.margins: outerBorder.border.width / 2

            Rectangle {
                id: maskShape
                anchors.fill: parent
                radius: Math.max(0, outerBorder.radius - (outerBorder.border.width / 2))
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

            // Bottom glass/overlay pill container
            Item {
                id: overlayContainer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
                height: 76
                visible: {
                    let entry = Config.options.background.widgets[root.configEntryName];
                    return entry && entry.showOverlay !== undefined ? entry.showOverlay : true;
                }

                // Mask defining rounded shape of the glass pill
                Rectangle {
                    id: overlayMask
                    anchors.fill: parent
                    radius: Appearance.rounding.windowRounding
                    visible: false
                }

                // Blur layer (using technique from BarGradientOverlay.qml)
                Item {
                    anchors.fill: parent
                    layer.enabled: photoImage.status === Image.Ready
                    layer.effect: OpacityMask {
                        maskSource: overlayMask
                    }

                    ShaderEffectSource {
                        id: glassShaderSource
                        anchors.fill: parent
                        sourceItem: maskedImage
                        sourceRect: Qt.rect(overlayContainer.x, overlayContainer.y, overlayContainer.width, overlayContainer.height)
                        live: false
                        hideSource: false
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: glassShaderSource
                        blurEnabled: true
                        blurMax: 64
                        blur: 0.65
                    }
                }

                // Semi-transparent color overlay over the blurred region
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.windowRounding
                    color: Qt.rgba(WidgetColorScheme.cardBgColor.r, WidgetColorScheme.cardBgColor.g, WidgetColorScheme.cardBgColor.b, 0.55)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        StyledText {
                            text: (root.currentData && root.currentData.wDesc) ? root.currentData.wDesc : Translation.tr("Clear Sky")
                            color: root.textColorOnBg
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: {
                                const humidity = (root.currentData && root.currentData.humidity !== undefined) ? String(root.currentData.humidity) : "";
                                const city = (root.currentData && root.currentData.city) ? root.currentData.city : "";
                                if (humidity && city) {
                                    return Translation.tr("Humidity %1% in %2").arg(humidity).arg(city);
                                } else if (city) {
                                    return city;
                                } else if (humidity) {
                                    return Translation.tr("Humidity %1%").arg(humidity);
                                }
                                return "";
                            }
                            color: root.subtextColorOnBg
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Normal
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Circle 1: Temperature display
                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: width / 2
                        color: WidgetColorScheme.innerShapeColor

                        StyledText {
                            anchors.centerIn: parent
                            text: (root.currentData && root.currentData.temp) ? root.currentData.temp.replace("°C", "°").replace("°F", "°") : "--°"
                            color: WidgetColorScheme.textColorOnBg
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }
                    }

                    // Circle 2: Weather icon circle
                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: width / 2
                        color: Appearance.colors.colPrimary

                        Image {
                            anchors.centerIn: parent
                            source: WeatherIcons.getWeatherIcon(root.currentData?.wCode ?? 113, false)
                            sourceSize: Qt.size(26, 26)
                        }
                    }
                }
            }
        }
    }
}
