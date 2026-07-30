import qs.modules.ii.bar.shared
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../shared/cards"

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.ii.bar

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large
    contentItem: HeroCard {
        id: weatherHero
        anchors.centerIn: parent
        Layout.minimumWidth: 320
        margins: 20
        iconSize: 100
        iconUrl: WeatherIcons.getWeatherIcon(Weather.data?.wCode ?? 113, false)
        pillText: Weather.data.city || "--"
        pillIcon: Weather.data.city ? "location_on" : ""
        title: Weather.data.temp
        subtitle: Weather.data.wDesc
    }
}
