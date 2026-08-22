import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.configs.widgets
import "widgets"

ContentPage {
    id: root

    forceWidth: false

    readonly property var opts: (Config.options && Config.options.interactions && Config.options.interactions.touchGestures)
        ? Config.options.interactions.touchGestures
        : null

    property string previewOrigin: "leftEdge"

    Component.onCompleted: {
        TouchGestureService.checkBinary();
    }

    // ── SECTION 1: MASTER & STATUS ──────────────────────────────────────────
    ContentSection {
        icon: "touch_app"
        title: Translation.tr("Touchscreen Gestures")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            TouchGestureStatusCard {
                Layout.fillWidth: true
            }

            ConfigSwitch {
                buttonIcon: "touch_app"
                text: Translation.tr("Enable touchscreen gestures")
                checked: (root.opts && root.opts.enable) ? true : false
                onCheckedChanged: {
                    if (Config.ready && root.opts && checked !== root.opts.enable) {
                        root.opts.enable = checked;
                    }
                }
            }

            ConfigSwitch {
                buttonIcon: "visibility"
                text: Translation.tr("Show visual feedback indicator during gestures")
                checked: (root.opts && root.opts.visualFeedback !== undefined) ? root.opts.visualFeedback : true
                onCheckedChanged: {
                    if (Config.ready && root.opts && checked !== root.opts.visualFeedback) {
                        root.opts.visualFeedback = checked;
                    }
                }
            }

            HelperCodeBox {
                visible: !TouchGestureService.binaryExists
                Layout.fillWidth: true
                icon: "terminal"
                title: Translation.tr("Compile Rust Helper Daemon")
                text: Translation.tr("To compile and install the native touch listener daemon, run this command in your terminal (requires Rust toolchain and cargo). After compiling, restart Quickshell to start the daemon:")
                codeSnippet: "cd " + Directories.scriptPath + "/touchGestures/touch_gestures_src && cargo build --release && cp target/release/touch_gestures ../touch_gestures"
                snippetWrapMode: Text.Wrap
            }

            HelperCodeBox {
                visible: !TouchGestureService.binaryExists
                Layout.fillWidth: true
                icon: "vpn_key"
                title: Translation.tr("Linux Input Group Permissions")
                text: Translation.tr("If the helper reports permission denied when reading /dev/input, add your user to the input group and restart your session:")
                codeSnippet: "sudo usermod -aG input $USER"
                snippetWrapMode: Text.Wrap
            }
        }
    }

    // ── SECTION 2: DEVICE & MONITOR MAPPING ───────────────────────────────────
    ContentSection {
        icon: "devices"
        title: Translation.tr("Device & Output Mapping")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ContentSubsection {
                icon: "touch_app"
                title: Translation.tr("Touchscreen device")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: (root.opts && root.opts.deviceId) ? root.opts.deviceId : "auto"
                    onSelected: function(newValue) {
                        if (Config.ready && root.opts) root.opts.deviceId = newValue;
                    }
                    options: {
                        var list = [{
                            displayName: Translation.tr("Automatic"),
                            icon: "auto_awesome",
                            value: "auto"
                        }];
                        if (TouchGestureService.devices) {
                            for (var i = 0; i < TouchGestureService.devices.length; ++i) {
                                var dev = TouchGestureService.devices[i];
                                list.push({
                                    displayName: dev.name ? dev.name : dev.deviceId,
                                    icon: dev.kind === "pen" ? "stylus" : "touch_app",
                                    value: dev.deviceId
                                });
                            }
                        }
                        return list;
                    }
                }
            }

            ConfigSwitch {
                buttonIcon: "stylus"
                text: Translation.tr("Let the stylus trigger gestures")
                checked: (root.opts && root.opts.includeStylus) ? true : false
                enabled: !root.opts || root.opts.deviceId === "auto"
                onCheckedChanged: {
                    if (Config.ready && root.opts && checked !== root.opts.includeStylus) {
                        root.opts.includeStylus = checked;
                    }
                }

                StyledToolTip {
                    text: Translation.tr("A pen also moves the pointer, so an edge swipe with it can drag or resize the window underneath at the same time. Ignored when a device is picked explicitly above.")
                }
            }

            ContentSubsection {
                icon: "monitor"
                title: Translation.tr("Target monitor")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: (root.opts && root.opts.targetMonitor) ? root.opts.targetMonitor : "auto"
                    onSelected: function(newValue) {
                        if (Config.ready && root.opts) root.opts.targetMonitor = newValue;
                    }
                    options: {
                        var list = [{
                            displayName: Translation.tr("Automatic / focused"),
                            icon: "center_focus_strong",
                            value: "auto"
                        }];
                        for (var i = 0; i < Quickshell.screens.length; ++i) {
                            var scr = Quickshell.screens[i];
                            list.push({
                                displayName: scr.name,
                                icon: "monitor",
                                value: scr.name
                            });
                        }
                        return list;
                    }
                }
            }

            ContentSubsection {
                icon: "screen_rotation"
                title: Translation.tr("Coordinate rotation")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: (root.opts && root.opts.transform) ? root.opts.transform : "auto"
                    onSelected: function(newValue) {
                        if (Config.ready && root.opts) root.opts.transform = newValue;
                    }
                    options: [
                        { displayName: Translation.tr("Automatic"), icon: "auto_awesome", value: "auto" },
                        { displayName: "0°", icon: "crop_portrait", value: "0" },
                        { displayName: "90°", icon: "crop_landscape", value: "90" },
                        { displayName: "180°", icon: "crop_portrait", value: "180" },
                        { displayName: "270°", icon: "crop_landscape", value: "270" }
                    ]
                }
            }
        }
    }

    // ── SECTION 3: GESTURE BINDINGS ──────────────────────────────────────────
    ContentSection {
        icon: "swipe"
        title: Translation.tr("Gesture Bindings")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            TouchGestureScreenPreview {
                Layout.fillWidth: true
                highlightedOrigin: root.previewOrigin
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.width >= 680 ? 2 : 1
                columnSpacing: 10
                rowSpacing: 10

                TouchGestureBindingCard {
                    title: Translation.tr("Left Edge Swipe")
                    description: Translation.tr("Swipe from the left edge toward the center")
                    directionIcon: "arrow_forward"
                    origin: "leftEdge"
                    actionId: (root.opts && root.opts.bindings && root.opts.bindings.leftEdge) ? root.opts.bindings.leftEdge : "sidebarLeft"
                    isHighlighted: root.previewOrigin === "leftEdge"
                    onCardHovered: function(orig) { root.previewOrigin = orig; }
                    onActionSelected: function(act) {
                        if (Config.ready && root.opts && root.opts.bindings) root.opts.bindings.leftEdge = act;
                    }
                }

                TouchGestureBindingCard {
                    title: Translation.tr("Right Edge Swipe")
                    description: Translation.tr("Swipe from the right edge toward the center")
                    directionIcon: "arrow_back"
                    origin: "rightEdge"
                    actionId: (root.opts && root.opts.bindings && root.opts.bindings.rightEdge) ? root.opts.bindings.rightEdge : "sidebarRight"
                    isHighlighted: root.previewOrigin === "rightEdge"
                    onCardHovered: function(orig) { root.previewOrigin = orig; }
                    onActionSelected: function(act) {
                        if (Config.ready && root.opts && root.opts.bindings) root.opts.bindings.rightEdge = act;
                    }
                }

                TouchGestureBindingCard {
                    title: Translation.tr("Top Edge Swipe")
                    description: Translation.tr("Swipe from the top edge downward")
                    directionIcon: "arrow_downward"
                    origin: "topEdge"
                    actionId: (root.opts && root.opts.bindings && root.opts.bindings.topEdge) ? root.opts.bindings.topEdge : "cheatsheet"
                    isHighlighted: root.previewOrigin === "topEdge"
                    onCardHovered: function(orig) { root.previewOrigin = orig; }
                    onActionSelected: function(act) {
                        if (Config.ready && root.opts && root.opts.bindings) root.opts.bindings.topEdge = act;
                    }
                }

                TouchGestureBindingCard {
                    title: Translation.tr("Bottom Edge Swipe")
                    description: Translation.tr("Swipe from the bottom edge upward")
                    directionIcon: "arrow_upward"
                    origin: "bottomEdge"
                    actionId: (root.opts && root.opts.bindings && root.opts.bindings.bottomEdge) ? root.opts.bindings.bottomEdge : "overview"
                    isHighlighted: root.previewOrigin === "bottomEdge"
                    onCardHovered: function(orig) { root.previewOrigin = orig; }
                    onActionSelected: function(act) {
                        if (Config.ready && root.opts && root.opts.bindings) root.opts.bindings.bottomEdge = act;
                    }
                }

                TouchGestureBindingCard {
                    title: Translation.tr("Top-Left Corner")
                    description: Translation.tr("Swipe downward from the top-left corner")
                    directionIcon: "south_east"
                    origin: "topLeftCorner"
                    actionId: (root.opts && root.opts.bindings && root.opts.bindings.topLeftCorner) ? root.opts.bindings.topLeftCorner : "none"
                    isHighlighted: root.previewOrigin === "topLeftCorner"
                    onCardHovered: function(orig) { root.previewOrigin = orig; }
                    onActionSelected: function(act) {
                        if (Config.ready && root.opts && root.opts.bindings) root.opts.bindings.topLeftCorner = act;
                    }
                }

                TouchGestureBindingCard {
                    title: Translation.tr("Top-Right Corner")
                    description: Translation.tr("Swipe downward from the top-right corner")
                    directionIcon: "south_west"
                    origin: "topRightCorner"
                    actionId: (root.opts && root.opts.bindings && root.opts.bindings.topRightCorner) ? root.opts.bindings.topRightCorner : "none"
                    isHighlighted: root.previewOrigin === "topRightCorner"
                    onCardHovered: function(orig) { root.previewOrigin = orig; }
                    onActionSelected: function(act) {
                        if (Config.ready && root.opts && root.opts.bindings) root.opts.bindings.topRightCorner = act;
                    }
                }

                TouchGestureBindingCard {
                    title: Translation.tr("Bottom-Left Corner")
                    description: Translation.tr("Swipe upward from the bottom-left corner")
                    directionIcon: "north_east"
                    origin: "bottomLeftCorner"
                    actionId: (root.opts && root.opts.bindings && root.opts.bindings.bottomLeftCorner) ? root.opts.bindings.bottomLeftCorner : "none"
                    isHighlighted: root.previewOrigin === "bottomLeftCorner"
                    onCardHovered: function(orig) { root.previewOrigin = orig; }
                    onActionSelected: function(act) {
                        if (Config.ready && root.opts && root.opts.bindings) root.opts.bindings.bottomLeftCorner = act;
                    }
                }

                TouchGestureBindingCard {
                    title: Translation.tr("Bottom-Right Corner")
                    description: Translation.tr("Swipe upward from the bottom-right corner")
                    directionIcon: "north_west"
                    origin: "bottomRightCorner"
                    actionId: (root.opts && root.opts.bindings && root.opts.bindings.bottomRightCorner) ? root.opts.bindings.bottomRightCorner : "osk"
                    isHighlighted: root.previewOrigin === "bottomRightCorner"
                    onCardHovered: function(orig) { root.previewOrigin = orig; }
                    onActionSelected: function(act) {
                        if (Config.ready && root.opts && root.opts.bindings) root.opts.bindings.bottomRightCorner = act;
                    }
                }
            }
        }
    }

    // ── SECTION 4: SENSITIVITY & SLIDERS ─────────────────────────────────────
    ContentSection {
        icon: "tune"
        title: Translation.tr("Sensitivity & Detection")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ContentSubsection {
                icon: "speed"
                title: Translation.tr("Sensitivity Presets")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: {
                        if (!root.opts) return "balanced";
                        var e = root.opts.edgeWidth;
                        var c = root.opts.cornerSize;
                        var m = root.opts.minDistance;
                        var cd = root.opts.commitDistance;
                        if (e === 18 && c === 72 && m === 44 && cd === 110) return "balanced";
                        if (e === 12 && c === 56 && m === 60 && cd === 145) return "strict";
                        if (e === 28 && c === 92 && m === 34 && cd === 86) return "relaxed";
                        return "custom";
                    }
                    options: [
                        { displayName: Translation.tr("Balanced"), icon: "balance", value: "balanced" },
                        { displayName: Translation.tr("Strict"), icon: "lock", value: "strict" },
                        { displayName: Translation.tr("Relaxed"), icon: "hotel", value: "relaxed" }
                    ]
                    onSelected: function(preset) {
                        if (!Config.ready || !root.opts) return;
                        if (preset === "balanced") {
                            root.opts.edgeWidth = 18;
                            root.opts.cornerSize = 72;
                            root.opts.minDistance = 44;
                            root.opts.commitDistance = 110;
                            root.opts.velocityThreshold = 650;
                            root.opts.directionTolerance = 35;
                            root.opts.cooldownMs = 250;
                        } else if (preset === "strict") {
                            root.opts.edgeWidth = 12;
                            root.opts.cornerSize = 56;
                            root.opts.minDistance = 60;
                            root.opts.commitDistance = 145;
                            root.opts.velocityThreshold = 850;
                            root.opts.directionTolerance = 25;
                            root.opts.cooldownMs = 350;
                        } else if (preset === "relaxed") {
                            root.opts.edgeWidth = 28;
                            root.opts.cornerSize = 92;
                            root.opts.minDistance = 34;
                            root.opts.commitDistance = 86;
                            root.opts.velocityThreshold = 480;
                            root.opts.directionTolerance = 45;
                            root.opts.cooldownMs = 200;
                        }
                    }
                }
            }

            ConfigSlider {
                buttonIcon: "border_left"
                text: Translation.tr("Edge detection zone (px)")
                usePercentTooltip: false
                value: (root.opts && root.opts.edgeWidth) ? root.opts.edgeWidth : 24
                from: 8
                to: 64
                stepSize: 1
                onValueChanged: {
                    if (Config.ready && root.opts) {
                        root.opts.edgeWidth = Math.round(value);
                        if (isPressed) TouchGestureService.updateCalibration(Math.round(value));
                    }
                }
                onIsPressedChanged: {
                    if (isPressed) {
                        TouchGestureService.startCalibration("edgeWidth", Math.round(value));
                    } else {
                        TouchGestureService.stopCalibration();
                    }
                }
            }

            ConfigSlider {
                buttonIcon: "crop_square"
                text: Translation.tr("Corner detection zone (px)")
                usePercentTooltip: false
                value: (root.opts && root.opts.cornerSize) ? root.opts.cornerSize : 72
                from: 32
                to: 160
                stepSize: 2
                onValueChanged: {
                    if (Config.ready && root.opts) {
                        root.opts.cornerSize = Math.round(value);
                        if (isPressed) TouchGestureService.updateCalibration(Math.round(value));
                    }
                }
                onIsPressedChanged: {
                    if (isPressed) {
                        TouchGestureService.startCalibration("cornerSize", Math.round(value));
                    } else {
                        TouchGestureService.stopCalibration();
                    }
                }
            }

            ConfigSlider {
                buttonIcon: "linear_scale"
                text: Translation.tr("Minimum travel before recognition (px)")
                usePercentTooltip: false
                value: (root.opts && root.opts.minDistance) ? root.opts.minDistance : 44
                from: 16
                to: 80
                stepSize: 2
                onValueChanged: {
                    if (Config.ready && root.opts) {
                        root.opts.minDistance = Math.round(value);
                        if (isPressed) TouchGestureService.updateCalibration(Math.round(value));
                    }
                }
                onIsPressedChanged: {
                    if (isPressed) {
                        TouchGestureService.startCalibration("minDistance", Math.round(value));
                    } else {
                        TouchGestureService.stopCalibration();
                    }
                }
            }

            ConfigSlider {
                buttonIcon: "check"
                text: Translation.tr("Commit activation distance (px)")
                usePercentTooltip: false
                value: (root.opts && root.opts.commitDistance) ? root.opts.commitDistance : 110
                from: 60
                to: 240
                stepSize: 5
                onValueChanged: {
                    if (Config.ready && root.opts) {
                        root.opts.commitDistance = Math.round(value);
                        if (isPressed) TouchGestureService.updateCalibration(Math.round(value));
                    }
                }
                onIsPressedChanged: {
                    if (isPressed) {
                        TouchGestureService.startCalibration("commitDistance", Math.round(value));
                    } else {
                        TouchGestureService.stopCalibration();
                    }
                }
            }

            ConfigSlider {
                buttonIcon: "bolt"
                text: Translation.tr("Flick velocity threshold (px/s)")
                usePercentTooltip: false
                value: (root.opts && root.opts.velocityThreshold) ? root.opts.velocityThreshold : 650
                from: 200
                to: 1600
                stepSize: 25
                onValueChanged: {
                    if (Config.ready && root.opts) root.opts.velocityThreshold = Math.round(value);
                }
            }

            ConfigSlider {
                buttonIcon: "rotate_90_degrees_ccw"
                text: Translation.tr("Direction angle tolerance (degrees)")
                usePercentTooltip: false
                value: (root.opts && root.opts.directionTolerance) ? root.opts.directionTolerance : 35
                from: 15
                to: 60
                stepSize: 1
                onValueChanged: {
                    if (Config.ready && root.opts) root.opts.directionTolerance = Math.round(value);
                }
            }

            ConfigSlider {
                buttonIcon: "timer"
                text: Translation.tr("Gesture cooldown (ms)")
                usePercentTooltip: false
                value: (root.opts && root.opts.cooldownMs) ? root.opts.cooldownMs : 250
                from: 100
                to: 800
                stepSize: 25
                onValueChanged: {
                    if (Config.ready && root.opts) root.opts.cooldownMs = Math.round(value);
                }
            }
        }
    }

    // ── SECTION 5: BEHAVIOR & RESTORE ────────────────────────────────────────
    ContentSection {
        icon: "security"
        title: Translation.tr("Behavior & Context")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "fullscreen"
                text: Translation.tr("Disable gestures in fullscreen applications")
                checked: (root.opts && root.opts.disableInFullscreen) ? true : false
                onCheckedChanged: {
                    if (Config.ready && root.opts) root.opts.disableInFullscreen = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "movie"
                text: Translation.tr("Disable gestures in Media Mode")
                checked: (root.opts && root.opts.disableInMediaMode !== undefined) ? root.opts.disableInMediaMode : true
                onCheckedChanged: {
                    if (Config.ready && root.opts) root.opts.disableInMediaMode = checked;
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8

                RippleButtonWithIcon {
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "restart_alt"
                    mainText: Translation.tr("Restore default bindings")
                    onClicked: {
                        if (Config.ready && root.opts && root.opts.bindings) {
                            root.opts.bindings.leftEdge = "sidebarLeft";
                            root.opts.bindings.rightEdge = "sidebarRight";
                            root.opts.bindings.topEdge = "cheatsheet";
                            root.opts.bindings.bottomEdge = "overview";
                            root.opts.bindings.topLeftCorner = "none";
                            root.opts.bindings.topRightCorner = "none";
                            root.opts.bindings.bottomLeftCorner = "none";
                            root.opts.bindings.bottomRightCorner = "osk";
                        }
                    }
                }

                RippleButtonWithIcon {
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "refresh"
                    mainText: Translation.tr("Reset sensitivity")
                    onClicked: {
                        if (Config.ready && root.opts) {
                            root.opts.edgeWidth = 18;
                            root.opts.cornerSize = 72;
                            root.opts.minDistance = 44;
                            root.opts.commitDistance = 110;
                            root.opts.velocityThreshold = 650;
                            root.opts.directionTolerance = 35;
                            root.opts.cooldownMs = 250;
                        }
                    }
                }

                RippleButtonWithIcon {
                    visible: TouchGestureService.binaryExists
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "delete"
                    colText: Appearance.colors.colError
                    mainText: Translation.tr("Delete compiled binary")
                    onClicked: {
                        TouchGestureService.deleteBinary();
                    }
                }
            }
        }
    }

    // ── SECTION 6: TOUCHPAD & SCROLLING ──────────────────────────────────────
    ContentSection {
        icon: "mouse"
        title: Translation.tr("Touchpad & Scrolling")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "speed"
                text: Translation.tr("Faster touchpad scrolling")
                checked: Config.options.interactions.scrolling.fasterTouchpadScroll ?? false
                onCheckedChanged: {
                    Config.options.interactions.scrolling.fasterTouchpadScroll = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Enables accelerated smooth scrolling across menus, panels, and lists when using a touchpad.")
                }
            }
        }
    }

    // ── SECTION 7: COMPATIBILITY NOTICE ──────────────────────────────────────
    ContentSection {
        icon: "info"
        title: Translation.tr("Compatibility Notice")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "info"
                text: Translation.tr("Hyprland touchscreen workspace gestures may overlap with edge gestures. Disable the conflicting binding in ii or the Hyprland workspace touchscreen gesture if both react to the same swipe.")
            }
        }
    }
}
