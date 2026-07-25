pragma Singleton

import QtQuick
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Simple hyprsunset service with automatic mode.
 * In theory we don't need this because hyprsunset has a config file, but it somehow doesn't work.
 * It should also be possible to control it via hyprctl, but it doesn't work consistently either so we're just killing and launching.
 */
Singleton {
    id: root
    signal gammaChangeAttempt()

    readonly property real gammaLowerLimit: 25

    property string from: (Config.options && Config.options.light && Config.options.light.night && Config.options.light.night.from) ? Config.options.light.night.from : "19:00" 
    property string to: (Config.options && Config.options.light && Config.options.light.night && Config.options.light.night.to) ? Config.options.light.night.to : "06:30"
    property bool automatic: (Config.options && Config.options.light && Config.options.light.night && Config.options.light.night.automatic) && (Config ? Config.ready : true)
    property int colorTemperature: (Config.options && Config.options.light && Config.options.light.night && Config.options.light.night.colorTemperature) ? Config.options.light.night.colorTemperature : 5000
    property int gamma: 100
    property bool shouldBeOn
    property bool firstEvaluation: true
    property bool temperatureActive: false
    property int defaultColorTemperature: 6000

    property int fromHour: Number(from.split(":")[0])
    property int fromMinute: Number(from.split(":")[1])
    property int toHour: Number(to.split(":")[0])
    property int toMinute: Number(to.split(":")[1])

    property int clockHour: DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    property var manualActive
    property real manualActiveAt: 0 // Epoch ms of the last manual toggle

    // "never" | "session" | "always" — see Config.options.light.night.persistManual
    readonly property string persistScope: (Config.options && Config.options.light && Config.options.light.night && Config.options.light.night.persistManual) ? Config.options.light.night.persistManual : "always"
    readonly property string _sessionId: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
    property bool restored: false
    property bool _stateApplied: false // A persisted temperature has been pushed to the daemon

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        // Ignore the initial settle of the binding, which happens while Config is still loading
        if (!root.restored)
            return;
        root.manualActive = undefined;
        root.manualActiveAt = 0;
        root.firstEvaluation = true;
        root.persistState();
        reEvaluate();
    }

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t <= to);
        } else {
            // Wrapped around midnight
            return (t >= from || t <= to);
        }
    }

    function minutesOfDay(timestamp) {
        const d = new Date(timestamp);
        return d.getHours() * 60 + d.getMinutes();
    }

    function crossedBoundary(fromMinutes, toMinutes, boundary) {
        if (fromMinutes === toMinutes)
            return false;
        // Walking forward from fromMinutes to toMinutes, possibly wrapping past midnight
        return boundary !== fromMinutes && inBetween(boundary, fromMinutes, toMinutes);
    }

    /**
     * Whether a manual override set at `setAt` (epoch ms) has been overtaken by a
     * schedule boundary since. Only meaningful while automatic mode is on.
     */
    function overrideExpired(setAt) {
        if (!setAt)
            return true;
        const now = Date.now();
        if (now <= setAt)
            return false;
        if (now - setAt >= 24 * 60 * 60 * 1000)
            return true;
        const startMinutes = root.minutesOfDay(setAt);
        const nowMinutes = clockHour * 60 + clockMinute;
        return crossedBoundary(startMinutes, nowMinutes, fromHour * 60 + fromMinute) || crossedBoundary(startMinutes, nowMinutes, toHour * 60 + toMinute);
    }

    function reEvaluate() {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;

        // A manual toggle overrides automatic mode only until the next start/end time.
        // With automatic mode off there is no schedule to fall back to, so it never expires.
        if (root.automatic && root.manualActive !== undefined && root.overrideExpired(root.manualActiveAt)) {
            root.manualActive = undefined;
            root.manualActiveAt = 0;
            root.persistState();
        }
        root.shouldBeOn = inBetween(t, from, to);
        if (firstEvaluation) {
            firstEvaluation = false;
            root.ensureState();
        }
    }

    onShouldBeOnChanged: ensureState()
    function ensureState() {
        // console.log("[Hyprsunset] Ensuring state:", root.shouldBeOn, "Automatic mode:", root.automatic);
        if (!root.automatic || root.manualActive !== undefined)
            return;
        if (root.shouldBeOn) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    function startHyprsunset() {
        Quickshell.execDetached(["bash", "-c", `pidof hyprsunset || hyprsunset`]);
    }

    function load() {
        root.startHyprsunset();
        root.ensureState();
    }

    Timer {
        id: updateHyprsunset
        interval: 100
        repeat: false
        onTriggered: {
            root.ensureState();
            root.setGamma(root.gamma);
        }
    }

    function enableTemperature() {
        root.temperatureActive = true;

        // console.log("[Hyprsunset] Enabling");
        root.startHyprsunset();
        Quickshell.execDetached(["bash", "-c", `hyprctl hyprsunset temperature ${root.colorTemperature}`]);
    }

    function disableTemperature() {
        root.temperatureActive = false;
        // console.log("[Hyprsunset] Disabling");
        Quickshell.execDetached(["bash", "-c", `hyprctl hyprsunset temperature ${root.defaultColorTemperature}`]);
    }

    function applyGamma(gamma, notify) {
        root.gamma = Math.max(root.gammaLowerLimit, Math.min(100, gamma));

        if (notify)
            root.gammaChangeAttempt();

        root.startHyprsunset();
        Quickshell.execDetached(["bash", "-c", `hyprctl hyprsunset gamma ${root.gamma}`]);
    }

    function setGamma(gamma) {
        root.applyGamma(gamma, true);
        root.persistState();
    }

    function fetchState() {
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        running: true
        command: ["bash", "-c", "hyprctl hyprsunset temperature"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                // Once a persisted state has been pushed to the daemon, we are the source
                // of truth — a fetch started before that would report the pre-restore value
                if (root._stateApplied)
                    return;
                const output = stateCollector.text.trim();
                if (output.length == 0 || output.startsWith("Couldn't"))
                    root.temperatureActive = false;
                else
                    root.temperatureActive = (output != root.defaultColorTemperature); // 6000 is the default when off
                // console.log("[Hyprsunset] Fetched state:", output, "->", root.temperatureActive);
            }
        }
    }

    function toggleTemperature(active = undefined) {
        if (root.manualActive === undefined) {
            root.manualActive = root.temperatureActive;
        }

        root.manualActive = active !== undefined ? active : !root.manualActive;
        root.manualActiveAt = Date.now();
        if (root.manualActive) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
        root.persistState();
    }

    function persistState() {
        if (!Persistent.ready)
            return;
        Persistent.states.nightLight.hasManual = (root.manualActive !== undefined);
        Persistent.states.nightLight.manualActive = root.manualActive ?? false;
        Persistent.states.nightLight.manualSetAt = root.manualActiveAt;
        Persistent.states.nightLight.gamma = root.gamma;
        Persistent.states.nightLight.sessionId = root._sessionId;
    }

    function restoreState() {
        root.restored = true;
        if (root.persistScope === "never")
            return;

        const stored = Persistent.states.nightLight;
        if (root.persistScope === "session" && (stored.sessionId || "") !== root._sessionId)
            return;

        // hyprsunset resets to its defaults when it restarts, so the stored values
        // have to be re-applied rather than just assigned. No OSD on startup though.
        const storedGamma = stored.gamma ?? 100;
        if (storedGamma !== 100)
            root.applyGamma(storedGamma, false);

        if (!stored.hasManual)
            return;
        // Don't resurrect an override the schedule has already moved past
        if (root.automatic && root.overrideExpired(stored.manualSetAt))
            return;

        root.manualActive = stored.manualActive;
        root.manualActiveAt = stored.manualSetAt;
        root._stateApplied = true;
        if (root.manualActive) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    Timer {
        id: restoreTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.restored)
                return;
            if (!Persistent.ready || !Config.ready)
                return;
            root.restoreState();
        }
    }

    Connections {
        target: Persistent
        function onReadyChanged() { restoreTimer.restart() }
    }

    Connections {
        target: Config
        function onReadyChanged() { restoreTimer.restart() }
    }

    // Both singletons may already be ready by the time this one loads
    Component.onCompleted: restoreTimer.restart()

    // Change temp
    Connections {
        target: (Config.options && Config.options.light && Config.options.light.night) ? Config.options.light.night : null
        function onColorTemperatureChanged() {
            if (!root.temperatureActive) return;
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", `${Config.options.light.night.colorTemperature}`]);
        }
    }
}