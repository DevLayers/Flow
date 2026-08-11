import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentPage {
    id: dynamicIslandConfigRoot

    forceWidth: false
    readonly property bool barNotTop: Config.options.bar.bottom || Config.options.bar.vertical
    readonly property bool centerInBarActive: Config.options.bar.floatingNotch.centerInBar

    // ── Dynamic Island in Bar Center ──────────────────────────────────────
    ContentSection {
        icon: "align_justify_center"
        title: Translation.tr("Dynamic Island in Bar Center")

        ConfigSwitch {
            buttonIcon: "align_justify_center"
            text: Translation.tr("Dynamic Island in bar center")
            checked: Config.options.bar.floatingNotch.centerInBar
            enabled: !dynamicIslandConfigRoot.barNotTop

            onCheckedChanged: {
                if (checked === Config.options.bar.floatingNotch.centerInBar)
                    return;

                if (checked) {
                    // Turn off Floating Dynamic Island toggle if active
                    Config.options.bar.floatingNotch.enable = false;

                    // Apply all prerequisites BEFORE setting centerInBar
                    Config.options.sidebar.sidebarStyle = "default";
                    Config.options.bar.bottom = false;
                    Config.options.bar.vertical = false;
                    if (Config.options.bar.barBackgroundStyle !== 3)
                        Config.options.bar.barBackgroundStyle = 0;
                    if (Config.options.appearance.fakeScreenRounding === 3 || Config.options.appearance.fakeScreenRounding === 4)
                        Config.options.appearance.fakeScreenRounding = 1;
                    Config.options.bar.autoHide.enable = false;

                    // Clear all center layout widgets (set visible: false)
                    var cl = Config.options.bar.layouts.center;
                    if (cl && cl.length) {
                        var cleared = [];
                        for (var i = 0; i < cl.length; i++) {
                            cleared.push({ id: cl[i].id, centered: cl[i].centered, visible: false });
                        }
                        Config.options.bar.layouts.center = cleared;
                    }

                    Config.options.bar.floatingNotch.centerInBar = true;
                } else {
                    Config.options.bar.floatingNotch.centerInBar = false;
                }
            }

            StyledToolTip {
                text: Translation.tr("Positions the Dynamic Island on top of the bar center. Forces Default mode, bar Top, Transparent background, hides center widgets.")
            }
        }

        NoticeBox {
            Layout.fillWidth: true
            visible: !dynamicIslandConfigRoot.centerInBarActive
            materialIcon: "info"
            text: Translation.tr("Prerequisites to enable:\n• Bar position must be set to Top\n• Bar background style must be Transparent or Islands\n• No widgets can be placed in the bar center layout")

            ShortcutBox {
                targetPageId: "bar"
                targetSectionTitle: Translation.tr("Bar position")
                materialIcon: "arrow_forward"
                text: Translation.tr("Go to Bar settings")
                linkText: Translation.tr("Go there")
            }
        }

        NoticeBox {
            Layout.fillWidth: true
            visible: dynamicIslandConfigRoot.centerInBarActive
            materialIcon: "check_circle"
            text: Translation.tr("Active: Dynamic Island floats above the bar center. All prerequisites are active and locked (Bar at Top, Transparent background, Center widgets hidden).")
        }

    }

    // ── General ───────────────────────────────────────────────────────────
    ContentSection {
        icon: "water_drop"
        title: Translation.tr("Floating Dynamic Island")

        NoticeBox {
            Layout.fillWidth: true
            materialIcon: "warning"
            text: Translation.tr("The search only works with dynamic island in connect mode.")

            RippleButtonWithIcon {
                buttonRadius: Appearance.rounding.small
                materialIcon: "arrow_forward"
                mainText: Translation.tr("Switch to connect mode")
                onClicked: {
                    var win = dynamicIslandConfigRoot.QsWindow.window;
                    if (!win || win.pageIndexById === undefined)
                        return ;

                    const idx = win.pageIndexById("bar");
                    if (idx < 0)
                        return ;

                    win.pendingSectionHighlight = Translation.tr("Shell mode");
                    win.currentPage = idx;
                }
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
            }

        }

        NoticeBox {
            Layout.fillWidth: true
            visible: Config.options.sidebar.sidebarStyle === "default" && !Config.options.bar.floatingNotch.centerInBar
            materialIcon: "block"
            text: Translation.tr("The Floating Dynamic Island requires Connect shell mode. Switch to Connect mode to use this feature.")

            ShortcutBox {
                targetPageId: "bar"
                targetSectionTitle: Translation.tr("Shell mode")
                materialIcon: "arrow_forward"
                text: Translation.tr("Go to Shell mode settings")
                linkText: Translation.tr("Go there")
            }
        }

        ConfigSwitch {
            buttonIcon: "water_drop"
            text: Translation.tr("Floating Dynamic Island")
            checked: Config.options.bar.floatingNotch.enable
            enabled: Config.options.sidebar.sidebarStyle !== "default"
            onCheckedChanged: {
                if (checked === Config.options.bar.floatingNotch.enable)
                    return;

                if (checked && Config.options.bar.floatingNotch.centerInBar) {
                    Config.options.bar.floatingNotch.centerInBar = false;
                }
                Config.options.bar.floatingNotch.enable = checked;
            }

            StyledToolTip {
                text: Translation.tr("Enables an independent, floating Dynamic Island at the top of the screen")
            }
        }

        ConfigSwitch {
            buttonIcon: "visibility_off"
            text: Translation.tr("Always hide floating island")
            visible: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            enabled: true
            checked: Config.options.bar.floatingNotch.autoHide
            onCheckedChanged: {
                Config.options.bar.floatingNotch.autoHide = checked;
            }

            StyledToolTip {
                text: Translation.tr("Hides the island until a workspace, media, Bluetooth, notification, or other activity trigger reveals it")
            }
        }

        ConfigSwitch {
            buttonIcon: "filter_drama"
            text: Translation.tr("Floating Island drop-shadow")
            visible: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            checked: Config.options.bar.floatingNotch.dropShadow
            onCheckedChanged: {
                Config.options.bar.floatingNotch.dropShadow = checked;
            }

            StyledToolTip {
                text: Translation.tr("Shows a drop shadow underneath the floating island")
            }

        }

        ConfigSwitch {
            buttonIcon: "desktop_windows"
            text: Translation.tr("Only show island on single monitor")
            visible: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            checked: Config.options.bar.floatingNotch.onlyShowOnSingleMonitor
            onCheckedChanged: {
                Config.options.bar.floatingNotch.onlyShowOnSingleMonitor = checked;
                if (checked && Config.options.bar.floatingNotch.singleMonitorName === "" && Quickshell.screens.length > 0)
                    Config.options.bar.floatingNotch.singleMonitorName = Quickshell.screens[0].name;

            }

            StyledToolTip {
                text: Translation.tr("Display the dynamic island on only one chosen monitor instead of following focus")
            }

        }

        ContentSubsection {
            title: Translation.tr("Selected Monitor")
            icon: "settings_input_hdmi"
            visible: (Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar) && Config.options.bar.floatingNotch.onlyShowOnSingleMonitor

            MonitorPicker {
                currentValue: Config.options.bar.floatingNotch.singleMonitorName
                onSelected: (newValue) => {
                    Config.options.bar.floatingNotch.singleMonitorName = newValue;
                }
            }

        }

        ConfigSwitch {
            buttonIcon: "compress"
            text: Translation.tr("Extra Compact Mode")
            visible: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            checked: Config.options.bar.floatingNotch.extraCompact
            onCheckedChanged: {
                Config.options.bar.floatingNotch.extraCompact = checked;
            }

            StyledToolTip {
                text: Translation.tr("Wider and shorter island with smoother concave corners (−25% height, +60% width)")
            }

        }

    }

    // ── Status notches ────────────────────────────────────────────────────
    ContentSection {
        icon: "sensors"
        title: Translation.tr("Status notches")
        visible: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar

        NotchCard {
            buttonIcon: "tab"
            text: Translation.tr("Workspaces Notch")
            tooltip: Translation.tr("Toggle the workspaces notch notification on workspace changes")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableWorkspaces
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableWorkspaces = !enabled;
            }
            heightLabel: Translation.tr("Workspaces contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightWorkspaces
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightWorkspaces = value;
            }
        }

        NotchCard {
            buttonIcon: "keyboard"
            text: Translation.tr("Keyboard Layout Notch")
            tooltip: Translation.tr("Toggle the keyboard layout switcher notch notification on layout changes")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableKeyboard
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableKeyboard = !enabled;
            }
            heightLabel: Translation.tr("Keyboard Layout contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightKeyboard
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightKeyboard = value;
            }
        }

        NotchCard {
            buttonIcon: "wifi"
            text: Translation.tr("Wi-Fi Notch")
            tooltip: Translation.tr("Toggle the Wi-Fi status notch notification")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableWifi
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableWifi = !enabled;
            }
            heightLabel: Translation.tr("Wi-Fi contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightWifi
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightWifi = value;
            }
        }

        NotchCard {
            buttonIcon: "bluetooth"
            text: Translation.tr("Bluetooth Notch")
            tooltip: Translation.tr("Toggle the Bluetooth connection status notch notification")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableBluetooth
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableBluetooth = !enabled;
            }
            heightLabel: Translation.tr("Bluetooth contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightBluetooth
            heightTo: 120
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightBluetooth = value;
            }
        }

        NotchCard {
            buttonIcon: "battery_charging_full"
            text: Translation.tr("Battery Charging Notch")
            tooltip: Translation.tr("Toggle the battery charging status notch (iOS-style)")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableBattery
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableBattery = !enabled;
            }
            heightLabel: Translation.tr("Battery contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightBattery
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightBattery = value;
            }
        }

    }

    // ── Activity notches ──────────────────────────────────────────────────
    ContentSection {
        icon: "notifications_active"
        title: Translation.tr("Activity notches")
        visible: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar

        NotchCard {
            buttonIcon: "music_note"
            text: Translation.tr("Media Notch")
            tooltip: Translation.tr("Toggle the Media Player status notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableMedia
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableMedia = !enabled;
            }
            heightLabel: Translation.tr("Media contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightMedia
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightMedia = value;
            }
        }

        NotchCard {
            buttonIcon: "notifications"
            text: Translation.tr("Notification Notch")
            tooltip: Translation.tr("Toggle the notification popups inside the notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableNotification
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableNotification = !enabled;
            }
            heightLabel: Translation.tr("Notification contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightNotification
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightNotification = value;
            }
        }

        NotchCard {
            buttonIcon: "volume_up"
            text: Translation.tr("OSD Notch")
            tooltip: Translation.tr("Toggle the volume/brightness OSD inside the notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableOsd
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableOsd = !enabled;
            }
            hasHeight: false
        }

        NotchCard {
            buttonIcon: "screen_record"
            text: Translation.tr("Screen Recording Notch")
            tooltip: Translation.tr("Toggle the screen recording indicator notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableRecording
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableRecording = !enabled;
            }
            heightLabel: Translation.tr("Screen Recording contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightRecording
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightRecording = value;
            }
        }

        NotchCard {
            buttonIcon: "auto_awesome"
            text: Translation.tr("AI Status Notch")
            tooltip: Translation.tr("Toggle the AI agent status indicator notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableAiStatus
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableAiStatus = !enabled;
            }
            heightLabel: Translation.tr("AI Status contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightAiStatus
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightAiStatus = value;
            }
        }

        NotchCard {
            buttonIcon: "timer"
            text: Translation.tr("Timer/Stopwatch Notch")
            tooltip: Translation.tr("Toggle the Pomodoro/Stopwatch timer notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableTimer
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableTimer = !enabled;
            }
            heightLabel: Translation.tr("Timer/Stopwatch contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightTimer
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightTimer = value;
            }
        }

        NotchCard {
            buttonIcon: "content_paste"
            text: Translation.tr("Clipboard Notch")
            tooltip: Translation.tr("Toggle the clipboard history notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableClipboard
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableClipboard = !enabled;
            }
            heightLabel: Translation.tr("Clipboard contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightClipboard
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightClipboard = value;
            }
        }

        NotchCard {
            buttonIcon: "share"
            text: Translation.tr("LocalSend Share Notch")
            tooltip: Translation.tr("Toggle the LocalSend files sharing and receiving notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableLocalSend
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableLocalSend = !enabled;
            }
            heightLabel: Translation.tr("LocalSend contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightLocalSend
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightLocalSend = value;
            }
        }

        NotchCard {
            buttonIcon: "playlist_add_check"
            text: Translation.tr("Checklist Notch")
            tooltip: Translation.tr("Toggle the checklist notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableChecklist
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableChecklist = !enabled;
            }
            heightLabel: Translation.tr("Checklist contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightChecklist
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightChecklist = value;
            }

            ConfigSwitch {
                buttonIcon: "visibility"
                text: Translation.tr("Checklist always visible (Contracted)")
                visible: !Config.options.bar.floatingNotch.disableChecklist
                checked: Config.options.bar.floatingNotch.checklistAlwaysVisible
                onCheckedChanged: {
                    Config.options.bar.floatingNotch.checklistAlwaysVisible = checked;
                    if (checked)
                        Config.options.bar.floatingNotch.checklistOnlyExpanded = false;

                }

                StyledToolTip {
                    text: Translation.tr("Make checklist always visible on the dynamic island, even when contracted and idle")
                }

            }

            ConfigSwitch {
                buttonIcon: "open_in_full"
                text: Translation.tr("Checklist always visible (Expanded Only)")
                visible: !Config.options.bar.floatingNotch.disableChecklist
                checked: Config.options.bar.floatingNotch.checklistOnlyExpanded
                onCheckedChanged: {
                    Config.options.bar.floatingNotch.checklistOnlyExpanded = checked;
                    if (checked)
                        Config.options.bar.floatingNotch.checklistAlwaysVisible = false;

                }

                StyledToolTip {
                    text: Translation.tr("Make checklist always show when the dynamic island is expanded, but not when contracted")
                }

            }

        }

        NotchCard {
            buttonIcon: "calendar_month"
            text: Translation.tr("Calendar Notch")
            tooltip: Translation.tr("Toggle the calendar notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableCalendar
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableCalendar = !enabled;
            }
            heightLabel: Translation.tr("Calendar contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightCalendar
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightCalendar = value;
            }
        }

        NotchCard {
            buttonIcon: "speaker"
            text: Translation.tr("Audio Output Notch")
            tooltip: Translation.tr("Toggle the audio output switcher notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableAudio
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableAudio = !enabled;
            }
            heightLabel: Translation.tr("Audio contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightAudio
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightAudio = value;
            }
        }

        NotchCard {
            buttonIcon: "progress_activity"
            text: Translation.tr("Live Progress Notch")
            tooltip: Translation.tr("Toggle the live transfer/build progress notch")
            masterEnabled: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar
            notchEnabled: !Config.options.bar.floatingNotch.disableProgress
            onNotchToggled: (enabled) => {
                Config.options.bar.floatingNotch.disableProgress = !enabled;
            }
            heightLabel: Translation.tr("Progress contracted height")
            contractedHeight: Config.options.bar.floatingNotch.heightProgress
            onContractedHeightEdited: (value) => {
                Config.options.bar.floatingNotch.heightProgress = value;
            }
        }

    }

    // ── Misc ──────────────────────────────────────────────────────────────
    ContentSection {
        icon: "more_horiz"
        title: Translation.tr("Misc")
        visible: Config.options.bar.floatingNotch.enable || Config.options.bar.floatingNotch.centerInBar

        ConfigSpinBox {
            icon: "height"
            text: Translation.tr("Idle/Home contracted height")
            value: Config.options.bar.floatingNotch.heightHome
            from: 24
            to: 60
            stepSize: 1
            onValueChanged: {
                Config.options.bar.floatingNotch.heightHome = value;
            }
        }

        ConfigSwitch {
            buttonIcon: "smartphone"
            text: Translation.tr("KDE Connect column in drag panel")
            visible: !Config.options.bar.floatingNotch.disableLocalSend
            checked: !Config.options.bar.floatingNotch.disableKdeConnectInLocalSend
            onCheckedChanged: {
                Config.options.bar.floatingNotch.disableKdeConnectInLocalSend = !checked;
            }

            StyledToolTip {
                text: Translation.tr("Show the KDE Connect drop column alongside LocalSend when dragging files into the notch")
            }

        }

    }

}
