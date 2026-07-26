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

    configEntryName: "photo_pill_2x1"

    implicitWidth: 492
    implicitHeight: 240

    readonly property color accentBgColor: WidgetColorScheme.accentColor
    readonly property color onAccentTextColor: WidgetColorScheme.onAccentColor

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
                radius: Appearance.rounding.windowRounding
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
        }
    }
}

