import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.ii.onScreenDisplay
import qs.modules.common.widgets
import qs.modules.common

Loader {
    sourceComponent: Config.options.osd.material.enable ? materialOsdComp : minimalOsdComp

    Component {
        id: minimalOsdComp
        OsdValueIndicator {
            id: rotateIcon

            icon: "wb_twilight"
            name: Translation.tr("Gamma")
            from: Hyprsunset.gammaLowerLimit / 100
            value: Hyprsunset.gamma / 100 ?? 0.5
        }
    }

    Component {
        id: materialOsdComp
        OsdMaterialValueIndicator {
            id: osdValues
            value: Hyprsunset.gamma / 100 ?? 0.5
            from: Hyprsunset.gammaLowerLimit / 100
            icon: "wb_twilight"
            shape: MaterialShape.Shape.Gem
        }
    }
}