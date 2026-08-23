pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    property bool credentialsConfigured: false
    property bool authenticating: false
    property bool reauthorizationRequired: false
    property string refreshToken: ""
    property string accessToken: ""
    property int accessTokenExpiry: 0
    property string activeAccountEmail: ""
    property string activeAccountAvatar: ""
    property list<var> calendars: []
    property var events: []
    property bool syncing: false
    property string lastErrorCode: ""
    property string lastErrorMessage: ""
    property int lastHttpStatus: 0

    property var _pendingAction: null
    property var _eventQueue: []
    property var _fetchedEvents: []

    readonly property bool hasRefreshToken: root.refreshToken.length > 0
    readonly property bool available: root.credentialsConfigured && root.hasRefreshToken && !root.reauthorizationRequired

    function startOAuth() {
        if (root.authenticating)
            return;
        root.authenticating = true;
        root.lastErrorCode = "";
        root.lastErrorMessage = "";
        oauthProcess.command = [
            "python3", Directories.scriptPath + "/google/oauth.py", "--scope",
            "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events email profile",
            "--port", "42071"
        ];
        oauthProcess.running = true;
    }

    function disconnect() {
        root.refreshToken = "";
        root.accessToken = "";
        root.accessTokenExpiry = 0;
        root.activeAccountEmail = "";
        root.activeAccountAvatar = "";
        root.calendars = [];
        root.events = [];
        root.reauthorizationRequired = false;
        KeyringStorage.setNestedField(["google_calendar_account"], ({}));
    }

    function refresh() {
        if (!root.available || root.syncing)
            return;
        root.syncing = true;
        root._ensureValidToken({ operation: "calendars" });
    }

    function createEvent(calendarId, fields) {
        if (!root.available)
            return false;
        const body = root.googleFields(fields);
        if (String(body.summary ?? "").trim().length === 0)
            return false;
        root.syncing = true;
        root._ensureValidToken({ operation: "create", calendarId: calendarId || "primary", body: body });
        return true;
    }

    function updateEvent(event, fields) {
        if (!root.available || !event?.id)
            return false;
        root.syncing = true;
        root._ensureValidToken({ operation: "update", calendarId: String(event.calendarId ?? "primary"), eventId: String(event.id), body: root.googleFields(fields) });
        return true;
    }

    function deleteEvent(event) {
        if (!root.available || !event?.id)
            return false;
        root.syncing = true;
        root._ensureValidToken({ operation: "delete", calendarId: String(event.calendarId ?? "primary"), eventId: String(event.id) });
        return true;
    }

    function googleFields(fields) {
        const start = String(fields?.start ?? "");
        const end = String(fields?.end ?? "");
        const allDay = fields?.allDay === true || (!start.includes("T") && start.length > 0);
        const body = {
            summary: String(fields?.summary ?? fields?.title ?? ""),
            description: String(fields?.description ?? ""),
            location: String(fields?.location ?? "")
        };
        if (allDay) {
            body.start = { date: start.slice(0, 10) };
            body.end = { date: end.slice(0, 10) };
        } else {
            body.start = { dateTime: start };
            body.end = { dateTime: end };
        }
        return body;
    }

    function _hasValidAccessToken() {
        return root.accessToken.length > 0 && Math.floor(Date.now() / 1000) < root.accessTokenExpiry - 30;
    }

    function _ensureValidToken(action) {
        root._pendingAction = action;
        if (root._hasValidAccessToken()) {
            root._runAction(action);
            return;
        }
        tokenRefreshProcess.stdinEnabled = true;
        tokenRefreshProcess.running = true;
    }

    function _runAction(action) {
        if (!action)
            return;
        if (action.operation === "calendars") {
            calendarsProcess.stdinEnabled = true;
            calendarsProcess.running = true;
            return;
        }
        mutationProcess.command = ["python3", Directories.scriptPath + "/google_calendar/api.py", action.operation];
        mutationProcess.stdinEnabled = true;
        mutationProcess.running = true;
    }

    function _apiError(result) {
        root.syncing = false;
        root.lastErrorCode = String(result?.code ?? "api_error");
        root.lastErrorMessage = String(result?.message ?? "");
        root.lastHttpStatus = Number(result?.http_status ?? 0);
        if (root.lastHttpStatus === 401) {
            root.accessToken = "";
            root.accessTokenExpiry = 0;
            root._ensureValidToken(root._pendingAction);
        } else if (root.lastErrorCode === "invalid_grant") {
            root.reauthorizationRequired = true;
        }
    }

    function _handleCalendars(output) {
        try {
            const result = JSON.parse(output.trim());
            if (!result.ok) {
                root._apiError(result);
                return;
            }
            const hidden = Array.from(Config.options.search.modules.calendar.hiddenCalendars ?? []);
            root.calendars = Array.from(result.data?.items ?? []).filter(calendar => !hidden.includes(String(calendar.id ?? "")));
            root._eventQueue = root.calendars.slice();
            root._fetchedEvents = [];
            root._fetchNextCalendar();
        } catch (error) {
            root._apiError({ code: "parse_error", message: error.message });
        }
    }

    function _fetchNextCalendar() {
        if (root._eventQueue.length === 0) {
            root.events = root._fetchedEvents.sort((left, right) => new Date(left.startDate) - new Date(right.startDate));
            root.syncing = false;
            return;
        }
        const calendar = root._eventQueue.shift();
        eventsProcess.calendar = calendar;
        eventsProcess.stdinEnabled = true;
        eventsProcess.running = true;
    }

    function _handleEvents(output, calendar) {
        try {
            const result = JSON.parse(output.trim());
            if (!result.ok) {
                root._apiError(result);
                return;
            }
            const values = Array.from(result.data?.items ?? []).map(event => root.normalizeEvent(event, calendar));
            root._fetchedEvents = root._fetchedEvents.concat(values);
            root._fetchNextCalendar();
        } catch (error) {
            root._apiError({ code: "parse_error", message: error.message });
        }
    }

    function normalizeEvent(event, calendar) {
        const startValue = String(event?.start?.dateTime ?? event?.start?.date ?? "");
        const endValue = String(event?.end?.dateTime ?? event?.end?.date ?? "");
        const allDay = !startValue.includes("T");
        return {
            id: String(event?.id ?? ""), uid: String(event?.iCalUID ?? event?.id ?? ""),
            title: String(event?.summary ?? Translation.tr("Untitled event")), content: String(event?.summary ?? Translation.tr("Untitled event")),
            description: String(event?.description ?? ""), location: String(event?.location ?? ""),
            startDate: new Date(startValue), endDate: new Date(endValue), allDay: allDay,
            status: String(event?.status ?? "confirmed"), calendar: String(calendar?.summary ?? ""),
            calendarId: String(calendar?.id ?? "primary"), color: String(event?.backgroundColor ?? calendar?.backgroundColor ?? Appearance.colors.colPrimary),
            url: String(event?.hangoutLink ?? event?.htmlLink ?? ""), htmlLink: String(event?.htmlLink ?? "")
        };
    }

    function _loadStoredAccount() {
        if (!KeyringStorage.loaded || !KeyringStorage.keyringData)
            return;
        const keyring = KeyringStorage.keyringData;
        const account = keyring.google_calendar_account ?? (Array.isArray(keyring.google_tasks_accounts) ? keyring.google_tasks_accounts[0] : null);
        if (!account)
            return;
        root.refreshToken = String(account.refreshToken ?? "");
        root.activeAccountEmail = String(account.email ?? "");
        root.activeAccountAvatar = String(account.avatar ?? "");
    }

    Component.onCompleted: {
        credentialsProcess.running = true;
        root._loadStoredAccount();
    }

    Connections {
        target: KeyringStorage
        function onLoadedChanged() {
            if (KeyringStorage.loaded)
                root._loadStoredAccount();
        }
        function onDataChanged() {
            root._loadStoredAccount();
        }
    }

    Process {
        id: credentialsProcess
        command: ["python3", Directories.scriptPath + "/google/check_credentials.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.credentialsConfigured = JSON.parse(text.trim()).configured === true; }
                catch (error) { root.credentialsConfigured = false; }
            }
        }
    }

    Process {
        id: oauthProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.authenticating = false;
                try {
                    const result = JSON.parse(text.trim());
                    if (!result.ok) {
                        root._apiError(result);
                        return;
                    }
                    root.refreshToken = String(result.refresh_token ?? "");
                    root.accessToken = String(result.access_token ?? "");
                    root.accessTokenExpiry = Math.floor(Date.now() / 1000) + Number(result.expires_in ?? 3600);
                    root.activeAccountEmail = String(result.email ?? "");
                    root.activeAccountAvatar = String(result.picture ?? "");
                    root.reauthorizationRequired = false;
                    KeyringStorage.setNestedField(["google_calendar_account"], {
                        email: root.activeAccountEmail, avatar: root.activeAccountAvatar, refreshToken: root.refreshToken
                    });
                    root.refresh();
                } catch (error) { root._apiError({ code: "parse_error", message: error.message }); }
            }
        }
        onExited: root.authenticating = false
    }

    Process {
        id: tokenRefreshProcess
        command: ["python3", Directories.scriptPath + "/google/token_refresh.py"]
        stdinEnabled: true
        onRunningChanged: if (running) { write(root.refreshToken + "\n"); stdinEnabled = false; }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text.trim());
                    if (!result.ok) { root._apiError(result); return; }
                    root.accessToken = String(result.access_token ?? "");
                    root.accessTokenExpiry = Math.floor(Date.now() / 1000) + Number(result.expires_in ?? 3600);
                    root._runAction(root._pendingAction);
                } catch (error) { root._apiError({ code: "parse_error", message: error.message }); }
            }
        }
    }

    Process {
        id: calendarsProcess
        command: ["python3", Directories.scriptPath + "/google_calendar/api.py", "calendars"]
        stdinEnabled: true
        onRunningChanged: if (running) { write(JSON.stringify({ accessToken: root.accessToken }) + "\n"); stdinEnabled = false; }
        stdout: StdioCollector { onStreamFinished: root._handleCalendars(text) }
    }

    Process {
        id: eventsProcess
        property var calendar: null
        command: ["python3", Directories.scriptPath + "/google_calendar/api.py", "events"]
        stdinEnabled: true
        onRunningChanged: if (running) {
            const start = new Date();
            const end = new Date(start.getTime() + Math.max(1, Config.options.search.modules.calendar.lookaheadDays) * 86400000);
            write(JSON.stringify({ accessToken: root.accessToken, calendarId: String(calendar?.id ?? "primary"), timeMin: start.toISOString(), timeMax: end.toISOString() }) + "\n");
            stdinEnabled = false;
        }
        stdout: StdioCollector { onStreamFinished: root._handleEvents(text, eventsProcess.calendar) }
    }

    Process {
        id: mutationProcess
        stdinEnabled: true
        onRunningChanged: if (running) {
            const action = root._pendingAction ?? ({});
            write(JSON.stringify({ accessToken: root.accessToken, calendarId: action.calendarId, eventId: action.eventId, body: action.body }) + "\n");
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text.trim());
                    if (!result.ok) { root._apiError(result); return; }
                    root.refresh();
                } catch (error) { root._apiError({ code: "parse_error", message: error.message }); }
            }
        }
    }
}
