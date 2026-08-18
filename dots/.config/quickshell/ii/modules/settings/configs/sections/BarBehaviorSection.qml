import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentSection {
    icon: "tune"
    title: Translation.tr("Behavior")

    ConfigSwitch {
        buttonIcon: "visibility_off"
        text: Translation.tr("Automatically hide")
        checked: Config.options.bar.autoHide.enable
        enabled: !ShellModePolicy.barPositionLocked
        onCheckedChanged: Config.options.bar.autoHide.enable = checked
        StyledToolTip {
            text: ShellModePolicy.barPositionLocked ? Translation.tr("Auto-hide is locked while 'Dynamic Island in bar center' is active.") : Translation.tr("Automatically hide the bar when not in use")
        }
    }

    ConfigSwitch {
        buttonIcon: "swap_vert"
        text: Translation.tr("Scroll actions")
        checked: Config.options.bar.enableVolumeScroll || Config.options.bar.enableBrightnessScroll
        configPage: Qt.resolvedUrl("../widgets/BarScrollActionsConfig.qml")
        property bool readyForToggle: false
        Component.onCompleted: readyForToggle = true
        onCheckedChanged: {
            if (!readyForToggle)
                return;
            Config.options.bar.enableVolumeScroll = checked;
            Config.options.bar.enableBrightnessScroll = checked;
        }
    }

    ConfigSwitch {
        buttonIcon: "tooltip"
        text: Translation.tr("Enable tooltips")
        checked: Config.options.bar.tooltips.enableTooltips
        configPage: Qt.resolvedUrl("../widgets/BarTooltipsConfig.qml")
        property bool readyForToggle: false
        Component.onCompleted: readyForToggle = true
        onCheckedChanged: {
            if (!readyForToggle || !Config.ready)
                return;
            Config.options.bar.tooltips.enableTooltips = checked;
        }
    }

    ConfigSwitch {
        buttonIcon: "open_in_new"
        text: Translation.tr("Enable popups")
        checked: Config.options.bar.tooltips.enablePopups
        configPage: Qt.resolvedUrl("../widgets/BarPopupsConfig.qml")
        property bool readyForToggle: false
        Component.onCompleted: readyForToggle = true
        onCheckedChanged: {
            if (!readyForToggle || !Config.ready)
                return;
            Config.options.bar.tooltips.enablePopups = checked;
        }
    }
}
