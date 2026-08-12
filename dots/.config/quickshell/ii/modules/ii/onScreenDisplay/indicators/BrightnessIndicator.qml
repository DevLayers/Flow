import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.ii.onScreenDisplay
import qs.modules.common.widgets

OsdValueIndicator {
    id: brightnessOsd
    property var brightnessMonitor: Brightness.getTargetMonitor()

    icon: {
        if (Hyprsunset.temperatureActive) return "routine";
        const val = brightnessOsd.value;
        if (val <= 0.33) return "brightness_low";
        if (val <= 0.66) return "brightness_medium";
        return "brightness_high";
    }
    rotateIcon: true
    scaleIcon: true
    name: Translation.tr("Brightness")
    value: brightnessOsd.brightnessMonitor?.brightness ?? 0.5
    shape: MaterialShape.Shape.Burst
}
