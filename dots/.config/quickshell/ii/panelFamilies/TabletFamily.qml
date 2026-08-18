import QtQuick
import Quickshell

import qs.modules.tablet.bar
import qs.modules.tablet.overview
import qs.modules.tablet.sidebarDashboard

IllogicalImpulseFamilyBase {
    horizontalBarComponent: tabletBarComponent
    overviewComponent: tabletOverviewComponent
    sidebarDashboardComponent: tabletSidebarDashboardComponent
    screenCornersComponent: null

    Component {
        id: tabletBarComponent
        TabletBar {}
    }

    Component {
        id: tabletOverviewComponent
        TabletOverview {}
    }

    Component {
        id: tabletSidebarDashboardComponent
        TabletSidebarDashboard {}
    }
}
