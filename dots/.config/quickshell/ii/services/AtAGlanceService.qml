pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.services

Singleton {
    id: root

    readonly property var options: Config.options.background.widgets.at_a_glance
    property int refreshVersion: 0

    readonly property var weatherData: Weather.data
    readonly property bool weatherAvailable: options.enableWeather && Weather.data && Weather.data.temp !== ""
    readonly property string weatherTemperature: weatherAvailable ? String(Weather.data.temp).replace("°C", "°").replace("°F", "°") : ""
    readonly property string weatherDescription: weatherAvailable ? (Weather.data.wDesc || "") : ""
    readonly property string weatherCity: weatherAvailable ? (Weather.data.city || "") : ""
    readonly property int weatherCode: weatherAvailable ? (Weather.data.wCode || 113) : 113

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool mediaAvailable: options.enableMedia && player !== null && String(player.trackTitle || "") !== ""
    readonly property bool mediaPlaying: mediaAvailable && player.playbackState === MprisPlaybackState.Playing
    readonly property string mediaTitle: mediaAvailable ? String(player.trackTitle || Translation.tr("Unknown Title")) : ""
    readonly property string mediaArtist: mediaAvailable ? String(player.trackArtist || Translation.tr("Unknown Artist")) : ""
    readonly property string mediaArtUrl: mediaAvailable ? String(MprisController.artUrl || "") : ""

    readonly property date now: DateTime.clock.date
    readonly property var todayEvents: {
        refreshVersion;
        if (!options.enableCalendar || !CalendarService.khalAvailable || !CalendarService.events)
            return [];
        return CalendarService.events.filter(event => {
            const date = new Date(event.startDate);
            const today = root.now || new Date();
            return date.getFullYear() === today.getFullYear()
                && date.getMonth() === today.getMonth()
                && date.getDate() === today.getDate();
        }).sort((a, b) => new Date(a.startDate) - new Date(b.startDate));
    }

    readonly property var nextEvent: {
        const events = todayEvents;
        const timestamp = (now || new Date()).getTime();
        for (let i = 0; i < events.length; i++) {
            if (new Date(events[i].endDate).getTime() > timestamp)
                return events[i];
        }
        return null;
    }

    readonly property bool calendarAvailable: nextEvent !== null
    readonly property bool calendarActive: calendarAvailable && ((new Date(nextEvent.startDate).getTime() - (now || new Date()).getTime()) <= options.calendarWindowMinutes * 60000)
    readonly property string calendarTitle: calendarAvailable ? String(nextEvent.content || Translation.tr("Calendar event")) : ""
    readonly property string calendarMeta: {
        if (!calendarAvailable)
            return "";
        const start = new Date(nextEvent.startDate);
        const end = new Date(nextEvent.endDate);
        if (start.getTime() <= (now || new Date()).getTime() && end.getTime() > (now || new Date()).getTime())
            return Translation.tr("Now");
        return Qt.formatDateTime(start, Config.options.time.format.includes("ap") || Config.options.time.format.includes("AP") ? "h:mm ap" : "hh:mm");
    }

    readonly property var game: {
        refreshVersion;
        if (!options.enableSports || !SportsService.enabled)
            return null;
        return SportsService.currentGame || (SportsService.allGames && SportsService.allGames.length > 0 ? SportsService.allGames[0] : null);
    }
    readonly property bool sportsAvailable: game !== null
    readonly property bool sportsActive: sportsAvailable && game.state === "in"
    readonly property string sportsTitle: sportsAvailable ? String(game.home.name + " · " + game.away.name) : ""
    readonly property string sportsMeta: sportsAvailable ? String(game.state === "in" ? (game.home.score + " – " + game.away.score) : game.status) : ""
    readonly property string sportsLeague: sportsAvailable ? String(game.league || "") : ""

    readonly property string activeService: chooseService()
    readonly property string activeItemKey: {
        if (activeService === "media") return "media:" + mediaTitle + ":" + mediaArtist;
        if (activeService === "calendar") return "calendar:" + (nextEvent?.uid || calendarTitle);
        if (activeService === "sports") return "sports:" + (game?.id || sportsTitle);
        return "fallback:" + Qt.formatDateTime(now || new Date(), "yyyy-MM-dd");
    }
    readonly property string activeTitle: {
        if (activeService === "media") return mediaTitle;
        if (activeService === "calendar") return calendarTitle;
        if (activeService === "sports") return sportsTitle;
        return Qt.formatDateTime(now || new Date(), "ddd, dd MMM");
    }
    readonly property string activeSubtitle: {
        if (activeService === "media") return mediaArtist;
        if (activeService === "calendar") return calendarMeta;
        if (activeService === "sports") return sportsLeague;
        return Qt.formatDateTime(now || new Date(), Config.options.time.format.includes("ap") || Config.options.time.format.includes("AP") ? "h:mm ap" : "hh:mm");
    }
    readonly property string activeMeta: {
        if (activeService === "sports") return sportsMeta;
        if (activeService === "calendar" && nextEvent?.description) return String(nextEvent.description);
        return mediaPlaying ? Translation.tr("Playing") : (activeService === "media" ? Translation.tr("Paused") : "");
    }
    readonly property string activeIcon: activeService === "media" ? (mediaPlaying ? "play_arrow" : "pause") : (activeService === "calendar" ? "event" : (activeService === "sports" ? "sports_soccer" : "today"))
    readonly property string activeState: activeService === "media" ? (mediaPlaying ? "playing" : "paused") : (activeService === "calendar" ? (calendarMeta === Translation.tr("Now") ? "now" : "upcoming") : (activeService === "sports" ? (game.state === "in" ? "live" : "upcoming") : "idle"))

    function chooseService() {
        refreshVersion;
        const priority = options.servicePriority || ["media", "calendar", "sports", "fallback"];
        for (let i = 0; i < priority.length; i++) {
            const service = priority[i];
            if (service === "media" && mediaAvailable)
                return service;
            if (service === "calendar" && calendarAvailable && (calendarActive || !mediaAvailable))
                return service;
            if (service === "sports" && sportsAvailable && (sportsActive || (!mediaAvailable && !calendarAvailable)))
                return service;
            if (service === "fallback")
                return service;
        }
        return "fallback";
    }

    function refresh() {
        refreshVersion++;
    }

    Connections {
        target: MprisController
        function onActivePlayerChanged() { root.refresh(); }
        function onActiveTrackChanged() { root.refresh(); }
        function onTrackChanged() { root.refresh(); }
    }

    Connections {
        target: CalendarService
        function onEventsChanged() { root.refresh(); }
        function onKhalAvailableChanged() { root.refresh(); }
    }

    Connections {
        target: SportsService
        function onCurrentGameChanged() { root.refresh(); }
        function onAllGamesChanged() { root.refresh(); }
        function onEnabledChanged() { root.refresh(); }
    }

    Connections {
        target: Weather
        function onDataChanged() { root.refresh(); }
    }
}
