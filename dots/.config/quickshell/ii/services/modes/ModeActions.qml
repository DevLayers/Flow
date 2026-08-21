import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.services
import qs.modules.common
import qs.modules.common.models.hyprland
import "ModeSchema.js" as ModeSchema

/**
 * Registry of everything a mode or routine can do.
 *
 * Each entry: { id, category, label, icon, editor, available(), volatile,
 *               read(action), apply(value, action), revert(was, action, extra),
 *               extra(action), normalize(value, action), choices(), routineOnly }
 *
 *  - read() returns the current value so it can be restored; entries without
 *    it are one-shot (launch, shell, notify) and are never subject to the
 *    manual-override check.
 *  - volatile entries are not persisted by their service, so the engine
 *    re-applies them after a shell reload (dnd, keepAwake, media).
 *  - normalize() maps the stored value onto what read() returns, so the
 *    override check compares like with like.
 *  - extra() captures anything revert needs beyond the plain value.
 *  - editor / choices are metadata for the overlay's action rows.
 *  - repeatable entries may appear more than once in one mode (a mode
 *    otherwise holds each setting once); flow entries are sequence steps
 *    the engine handles itself, never applied or reverted.
 *
 * `engine` is the Modes singleton; only the routine-only entries (mode,
 * routine) need it.
 */
