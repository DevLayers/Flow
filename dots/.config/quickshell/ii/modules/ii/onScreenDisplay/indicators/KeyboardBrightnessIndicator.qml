import qs.services
import QtQuick
import Quickshell
import qs.modules.ii.onScreenDisplay
import qs.modules.common.widgets
import qs.modules.common

Loader {
    sourceComponent: Config.options.osd.material.enable ? materialOsdComp : minimalOsdComp

    Component {
        id: minimalOsdComp
        OsdValueIndicator {
            id: kbdBrightnessOsd
            
            icon: "keyboard"
            rotateIcon: false
            scaleIcon: true
            name: Translation.tr("Keyboard Backlight")
            value: KeyboardBacklight.percentage / 100
            shape: MaterialShape.Shape.Hexagon
        }
    }

    Component {
        id: materialOsdComp
        OsdMaterialValueIndicator {
            id: osdValues
            value: KeyboardBacklight.percentage / 100
            icon: "keyboard"
            shape: MaterialShape.Shape.Hexagon
        }
    }
}