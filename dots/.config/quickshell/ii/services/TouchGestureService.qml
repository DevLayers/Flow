pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common

Singleton {
    id: root

    readonly property var opts:
        (Config.options && Config.options.interactions && Config.options.interactions.touchGestures)
            ? Config.options.interactions.touchGestures
            : null

    readonly property bool enabled:
        Config.ready && Boolean(root.opts && root.opts.enable)

    property string helperStatus: "stopped"
    property string helperError: ""
    property var devices: []

    // Gesture Recognizer States
    readonly property int stateIdle: 0
    readonly property int stateTracking: 1
    readonly property int stateQualified: 2
    readonly property int stateCooldown: 3

    property int gestureState: root.stateIdle

    // Active Gesture Data
    property string activeDeviceId: ""
    property int activeContactId: -1
    property string activeOrigin: ""
    property string activeActionId: ""
    property string activeScreenName: ""

    property real startX: 0
    property real startY: 0
    property real currentX: 0
    property real currentY: 0

    property real startTime: 0
    property real currentTime: 0

    property real primaryTravel: 0
    property real offAxisTravel: 0
    property real progress: 0

    property var velocitySamples: []
    property int activeContactCount: 0
    property bool waitForAllContactsUp: false

    // Signals for feedback overlay
    signal gestureStarted(string screenName, string origin, string actionId, real x, real y)
    signal gestureProgressChanged(string screenName, string origin, string actionId, real progress, real primaryTravel)
    signal gestureCancelled(string screenName, string origin, string actionId)
    signal gestureCommitted(string screenName, string origin, string actionId)

    // Calibration / Visual Overlay preview state
    property bool calibrating: false
    property string calibrationMode: ""
    property real calibrationValue: 0

    function startCalibration(mode, val) {
        calibrating = true;
        calibrationMode = mode;
        calibrationValue = val;
    }

    function updateCalibration(val) {
        calibrationValue = val;
    }

    function stopCalibration() {
        calibrating = false;
        calibrationMode = "";
        calibrationValue = 0;
    }

    Component.onCompleted: {
        console.log("[TouchGestures] Service initialized. enabled:", root.enabled);
    }

    // Fullscreen / Context detection
    function isFullscreenOnScreen(screenName) {
        try {
            var focusedName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
            if (focusedName === screenName && HyprlandData && HyprlandData.activeWindow && HyprlandData.activeWindow.fullscreen) {
                return true;
            }
        } catch (e) {}
        return false;
    }

    readonly property bool gesturesBlocked:
        GlobalStates.screenLocked
        || GlobalStates.regionSelectorOpen
        || GlobalStates.screenshotOverlayOpen
        || (root.opts && root.opts.disableInMediaMode && GlobalStates.isMediaModeActiveForScreen(activeScreenName))
        || (root.opts && root.opts.disableInFullscreen && isFullscreenOnScreen(activeScreenName))

    onGesturesBlockedChanged: {
        if (gesturesBlocked && gestureState !== root.stateIdle) {
            cancelActiveGesture("blocked");
        }
    }

    Timer {
        id: cooldownTimer
        interval: (root.opts && root.opts.cooldownMs) ? root.opts.cooldownMs : 250
        repeat: false
        onTriggered: root.resetGestureState()
    }

    // Safety net: a touch_up that never arrives (or arrives for a contact we are not
    // tracking) would otherwise pin the recognizer in "tracking" forever, leaving the
    // feedback indicator on screen and rejecting every later gesture.
    Timer {
        id: watchdogTimer
        interval: 4000
        repeat: false
        running: root.gestureState === root.stateTracking
        onTriggered: {
            console.warn("[TouchGestures] Watchdog: no touch up after", interval, "ms — forcing reset");
            root.cancelActiveGesture("watchdog-timeout");
            root.forgetContacts();
        }
    }

    // Contact bookkeeping lives outside the gesture state machine, so it needs an
    // explicit reset whenever the event stream is no longer trustworthy.
    function forgetContacts() {
        activeContactCount = 0;
        waitForAllContactsUp = false;
    }

    Process {
        id: helperProcess

        running: root.enabled && !GlobalStates.screenLocked && Directories.scriptPath.length > 0

        command: [
            Directories.scriptPath + "/touchGestures/touch_gestures"
        ]

        onStarted: {
            console.log("[TouchGestures] Process started:", command[0]);
        }

        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }

        stderr: SplitParser {
            onRead: line => console.warn("[TouchGestures-stderr]", line)
        }

        onExited: (code, status) => {
            console.log("[TouchGestures] Process exited. code:", code, "status:", status);
            root.cancelActiveGesture("helper-stopped");
            root.forgetContacts();
            root.devices = [];
            if (root.helperStatus !== "error") {
                root.helperStatus = "stopped";
            }
        }
    }

    function handleLine(line) {
        var event;
        try {
            event = JSON.parse(line);
        } catch (error) {
            console.warn("[TouchGestures] Invalid helper event:", line);
            return;
        }

        switch (event.type) {
        case "ready":
            helperStatus = "ready";
            helperError = "";
            console.log("[TouchGestures] Helper daemon ready");
            break;

        case "device_added":
            addDevice(event);
            break;

        case "device_removed":
            removeDevice(event.deviceId);
            break;

        case "touch_down":
            onTouchDown(event);
            break;

        case "touch_move":
            onTouchMove(event);
            break;

        case "touch_up":
            onTouchUp(event);
            break;

        case "touch_cancel":
            onTouchCancel(event);
            break;

        case "status":
            if (event.code === "no_touchscreen") {
                helperStatus = "no_touchscreen";
                console.log("[TouchGestures] Helper reported: no touchscreen");
            } else if (event.code === "permission_denied") {
                helperStatus = "permission_denied";
                console.warn("[TouchGestures] Permission denied opening /dev/input devices. Add user to 'input' group: sudo usermod -aG input $USER");
            }
            break;

        case "error":
            helperStatus = "error";
            helperError = event.code ? event.code : "unknown";
            console.warn("[TouchGestures] Helper error:", helperError);
            break;
        }
    }

    function addDevice(event) {
        var list = devices.slice();
        var existingIdx = -1;
        for (var i = 0; i < list.length; ++i) {
            if (list[i].deviceId === event.deviceId) {
                existingIdx = i;
                break;
            }
        }
        var entry = {
            deviceId: event.deviceId,
            name: event.name,
            path: event.path,
            kind: event.kind ? event.kind : "touch"
        };
        if (existingIdx >= 0) {
            list[existingIdx] = entry;
        } else {
            list.push(entry);
        }
        devices = list;
        helperStatus = "ready";
        console.log("[TouchGestures] Device registered:", event.name, "(" + event.path + ")");
    }

    function removeDevice(deviceId) {
        var list = [];
        for (var i = 0; i < devices.length; ++i) {
            if (devices[i].deviceId !== deviceId) {
                list.push(devices[i]);
            }
        }
        devices = list;
        if (devices.length === 0) {
            helperStatus = "no_touchscreen";
        }
        if (deviceId === activeDeviceId) {
            cancelActiveGesture("device-removed");
            forgetContacts();
        }
        console.log("[TouchGestures] Device removed:", deviceId);
    }

    function deviceKind(deviceId) {
        for (var i = 0; i < devices.length; ++i) {
            if (devices[i].deviceId === deviceId)
                return devices[i].kind ? devices[i].kind : "touch";
        }
        return "touch";
    }

    function deviceAllowed(deviceId) {
        // An explicitly picked device always wins, stylus included.
        if (root.opts && root.opts.deviceId && root.opts.deviceId !== "auto")
            return root.opts.deviceId === deviceId;

        // A pen is a pointer as well, so it drags and resizes windows while it swipes.
        // Keep it out of the recognizer unless the user asked for it.
        if (deviceKind(deviceId) === "pen")
            return Boolean(root.opts && root.opts.includeStylus);

        return true;
    }

    function screenByName(name) {
        for (var i = 0; i < Quickshell.screens.length; ++i) {
            if (Quickshell.screens[i].name === name) {
                return Quickshell.screens[i];
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function resolveScreenName() {
        if (root.opts && root.opts.targetMonitor && root.opts.targetMonitor !== "auto") {
            for (var i = 0; i < Quickshell.screens.length; ++i) {
                if (Quickshell.screens[i].name === root.opts.targetMonitor)
                    return root.opts.targetMonitor;
            }
        }

        if (Quickshell.screens.length === 1)
            return Quickshell.screens[0].name;

        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
            return Hyprland.focusedMonitor.name;

        if (Quickshell.primaryScreen && Quickshell.primaryScreen.name)
            return Quickshell.primaryScreen.name;

        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    function effectiveTransform(screenName) {
        if (root.opts && root.opts.transform && root.opts.transform !== "auto") {
            var val = parseInt(root.opts.transform, 10);
            return isNaN(val) ? 0 : val;
        }
        if (HyprlandData && HyprlandData.monitors) {
            for (var i = 0; i < HyprlandData.monitors.length; ++i) {
                var m = HyprlandData.monitors[i];
                if (m.name === screenName) {
                    switch (m.transform) {
                    case 1: return 90;
                    case 2: return 180;
                    case 3: return 270;
                    default: return 0;
                    }
                }
            }
        }
        return 0;
    }

    function transformPoint(x, y, screenName) {
        var rot = effectiveTransform(screenName);
        switch (rot) {
        case 90:
            return Qt.point(1 - y, x);
        case 180:
            return Qt.point(1 - x, 1 - y);
        case 270:
            return Qt.point(y, 1 - x);
        default:
            return Qt.point(x, y);
        }
    }

    function classifyOrigin(px, py, width, height) {
        var edge = (root.opts && root.opts.edgeWidth) ? root.opts.edgeWidth : 24;
        var corner = (root.opts && root.opts.cornerSize) ? root.opts.cornerSize : 72;

        if (px <= corner && py <= corner)
            return "topLeftCorner";

        if (px >= width - corner && py <= corner)
            return "topRightCorner";

        if (px <= corner && py >= height - corner)
            return "bottomLeftCorner";

        if (px >= width - corner && py >= height - corner)
            return "bottomRightCorner";

        if (px <= edge)
            return "leftEdge";

        if (px >= width - edge)
            return "rightEdge";

        if (py <= edge)
            return "topEdge";

        if (py >= height - edge)
            return "bottomEdge";

        return "";
    }

    function actionForOrigin(origin) {
        var bindings = root.opts ? root.opts.bindings : null;
        if (!bindings) return "none";

        switch (origin) {
        case "leftEdge": return bindings.leftEdge ? bindings.leftEdge : "none";
        case "rightEdge": return bindings.rightEdge ? bindings.rightEdge : "none";
        case "topEdge": return bindings.topEdge ? bindings.topEdge : "none";
        case "bottomEdge": return bindings.bottomEdge ? bindings.bottomEdge : "none";
        case "topLeftCorner": return bindings.topLeftCorner ? bindings.topLeftCorner : "none";
        case "topRightCorner": return bindings.topRightCorner ? bindings.topRightCorner : "none";
        case "bottomLeftCorner": return bindings.bottomLeftCorner ? bindings.bottomLeftCorner : "none";
        case "bottomRightCorner": return bindings.bottomRightCorner ? bindings.bottomRightCorner : "none";
        default: return "none";
        }
    }

    function calculateTravel(px, py) {
        var dx = px - startX;
        var dy = py - startY;

        switch (activeOrigin) {
        case "leftEdge":
            return { primary: dx, offAxis: Math.abs(dy) };
        case "rightEdge":
            return { primary: -dx, offAxis: Math.abs(dy) };
        case "topEdge":
        case "topLeftCorner":
        case "topRightCorner":
            return { primary: dy, offAxis: Math.abs(dx) };
        case "bottomEdge":
        case "bottomLeftCorner":
        case "bottomRightCorner":
        default:
            return { primary: -dy, offAxis: Math.abs(dx) };
        }
    }

    function currentVelocity() {
        if (velocitySamples.length < 2)
            return 0;

        var first = velocitySamples[0];
        var last = velocitySamples[velocitySamples.length - 1];
        var dt = (last.time - first.time) / 1000;

        if (dt <= 0)
            return 0;

        return (last.distance - first.distance) / dt;
    }

    function onTouchDown(event) {
        // Filtered devices must not reach the contact counter either, or their unpaired
        // ups and downs would drift it away from the real number of fingers down.
        if (!deviceAllowed(event.deviceId))
            return;

        activeContactCount++;

        if (activeContactCount > 1) {
            waitForAllContactsUp = true;
            if (gestureState !== root.stateIdle) {
                cancelActiveGesture("multitouch");
            }
            return;
        }

        if (!enabled || gestureState !== root.stateIdle || waitForAllContactsUp)
            return;

        var screenName = resolveScreenName();
        var screen = screenByName(screenName);
        if (!screen)
            return;

        var pt = transformPoint(event.x, event.y, screenName);
        var px = pt.x * screen.width;
        var py = pt.y * screen.height;

        var origin = classifyOrigin(px, py, screen.width, screen.height);
        if (origin === "") {
            return;
        }

        var actionId = actionForOrigin(origin);
        if (!actionId || actionId === "none")
            return;

        if (gesturesBlocked) {
            console.log("[TouchGestures] Gestures blocked by active modal/lockscreen");
            return;
        }

        activeDeviceId = event.deviceId;
        activeContactId = event.contactId;
        activeOrigin = origin;
        activeActionId = actionId;
        activeScreenName = screenName;

        startX = px;
        startY = py;
        currentX = px;
        currentY = py;

        startTime = event.time;
        currentTime = event.time;

        primaryTravel = 0;
        offAxisTravel = 0;
        progress = 0;
        velocitySamples = [{ distance: 0, time: event.time }];

        gestureState = root.stateTracking;

        console.log("[TouchGestures] Gesture START:", origin, "action:", actionId, "startX:", px.toFixed(0), "startY:", py.toFixed(0));
        gestureStarted(screenName, origin, actionId, px, py);
    }

    function onTouchMove(event) {
        if (event.deviceId !== activeDeviceId || event.contactId !== activeContactId)
            return;

        if (gestureState !== root.stateTracking)
            return;

        var screen = screenByName(activeScreenName);
        if (!screen)
            return;

        var pt = transformPoint(event.x, event.y, activeScreenName);
        var px = pt.x * screen.width;
        var py = pt.y * screen.height;

        currentX = px;
        currentY = py;
        currentTime = event.time;

        var travel = calculateTravel(px, py);
        primaryTravel = travel.primary;
        offAxisTravel = travel.offAxis;

        if (primaryTravel < -8) {
            cancelActiveGesture("reverse-direction");
            return;
        }

        // Direction lock check after 16px
        if (primaryTravel > 16) {
            var angle = Math.atan2(travel.offAxis, Math.max(travel.primary, 0.001)) * 180 / Math.PI;
            var tol = (root.opts && root.opts.directionTolerance) ? root.opts.directionTolerance : 35;
            if (angle > tol) {
                cancelActiveGesture("direction-tolerance-exceeded");
                return;
            }
        }

        velocitySamples.push({ distance: primaryTravel, time: event.time });
        while (velocitySamples.length > 1 && event.time - velocitySamples[0].time > 80) {
            velocitySamples.shift();
        }

        var commitDist = (root.opts && root.opts.commitDistance) ? root.opts.commitDistance : 110;
        progress = Math.max(0, Math.min(1, primaryTravel / commitDist));

        gestureProgressChanged(activeScreenName, activeOrigin, activeActionId, progress, primaryTravel);
    }

    function onTouchUp(event) {
        if (!deviceAllowed(event.deviceId))
            return;

        activeContactCount = Math.max(0, activeContactCount - 1);
        if (activeContactCount === 0) {
            waitForAllContactsUp = false;
        }

        if (event.deviceId !== activeDeviceId || event.contactId !== activeContactId)
            return;

        if (gestureState !== root.stateTracking)
            return;

        var commitDist = (root.opts && root.opts.commitDistance) ? root.opts.commitDistance : 110;
        var minDist = (root.opts && root.opts.minDistance) ? root.opts.minDistance : 44;
        var velThreshold = (root.opts && root.opts.velocityThreshold) ? root.opts.velocityThreshold : 650;

        var vel = currentVelocity();
        var distanceCommit = primaryTravel >= commitDist;
        var flickCommit = primaryTravel >= minDist && vel >= velThreshold;

        if (distanceCommit || flickCommit) {
            commitGesture();
        } else {
            cancelActiveGesture("released-before-threshold (travel: " + primaryTravel.toFixed(0) + "px / needed: " + commitDist + "px)");
        }
    }

    function onTouchCancel(event) {
        if (!deviceAllowed(event.deviceId))
            return;

        activeContactCount = Math.max(0, activeContactCount - 1);
        if (activeContactCount === 0) {
            waitForAllContactsUp = false;
        }

        if (event.deviceId === activeDeviceId && event.contactId === activeContactId) {
            cancelActiveGesture("cancelled");
        }
    }

    function commitGesture() {
        if (gestureState === root.stateIdle)
            return;

        var actionId = activeActionId;
        var screenName = activeScreenName;
        var origin = activeOrigin;

        console.log("[TouchGestures] Gesture COMMITTED:", origin, "-> action:", actionId, "on screen:", screenName);
        gestureCommitted(screenName, origin, actionId);
        TouchGestureActionRegistry.trigger(actionId, screenName);

        enterCooldown();
    }

    function cancelActiveGesture(reason) {
        if (gestureState === root.stateTracking || gestureState === root.stateQualified) {
            console.log("[TouchGestures] Gesture CANCELLED:", reason);
            gestureCancelled(activeScreenName, activeOrigin, activeActionId);
        }
        resetGestureState();
    }

    function enterCooldown() {
        gestureState = root.stateCooldown;
        cooldownTimer.restart();
    }

    function resetGestureState() {
        gestureState = root.stateIdle;
        activeDeviceId = "";
        activeContactId = -1;
        activeOrigin = "";
        activeActionId = "";
        activeScreenName = "";
        startX = 0;
        startY = 0;
        currentX = 0;
        currentY = 0;
        primaryTravel = 0;
        offAxisTravel = 0;
        progress = 0;
        velocitySamples = [];
    }
}
