import QtQuick
import Quickshell.Io
import qs.modules.common.models.hyprland
import qs.services

QuickToggleModel {
    id: root
    name: Translation.tr("Game mode")
    toggled: !confOpt.value
    icon: "gamepad"

    // Forces every window opaque so custom opacity rules (kitty/code/etc.) stop applying.
    readonly property string opaqueRule: 'hl.window_rule({name="shell:game-mode-opaque",match={class=".*"},opacity="1.0 override 1.0 override 1.0 override",opaque=true})'
    readonly property string opaqueRuleMarker: "shell:game-mode-opaque"

    mainAction: () => {
        root.toggled = !root.toggled;
        if (root.toggled) {
            HyprlandConfig.setMany({
                "animations:enabled": 0,
                "decoration:shadow:enabled": 0,
                "decoration:blur:enabled": 0,
                "general:gaps_in": 0,
                "general:gaps_out": 0,
                "general:border_size": 1,
                "decoration:rounding": 0,
								"decoration:rounding_power": 0,
                "general:allow_tearing": 1
            }, {
                addLines: [root.opaqueRule]
            });
        } else {
            HyprlandConfig.resetMany([ //
                "animations:enabled", //
                "decoration:shadow:enabled", //
                "decoration:blur:enabled", //
                "general:gaps_in", //
                "general:gaps_out", //
                "general:border_size", //
                "decoration:rounding", //
                "decoration:rounding_power", //
                "general:allow_tearing", //
            ], {
                removeMatching: [root.opaqueRuleMarker]
            });
        }
    }

    HyprlandConfigOption {
        id: confOpt
        key: "animations:enabled"
    }

    tooltipText: Translation.tr("Game mode")
}