QtObject {
    id: root

    property var engine: null

    // ---------------------------------------------------------------- helpers

    readonly property var powerProfileNames: ({
        "power-saver": PowerProfile.PowerSaver,
        "balanced": PowerProfile.Balanced,
        "performance": PowerProfile.Performance
    })

    function powerProfileFromName(name) {
        if (typeof name === "number")
            return name;
        return root.powerProfileNames[String(name)] ?? PowerProfile.Balanced;
    }

    function powerProfileName(value) {
        for (const key in root.powerProfileNames) {
            if (root.powerProfileNames[key] === value)
                return key;
        }
        return "balanced";
    }

    function clampPercent(value) {
        const n = Number(value);
        if (!isFinite(n))
            return null;
        return Math.max(0, Math.min(100, Math.round(n)));
    }

    function asObject(v) {
        return (v && typeof v === "object") ? v : {};
    }

    function nonEmpty(text) {
        return typeof text === "string" && text.trim().length > 0;
    }

    // A volume value is either a bare level or { level, muted }; a missing
    // part means "leave that part alone".
    function volumeRequest(v) {
        const obj = (v && typeof v === "object") ? v : { level: v, muted: null };
        return {
            level: obj.level === undefined || obj.level === null ? null : obj.level,
            muted: obj.muted === undefined || obj.muted === null ? null : obj.muted
        };
    }

    // Brightness value: bare percent or { level, scope: "focused" | "all" }.
    function brightnessRequest(v) {
        const obj = (v && typeof v === "object") ? v : { level: v };
        return {
            level: root.clampPercent(obj.level),
            scope: obj.scope === "focused" ? "focused" : "all"
        };
    }

    function brightnessTargets(action) {
        const req = root.brightnessRequest(action?.value);
        const all = Array.from(Brightness.monitors ?? []).filter(m => m && m.ready);
        if (req.scope === "focused") {
            const target = Brightness.getTargetMonitor();
            return target && target.ready ? [target] : [];
        }
        return all;
    }

    function brightnessMap(monitors) {
        const out = {};
        for (const m of monitors)
            out[m.screen?.name ?? "?"] = Math.round((m.brightness ?? 0) * 100);
        return out;
    }

    function monitorByName(name) {
        return Array.from(Brightness.monitors ?? []).find(m => m && m.screen?.name === name) ?? null;
    }

    // Hyprland option keys/values go through a shell command line; only
    // accept the characters an option can actually contain.
    function hyprlandOptions(v) {
        const obj = root.asObject(v);
        const source = root.asObject(obj.options ?? obj);
        const out = {};
        for (const preset of ModeSchema.toArray(obj.presets)) {
            const set = ModeSchema.HYPRLAND_PRESETS[String(preset)];
            for (const key in (set ?? {}))
                out[key] = set[key];
        }
        for (const key in source) {
            if (key === "presets" || key === "options")
                continue;
            if (!/^[a-zA-Z0-9_:.-]+$/.test(key))
                throw new Error(`bad option key "${key}"`);
            const value = String(source[key]);
            if (!/^[a-zA-Z0-9_ .,:+()\/-]*$/.test(value))
                throw new Error(`bad value for "${key}"`);
            out[key] = value;
        }
        return out;
    }

    // The Game Mode toggle's own heuristic: animations disabled ⇒ game mode on.
    property HyprlandConfigOption animationsOption: HyprlandConfigOption {
        key: "animations:enabled"
    }
    readonly property bool gameModeOn: root.animationsOption.value === 0
        || root.animationsOption.value === false

    function setGameMode(on) {
        if (on) {
            HyprlandConfig.setMany(ModeSchema.GAME_MODE_OPTIONS, { addLines: [ModeSchema.GAME_MODE_RULE] });
            return;
        }
        HyprlandConfig.resetMany(Object.keys(ModeSchema.GAME_MODE_OPTIONS), {
            removeMatching: [ModeSchema.GAME_MODE_RULE_MARKER]
        });
    }

    function closeWindowsByClass(classes) {
        for (const cls of ModeSchema.stringList(classes)) {
            const pattern = cls.replace(/[^a-zA-Z0-9_.\-|()\[\]*+?^$\\]/g, "");
            if (!pattern.length)
                continue;
            Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", `class:^(${pattern})$`]);
        }
    }

    function launchRequest(v) {
        const obj = (v && typeof v === "object") ? v : { command: v };
        return {
            app: root.nonEmpty(obj.app) ? obj.app.trim() : "",
            command: root.nonEmpty(obj.command) ? obj.command : "",
            onEnd: obj.onEnd === "close" ? "close" : "keep",
            cls: root.nonEmpty(obj["class"]) ? obj["class"].trim() : ""
        };
    }

    function launchClass(req) {
        if (req.cls)
            return req.cls;
        if (!req.app)
            return "";
        const entry = DesktopEntries.byId(req.app) ?? DesktopEntries.heuristicLookup(req.app);
        if (entry?.startupClass)
            return entry.startupClass;
        return req.app.replace(/\.desktop$/, "");
    }

    function playingPlayers() {
        return Array.from(Mpris.players?.values ?? []).filter(p => p && p.isPlaying);
    }

    function playerKey(p) {
        return `${p.dbusName ?? ""}|${p.identity ?? ""}`;
    }

    function clampBacklight(v) {
        return Math.max(0, Math.min(KeyboardBacklight.maxValue, Math.round(Number(v) || 0)));
    }

    function barDockRequest(v) {
        const obj = root.asObject(v);
        const bar = ["autoHide", "fixed"].indexOf(obj.bar) !== -1 ? obj.bar : "keep";
        const dock = ["hide", "show"].indexOf(obj.dock) !== -1 ? obj.dock : "keep";
        return { bar: bar, dock: dock };
    }

    // ---------------------------------------------------------------- registry

    readonly property var registry: ({
        // ------------------------------------------------- notifications
        dnd: {
            id: "dnd", category: "notifications", label: "Do Not Disturb", icon: "do_not_disturb_on",
            editor: "switch", volatile: true,
            available: () => true,
            read: () => Notifications.silent,
            normalize: v => !!v,
            apply: v => { Notifications.silent = !!v; },
            revert: was => { Notifications.silent = !!was; }
        },
        autoDndFullscreen: {
            id: "autoDndFullscreen", category: "notifications", label: "Auto DND in fullscreen",
            icon: "fullscreen", editor: "switch", volatile: false,
            available: () => true,
            read: () => Config.options.notifications.autoDndFullscreen,
            normalize: v => !!v,
            apply: v => { Config.options.notifications.autoDndFullscreen = !!v; },
            revert: was => { Config.options.notifications.autoDndFullscreen = !!was; }
        },

        // ------------------------------------------------- display
        nightLight: {
            id: "nightLight", category: "display", label: "Night Light", icon: "nightlight",
            editor: "switch", volatile: false,
            available: () => true,
            read: () => Hyprsunset.temperatureActive,
            normalize: v => !!v,
            // Whether the user already had a manual override before the mode
            // touched it. If not, the revert hands control back to the
            // schedule instead of leaving a stale override behind.
            extra: () => ({ hadManual: Hyprsunset.manualActive !== undefined }),
            apply: v => { Hyprsunset.toggleTemperature(!!v); },
            revert: (was, action, extra) => {
                if (Hyprsunset.automatic && !(extra?.hadManual)) {
                    Hyprsunset.manualActive = undefined;
                    Hyprsunset.manualActiveAt = 0;
                    Hyprsunset.persistState();
                    Hyprsunset.ensureState();
                    return;
                }
                Hyprsunset.toggleTemperature(!!was);
            }
        },
        darkMode: {
            id: "darkMode", category: "display", label: "Dark mode", icon: "contrast",
            editor: "segmented", choices: () => ["dark", "light"], volatile: false,
            available: () => true,
            read: () => Appearance.m3colors.darkmode ? "dark" : "light",
            normalize: v => (v === "light" || v === false) ? "light" : "dark",
            apply: v => {
                const dark = !(v === "light" || v === false);
                if (dark)
                    DarkModeService.enableDarkMode();
                else
                    DarkModeService.disableDarkMode();
            },
            revert: was => {
                if (was === "light")
                    DarkModeService.disableDarkMode();
                else
                    DarkModeService.enableDarkMode();
            }
        },
        brightness: {
            id: "brightness", category: "display", label: "Brightness", icon: "brightness_6",
            editor: "brightness", volatile: false,
            available: () => Array.from(Brightness.monitors ?? []).length > 0,
            // value: percent or { level, scope: "focused" | "all" }; snapshot is per monitor
            read: action => root.brightnessMap(root.brightnessTargets(action)),
            normalize: (v, action) => {
                const req = root.brightnessRequest(v);
                const out = {};
                for (const m of root.brightnessTargets(action))
                    out[m.screen?.name ?? "?"] = req.level;
                return out;
            },
            apply: (v, action) => {
                const req = root.brightnessRequest(v);
                if (req.level === null)
                    throw new Error("no level");
                const targets = root.brightnessTargets(action);
                if (!targets.length)
                    throw new Error("no monitor ready");
                for (const m of targets)
                    m.setBrightness(req.level / 100);
            },
            revert: was => {
                for (const name in root.asObject(was)) {
                    const m = root.monitorByName(name);
                    if (m && m.ready)
                        m.setBrightness(root.clampPercent(was[name]) / 100);
                }
            }
        },
        screenShader: {
            id: "screenShader", category: "display", label: "Screen shader", icon: "gradient",
            editor: "dropdown", volatile: false,
            choices: () => [""].concat(Array.from(ScreenShader.shaders ?? []).map(s => s.name)),
            available: () => true,
            read: () => ScreenShader.activeName,
            normalize: v => String(v ?? ""),
            apply: v => {
                const name = String(v ?? "");
                if (!name.length) {
                    ScreenShader.clear();
                    return;
                }
                if (!ScreenShader.findShader(name))
                    throw new Error(`shader "${name}" not found`);
                ScreenShader.apply(name);
            },
            revert: was => {
                const name = String(was ?? "");
                if (!name.length || !ScreenShader.findShader(name))
                    ScreenShader.clear();
                else
                    ScreenShader.apply(name);
            }
        },
        keyboardBacklight: {
            id: "keyboardBacklight", category: "display", label: "Keyboard backlight",
            icon: "keyboard", editor: "stepper", volatile: false,
            available: () => KeyboardBacklight.available,
            read: () => KeyboardBacklight.currentValue,
            normalize: v => root.clampBacklight(v),
            apply: v => { KeyboardBacklight.setValue(root.clampBacklight(v)); },
            revert: was => { KeyboardBacklight.setValue(Math.round(Number(was) || 0)); }
        },
        wallpaper: {
            id: "wallpaper", category: "display", label: "Wallpaper", icon: "wallpaper",
            editor: "file", volatile: false,
            available: () => true,
            read: () => Config.options.background.wallpaperPath,
            normalize: v => String(v ?? ""),
            apply: v => {
                const path = String(v ?? "");
                if (!path.length)
                    throw new Error("no path");
                Wallpapers.apply(path);
            },
            revert: was => {
                const path = String(was ?? "");
                if (path.length)
                    Wallpapers.apply(path);
            }
        },

        // ------------------------------------------------- sound
        volume: {
            id: "volume", category: "sound", label: "Volume", icon: "volume_up",
            editor: "volume", volatile: false,
            available: () => Audio.sink?.audio !== undefined && Audio.sink?.audio !== null,
            // value: { level: 0–100 | null, muted: bool | null }; null leaves that part alone
            read: () => ({
                level: Math.round((Audio.sink?.audio?.volume ?? 0) * 100),
                muted: Audio.sink?.audio?.muted ?? false
            }),
            normalize: v => {
                const wanted = root.volumeRequest(v);
                const current = root.registry.volume.read();
                return {
                    level: wanted.level === null ? current.level : root.clampPercent(wanted.level),
                    muted: wanted.muted === null ? current.muted : !!wanted.muted
                };
            },
            apply: v => {
                const audio = Audio.sink?.audio;
                if (!audio)
                    throw new Error("no default sink");
                const wanted = root.volumeRequest(v);
                if (wanted.level !== null) {
                    let level = root.clampPercent(wanted.level);
                    if (Config.options.audio.protection.enable)
                        level = Math.min(level, Config.options.audio.protection.maxAllowed);
                    audio.volume = level / 100;
                }
                if (wanted.muted !== null)
                    audio.muted = !!wanted.muted;
            },
            revert: was => {
                const audio = Audio.sink?.audio;
                if (!audio || !was)
                    return;
                audio.volume = root.clampPercent(was.level) / 100;
                audio.muted = !!was.muted;
            }
        },
        micMute: {
            id: "micMute", category: "sound", label: "Mute microphone", icon: "mic_off",
            editor: "switch", volatile: false,
            available: () => Audio.source?.audio !== undefined && Audio.source?.audio !== null,
            read: () => Audio.source?.audio?.muted ?? false,
            normalize: v => !!v,
            apply: v => {
                const audio = Audio.source?.audio;
                if (!audio)
                    throw new Error("no default source");
                audio.muted = !!v;
            },
            revert: was => {
                const audio = Audio.source?.audio;
                if (audio)
                    audio.muted = !!was;
            }
        },
        systemSounds: {
            id: "systemSounds", category: "sound", label: "System sounds", icon: "music_note",
            editor: "switch", volatile: false,
            available: () => true,
            read: () => Config.options.sounds.enable,
            normalize: v => !!v,
            apply: v => { Config.options.sounds.enable = !!v; },
            revert: was => { Config.options.sounds.enable = !!was; }
        },
        media: {
            id: "media", category: "sound", label: "Media", icon: "play_pause",
            editor: "segmented", choices: () => ["pause", "play"], volatile: true,
            available: () => true,
            read: () => root.playingPlayers().length > 0,
            normalize: v => v === "play",
            // Which players we silenced, so only those come back.
            extra: () => ({ playing: root.playingPlayers().map(root.playerKey) }),
            apply: v => {
                if (v === "play") {
                    const p = MprisController.activePlayer;
                    if (p && p.canPlay)
                        p.play();
                    return;
                }
                for (const p of root.playingPlayers()) {
                    if (p.canPause)
                        p.pause();
                }
            },
            revert: (was, action, extra) => {
                if (was) {
                    const keys = ModeSchema.toArray(extra?.playing);
                    for (const p of Array.from(Mpris.players?.values ?? [])) {
                        if (p && keys.indexOf(root.playerKey(p)) !== -1 && p.canPlay && !p.isPlaying)
                            p.play();
                    }
                    return;
                }
                for (const p of root.playingPlayers()) {
                    if (p.canPause)
                        p.pause();
                }
            }
        },

        // ------------------------------------------------- power
        keepAwake: {
            id: "keepAwake", category: "power", label: "Keep Awake", icon: "coffee",
            editor: "switch", volatile: true,
            available: () => true,
            read: () => Idle.inhibit,
            normalize: v => !!v,
            extra: () => ({ expiresAt: Idle.expiresAt }),
            apply: v => {
                // Already on (possibly on a timer the user set): leave it alone.
                if (!!v === Idle.inhibit)
                    return;
                Idle.toggleInhibit(!!v);
            },
            revert: (was, action, extra) => {
                if (!!was === Idle.inhibit)
                    return;
                const remainingMin = extra?.expiresAt ? Math.ceil((extra.expiresAt - Date.now()) / 60000) : 0;
                if (was && remainingMin > 0) {
                    Idle.inhibitFor(remainingMin);
                    return;
                }
                Idle.toggleInhibit(!!was);
            }
        },
        powerProfile: {
            id: "powerProfile", category: "power", label: "Power profile", icon: "speed",
            editor: "segmented", volatile: false,
            choices: () => PowerProfiles.hasPerformanceProfile
                ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"],
            available: () => true,
            read: () => PowerProfiles.profile,
            normalize: v => root.powerProfileFromName(v),
            apply: v => {
                let target = root.powerProfileFromName(v);
                if (target === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
                    target = PowerProfile.Balanced;
                PowerProfiles.profile = target;
            },
            revert: was => { PowerProfiles.profile = root.powerProfileFromName(was); }
        },

        // ------------------------------------------------- hyprland
        hyprland: {
            id: "hyprland", category: "hyprland", label: "Hyprland options", icon: "settings_suggest",
            editor: "hyprland", volatile: false,
            // value: { presets: ["animations", "blur", …], options: { "key": value } }
            // One setMany per apply; revert resets the same keys, minus the
            // ones Game Mode holds while it is on.
            available: () => true,
            apply: v => {
                const options = root.hyprlandOptions(v);
                if (!Object.keys(options).length)
                    throw new Error("no options");
                HyprlandConfig.setMany(options, null);
            },
            revert: (was, action) => {
                let keys = Object.keys(root.hyprlandOptions(action?.value));
                if (root.gameModeOn)
                    keys = keys.filter(k => ModeSchema.GAME_MODE_OPTIONS[k] === undefined);
                if (keys.length)
                    HyprlandConfig.resetMany(keys, null);
            }
        },
        gameMode: {
            id: "gameMode", category: "hyprland", label: "Game mode", icon: "gamepad",
            editor: "switch", volatile: false,
            available: () => true,
            read: () => root.gameModeOn,
            normalize: v => !!v,
            apply: v => { root.setGameMode(!!v); },
            revert: was => { root.setGameMode(!!was); }
        },
        barDock: {
            id: "barDock", category: "hyprland", label: "Bar & dock", icon: "dock_to_bottom",
            editor: "barDock", volatile: false,
            // value: { bar: "keep" | "autoHide" | "fixed", dock: "keep" | "hide" | "show" }
            available: () => true,
            read: () => ({
                barAutoHide: Config.options.bar.autoHide.enable,
                dockEnabled: Config.options.dock.enable
            }),
            normalize: v => {
                const req = root.barDockRequest(v);
                const current = root.registry.barDock.read();
                return {
                    barAutoHide: req.bar === "keep" ? current.barAutoHide : req.bar === "autoHide",
                    dockEnabled: req.dock === "keep" ? current.dockEnabled : req.dock === "show"
                };
            },
            apply: v => {
                const req = root.barDockRequest(v);
                if (req.bar !== "keep")
                    Config.options.bar.autoHide.enable = req.bar === "autoHide";
                if (req.dock !== "keep")
                    Config.options.dock.enable = req.dock === "show";
            },
            revert: was => {
                const w = root.asObject(was);
                if (typeof w.barAutoHide === "boolean")
                    Config.options.bar.autoHide.enable = w.barAutoHide;
                if (typeof w.dockEnabled === "boolean")
                    Config.options.dock.enable = w.dockEnabled;
            }
        },

        // ------------------------------------------------- apps
        launch: {
            id: "launch", category: "apps", label: "Launch app", icon: "rocket_launch",
            editor: "launch", volatile: false,
            // value: { app: "<desktop id>" | command: "…", onEnd: "keep" | "close", class: "<override>" }
            available: () => true,
            apply: v => {
                const req = root.launchRequest(v);
                if (req.app) {
                    const entry = DesktopEntries.byId(req.app) ?? DesktopEntries.heuristicLookup(req.app);
                    if (!entry)
                        throw new Error(`no desktop entry "${req.app}"`);
                    entry.execute();
                    return;
                }
                if (!req.command)
                    throw new Error("nothing to launch");
                Quickshell.execDetached(["sh", "-c", req.command]);
            },
            revert: (was, action) => {
                const req = root.launchRequest(action?.value);
                if (req.onEnd !== "close")
                    return;
                const cls = root.launchClass(req);
                if (cls)
                    root.closeWindowsByClass([cls]);
            }
        },
        closeApps: {
            id: "closeApps", category: "apps", label: "Close apps", icon: "cancel_presentation",
            editor: "classes", volatile: false,
            // value: ["class", …] or { classes: [...] }. Graceful close, never kill.
            available: () => true,
            apply: v => {
                const classes = Array.isArray(v) || ModeSchema.isArrayLike(v) ? v : root.asObject(v).classes;
                const list = ModeSchema.stringList(classes);
                if (!list.length)
                    throw new Error("no classes");
                root.closeWindowsByClass(list);
            }
        },
        workspaceProfile: {
            id: "workspaceProfile", category: "apps", label: "Workspace profile", icon: "dashboard_customize",
            editor: "dropdown", volatile: false,
            choices: () => Array.from(WorkspaceProfileService.profiles ?? []).map(p => p.slug ?? p.name),
            available: () => WorkspaceProfileService.binaryExists,
            apply: v => {
                const slug = String(v ?? "");
                if (!slug.length)
                    throw new Error("no profile");
                WorkspaceProfileService.restoreProfile(slug);
            }
        },
        openUrl: {
            id: "openUrl", category: "apps", label: "Open URL", icon: "link",
            editor: "text", volatile: false,
            available: () => true,
            apply: v => {
                const url = String(v ?? "").trim();
                if (!/^[a-z][a-z0-9+.-]*:/i.test(url))
                    throw new Error("not a URL");
                Qt.openUrlExternally(url);
            }
        },

        // ------------------------------------------------- radios
        wifi: {
            id: "wifi", category: "radios", label: "Wi-Fi", icon: "wifi",
            editor: "switch", volatile: false,
            available: () => Network.wifi,
            read: () => Network.wifiEnabled,
            normalize: v => !!v,
            apply: v => { Network.enableWifi(!!v); },
            revert: was => { Network.enableWifi(!!was); }
        },
        bluetooth: {
            id: "bluetooth", category: "radios", label: "Bluetooth", icon: "bluetooth",
            editor: "switch", volatile: false,
            available: () => BluetoothStatus.available,
            read: () => BluetoothStatus.enabled,
            normalize: v => !!v,
            // setEnabled(true) lifts an rfkill soft block first, like the toggle.
            apply: v => { BluetoothStatus.setEnabled(!!v); },
            revert: was => { BluetoothStatus.setEnabled(!!was); }
        },
        vpn: {
            id: "vpn", category: "radios", label: "VPN", icon: "vpn_lock",
            editor: "switch", volatile: false,
            available: () => VpnService.enabled && VpnService.available,
            read: () => VpnService.active,
            normalize: v => !!v,
            apply: v => {
                if (!!v === VpnService.active)
                    return;
                if (v)
                    VpnService.connectDefault();
                else
                    VpnService.disconnectVpn();
            },
            revert: was => {
                if (!!was === VpnService.active)
                    return;
                if (was)
                    VpnService.connectDefault();
                else
                    VpnService.disconnectVpn();
            }
        },
        tailscale: {
            id: "tailscale", category: "radios", label: "Tailscale", icon: "lan",
            editor: "switch", volatile: false,
            available: () => TailscaleService.enabled && TailscaleService.available,
            read: () => TailscaleService.active,
            normalize: v => !!v,
            apply: v => {
                if (!!v === TailscaleService.active)
                    return;
                if (v)
                    TailscaleService.connectTailscale();
                else
                    TailscaleService.disconnectTailscale();
            },
            revert: was => {
                if (!!was === TailscaleService.active)
                    return;
                if (was)
                    TailscaleService.connectTailscale();
                else
                    TailscaleService.disconnectTailscale();
            }
        },
        dnsOverTls: {
            id: "dnsOverTls", category: "radios", label: "Encrypted DNS", icon: "dns",
            editor: "switch", volatile: false,
            available: () => DnsOverTls.available,
            read: () => DnsOverTls.active,
            normalize: v => !!v,
            apply: v => {
                if (!!v === DnsOverTls.active)
                    return;
                if (v)
                    DnsOverTls.enable();
                else
                    DnsOverTls.disable();
            },
            revert: was => {
                if (!!was === DnsOverTls.active)
                    return;
                if (was)
                    DnsOverTls.enable();
                else
                    DnsOverTls.disable();
            }
        },

        // ------------------------------------------------- flow
        // Not an action: a pause the engine honours while walking the list.
        // It is in the registry so the editor can offer and describe it.
        wait: {
            id: "wait", category: "flow", label: "Wait", icon: "hourglass_top",
            editor: "wait", volatile: false, flow: true, repeatable: true,
            // value: seconds
            available: () => true
        },

        // ------------------------------------------------- advanced
        shell: {
            id: "shell", category: "advanced", label: "Shell command", icon: "terminal",
            editor: "shell", volatile: false,
            available: () => true,
            // value: { start: "cmd", end: "cmd" } — `end` runs when the mode ends
            apply: v => {
                const start = (v && typeof v === "object") ? v.start : v;
                if (root.nonEmpty(start))
                    Quickshell.execDetached(["sh", "-c", start]);
            },
            revert: (was, action) => {
                const v = action?.value;
                const end = (v && typeof v === "object") ? v.end : "";
                if (root.nonEmpty(end))
                    Quickshell.execDetached(["sh", "-c", end]);
            }
        },
        notify: {
            id: "notify", category: "advanced", label: "Notification", icon: "notifications",
            editor: "notify", volatile: false, routineOnly: true,
            // value: { title, body, icon }
            available: () => true,
            apply: v => {
                const obj = (v && typeof v === "object") ? v : { title: String(v ?? "") };
                const title = root.nonEmpty(obj.title) ? obj.title : "Routine";
                const args = ["notify-send", "-a", "Modes & Routines"];
                if (root.nonEmpty(obj.icon))
                    args.push("-i", obj.icon);
                args.push(title);
                if (root.nonEmpty(obj.body))
                    args.push(obj.body);
                Quickshell.execDetached(args);
            }
        },
        mode: {
            id: "mode", category: "advanced", label: "Mode", icon: "tune",
            editor: "mode", volatile: false, routineOnly: true,
            // value: { action: "start" | "stop", id }
            available: () => root.engine !== null,
            apply: v => {
                const obj = root.asObject(v);
                const id = String(obj.id ?? "");
                if (obj.action === "stop") {
                    if (!id.length || root.engine.activeModeId === id)
                        root.engine.deactivate("routine");
                    return;
                }
                if (!id.length)
                    throw new Error("no mode id");
                if (!root.engine.activate(id, "routine"))
                    throw new Error(`no such mode "${id}"`);
            }
        },
        routine: {
            id: "routine", category: "advanced", label: "Routine", icon: "bolt",
            editor: "routine", volatile: false, routineOnly: true,
            // value: { action: "run" | "stop", id }
            available: () => root.engine !== null,
            apply: v => {
                const obj = root.asObject(v);
                const id = String(obj.id ?? "");
                if (!id.length)
                    throw new Error("no routine id");
                const ok = obj.action === "stop"
                    ? root.engine.stopRoutine(id, "routine")
                    : root.engine.runRoutine(id, "routine");
                if (!ok)
                    throw new Error(`routine "${id}" not run`);
            }
        }
    })

    readonly property var categories: ({
        notifications: { label: "Notifications", icon: "notifications" },
        display: { label: "Display", icon: "display_settings" },
        sound: { label: "Sound", icon: "volume_up" },
        power: { label: "Power", icon: "bolt" },
        hyprland: { label: "Hyprland", icon: "window" },
        apps: { label: "Apps", icon: "apps" },
        radios: { label: "Connectivity", icon: "settings_input_antenna" },
        flow: { label: "Timing", icon: "hourglass_top" },
        advanced: { label: "Advanced", icon: "code" }
    })

    function get(type) {
        return root.registry[type] ?? null;
    }

    function isAvailable(type) {
        const entry = root.get(type);
        if (!entry)
            return false;
        try {
            return entry.available ? !!entry.available() : true;
        } catch (e) {
            return false;
        }
    }

    function types() {
        return Object.keys(root.registry);
    }

    // One line per registry row for `modes actions`.
    function describe(type) {
        const e = root.get(type);
        if (!e)
            return `${type}: unknown`;
        const flags = [];
        if (e.flow)
            flags.push("sequence step");
        else if (!e.read)
            flags.push("one-shot");
        if (e.volatile)
            flags.push("volatile");
        if (e.routineOnly)
            flags.push("routines only");
        const avail = root.isAvailable(type) ? "available" : "not available here";
        let current = "";
        if (e.read && root.isAvailable(type)) {
            try {
                current = ` now=${JSON.stringify(e.read({ value: null }))}`;
            } catch (err) {
                current = ` now=?`;
            }
        }
        const suffix = flags.length ? ` (${flags.join(", ")})` : "";
        return `${type.padEnd(18)} ${e.category.padEnd(14)} ${avail}${suffix}${current}`;
    }
}
