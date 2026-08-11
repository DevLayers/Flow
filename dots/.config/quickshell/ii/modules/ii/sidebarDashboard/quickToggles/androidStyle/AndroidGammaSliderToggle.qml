import QtQuick
import Quickshell
import qs.services
import Quickshell.Hyprland

AndroidSliderWidgetBase {
    id: root

    property var screen: Brightness.targetScreen
    property var brightnessMonitor: Brightness.getTargetMonitor()

    tooltipText: Translation.tr("Gamma / Brightness")
    materialSymbol: "light_mode"
    secondaryMaterialSymbol: "wb_twilight"
    
    sliderValue: Hyprsunset.gamma === 100 ? 0.3 + (root.brightnessMonitor?.brightness ?? 0) * 0.7 : (Hyprsunset.gamma - Hyprsunset.gammaLowerLimit) / (100 - Hyprsunset.gammaLowerLimit) * 0.3
    onMoved: function(v) {
        if (v >= 0.3) {
            // 0.3 - 1.0 brightness
            root.brightnessMonitor?.setBrightness((v - 0.3) / 0.7);
            if (Hyprsunset.gamma !== 100) {
                Hyprsunset.setGamma(100);
            }
        } else {
            // 0 - 0.3 gamma
            if (root.brightnessMonitor && root.brightnessMonitor.brightness !== 0) {
                root.brightnessMonitor.setBrightness(0);
            }
            Hyprsunset.setGamma((v / 0.3 * (100 - Hyprsunset.gammaLowerLimit) + Hyprsunset.gammaLowerLimit));
        }
    }
}
