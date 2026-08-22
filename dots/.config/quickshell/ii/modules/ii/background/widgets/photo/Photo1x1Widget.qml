import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "photo_1x1"

    visibleWhenLocked: root.lockBehavior === "keep"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (Config.options.lock.centerWidget === "photo_1x1")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return GlobalStates.screenLocked ? 1 : 0;
        if (GlobalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property real contentScale: (Config.options.background.widgets.photo_1x1.widgetSize ?? 100) / 100.0
    implicitWidth:  240 * contentScale
    implicitHeight: 240 * contentScale

    readonly property var options: Config.options.background.widgets.photo_1x1
    readonly property string shapeName: options?.backgroundShape ?? "Cookie9Sided"
    readonly property var chosenShape: MaterialShape.Shape[shapeName] !== undefined
                                        ? MaterialShape.Shape[shapeName]
                                        : MaterialShape.Shape.Cookie9Sided

    readonly property string imageSource: {
        const customPath = options?.imagePath;
        if (customPath && customPath !== "") {
            return customPath.startsWith("file://") ? customPath : ("file://" + customPath);
        }
        // Fallback to desktop wallpaper if no custom photo set
        const wallPath = Config.options?.background?.wallpaperPath;
        if (wallPath && wallPath !== "") {
            return wallPath.startsWith("file://") ? wallPath : ("file://" + wallPath);
        }
        return "";
    }

    StyledDropShadow {
        target: shapeBg
        visible: Config.options.background.widgets.enableShadows ?? true
    }

    Item {
        anchors.fill: parent

        // 1. Background shape fill
        MaterialShape {
            id: shapeBg
            anchors.fill: parent
            shape: root.chosenShape
            color: WidgetColorScheme.cardBgColor
        }

        // 2. Shape mask for photo image
        MaterialShape {
            id: shapeMask
            anchors.fill: parent
            shape: root.chosenShape
            visible: false
        }

        // 3. Photo Image clipped with OpacityMask
        Image {
            id: photoImg
            anchors.fill: parent
            source: root.imageSource
            fillMode: Image.PreserveAspectCrop
            mipmap: true
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: photoImg
            maskSource: shapeMask
            visible: photoImg.status === Image.Ready
        }

        // Placeholder icon if no photo is available
        MaterialSymbol {
            anchors.centerIn: parent
            visible: photoImg.status !== Image.Ready
            text: "image"
            iconSize: Math.round(48 * root.contentScale)
            color: Appearance.colors.colOnLayer0
            opacity: 0.50
        }
    }
}
