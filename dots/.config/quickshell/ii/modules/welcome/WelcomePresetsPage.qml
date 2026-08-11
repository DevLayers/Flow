import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    PagePlaceholder {
        anchors.fill: parent
        shown: true
        icon: "auto_awesome"
        shape: MaterialShape.Shape.Cookie9Sided
        title: Translation.tr("Custom presets are coming")
        description: Translation.tr("This page is reserved for the three built-in II presets.")
    }
}
