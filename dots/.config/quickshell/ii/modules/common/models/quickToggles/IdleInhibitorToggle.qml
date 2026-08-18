import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Keep awake")
    statusText: Idle.timed ? Translation.tr("%1 left").arg(Idle.remainingText) : toggled ? Translation.tr("On") : Translation.tr("Off")

    toggled: Idle.inhibit
    icon: toggled ? "kettle" : "coffee"
    mainAction: () => {
        Idle.toggleInhibit()
    }
    hasMenu: true
    tooltipText: Translation.tr("Keep system awake | Right-click to set a duration")
}
