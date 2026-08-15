import QtQuick
import Quickshell

import qs.modules.tablet.bar
import qs.modules.tablet.overview

IllogicalImpulseFamilyBase {
    horizontalBarComponent: tabletBarComponent
    overviewComponent: tabletOverviewComponent

    Component {
        id: tabletBarComponent
        TabletBar {}
    }

    Component {
        id: tabletOverviewComponent
        TabletOverview {}
    }
}
