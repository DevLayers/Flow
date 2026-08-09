pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common.functions

Singleton {
    id: root
    property string filePath: Directories.shellConfigPath
    property alias options: configOptionsJsonAdapter
    property bool ready: false
    property int readWriteDelay: 75 // milliseconds
    property bool blockWrites: false
    // Wall-clock time (ms) at singleton init. Used to detect legitimately missing
    // config.json (after the singleton has been alive long enough) vs. transient
    // inaccessibility (git pull, hot-reload timing, FS race) where we must NOT
    // overwrite the user's real config.json with the in-memory QML defaults.
    property real initTimestamp: Date.now()
    // Grace window during which a missing file is assumed transient and a
    // reload is retried before we ever dare to write defaults.
    // Increased from 2000 to 5000 to match writeGuardDelay — prevents
    // config.json from being clobbered with defaults during hot-reload.
    property int missingFileGracePeriod: 5000
    property int missingFileRetryInterval: 1500
    // Minimum time (ms) since singleton creation before ANY write is allowed,
    // even after `onLoaded` sets `ready = true`. This catches hot-reload races
    // where the file loads from page cache almost instantly but the
    // JsonAdapter hasn't fully merged values into all nested JsonObjects yet.
    // Increased from 3000 to 5000 to prevent config.json resets during
    // shell hot-reload while Phone services are initializing.
    property int writeGuardDelay: 5000

    function setNestedValue(nestedKey, value) {
        let keys = nestedKey.split(".");
        let obj = root.options;
        let parents = [obj];

        // Traverse and collect parent objects
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        // Convert value to correct type using JSON.parse when safe
        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        obj[keys[keys.length - 1]] = convertedValue;
    }

    // Persist options immediately (e.g. kill dialog "Always" in a short-lived process).
    function saveOptionsNow() {
        // Never let an unrelated forced save (e.g. the kill dialog's
        // "Always" button) defeat the malformed-config write block — that
        // block exists specifically to stop the in-memory defaults from
        // clobbering a broken-but-recoverable file.
        if (root.configMalformed)
            return;
        root.blockWrites = false;
        if (!root.ready)
            return;
        configFileView.writeAdapter();
    }

    Timer {
        id: fileReloadTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.reload();
        }
    }

    Timer {
        id: fileWriteTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            // Never overwrite the user's config.json with the in-memory
            // JsonAdapter state (which is mostly QML defaults until the file
            // is loaded). If the file has not loaded yet, defer the write and
            // keep retrying — once `onLoaded` flips `root.ready` the pending
            // write will fire with the file's real values merged in.
            if (root.blockWrites) {
                return;
            }
            if (!root.ready) {
                fileWriteTimer.restart();
                return;
            }
            // Extra guard: even after `ready`, if the singleton was created
            // less than `writeGuardDelay` ms ago, defer. This catches the
            // hot-reload race where `onLoaded` fires very fast (file is in
            // page cache) but the JsonAdapter hasn't fully merged the file's
            // values into all nested JsonObjects yet.
            const elapsed = Date.now() - root.initTimestamp;
            if (elapsed < root.writeGuardDelay) {
                fileWriteTimer.restart();
                return;
            }
            configFileView.writeAdapter();
        }
    }

    // If `onLoadFailed(FileNotFound)` fires, do NOT immediately call
    // `writeAdapter()` — during a git pull, hot-reload, or PC restart the file
    // can be briefly inaccessible and the QML defaults would clobber the user's
    // real config.json. Instead, retry `reload()` after the grace period; only
    // if the file is still genuinely missing after the singleton has been alive
    // for a while do we create defaults.
    Timer {
        id: missingFileRetryTimer
        interval: root.missingFileRetryInterval
        repeat: false
        onTriggered: {
            configFileView.reload();
        }
    }

    function isWidgetActive(widgetId) {
        let list = root.options.background.activeWidgets || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].widgetId === widgetId)
                return true;
        }
        return false;
    }

    function getWidgetLockBehavior(widgetId) {
        let list = root.options.background.activeWidgets || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].widgetId === widgetId)
                return list[i].lockBehavior || "hide";
        }
        return "hide";
    }

    function setWidgetLockBehavior(widgetId, newLockBehavior) {
        let cloned = JSON.parse(JSON.stringify(root.options.background.activeWidgets || []));
        for (let i = 0; i < cloned.length; i++) {
            if (cloned[i].widgetId === widgetId) {
                cloned[i].lockBehavior = newLockBehavior;
                root.options.background.activeWidgets = cloned;
                return;
            }
        }
    }

    function addWidgetToDesktop(widgetId, defaultX, defaultY) {
        let cloned = JSON.parse(JSON.stringify(root.options.background.activeWidgets || []));
        for (let i = 0; i < cloned.length; i++) {
            if (cloned[i].widgetId === widgetId)
                return;
        }

        let startX = defaultX !== undefined ? defaultX : 200;
        let startY = defaultY !== undefined ? defaultY : 200;

        if (defaultX === undefined && defaultY === undefined) {
            let offset = 0;
            while (true) {
                let collision = false;
                for (let i = 0; i < cloned.length; i++) {
                    if (Math.abs(cloned[i].x - (startX + offset)) < 30 && Math.abs(cloned[i].y - (startY + offset)) < 30) {
                        collision = true;
                        break;
                    }
                }
                if (!collision) {
                    startX += offset;
                    startY += offset;
                    break;
                }
                offset += 80;
            }
        }

        let instanceId = "widget_" + widgetId + "_" + Date.now();
        cloned.push({
            "id": instanceId,
            "widgetId": widgetId,
            "x": startX,
            "y": startY,
            "placementStrategy": "free",
            "lockBehavior": "hide"
        });
        root.options.background.activeWidgets = cloned;
    }

    function removeWidgetFromDesktop(widgetId) {
        let cloned = JSON.parse(JSON.stringify(root.options.background.activeWidgets || []));
        let indexToRemove = -1;
        for (let i = 0; i < cloned.length; i++) {
            if (cloned[i].widgetId === widgetId) {
                indexToRemove = i;
                break;
            }
        }
        if (indexToRemove !== -1) {
            cloned.splice(indexToRemove, 1);
            root.options.background.activeWidgets = cloned;
        }
    }

    function updateWidgetPosition(instanceId, newX, newY) {
        let cloned = JSON.parse(JSON.stringify(root.options.background.activeWidgets || []));
        let found = false;
        for (let i = 0; i < cloned.length; i++) {
            if (cloned[i].id === instanceId) {
                cloned[i].x = newX;
                cloned[i].y = newY;
                found = true;
                break;
            }
        }
        if (found) {
            root.options.background.activeWidgets = cloned;
        }
    }

    function updateWidgetLockBehavior(instanceId, newLockBehavior) {
        let cloned = JSON.parse(JSON.stringify(root.options.background.activeWidgets || []));
        let found = false;
        for (let i = 0; i < cloned.length; i++) {
            if (cloned[i].id === instanceId) {
                cloned[i].lockBehavior = newLockBehavior;
                found = true;
                break;
            }
        }
        if (found) {
            root.options.background.activeWidgets = cloned;
        }
    }

    function migrateRoundingConfig() {
        if (root.options.appearance.roundingValue >= 0)
            return;
        var oldMode = root.options.appearance.globalRounding || "large";
        if (oldMode === "sharp") {
            root.options.appearance.roundingValue = 0;
        } else if (oldMode === "normal") {
            root.options.appearance.roundingValue = 17;
        } else if (oldMode === "verylarge") {
            root.options.appearance.roundingValue = 32;
        } else {
            root.options.appearance.roundingValue = 24;
        }
        root.options.appearance.sharpMode = (root.options.appearance.roundingValue === 0);
    }

    function migrateWidgetLockBehavior() {
        if (Persistent.states.background.lockBehaviorMigrated)
            return;
        let cloned = JSON.parse(JSON.stringify(root.options.background.activeWidgets || []));
        let changed = false;
        for (let i = 0; i < cloned.length; i++) {
            if (!cloned[i].lockBehavior) {
                cloned[i].lockBehavior = "hide";
                changed = true;
            }
        }
        if (changed) {
            root.options.background.activeWidgets = cloned;
        }
        Persistent.states.background.lockBehaviorMigrated = true;
    }

    // ── Schema versioning & type-drift repair ─────────────────────────────────
    // JsonAdapter coerces rather than rejects, and the damaging coercions are
    // silent: an int landing on a string property becomes "1" and matches no
    // branch; a string landing on a list property is split into one entry per
    // character ("left" -> ["l","e","f","t"]); a list of objects landing on
    // list<string> becomes ["", ""]. The next write persists the wreckage, so
    // the damage outlives the version that caused it, which is why the only fix
    // users find is deleting config.json outright.
    //
    // Both passes below work on the raw file rather than the adapter, because
    // by the time the adapter is readable the original values are gone.
    // Migration runs first so a retyped key can be converted; whatever is still
    // unrepresentable afterwards is replaced with its schema default.
    //
    // Bump `currentConfigVersion` and add a matching block to `migrateRaw()`
    // whenever an existing key changes type or meaning.
    readonly property int currentConfigVersion: 4
    // Defaults have to be captured before the file lands, because deserializing
    // is what destroys them. FileView loads asynchronously, so at component
    // completion the adapter still holds nothing but the QML defaults.
    property var defaultOptions: null
    property bool configRepaired: false
    // True while config.json fails to parse as JSON at all. Writes stay
    // blocked the whole time (see saveOptionsNow() and fileWriteTimer)
    // because the in-memory adapter holds nothing but QML defaults, and the
    // broken file on disk is the only remaining source of truth.
    property bool configMalformed: false
    // Drives ConfigHealthBanner: "ok" | "malformed" | "recovered" | "migrated" | "repaired" | "unknownKeys" | "reset"
    property string configHealthState: "ok"
    property list<string> configHealthKeys: []

    function snapshotDefaults(source) {
        if (source === null || typeof source !== "object")
            return source;
        if (root.isArrayLike(source)) {
            let copy = [];
            for (let i = 0; i < source.length; ++i) {
                copy.push(root.snapshotDefaults(source[i]));
            }
            return copy;
        }
        let copy = {};
        for (const key in source) {
            if (key === "objectName")
                continue;
            const value = source[key];
            if (typeof value === "function")
                continue;
            copy[key] = root.snapshotDefaults(value);
        }
        return copy;
    }

    // A config written before versioning existed has no `configVersion` key, so
    // those files read back as 0 and every migration runs. A fresh config is
    // stamped with the current version when defaults are seeded, so it
    // correctly skips all of them.
    function migrateRaw(raw) {
        const from = raw.configVersion ?? 0;
        if (from >= root.currentConfigVersion)
            return false;

        // v0 -> v1: sidebar.position went from int to string ("more
        // understandable config naming", Jan 2026). Old files still hold 0-3,
        // which JsonAdapter turns into the strings "0".."3" — matching nothing,
        // so every sidebar position silently behaved as "default".
        if (from < 1 && raw.sidebar !== undefined && typeof raw.sidebar.position === "number") {
            const legacyPositions = ["default", "inverted", "left", "right"];
            const previous = raw.sidebar.position;
            if (previous >= 0 && previous < legacyPositions.length) {
                raw.sidebar.position = legacyPositions[previous];
                console.log(`[Config] Migrated sidebar.position ${previous} -> ${raw.sidebar.position}`);
            }
        }

        // v1 -> v2: the tiling assistant stopped inferring drags from window
        // motion (Aug 2026), so tiling.detection.idleHz changed meaning from
        // "how fast the cursor is tracked" to "how often the active window is
        // sampled" - the far slower job the old idleFloorHz already described.
        // Carrying the old 30 over would poll six times harder than anything
        // now asks for. The two keys that only existed for the heuristic go.
        if (from < 2 && raw.tiling?.detection !== undefined) {
            const detection = raw.tiling.detection;
            if (typeof detection.idleFloorHz === "number")
                detection.idleHz = detection.idleFloorHz;
            else if (typeof detection.idleHz === "number")
                detection.idleHz = Math.min(detection.idleHz, 5);
            delete detection.idleFloorHz;
            delete detection.useMotionHeuristic;
            console.log(`[Config] Migrated tiling.detection to keybind-only drag detection (idleHz ${detection.idleHz})`);
        }

        // v2 -> v3: the dashboard quick toggles changed from one flat list
        // (`android.toggles`) to pages (`android.pages`). Keep old layouts
        // editable instead of silently dropping the legacy key on the next save.
        if (from < 3 && raw.sidebar?.quickToggles?.android !== undefined) {
            const android = raw.sidebar.quickToggles.android;
            if (android.pages === undefined && Array.isArray(android.toggles)) {
                android.pages = [android.toggles];
                console.log("[Config] Migrated sidebar.quickToggles.android.toggles to pages");
            }
            delete android.toggles;
        }

        // v3 -> v4: osk.layout keeps its type but changes meaning (Aug 2026). It used to be
        // overwritten by HyprlandXkb on every layout switch, so no value on disk was ever a
        // deliberate choice - and the shipped default "qwerty_full" named no layout at all,
        // which is why the keyboard always drew the same one. "auto" says out loud what the
        // overwriting was doing, and the keyboard settings now offer a real choice to anyone
        // who would rather pin a layout.
        if (from < 4 && typeof raw.osk?.layout === "string" && raw.osk.layout !== "auto") {
            console.log(`[Config] Migrated osk.layout "${raw.osk.layout}" -> "auto"`);
            raw.osk.layout = "auto";
        }

        raw.configVersion = root.currentConfigVersion;
        console.log(`[Config] Migrated config schema ${from} -> ${root.currentConfigVersion}`);
        return true;
    }

    // list<var>/list<string> are QML sequences: indexable with a numeric length,
    // but Array.isArray is false for them.
    function isArrayLike(value) {
        return typeof value === "object" && value !== null && typeof value.length === "number";
    }

    // The adapter is the type oracle: whatever a value was coerced into, its
    // type is by definition the type the schema declares.
    function typesConflict(rawValue, qmlValue) {
        if (rawValue === null || rawValue === undefined)
            return false;
        // Unknown keys have no counterpart to conflict with. JsonAdapter drops
        // them on the next write anyway.
        if (qmlValue === undefined || qmlValue === null)
            return false;

        const rawIsArray = Array.isArray(rawValue);
        const qmlIsArray = root.isArrayLike(qmlValue);
        if (rawIsArray !== qmlIsArray)
            return true;

        if (rawIsArray) {
            // Coercion is positional and length-preserving, so mismatched
            // lengths mean this is not a coerced copy and nothing can be
            // concluded. Equal lengths let each element be compared in place,
            // which is what catches [{...}] collapsing into [""].
            if (rawValue.length !== qmlValue.length)
                return false;
            for (let i = 0; i < rawValue.length; ++i) {
                if (typeof rawValue[i] !== typeof qmlValue[i])
                    return true;
            }
            return false;
        }

        const rawIsObject = typeof rawValue === "object";
        const qmlIsObject = typeof qmlValue === "object";
        if (rawIsObject !== qmlIsObject)
            return true;
        if (rawIsObject)
            return false;

        // Scalars. number<->bool is deliberately allowed: 0/1 for a bool is a
        // plausible hand-edit and coerces to the right thing.
        if (typeof rawValue === "string" && typeof qmlValue === "number")
            return true;
        if (typeof rawValue === "number" && typeof qmlValue === "string")
            return true;
        if (typeof rawValue === "string" && typeof qmlValue === "boolean")
            return true;
        return false;
    }

    function repairTypeConflicts(rawObject, qmlObject, defaultObject, prefix, repaired) {
        for (const key in rawObject) {
            const rawValue = rawObject[key];
            const qmlValue = qmlObject[key];
            const defaultValue = defaultObject ? defaultObject[key] : undefined;
            const path = prefix ? `${prefix}.${key}` : key;

            if (root.typesConflict(rawValue, qmlValue)) {
                // Writing the default back rather than dropping the key means
                // the adapter picks the right value up from this same write; a
                // missing key would leave the coerced garbage in place.
                if (defaultValue === undefined)
                    continue;
                console.warn(`[Config] Resetting ${path} to its default: the stored value no longer matches the schema`);
                rawObject[key] = defaultValue;
                repaired.push(path);
                continue;
            }
            // Recurse into plain objects only — array elements are free-form.
            if (rawValue && typeof rawValue === "object" && !Array.isArray(rawValue) && qmlValue && typeof qmlValue === "object" && !root.isArrayLike(qmlValue)) {
                root.repairTypeConflicts(rawValue, qmlValue, defaultValue, path, repaired);
            }
        }
    }

    // Semantically wrong but syntactically valid values (a typo'd enum
    // string, a stale value from a renamed option, an out-of-range mode
    // number) pass typesConflict() untouched, since it only compares JS
    // types. Covers both string and integer enums — plenty of options here
    // are int-coded modes, and an unlisted number silently falls through
    // every branch that consumes it. Options with a continuous range rather
    // than a fixed value set (speedScale, gains, sizes) are deliberately
    // absent: they need bounds checking, not membership.
    //
    // An entry that is *missing* a legal value is worse than no entry at all:
    // it resets a setting the user deliberately chose. Every list below is
    // copied from the option set the corresponding ConfigSelectionArray in
    // modules/settings declares, so adding a mode to the UI means adding it
    // here too. Anything whose full value set can't be read off one such list
    // (background widget placementStrategy, which also accepts undocumented
    // aliases) is left out on purpose.
    readonly property var enumConstraints: ({
            "panelFamily": ["ii", "waffle"],
            "policies.ai": [0, 1, 2],
            "policies.weeb": [0, 1, 2],
            "policies.wallpapers": [0, 1],
            "policies.translator": [0, 1, 2],
            "policies.player": [0, 1],
            "policies.phone": [0, 1],
            "phone.webcam.cameraFacing": ["front", "back"],
            "phone.webcam.resolution": ["640x480", "1280x720", "1920x1080"],
            "phone.webcam.rotateDegrees": [0, 90, 180, 270],
            "phone.webcam.connection": ["wifi", "usb"],
            "appearance.fakeScreenRounding": [0, 1, 2, 3, 4],
            "appearance.colorEngine": ["vynx", "fork"],
            "background.zoomOutStyle": [0, 1, 2],
            "background.mediaMode.visualizerMode": [0, 1, 2, 3],
            "background.mediaMode.syllable.textHighlightStyle": [0, 1],
            "bar.cornerStyle": [0, 1, 2, 3],
            "bar.barGroupStyle": [0, 1, 2],
            "bar.barBackgroundStyle": [0, 1, 2, 3],
            "bar.mediaPlayer.popupStyle": ["default", "expressive", "android"],
            "cheatsheet.aminoAcidScheme": ["five", "seven", "four"],
            "userProfile.imageStyle": ["initial", "expressive", "custom"],
            "lock.centerAlignment": ["vertical", "horizontal"],
            "lock.notifications.position": ["top_left", "top_right", "bottom_left", "bottom_right"],
            "lock.notifications.privacy": ["full", "redacted", "countOnly"],
            "lock.notifications.defaultPolicy": ["show", "hide"],
            "lock.notifications.filters.criticalOverride": ["full", "none"],
            // osk.layout is deliberately absent: its values are layout names out of layouts.js,
            // so a fixed list here would reject a layout added later. An unknown one already
            // falls back to the keyboard's default.
            "osk.style": ["deck", "classic"],
            "sidebar.position": ["default", "inverted", "left", "right"],
            "sidebar.sidebarStyle": ["default", "connect"],
            "sidebar.dashboardHeader.profileImageType": ["user_profile", "distro", "none"],
            "sidebar.dashboardHeader.textMode": ["username", "uptime", "none", "custom"],
            "sounds.notificationDefaultPolicy": ["play", "mute"],
            "time.firstDayOfWeek": [0, 1, 2, 3, 4, 5, 6]
        })

    function getNestedValue(obj, keys) {
        let node = obj;
        for (const key of keys) {
            if (node === undefined || node === null || typeof node !== "object")
                return undefined;
            node = node[key];
        }
        return node;
    }

    function repairEnumViolations(raw, repaired) {
        for (const path in root.enumConstraints) {
            const allowed = root.enumConstraints[path];
            const keys = path.split(".");
            let node = raw;
            let parent = null;
            let lastKey = null;
            let missing = false;
            for (const key of keys) {
                if (node === undefined || node === null || typeof node !== "object") {
                    missing = true;
                    break;
                }
                parent = node;
                lastKey = key;
                node = node[key];
            }
            // Key absent from this file (older config, or genuinely unset):
            // nothing to validate. Strings and numbers are both checked; a
            // value of any other type on this same path is a type conflict,
            // already caught by repairTypeConflicts(). Bools are excluded
            // deliberately — `true` would otherwise match a `1` entry.
            const checkable = typeof node === "string" || typeof node === "number";
            if (missing || !checkable || allowed.includes(node))
                continue;

            const defaultValue = root.getNestedValue(root.defaultOptions, keys);
            if (defaultValue === undefined)
                continue;
            console.warn(`[Config] Resetting ${path} to its default: ${JSON.stringify(node)} is not a recognized value`);
            parent[lastKey] = defaultValue;
            repaired.push(path);
        }
    }

    // JsonAdapter has no property to bind an unrecognized key to, so it
    // ignores the key on read and omits it on the next write (serializeRec
    // builds a fresh object from declared properties only). A typo'd key —
    // "sidebar.postion" — therefore does nothing, warns about nothing, and
    // then quietly disappears, which is the single most common "why is my
    // setting not applying" case. Nothing here deletes anything: the drop is
    // already the runtime's behaviour. This only finds them so they can be
    // reported while the file still contains them.
    function collectUnknownKeys(rawObject, defaultObject, prefix, unknown) {
        for (const key in rawObject) {
            const path = prefix ? `${prefix}.${key}` : key;
            if (!(key in defaultObject)) {
                unknown.push(path);
                continue;
            }
            const rawValue = rawObject[key];
            const defaultValue = defaultObject[key];
            // Descend into plain objects on both sides only. Array entries are
            // free-form, and an empty default object is indistinguishable from
            // a free-form map, so neither can be checked against a schema.
            if (!rawValue || typeof rawValue !== "object" || Array.isArray(rawValue))
                continue;
            if (!defaultValue || typeof defaultValue !== "object" || root.isArrayLike(defaultValue))
                continue;
            if (Object.keys(defaultValue).length === 0)
                continue;
            root.collectUnknownKeys(rawValue, defaultValue, path, unknown);
        }
    }

    // Returns true when the file needed rewriting. Repair runs at most once per
    // session: it is a one-time upgrade step, and capping it removes any chance
    // of a write/reload loop.
    function repairConfigFile() {
        // Malformed-JSON detection runs on every load, independent of the
        // configRepaired cap below — that cap only limits the one-time
        // migration/type-repair pass, and gating parse detection on it too
        // would mean a corruption introduced *after* the first repair goes
        // undetected for the rest of the session.
        let raw;
        try {
            raw = JSON.parse(configFileView.text());
        } catch (e) {
            // JsonAdapter's own C++ parser swallows this exact same error
            // with a qmlWarning and treats the load as successful, so
            // onLoaded still fires — with the adapter holding nothing but
            // QML defaults. Without handleMalformedConfig() blocking writes
            // here, the first user-triggered save clobbers the real (broken
            // but recoverable) file with those defaults.
            root.handleMalformedConfig(e);
            return false;
        }
        // Parsing is necessary but not sufficient: deserializeAdapter() also
        // bails on `!json.isObject()`, so a file holding a bare string,
        // number or array leaves the adapter on pure QML defaults exactly
        // like a syntax error does — and would otherwise reach
        // recoverFromMalformedConfig() below, unblocking the very write that
        // clobbers it. Array.isArray matters here because `typeof []` is
        // "object" and would sail through the plain type check.
        if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
            root.handleMalformedConfig({
                message: `top-level value is ${Array.isArray(raw) ? "an array" : typeof raw}, expected an object`
            });
            return false;
        }
        root.recoverFromMalformedConfig();

        if (root.configRepaired || root.defaultOptions === null)
            return false;

        const migrated = root.migrateRaw(raw);
        let repaired = [];
        root.repairTypeConflicts(raw, root.options, root.defaultOptions, "", repaired);
        root.repairEnumViolations(raw, repaired);

        let unknown = [];
        root.collectUnknownKeys(raw, root.defaultOptions, "", unknown);
        if (unknown.length > 0)
            console.warn(`[Config] Ignoring ${unknown.length} unrecognized key(s), which the next save will drop: ${unknown.join(", ")}`);

        if (!migrated && repaired.length === 0) {
            // Unknown keys alone never justify a rewrite — they're dropped by
            // the next write regardless. Back the file up so the discarded
            // lines survive somewhere, then just report them.
            if (unknown.length > 0) {
                root.configRepaired = true;
                Quickshell.execDetached(["cp", "--", root.filePath, `${root.filePath}.bak`]);
                root.notifyConfigHealth("unknownKeys", unknown);
            }
            return false;
        }

        root.configRepaired = true;
        // Keep a copy before healing — the reset values are the only record of
        // what the user had, and a wrong guess here should be recoverable.
        // Unknown keys ride along: this same write is what erases them.
        if (repaired.length > 0 || unknown.length > 0)
            Quickshell.execDetached(["cp", "--", root.filePath, `${root.filePath}.bak`]);

        // Deferred: a setText issued from inside onLoaded is treated as part of
        // the load still in flight and its save gets dropped.
        const payload = JSON.stringify(raw, null, 2);
        Qt.callLater(() => {
            configFileView.setText(payload);
            // setText re-deserializes, so the adapter now holds the repaired
            // values and rounding can be migrated off them.
            root.migrateRoundingConfig();
        });
        root.notifyConfigHealth(migrated ? "migrated" : "repaired", repaired);
        return true;
    }

    // Called once per malformed load, from the JSON.parse catch above.
    function handleMalformedConfig(parseError) {
        if (root.configMalformed)
            return;
        root.configMalformed = true;
        console.warn(`[Config] config.json is not valid JSON (${parseError.message}); preserving it as-is and blocking writes until it's fixed`);
        // Preserve the broken file exactly as the user left it — it's the
        // only copy, and hand-editing it back to valid JSON is the intended
        // recovery path (the existing watchChanges watcher picks the fix up
        // automatically via fileReloadTimer -> onLoaded -> repairConfigFile()).
        Quickshell.execDetached(["cp", "--", root.filePath, `${root.filePath}.malformed-${Date.now()}`]);
        root.blockWrites = true;
        root.notifyConfigHealth("malformed", []);
    }

    // Called on every successful parse; no-ops unless a prior load left
    // configMalformed set, i.e. the user (or watcher-triggered reload) just
    // fixed the file.
    function recoverFromMalformedConfig() {
        if (!root.configMalformed)
            return;
        root.configMalformed = false;
        root.blockWrites = false;
        console.log("[Config] config.json is valid JSON again; resuming normal writes");
        root.notifyConfigHealth("recovered", []);
    }

    // Escape hatch for a user who can't or doesn't want to hand-fix a
    // malformed config.json — wired to ConfigHealthBanner's reset action.
    function resetConfigToDefaults() {
        if (root.defaultOptions === null)
            return;
        console.warn("[Config] Resetting config.json to defaults at user request");
        root.configMalformed = false;
        root.blockWrites = false;
        // Object spread ({...obj}) isn't supported by this JS engine
        // (only array spread is) — use Object.assign instead.
        const payload = JSON.stringify(Object.assign({}, root.defaultOptions, {
            configVersion: root.currentConfigVersion
        }), null, 2);
        Qt.callLater(() => {
            configFileView.setText(payload);
        });
        root.notifyConfigHealth("reset", []);
    }

    // Single point where config health changes reach the user: updates the
    // state ConfigHealthBanner binds to and fires a desktop notification.
    function notifyConfigHealth(state, keys) {
        root.configHealthState = state;
        root.configHealthKeys = keys;
        const copy = {
            "malformed": ["Config file is broken", "config.json has invalid JSON syntax. Your settings are safe on disk, but changes won't save until it's fixed."],
            "recovered": ["Config file fixed", "config.json is valid again — settings will save normally."],
            "migrated": ["Config updated", "Some settings were migrated to a newer format."],
            "repaired": ["Config values reset", `${keys.length} setting${keys.length === 1 ? "" : "s"} had an invalid value and ${keys.length === 1 ? "was" : "were"} reset to default.`],
            "unknownKeys": ["Unrecognized settings", `${keys.length} entr${keys.length === 1 ? "y" : "ies"} in config.json ${keys.length === 1 ? "isn't" : "aren't"} recognized and will be removed on the next save.`],
            "reset": ["Config reset to defaults", "config.json was replaced with default settings."]
        }[state];
        if (!copy)
            return;
        Quickshell.execDetached(["notify-send", copy[0], copy[1], "-a", "Shell", "-i", "dialog-warning", `--urgency=${state === "malformed" ? "critical" : "normal"}`]);
    }

    // Runs before the async file load completes, so this captures the pure QML
    // defaults — the only chance to, since deserializing overwrites them.
    Component.onCompleted: {
        root.defaultOptions = root.snapshotDefaults(root.options);
    }

    Component.onDestruction: {
        root.blockWrites = true;
    }

    FileView {
        id: configFileView
        path: root.filePath
        watchChanges: true
        blockWrites: root.blockWrites
        // Atomic writes: write to a temp file then rename. Prevents mid-write
        // corruption if the process is killed mid-save (e.g. PC power loss,
        // SIGKILL during shell update).
        atomicWrites: true
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: {
            if (root.ready && !root.blockWrites)
                fileWriteTimer.restart();
        }
        onLoaded: {
            root.ready = true;
            // When a repair is queued, rounding is migrated from inside it —
            // the values in the adapter right now are the coerced ones.
            if (root.repairConfigFile())
                return;
            migrateRoundingConfig();
        }
        onLoadFailed: error => {
            if (error != FileViewError.FileNotFound) {
                return;
            }
            const elapsed = Date.now() - root.initTimestamp;
            if (elapsed > root.missingFileGracePeriod && !root.ready) {
                // Singleton has been alive past the grace window and the file
                // is still gone — legitimately missing (first-run install or
                // user manually deleted it). Safe to seed defaults.
                // Stamp the schema version so a brand-new file is not mistaken
                // for a pre-versioning one and re-migrated on next start.
                root.options.configVersion = root.currentConfigVersion;
                writeAdapter();
                // Mark ready so subsequent user-triggered writes go through
                // (fileWriteTimer guards on `root.ready`).
                root.ready = true;
            } else {
                // Likely transient: schedule a reload. If it succeeds,
                // `onLoaded` flips `root.ready` and nothing is overwritten. If
                // it still fails past the grace window, defaults are written.
                missingFileRetryTimer.restart();
            }
        }

        Component.onDestruction: {
            configFileView.blockWrites = true;
        }

        JsonAdapter {
            id: configOptionsJsonAdapter

            // 0 means "written before schema versioning existed" — see
            // migrateRaw(). Never default this to currentConfigVersion.
            property int configVersion: 0

            property string panelFamily: "ii" // "ii", "waffle"

            property JsonObject policies: JsonObject {
                property int ai: 1 // 0: No | 1: Yes | 2: Local
                property int weeb: 0 // 0: No | 1: Open | 2: Closet
                property int wallpapers: 0 // 0: No | 1: Yes
                property int translator: 0 // 0: No | 1: Default (illogical-impulse) | 2: Expressive (reworked)
                property int player: 0 // 0: No | 1: Yes
                property int phone: 1 // 0: No | 1: Yes — Phone tab (future KDE Connect + scrcpy external)
            }

            property JsonObject phone: JsonObject {
                property bool kdeconnectEnabled: true
                property bool showPeripheralCards: true
                property JsonObject scrcpy: JsonObject {
                    property bool stayAwake: false  // bare scrcpy default — don't add overhead
                    property bool turnScreenOff: false  // turning screen off causes input delay on Samsung (touch sampling rate drops)
                    property bool noPowerOn: false  // bare scrcpy default
                    property bool noAudio: false
                    property bool showTouches: false
                    property bool fullscreen: false
                    property bool alwaysOnTop: false
                    property int maxFps: 0  // 0 = use device's native frame rate (matches bare `scrcpy`)
                    property string bitRate: "8M"
                    property int maxSize: 0
                    property int videoBuffer: 0  // scrcpy 4.0 default is 0ms — 80ms adds visible latency
                    property bool useWireless: false
                    property bool autoWirelessIp: true  // resolve IP live from KDE Connect instead of the manual field
                    property string wirelessIp: ""
                    property string wirelessPort: "5555"
                    property bool showTerminal: false
                }
                property JsonObject webcam: JsonObject {
                    property bool enabled: false
                    property string cameraFacing: "front" // "front" | "back"
                    property string resolution: "1280x720" // "640x480" | "1280x720" | "1920x1080"
                    property int fps: 30
                    property string bitrate: "4M"
                    property bool mirrorHorizontally: false
                    property int rotateDegrees: 0 // 0 | 90 | 180 | 270
                    property string connection: "wifi" // "wifi" | "usb"
                    property string wifiIp: ""
                    property int port: 4747
                }
                property JsonObject microphone: JsonObject {
                    property bool enabled: false
                    property string connection: "wifi"
                    property string wifiIp: ""
                    property int port: 4748
                    property bool noiseSuppression: false
                    property bool echoCancellation: false
                    property bool autoGainControl: false
                    property int micGain: 100
                    property bool setAsDefault: false
                }
            }

            property JsonObject localsend: JsonObject {
                property bool autoStart: true
                property string downloadPath: Directories.localSendDownloadPath.replace("file://", "")
                property bool showNotifications: true
                property bool preferPopupOverNotification: true
            }

            property JsonObject googleDrive: JsonObject {
                property bool enabled: false
                property string syncInterval: "3d" // "1h", "4h", "1d", "2d", "3d"
                property bool syncOnBoot: true
                property bool syncOnNetworkChange: false
                property int bandwidthLimitKbps: 0
                property bool pauseOnMeteredConnection: true
                property list<string> backupFolders: []
                property list<string> excludePatterns: ["*.tmp", "*.swp", "*.lock", "node_modules/", ".git/", "__pycache__/"]
                // Empty means the per-machine default: <username>_<distro>_backups.
                // GoogleDriveService also treats the old "ii-backup" default as
                // automatic so existing installs migrate without rewriting config.
                property string driveBasePath: ""
                property bool notifyOnComplete: true
                property bool notifyOnError: true
                property int keepVersions: 3
                property bool deleteRemoteOrphans: false
                property string lastSyncTime: ""
                property string lastSyncStatus: ""
                property int lastSyncFileCount: 0
                property real lastSyncSizeMb: 0.0
                // Durable sync events used by the Drive activity charts. Keep
                // this explicitly typed: nested JsonObject arrays must not use
                // `var` in Quickshell's JSON adapter.
                property list<var> syncHistory: []
                property real totalDriveUsageMb: 0.0
                property real driveQuotaMb: 0.0
                property real driveBackupUsageMb: 0.0
            }

            property JsonObject vpn: JsonObject {
                property bool enabled: false
                property bool autoConnect: false
                property string backend: "networkmanager"
                property string defaultProfile: ""
                property string defaultProvider: "networkmanager"
                property string recentProvider: "networkmanager"
                property string defaultLocation: ""
                property bool disconnectOnDisable: false
                property bool killSwitch: false
                property bool blockLan: false
                property bool enableDiagnostics: true
            }

            property JsonObject tailscale: JsonObject {
                property bool enabled: false
                property bool autoConnect: false
                property bool acceptDns: true
                property bool shieldsUp: false
                property bool ssh: false
                property string exitNode: ""
                property list<string> advertiseRoutes: []
                property bool advertiseExitNode: false
                property bool showPeers: true
                property bool stopDaemonWhenDisabled: false
                property bool enableDiagnostics: true
            }

            property JsonObject dnsOverTls: JsonObject {
                property bool enabled: false // Desired state, re-applied on startup and network changes
                property string preset: "adguard"
                property string serverName: "dns.adguard-dns.com" // TLS certificate name (SNI)
                property string serverAddress: "94.140.14.14"
                property string fallbackAddress: "94.140.15.15"
                property bool strict: true // "yes" when true, "opportunistic" when false
                property bool routeAllQueries: true // Route every domain through this server
                property bool reapplyOnNetworkChange: true
            }

            property JsonObject ai: JsonObject {
                property string systemPrompt: "## Style\n- Use casual tone, don't be formal!\n- Always be brief and to the point, unless asked otherwise\n- Don't repeat the user's question\n- Be approachable: Avoid using overly complicated, domain-specific terms and provide analogies when asked to explain a concept\n\n## Context (ignore when irrelevant)\n- You are a helpful and inspiring sidebar assistant on a {DISTRO} Linux system\n- Desktop environment: {DE}\n- Current date & time: {DATETIME}\n- Focused app: {WINDOWCLASS}\n\n## Presentation\n- Use Markdown features in your response: \n  - **Bold** text to **highlight keywords** in your response\n  - **Split long information into small sections** with h2 headers and a relevant emoji at the start of it (for example `## 🐧 Linux`). Bullet points are preferred over long paragraphs, unless you're offering writing support or instructed otherwise by the user.\n- Asked to compare different options? You should firstly use a table to compare the main aspects, then elaborate or include relevant comments from online forums *after* the table. Make sure to provide a final recommendation for the user's use case!\n- Use LaTeX formatting for mathematical and scientific notations whenever appropriate. Enclose all LaTeX '$$' delimiters. NEVER generate LaTeX code in a latex block unless the user explicitly asks for it. DO NOT use LaTeX for regular documents (resumes, letters, essays, CVs, etc.).\n\nThanks!\n"
                property string tool: "functions" // search, functions, or none
                property list<var> models: [
                    // Needed entries in the object: title, value, modelProvider (only for openrouter)
                    {
                        "openrouter": [
                            {
                                title: "Gemini 2.5 Flash",
                                value: "gemini-2.5-flash",
                                modelProvider: "google"
                            },
                        ]
                    },
                    {
                        "google": []
                    }
                ]
                property list<var> otherModels: [
                    // Available api_format(s): openai, gemini, mistral
                    {
                        "name": "Mistral Medium",
                        "model": "mistral-medium-2505",
                        "icon": "mistral-symbolic",
                        "endpoint": "https://api.mistral.ai/v1/chat/completions",
                        "requires_key": true,
                        "key_id": "mistral",
                        "api_format": "mistral"
                    }
                ]
            }

            property JsonObject appearance: JsonObject {
                property bool extraBackgroundTint: true
                property int fakeScreenRounding: 3 // 0: None | 1: Always | 2: When not fullscreen | 3: Wrapped
                property int wrappedFrameThickness: 10
                property bool sharpMode: false
                property string globalRounding: "large" // Legacy — migrated to roundingValue via onLoaded
                property int roundingValue: -1 // -1 = not yet migrated, 0-48 = active slider value (default 24 after migration)
                property int defaultBorderRadius: 18
                property bool toggleWindowRounding: true // Changes Hyprland window rounding to 0 if sharpMode is true
                property real iconTintPercentage: 0.6
                property JsonObject fonts: JsonObject {
                    property bool enableCustom: false
                    property string main: "Google Sans Flex" // xmpl: right sidebar, settings, system monitor, default clock, expressive weather
                    property string numbers: "Google Sans Flex" // xmpl: styled slider, config
                    property string title: "Google Sans Flex" // settings list item, popup titles
                    property string iconNerd: "JetBrainsMono Nerd Font"
                    property string monospace: "JetBrainsMono Nerd Font" // clipboard metadata
                    property string reading: "Readex Pro" // cookie clock quote
                    property string expressive: "Space Grotesk" // desktop widgets font, overview workspace number, user profile config
                    property bool roundnessFull: false
                }
                property JsonObject transparency: JsonObject {
                    property bool enable: false
                    property bool automatic: false
                    property bool popups: false
                    property real backgroundTransparency: 0.48
                    property real contentTransparency: 0.38
                }
                property int blurSize: 10
                property int borderWidth: 2
                property int gapsIn: 4
                property int gapsOut: 5
                property real ignoreAlpha: 0.4
                property JsonObject wallpaperTheming: JsonObject {
                    property bool enableAppsAndShell: true
                    property bool enableQtApps: true
                    property bool enableTerminal: true
                    property bool autoRestartQuickshell: false
                    property JsonObject terminalGenerationProps: JsonObject {
                        property real harmony: 0.6
                        property real harmonizeThreshold: 100
                        property real termFgBoost: 0.35
                        property bool forceDarkMode: false
                    }
                }
                property JsonObject icons: JsonObject {
                    property bool enableThemed: false
                    property bool enableShapeMask: true
                    property string shapeMask: "Circle"
                }
                property string borderColorType: "primary" // Options: primary, secondary, tertiary, primaryContainer, surface
                property bool borderless: false
                property string colorEngine: "vynx" // "vynx" | "fork" — color generation engine
                property string iconTheme: "Papirus"
                property JsonObject palette: JsonObject {
                    property string type: "scheme-fidelity" // Allowed: auto, scheme-content, scheme-expressive, scheme-fidelity, scheme-fruit-salad, scheme-intense, scheme-monochrome, scheme-neutral, scheme-rainbow, scheme-tonal-spot, scheme-vibrant
                    property string accentColor: ""
                }
                property list<string> customColorSchemes: []
                property real animationMultiplier: 1.0 // 0.25 = fast, 1.0 = default, 2.0 = slow
                property bool colorfulScrollbar: false
                property bool scrollAnimations: true
                property bool scrollFadeMask: false
                property JsonObject openrgb: JsonObject {
                    property bool enable: false
                    property bool applyOnStartup: true
                    property real fadeDuration: 0.5
                    property real interpolationSteps: 100
                    property list<var> devices: []
                }
            }

            property JsonObject audio: JsonObject {
                // Values in %
                property JsonObject protection: JsonObject {
                    // Prevent sudden bangs
                    property bool enable: false
                    property real maxAllowedIncrease: 10
                    property real maxAllowed: 99
                }
            }

            property JsonObject apps: JsonObject {
                property string bluetooth: "kcmshell6 kcm_bluetooth"
                property string changePassword: "kitty -1 --hold=yes fish -i -c 'passwd'"
                property string network: "kcmshell6 kcm_networkmanagement"
                property string manageUser: "kcmshell6 kcm_users"
                property string networkEthernet: "kcmshell6 kcm_networkmanagement"
                property string taskManager: "plasma-systemmonitor --page-name Processes"
                property string terminal: "kitty -1" // This is only for shell actions
                property string update: "kitty -1 --hold=yes fish -i -c 'pkexec pacman -Syu'"
                property string volumeMixer: `~/.config/hypr/hyprland/scripts/launch_first_available.sh "pavucontrol-qt" "pavucontrol"`
            }

            // Per-app usage and energy history. The sampler is a separate process
            // that reads its flags once at startup, so everything above the display
            // options relaunches it rather than taking effect in place.
            property JsonObject appStats: JsonObject {
                property bool enable: true
                property int sampleIntervalMs: 10000
                property int flushIntervalMs: 60000
                // Days of history kept. Under "previousMonth" this is a floor rather
                // than the window itself: nothing the previous calendar month needs
                // is dropped, so the window slides between 31 and 62 days and this
                // month can always be compared with the one before it. "fixed" keeps
                // exactly this many days.
                property int retentionDays: 31
                property string retentionMode: "previousMonth"
                // "auto" prefers RAPL and falls back to battery drain; "rapl",
                // "battery" and "none" pin the choice.
                property string energySource: "auto"
                // Sample intervals between full /proc sweeps for new GPU clients.
                // Only a backstop; a new window forces one immediately.
                property int gpuFullEvery: 30
                // Seconds without input before foreground time stops accruing.
                // 0 turns the idle monitor off, and time keeps running.
                property int idleTimeoutSec: 300
                // Daemons with no window are recorded either way; this only decides
                // whether they are worth showing next to the apps.
                property bool trackHeadless: true
                property bool showHeadless: false
                property bool overlayEnabled: true

                // What the overlay opens on. "day", "week" or "month", and a metric
                // key from the tab row. `rememberLastView` overrides both with
                // whatever was last looked at.
                property string defaultGranularity: "day"
                property string defaultMetric: "fg"
                property bool rememberLastView: true
                property string lastGranularity: "day"
                property string lastMetric: "fg"
                // "apps" or "battery". Only ever "battery" on a machine that has
                // one, and ignored on a machine that does not.
                property string lastView: "apps"
                // Which day a week runs from. Weeks are calendar weeks so that the
                // one before is always the same seven days, whoever asks.
                property bool weekStartsMonday: true
                // Keep the picked app across openings instead of clearing it.
                property bool keepSelection: false
                // Off by default: it needs the period before the one on screen
                // parsed as well, which doubles the files read for a month.
                property bool showComparison: false
                // Apps under this many seconds for the chosen metric are left out of
                // the list. Duration metrics only; energy is never thresholded.
                property int minDurationSec: 0
            }

            property list<var> bluetoothDeviceImages: []

            property JsonObject background: JsonObject {
                property bool enable: true // if someone wants to use an external wallpaper manager, note that its not fully tested but it should just disable background.qml from being loaded
                property bool blurGradientExperiment: false
                property JsonObject widgets: JsonObject {
                    property string colorScheme: "default"
                    property bool showOnlyOnSingleMonitor: false
                    property string targetMonitor: ""
                    property JsonObject clock_cookie: JsonObject {
                        property bool enable: false
                        property bool disableAnimationOnLock: false
                        property string placementStrategy: "free"
                        property real x: 1518.98
                        property real y: 168.8
                        property bool aiStyling: false
                        property string aiStylingModel: "gemini"
                        property int sides: 14
                        property string backgroundStyle: "cookie"
                        property string backgroundShape: "Arch"
                        property string dialNumberStyle: "full"
                        property string hourHandStyle: "fill"
                        property string minuteHandStyle: "medium"
                        property string secondHandStyle: "dot"
                        property string dateStyle: "bubble"
                        property bool timeIndicators: true
                        property bool hourMarks: false
                        property bool dateInClock: true
                        property bool constantlyRotate: false
                        property bool quoteEnable: false
                        property string quoteText: ""
                    }
                    property JsonObject clock_expressive_card: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property int widgetSize: 100
                    }

                    property JsonObject clock_flex: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property int widgetSize: 100
                        property bool useAltColors: false
                    }
                    property JsonObject clock_digital: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool adaptiveAlignment: true
                        property bool showDate: true
                        property bool animateChange: true
                        property bool vertical: false
                        property bool colorful: false
                        property bool showColon: true
                        property JsonObject font: JsonObject {
                            property real weight: 350
                            property real width: 100
                            property real size: 90
                            property real roundness: 0
                        }
                        property bool quoteEnable: false
                        property string quoteText: ""
                    }
                    property JsonObject clock_nagasaki: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool monochrome: false
                    }
                    property JsonObject clock_word: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property int size: 240
                        property string backgroundStyle: "shape"
                        property string backgroundShape: "Circle"
                    }
                    property JsonObject clock_dial: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool showTicks: true
                        property bool showMinuteHand: true
                        property bool enableShadows: false
                        property bool enableInnerShadow: false
                        property string hourHandStyle: "fill"
                        property string minuteHandStyle: "medium"
                        property bool showSecondHand: false
                        property string secondHandStyle: "dot"
                        property bool showNumberRing: false
                        property bool expressiveColors: false
                    }
                    property JsonObject nagasaki_text: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property int size: 200
                    }
                    property JsonObject clock_hori: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property int widgetSize: 100
                        property bool useAltColors: false
                    }
                    property JsonObject clock_nothing: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool use24h: true
                        property bool showAmPmChip: true
                        property bool showTopLabel: true
                        property bool showDate: true
                        property bool useAccentColor: false
                    }
                    property JsonObject nothing_wheel_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject media: JsonObject {
                        property bool enable: true
                        property string style: "circular" // circular, expressive
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 249.21
                        property real y: 612.92
                        property bool useAlbumColors: true
                        property bool hideAllButtons: false
                        property bool showPreviousToggle: true
                        property bool tintArtCover: false
                        property string backgroundShape: "Cookie12Sided"  // Options: MaterialShape.Shape enum values as string
                        property bool rotateAlbumArt: true
                        property bool showTimeInfo: true
                        property bool showArtist: true
                        property bool showProgressSlider: true
                        property bool dynamicAlbumColors: false
                        property JsonObject glow: JsonObject {
                            property bool enable: true
                            property real brightness: 10
                        }
                        property JsonObject visualizer: JsonObject {
                            property bool enable: false
                            property real opacity: 0.15
                            property int smoothing: 2
                            property int blur: 1
                        }
                    }
                    property JsonObject circular_media: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 249.21
                        property real y: 612.92
                        property bool useAlbumColors: true
                        property bool enableGlassReflection: true
                        property bool enableShadows: false
                        property bool showPrevButton: true
                        property bool showNextButton: true
                        property bool showDevicePill: true
                        property string progressShape: "Cookie9Sided"
                        property int widgetSize: 100
                    }
                    property JsonObject wearos_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property bool useAlbumColors: true
                        property bool enableGlassReflection: true
                        property bool showDistroLogo: true
                        property bool showSunsetComplication: true
                        property bool showDigitalTimePill: true
                        property bool showBatteryPill: true
                        property bool showHourSubDial: true
                        property bool showBedtimeIcon: true
                        property bool showKdeConnect: true
                        property bool showDateComplication: true
                        property bool showMinuteHand: true
                        property bool showOuterNumbers: true
                        property bool showInnerNumbers: true
                        property bool showBezelRing: true
                        property bool enableShadows: false
                        property int widgetSize: 100
                    }
                    property JsonObject wearos_arc_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property bool blackBackground: false
                        property bool enableGlassReflection: true
                        property bool enableBackgroundPattern: true
                        property string leftComplication: "weather"
                        property string rightComplication: "battery"
                        property string bottomComplication: "calendar"
                        property bool enableShadows: false
                    }
                    property JsonObject concentric_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property string dialStyle: "concentric"
                        property string frameStyle: "none"
                        property bool boldFont: false
                        property bool use24h: true
                        property bool showHourText: true
                        property string hourHandStyle: "hide"
                        property string minuteHandStyle: "hide"
                        property string secondHandStyle: "hide"
                        property bool showHourMarks: false
                        property string minuteStyle: "pill_horizontal"
                        property bool showArc24h: false
                        property bool showHourSubDial: false
                        property bool showSunsetDial: false
                        property string bottomSubDialContent: "weather_temp"
                        property bool showMinuteDot: false
                        property bool quoteEnable: false
                        property string quoteText: ""
                        property int minutePillLeftMargin: 67
                        property int subdialMarginOffset: 5
                        property int dialMarginOffset: 3
                        property int hourPixelSize: 30
                        property int hourFontWeight: 600
                        property int hourFontWidth: 85
                        property int hourFontRound: 100
                        property bool useBlackBg: false
                        property bool enableGlassReflection: false
                        property bool enableShadows: false
                    }
                    property JsonObject month_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property bool showMonthRing: true
                        property bool showDayRing: true
                        property bool showWeekRing: true
                        property bool showMonthPill: true
                        property bool showDayPill: true
                        property bool showWeekPill: true
                        property bool showTickMarks: true
                        property bool boldFont: true
                        property bool useBlackBg: true
                        property bool enableGlassReflection: false
                        property string hourHandStyle: "fill"
                        property string minuteHandStyle: "medium"
                        property string secondHandStyle: "line"
                    }
                    property JsonObject scallop_dot_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property bool boldFont: true
                        property bool useBlackBg: false
                        property bool enableGlassReflection: false
                        property bool showHourHand: true
                        property bool showMinuteBubble: true
                        property bool showDots: true
                    }
                    property JsonObject scallop_number_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property bool boldFont: true
                        property bool useBlackBg: false
                        property bool enableGlassReflection: false
                        property bool showHourHand: true
                        property bool showMinuteBubble: true
                        property bool showDots: true
                    }
                    property JsonObject circle_pointer_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property bool boldFont: true
                        property bool useBlackBg: false
                        property bool enableGlassReflection: false
                        property bool showDots: true
                    }
                    property JsonObject triple_ring_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property bool boldFont: true
                        property bool useBlackBg: false
                        property bool enableGlassReflection: false
                    }
                    property JsonObject photo_1x1: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property string backgroundShape: "Cookie9Sided"
                        property string imagePath: ""
                    }
                    property JsonObject android_search_bar: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property string aspectRatio: "0.5x2"
                        property string action1: "music_rec"
                        property string action2: "ai_chat"
                        property string action3: "search"
                    }
                    property JsonObject search_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property string aspectRatio: "0.5x2"
                        property string action1: "ai_chat"
                        property string action2: "music_rec"
                        property string action3: "search"
                        property string aiLogo: "gemini"
                        property string outerLeftIcon: "spark"
                        property bool useMaterialSymbolForOuterLeftIcon: false
                    }
                    property JsonObject resource_cpu_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property string aspectRatio: "2x0.5"
                        property bool showDetails: true
                    }
                    property JsonObject resource_ram_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property string aspectRatio: "2x0.5"
                        property bool showDetails: true
                    }
                    property JsonObject resource_disk_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property string aspectRatio: "2x0.5"
                        property bool showDetails: true
                    }
                    property JsonObject resource_fill_cards: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property string orientation: "horizontal"
                        property bool enableCpu: true
                        property bool enableRam: true
                        property bool enableDisk: true
                    }
                    property JsonObject grid_card_clock: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                    }
                    property JsonObject at_a_glance: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property int widgetSize: 100
                        property int widthCells: 3
                        property bool dualColumnMode: false
                        property list<string> servicePriority: ["media", "calendar", "sports", "todo", "email", "localsend", "kdeconnect", "fallback"]
                        property bool enableMedia: true
                        property bool enableCalendar: true
                        property bool enableSports: true
                        property bool enableTodo: true
                        property bool enableEmail: true
                        property bool enableLocalSend: true
                        property bool enableKdeConnect: true
                        property bool enableWeather: true
                        property int calendarWindowMinutes: 60
                        property int sportsWindowHours: 12
                        property bool showLocation: true
                        property bool showServiceLabel: false
                        property bool showSeparators: true
                        property bool animateContent: true
                    }
                    property JsonObject weather: JsonObject {
                        property bool enable: false
                        property string style: "default" // default, expressive
                        property string backgroundShape: "Cookie9Sided"
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 400
                        property real y: 100
                        property bool expressiveColors: false
                    }
                    property JsonObject weather_forecast: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: true
                    }
                    property JsonObject weather_card: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: true
                    }
                    property JsonObject weather_icon: JsonObject {
                        property bool enable: false
                        property string backgroundShape: "Cookie12Sided"
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: true
                    }
                    property JsonObject weather_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: true
                    }
                    property JsonObject weather_circle: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: true
                    }
                    property JsonObject nothing_weather_circle: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject volume_mute_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject wifi_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject bluetooth_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject mic_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject dark_mode_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject screen_record_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject easy_effects_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject nothing_ring_media: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject weather_typography: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: true
                    }
                    property JsonObject weather_hourly: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: true
                    }
                    property JsonObject date: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 100
                        property real y: 100
                        property bool expressiveColors: false
                    }
                    property JsonObject calendar_minimal: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject calendar_grid: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject calendar_agenda: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject calendar_next_event: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject calendar_pill: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject calendar_upcoming_3days: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject photo: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property string imagePath: ""
                        property bool expressiveColors: false
                    }
                    property JsonObject photo_weather_2x1: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property string imagePath: ""
                        property bool showOverlay: true
                        property bool expressiveColors: false
                    }
                    property JsonObject photo_pill_2x1: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property string imagePath: ""
                        property bool showOverlay: true
                        property bool expressiveColors: false
                    }
                    property JsonObject photo_minimal_temp_2x1: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property string imagePath: ""
                        property bool showOverlay: true
                        property bool expressiveColors: false
                    }
                    property JsonObject bluetooth_battery: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject bluetooth_headphone: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool halfSize: true
                        property bool expressiveColors: false
                    }
                    property JsonObject mobile_battery: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject bluetooth_headphone_cookie: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property string materialShape: "Cookie12Sided"
                        property bool expressiveColors: false
                    }
                    property JsonObject bluetooth_fill_cards: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject pc_battery_bars: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject pc_battery_cable: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject devices_battery_list: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject devices_battery_list_1x1: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject bluetooth_earbuds_stem: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject email_inbox: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject email_inbox_2x1: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject quote: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                        property string quoteText: ""
                        property real fontSize: 16
                    }
                    property JsonObject quick_actions: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                        property string bottomButton1: "translator"
                        property string bottomButton2: "phone"
                    }
                    property JsonObject ai_chat: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject notes_widget: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject notes_widget_2x1: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                    }
                    property JsonObject media_cd: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool dynamicAlbumColors: false
                        property bool enableShadows: false
                        property bool enableInnerShadow: false
                        property int widgetSize: 100
                    }
                    property JsonObject compact_media: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool dynamicAlbumColors: false
                        property string backgroundShape: "Rectangle"
                        property bool enableShadows: false
                        property bool enableInnerShadow: false
                        property int widgetSize: 100
                    }
                    property JsonObject water_reminder: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 200
                        property real y: 200
                        property bool expressiveColors: false
                        property int dailyGoal: 8
                        property int intervalHours: 2
                        property string reminderText: "Time to hydrate! 💧"
                    }
                    property bool enableInnerShadow: false
                    property bool enableShadows: false
                    property bool enableGrid: false
                    property bool enableSnap: false
                    property real widgetsScale: 1.0
                    property bool lockWidgetPositions: false
                }
                property list<var> activeWidgets: [
                    {
                        "id": "widget_clock_cookie",
                        "widgetId": "clock_cookie",
                        "x": 1518.98,
                        "y": 168.8,
                        "placementStrategy": "free",
                        "lockBehavior": "center"
                    },
                    {
                        "id": "widget_media_circular",
                        "widgetId": "media_circular",
                        "x": 249.21,
                        "y": 612.92,
                        "placementStrategy": "free",
                        "lockBehavior": "hide"
                    }
                ]
                property bool scaleLargeWallpapers: true
                property bool animateWallpaperChanges: true
                property string wallpaperAnimation: ""
                property bool zoomOutEnabled: true  // master toggle for zoom-out animations
                property bool windowZoomOnOverview: false // fake window scale-out during overview (GNOME-like)
                property bool windowZoomLiveCapture: false // keep screencopy live instead of freezing on overview open
                property bool cheatsheetZoomOut: true
                property bool overviewZoomOut: true
                property bool workspaceBlur: false
                property string wallpaperPath: ""
                property string lockscreenWallpaperPath: ""
                property bool useSeparateLockscreenWallpaper: false
                property string lightModeWallpaperPath: ""
                property bool useSeparateLightModeWallpaper: false
                property string thumbnailPath: ""
                property bool hideWhenFullscreen: true
                property bool useWallpaperEngine: false
                property string wallpaperEngineId: ""
                property string wallpaperEngineAssetsPath: ""
                property bool wpeSilent: true
                property real wpeVolume: 50
                property bool wpeNoAutoMute: false
                property bool wpeNoAudioProcessing: false
                property int wpeFps: 30
                property string wpeScreenSpan: ""
                property string wpeScaling: "default"
                property bool wpeDisableMouse: false
                property bool wpeDisableParallax: false
                property bool wpeNoFullscreenPause: false
                property bool wpePauseWhenWindowsOpen: false
                property int zoomOutStyle: 0 // 0: Blurred Backing | 1: Mirrored Plane
                property bool blurWhenWindowsOpen: false
                property int blurWhenWindowsOpenRadius: 80
                property JsonObject gradientBlur: JsonObject {
                    property bool enable: false
                    property int radius: 50
                    property string direction: "top-to-bottom"
                }
                property JsonObject parallax: JsonObject {
                    property bool vertical: false
                    property bool autoVertical: false
                    property bool enableWorkspace: true
                    property real workspaceZoom: 1.05 // Relative to wallpaper size
                    property bool enableSidebar: true
                    property real widgetsFactor: 1.2
                    property bool loop: false
                    property bool invertHorizontal: false
                    property bool invertVertical: false
                    property int intensity: 4
                }
                property JsonObject mediaMode: JsonObject {
                    property bool togglePerMonitor: false
                    property string backgroundShape: "Square"
                    property bool enableBackgroundAnimation: true // It **may** cause nausea for someone
                    property bool changeShellColor: true // Changes the shell color to the album color
                    property int backgroundOpacity: 50 // In percent
                    property int backgroundBlurRadius: 120
                    property int visualizerMode: 1 // 0: Off, 1: Waves, 2: Bars, 3: Radial
                    property bool showLyrics: true
                    property bool showPlayerSwitcher: true
                    property bool showSeekBar: true
                    property bool showVolumeSlider: true
                    property int lyricsOffsetMs: 0 // offset in milliseconds for lyrics sync adjustment
                    property JsonObject backgroundAnimation: JsonObject {
                        property bool enable: true
                        property int speedScale: 10 // 1: very slow, 10: default, 20: 2x speed etc.
                    }
                    property JsonObject syllable: JsonObject {
                        property int textHighlightStyle: 0 // 0: vertical, 1: horizontal (not perfect bc its not synced in a word level, but a cool animation to have)
                    }
                    property JsonObject musicVideo: JsonObject {
                        property bool enable: true
                        property int maxResolution: 1080
                        property bool dimBackground: true
                        property int dimOpacity: 60   // percent (0-100)
                        property string searchSuffix: "official music video"
                        property int videoSamplingInterval: 200 // ms between color sampling updates (100-5000)
                    }
                }
            }

            property JsonObject bar: JsonObject {
                property bool borderless: false
                property bool expressiveGroupColor: false
                property JsonObject clock: JsonObject {
                    property bool showSeconds: true
                    property bool secondaryOpposite: false
                    property bool showPrimary: true
                    property bool showSecondary: true
                    property bool swapPrimaryWithSecondary: false
                }
                property JsonObject styles: JsonObject {
                    property string activeWindow: "default"
                    property string clock: "expressive" // default, expressive, material
                    property string media: "expressive"
                    property string notification: "default"
                    property string utilButtons: "expressive"
                    property string workspaces: "minimal"
                    property string weather: "expressive"
                    property string dashboard: "expressive"
                    property string resources: "expressive"
                    property string policies: "default"
                    property string power: "expressive"
                    property string battery: "expressive"
                    property string systray: "default"
                    property string bluetooth: "expressive"
                    property string keyboard: "expressive"
                    property string sports: "expressive"
                }

                property JsonObject activeWindow: JsonObject {
                    property bool fixedSize: false
                    property int customSize: 225
                    property bool showOnAllMonitors: false
                }

                property JsonObject autoHide: JsonObject {
                    property bool enable: false
                    property int hoverRegionWidth: 2
                    property bool pushWindows: false
                    property JsonObject showWhenPressingSuper: JsonObject {
                        property bool enable: true
                        property int delay: 140
                    }
                }

                property bool bottom: false // Instead of top
                property int cornerStyle: 0 // 0: Hug | 1: Float | 2: Plain rectangle
                property bool floatStyleShadow: true // Show shadow behind bar when cornerStyle == 1 (Float)
                property bool dropShadow: false
                property int dynamicIslandSpacingHorizontal: 48
                property int dynamicIslandSpacingVertical: 16
                property bool dynamicIslandLoadBalance: true

                property JsonObject dynamicIsland: JsonObject {
                    property JsonObject notchMode: JsonObject {
                        property bool enable: false
                        property int expandAnimDuration: 250
                        property int fadeDelay: 0
                        property list<string> visibleWidgets: []
                        property bool overlapApps: false
                    }
                }

                property JsonObject floatingNotch: JsonObject {
                    property bool enable: false
                    property bool autoHide: false
                    property bool dropShadow: false
                    property bool onlyShowOnSingleMonitor: false
                    property string singleMonitorName: ""
                    property bool extraCompact: false

                    // Disables
                    property bool disableWorkspaces: false
                    property bool disableKeyboard: false
                    property bool disableWifi: false
                    property bool disableBluetooth: false
                    property bool disableMedia: false
                    property bool disableNotification: false
                    property bool disableOsd: false
                    property bool disableRecording: false
                    property bool disableTimer: false
                    property bool disableClipboard: false
                    property bool disableLocalSend: false
                    property bool disableKdeConnectInLocalSend: false
                    property bool disableChecklist: true
                    property bool checklistAlwaysVisible: false
                    property bool checklistOnlyExpanded: false
                    property bool disableCalendar: false
                    property bool disableAudio: true
                    property bool disableProgress: false
                    property bool disableBattery: false
                    property bool disableAiStatus: false
                    property bool clickToExpand: false
                    property bool centerInBar: false // "Dynamic Island in bar center" integration mode

                    // Contracted Heights
                    property int heightHome: 36
                    property int heightWorkspaces: 36
                    property int heightKeyboard: 36
                    property int heightWifi: 36
                    property int heightBluetooth: 88
                    property int heightMedia: 52
                    property int heightNotification: 64
                    property int heightRecording: 36
                    property int heightTimer: 36
                    property int heightClipboard: 36
                    property int heightLocalSend: 42
                    property int heightChecklist: 36
                    property int heightCalendar: 48
                    property int heightAudio: 36
                    property int heightProgress: 48
                    property int heightBattery: 36
                    property int heightAiStatus: 36
                }

                property int barGroupStyle: 1 // 0: Pills | 1: Island (opaque) | 2: Transparent (or maybe line-separated in the future)
                property string topLeftIcon: "spark" // Options: "distro" or any icon name in ~/.config/quickshell/ii/assets/icons
                property bool useMaterialSymbolForTopLeftIcon: false
                property int barBackgroundStyle: 1 // 0: Transparent | 1: Visible | 2: Adaptive
                property bool transparentGlow: true
                property bool expressiveColors: false
                property string expressiveColorTheme: "content"
                property bool verbose: true
                property bool vertical: false
                property bool enableVolumeScroll: true
                property bool enableBrightnessScroll: true

                property JsonObject mediaPlayer: JsonObject {
                    property string popupStyle: "default" // "default" | "expressive" | "android"
                    property bool expressivePopup: false
                    property bool useFixedSize: true
                    property int customSize: 200
                    property int maxSize: 400
                    property bool enableVolumeScroll: false
                    property JsonObject artwork: JsonObject {
                        property bool enable: false
                    }
                    property JsonObject lyrics: JsonObject {
                        property bool enable: true
                        property int customSize: 300
                        property string style: "scroller" // Options: scroller, static
                        property bool useGradientMask: true
                    }
                }

                property JsonObject resources: JsonObject {
                    property bool showPercentageText: true
                    property bool alwaysShowRam: true
                    property bool alwaysShowCpu: true
                    property bool alwaysShowCpuTemp: false
                    property bool alwaysShowDisk: false
                    property bool alwaysShowSwap: false
                    property int memoryWarningThreshold: 95
                    property int swapWarningThreshold: 85
                    property int cpuWarningThreshold: 90
                    property bool expressivePopup: true
                    property bool showDocker: false
                }

                property JsonObject sports: JsonObject {
                    property bool enable: true
                    property bool showBRA: true
                    property bool showBUND: false
                    property bool showCL: true
                    property bool showCLA: true
                    property bool showEPL: true
                    property bool showLIGA: true
                    property bool showLIG1: false
                    property bool showSERA: false
                    property bool showUECL: false
                    property bool showUEL: false
                    property bool showWC: true
                    property bool showWWC: false
                    property list<var> monitoredLeagues: [
                        {
                            "sport": "soccer",
                            "league": "bra.1",
                            "name": "Brasileirão",
                            "enabled": true
                        },
                        {
                            "sport": "soccer",
                            "league": "eng.1",
                            "name": "Premier League",
                            "enabled": true
                        },
                        {
                            "sport": "soccer",
                            "league": "uefa.champions",
                            "name": "Champions League",
                            "enabled": true
                        },
                        {
                            "sport": "basketball",
                            "league": "nba",
                            "name": "NBA",
                            "enabled": true
                        },
                        {
                            "sport": "racing",
                            "league": "f1",
                            "name": "Formula 1",
                            "enabled": false
                        }
                    ]
                    property string teamFilter: ""
                    property int updateInterval: 60
                    property int maxCardsPopup: 4
                    property int showBeforeHours: 12
                    property int showAfterMinutes: 180
                    property string activeGameId: ""
                    property list<var> customOrder: []
                }
                property list<string> screenList: [] // List of names, like "eDP-1", find out with 'hyprctl monitors' command
                property bool onlyShowOnSingleMonitor: false
                property string singleMonitorName: ""

                property JsonObject timers: JsonObject {
                    property bool showPomodoro: true
                    property bool showStopwatch: true
                }
                property JsonObject utilButtons: JsonObject {
                    property bool showScreenSnip: false
                    property bool showColorPicker: true
                    property bool showMicToggle: false
                    property bool showKeyboardToggle: false
                    property bool showDarkModeToggle: false
                    property bool showPerformanceProfileToggle: false
                    property bool showScreenRecord: true
                    property bool isRecording: false
                    property bool showWallpaperToggle: true
                }
                property JsonObject workspaces: JsonObject {
                    property bool monochromeIcons: false
                    property int shown: 7
                    property bool showAppIcons: false
                    property bool alwaysShowNumbers: false
                    property int showNumberDelay: 300 // milliseconds
                    property list<string> numberMap: ["1", "2"] // Characters to show instead of numbers on workspace indicator
                    property bool useWorkspaceMap: false
                    property list<var> workspaceMap: [0, 10]
                    property int maxWindowCount: 1 // Maximum windows to show in one workspace
                    property bool useNerdFont: false
                    property int activeIndicatorOpacity: 100 // 0-100
                    property bool dynamicWorkspaces: false
                    property bool useMaterialShapeForActiveIndicator: false
                    property bool useRandomShapeForActiveIndicator: true
                    property string activeIndicatorShape: "Pentagon"
                    property bool dockShowActiveIndicator: true
                    property bool dockShowWindowDots: true
                    property bool dockHoverEffect: true
                    property bool dockShowAppIcons: true
                }
                property JsonObject weather: JsonObject {
                    property bool enable: false
                    property bool enableGPS: true // gps based location
                    property string city: "" // When 'enableGPS' is false
                    property bool useUSCS: false // Instead of metric (SI) units
                    property int fetchInterval: 10 // minutes
                }
                property JsonObject indicators: JsonObject {
                    property JsonObject notifications: JsonObject {
                        property bool showUnreadCount: true
                    }
                    property JsonObject record: JsonObject {
                        property bool minimal: false
                    }
                }
                property JsonObject dashboardButton: JsonObject {
                    property bool showVolume: true
                    property bool showMic: true
                    property bool showNetwork: true
                    property bool showBluetooth: true
                    property bool showVpn: true
                    property bool showTailscale: true
                    property bool showNotifications: true
                }
                property JsonObject layouts: JsonObject {
                    // Only storing id and layout-specific flags (visible, centered)
                    // Component display info (icon, title) comes from BarComponentRegistry
                    property list<var> left: [
                        {
                            centered: false,
                            id: "policies_panel_button",
                            visible: true
                        },
                        {
                            centered: false,
                            id: "workspaces",
                            visible: true
                        },
                        {
                            centered: false,
                            id: "record_indicator",
                            visible: false
                        },
                        {
                            centered: false,
                            id: "timer",
                            visible: false
                        },
                        {
                            centered: false,
                            id: "system_monitor",
                            visible: true
                        }
                    ]
                    property list<var> center: [
                        {
                            centered: false,
                            id: "music_player",
                            visible: true
                        },
                        {
                            centered: true,
                            id: "clock",
                            visible: true
                        },
                        {
                            centered: false,
                            id: "weather",
                            visible: true
                        },
                        {
                            centered: false,
                            id: "utility_buttons",
                            visible: true
                        }
                    ]
                    property list<var> right: [
                        {
                            centered: false,
                            id: "system_tray",
                            visible: true
                        },
                        {
                            centered: false,
                            id: "keyboard_layout",
                            visible: true
                        },
                        {
                            centered: false,
                            id: "bluetooth_devices",
                            visible: true
                        },
                        {
                            centered: false,
                            id: "battery",
                            visible: true
                        },
                        {
                            centered: false,
                            id: "dashboard_panel_button",
                            visible: true
                        },
                        {
                            centered: false,
                            id: "power",
                            visible: true
                        }
                    ]
                }
                property JsonObject tooltips: JsonObject {
                    property bool clickToShow: false
                    property bool compactPopups: false
                    property real popupScaleMultiplier: 1.0
                    property int closeDelay: 50
                    property bool enableColorPickerPopup: true
                    property bool enableBluetoothConnectionPopup: true
                    property bool enableKeyboardLayoutTransitionPopup: true
                }
                property JsonObject keyboardLayout: JsonObject {
                    property bool secondaryOpposite: false
                    property bool showSecondary: true
                    property bool showPrimary: true
                    property bool swapPrimaryWithSecondary: false
                    property bool uppercaseLayout: false
                }
                property JsonObject battery: JsonObject {
                    property bool secondaryOpposite: true
                    property bool showPrimary: true
                    property bool showSecondary: true
                    property bool swapPrimaryWithSecondary: false
                    property bool showPercentageInsideBattery: false
                    property string showPercentage: "off"
                }
                property string bluetoothDevicesLayout: "expressive" // Options: classic, expressive
                property JsonObject sizes: JsonObject {
                    property int height: 40 // horizontal mode
                    property int width: 45 // vertical mode
                }
            }

            property JsonObject battery: JsonObject {
                property string style: "android16"
                property string showPercentage: "off"
                property int low: 20
                property int critical: 5
                property int full: 101
                property bool automaticSuspend: true
                property int suspend: 3
            }

            property JsonObject calendar: JsonObject {
                property string locale: "en-GB"
            }

            property JsonObject cheatsheet: JsonObject {
                // Use a nerdfont to see the icons
                // 0: 󰖳  | 1: 󰌽 | 2: 󰘳 | 3:  | 4: 󰨡
                // 5:  | 6:  | 7: 󰣇 | 8:  | 9: 
                // 10:  | 11:  | 12:  | 13:  | 14: 󱄛
                property string superKey: ""
                property bool useMacSymbol: false
                property bool splitButtons: false
                property bool useMouseSymbol: false
                property bool useFnSymbol: false
                property bool filterUnbinds: true
                property bool enableGmail: true
                property bool enableTimetable: true
                property bool timetableTodayFirst: false
                property bool enablePeriodicTable: false
                property bool enableAminoAcids: false
                // "five" | "seven" | "four" — side chain classification scheme
                property string aminoAcidScheme: "seven"
                property bool enableCommands: true
                property bool commandsTagsSidebar: false
                property bool enableWorkspaceProfiles: false
                property JsonObject fontSize: JsonObject {
                    property int key: Appearance.font.pixelSize.smaller
                    property int comment: Appearance.font.pixelSize.smaller
                }
            }

            property JsonObject conflictKiller: JsonObject {
                property bool autoKillNotificationDaemons: false
                property bool autoKillTrays: false
            }

            property JsonObject crosshair: JsonObject {
                // Valorant crosshair format. Use https://www.vcrdb.net/builder
                property string code: "0;P;d;1;0l;10;0o;2;1b;0"
            }

            property JsonObject dock: JsonObject {
                property bool enable: true
                property bool smartGrouping: false
                property bool isolateMonitors: false
                property bool showOnlyOnFocusedMonitor: false
                property bool monochromeIcons: false
                property bool dimInactiveIcons: false
                property real iconSpacing: 2
                property real dockRadius: -1
                property real widgetRadius: -1
                property bool enableMagnification: false
                property real magnificationScale: 1.5
                property bool enableShapeMask: false
                property string shapeMask: "Circle"
                property real height: 60
                property real hoverRegionHeight: 2
                property bool pinnedOnStartup: false
                property bool enablePreview: true
                property bool enableAppTooltip: false
                property bool hoverToReveal: true
                property bool enableMediaWidget: true
                property bool enableWeatherWidget: true
                property bool showDividers: true
                property bool showOverviewButton: true
                property bool showPinButton: true
                property bool showTrashButton: true
                property bool showNotificationBadges: true
                property string position: "auto"
                property list<string> pinnedApps: ["org.kde.dolphin", "kitty",]
                property list<string> ignoredAppRegexes: []
                property list<string> pinnedFiles: []
                property list<string> order: ["pin", "app:org.kde.dolphin", "app:kitty", "runningApps", "media", "weather", "trash", "overview"]
            }

            property JsonObject dockToPanel: JsonObject {
                property int iconSize: 25
                property int buttonSpacing: 2
                property bool enableWorkspaceScroll: false
                property bool alignToWorkspace: false
                property bool enableTooltip: false
                property bool enablePreview: false
                property bool enableMacOsMagnification: false
                property real macOsMagnificationScale: 1.6
                property bool isolateMonitors: false
            }

            property JsonObject hyprland: JsonObject {
                property string defaultHyprlandLayout: "dwindle" // Options: dwindle, monocle, master // It's best to not use scrolling
            }

            property JsonObject idle: JsonObject {
                // How long the "Keep awake" inhibitor should survive:
                // "never" (always off at startup), "session" (until logout/reboot), "always"
                property string persistInhibit: "session"
            }

            property JsonObject interactions: JsonObject {
                property JsonObject scrolling: JsonObject {
                    property bool fasterTouchpadScroll: false // Enable faster scrolling with touchpad
                    property int mouseScrollDeltaThreshold: 120 // delta >= this then it gets detected as mouse scroll rather than touchpad
                    property int mouseScrollFactor: 120
                    property int touchpadScrollFactor: 450
                }
                property JsonObject deadPixelWorkaround: JsonObject { // Hyprland leaves out 1 pixel on the right for interactions
                    property bool enable: false
                }
            }

            property JsonObject language: JsonObject {
                property string ui: "en_US" // UI language. "auto" for system locale, or specific language code like "zh_CN", "en_US"
                property JsonObject translator: JsonObject {
                    property string engine: "auto" // Run `trans -list-engines` for available engines. auto should use google
                    property string targetLanguage: "auto" // Run `trans -list-all` for available languages
                    property string sourceLanguage: "auto"
                    property string defaultTargetLanguage: "auto"
                    property string defaultSourceLanguage: "auto"
                }
            }

            property JsonObject userProfile: JsonObject {
                property string imageStyle: "initial" // "initial", "expressive", "custom"
                property string imagePath: Directories.userProfileImagePath
                property string customName: ""
                property string customGreeting: ""
                property string customBio: ""
                property string avatarShape: "Cookie9Sided"
                property string avatarColor: "primary"
            }

            property JsonObject launcher: JsonObject {
                property list<string> pinnedApps: ["org.kde.dolphin", "kitty", "cmake-gui"]
            }

            property JsonObject light: JsonObject {
                property JsonObject darkMode: JsonObject {
                    property bool automatic: false
                    property string from: "18:00" // Format: "HH:mm", 24-hour time
                    property string to: "06:00"   // Format: "HH:mm", 24-hour time
                }
                property JsonObject night: JsonObject {
                    property bool automatic: true
                    property string from: "19:00" // Format: "HH:mm", 24-hour time
                    property string to: "06:30"   // Format: "HH:mm", 24-hour time
                    property int colorTemperature: 5000
                    // How long a manual Night Light toggle (and the gamma level) should survive:
                    // "never" (always off at startup), "session" (until logout/reboot), "always".
                    // With automatic mode on, a restored toggle still expires at the next start/end time.
                    property string persistManual: "always"
                }
                property JsonObject antiFlashbang: JsonObject {
                    property bool enable: false
                }
                property JsonObject keyboardBacklight: JsonObject {
                    // Switch the keyboard backlight off after a period without keyboard
                    // or pointer input, then restore the previous level on the next input.
                    // Off by default: it changes hardware state without being asked to.
                    property bool autoOff: false
                    property int timeout: 15 // Seconds of no input
                }
            }

            property JsonObject lock: JsonObject {
                property bool useHyprlock: false
                property bool launchOnStartup: false
                property JsonObject blur: JsonObject {
                    property bool enable: true
                    property real radius: 100
                    property real extraZoom: 1.1
                }
                property JsonObject desaturate: JsonObject {
                    property bool enable: false
                    property real amount: 1.0
                }
                property JsonObject colorWash: JsonObject {
                    property bool enable: false
                    property real amount: 0.5
                }
                property JsonObject vignette: JsonObject {
                    property bool enable: false
                    property real amount: 0.7
                }

                property real centerSpacing: 20 // spacing between multiple centered widgets
                property string centerAlignment: "horizontal" // "vertical" | "horizontal"
                property bool showLockedText: true
                property JsonObject security: JsonObject {
                    property bool unlockKeyring: true
                    property bool requirePasswordToPower: false
                }
                property bool materialShapeChars: true
                property bool rippleEffect: true
                property bool nowPlaying: true
                property bool showAlarm: true
                property bool showWeather: true
                property JsonObject zoomAnimation: JsonObject {
                    property bool enabled: true
                }
                property JsonObject notifications: JsonObject {
                    property bool enable: false // Off by default: showing notifications on the lock screen is a privacy trade-off
                    property string position: "top_right" // "top_left" | "top_right" | "bottom_left" | "bottom_right"
                    property string privacy: "redacted" // "full" | "redacted" | "countOnly"
                    property bool onlySinceLock: true // Only show notifications that arrived while locked
                    property int maxShown: 5
                    property int zoomPercent: 100 // 50-200, step 10
                    property string defaultPolicy: "show" // "show" | "hide" — apps without an explicit rule
                    property list<string> alwaysShowApps: [] // App names, case-insensitive match
                    property list<string> neverShowApps: []
                    property JsonObject filters: JsonObject {
                        property bool skipTransient: true
                        property bool skipLowUrgency: false
                        property string criticalOverride: "full" // "full" | "none" — critical notifications bypass privacy redaction
                    }
                }
            }

            property JsonObject media: JsonObject {
                property bool filterDuplicatePlayers: true
                property string priorityPlayer: ""
                property bool dynamicAlbumColors: true
            }

            property JsonObject networking: JsonObject {
                property string userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            }

            property JsonObject notifications: JsonObject {
                property int timeout: 7000
                property string position: "top_right"
                property int zoomPercent: 100 // 50-200, step 10
                property bool autoDndFullscreen: true
                property JsonObject monitor: JsonObject {
                    property bool enable: false
                    property string name: "" // Name of the monitor to show notifications on, like "eDP-1". Find out with 'hyprctl monitors' command
                }
            }

            property JsonObject oledSaver: JsonObject {
                property int cursorHideDelay: 5 // seconds of no mouse movement before the cursor hides again
                property int hintExtraDelay: 10 // extra seconds the dismiss hint stays visible after the cursor hides
            }

            property JsonObject osd: JsonObject {
                property bool enable: true
                property string style: "default"
                property string position: "right"
                property int height: 500
                property int timeout: 3000
                property bool showValues: true
            }

            property JsonObject osk: JsonObject {
                // "deck" is the full-bleed keyboard, "classic" the original floating one.
                property string style: "deck"
                // "auto" follows whatever layout Hyprland reports; any other value pins a
                // layout by name ("French", "German", ...).
                property string layout: "auto"
                // Share of the screen height the deck takes. Key size falls out of it, so this
                // is the only size control the deck needs.
                property int heightPercent: 35
                // The small shift and AltGr glyphs in the corners of a deck key.
                property bool secondaryGlyphs: true
                property bool pinnedOnStartup: false

                // Raises the keyboard when a text field is focused by finger or pen.
                // Requires the osk_autoshow helper (see scripts/osk/README.md).
                property JsonObject autoShow: JsonObject {
                    property bool enable: false
                    property bool allowTouch: true
                    property bool allowPen: true
                    // How long after a touch a text field may claim focus and still count as touch-driven.
                    property int touchWindowMs: 1200
                    property bool hideOnPhysicalKey: true
                    property bool hideOnTouchOutside: true
                }
            }

            property JsonObject overlay: JsonObject {
                property bool openingZoomAnimation: true
                property bool darkenScreen: true
                property real clickthroughOpacity: 0.8
                property list<string> buttons: ["crosshair", "recorder", "media", "volumeMixer", "resources", "discordVoice"]
                property JsonObject floatingImage: JsonObject {
                    property string imageSource: "https://media.tenor.com/H5U5bJzj3oAAAAAi/kukuru.gif"
                    property real scale: 0.5
                }
                property JsonObject notes: JsonObject {
                    property bool showTabs: true
                    property bool allowEditingIcon: true
                }
                property JsonObject media: JsonObject {
                    property int backgroundOpacityPercentage: 100
                    property bool useGradientMask: true
                    property bool showSlider: true
                    property int lyricSize: Appearance.font.pixelSize.larger
                }
                property JsonObject discordVoice: JsonObject {
                    property int maxAvatars: 8
                    property int avatarSize: 52
                    property string participantBackground: "name"
                    property real participantBackgroundOpacity: 0.72
                    property string layoutMode: "column"
                    property bool blurEnabled: true
                    property bool autoResize: true
                    property bool speakingPulseContinuous: true
                }
            }

            property JsonObject overview: JsonObject {
                property bool enable: true
                property bool showWindowPreviews: true
                property bool enableManualScale: false
                property real autoScaleFactor: 1.0 // Multiplier for automatic scaling (0.5 to 1.5)
                property real scale: 0.18 // Relative to screen size (used when enableManualScale is true)
                property string animationStyle: "bounce" // Options: "bounce", "smooth", "zoom"
                property bool enableCascadeAnimation: true
                property real rows: 2
                property real columns: 5
                property bool orderRightLeft: false
                property bool orderBottomUp: false
                property bool showIcons: true
                property bool centerIcons: true
                property bool showOpeningAnimation: true
                property bool useWorkspaceMap: false

                property JsonObject scrollingStyle: JsonObject {

                    property int dimPercentage: 50 // 0-75
                    property string backgroundStyle: "blur" // Options: transparent, blur, dim
                    property string zoomStyle: "out"        // Options: in, out
                }
            }

            property JsonObject regionSelector: JsonObject {
                property bool showOnlyOnFocusedMonitor: false
                property bool enableOverlay: true
                // Shows a system notification when a screenshot is copied to the clipboard (default off).
                property bool copyNotification: false
                property JsonObject targetRegions: JsonObject {
                    property bool windows: true
                    property bool layers: true
                    property bool content: true
                    property bool showLabel: false
                    property real opacity: 0.3
                    property real contentRegionOpacity: 0.8
                    property int selectionPadding: 5
                }
                property JsonObject rect: JsonObject {
                    property bool showAimLines: false
                }
                property JsonObject circle: JsonObject {
                    property int strokeWidth: 6
                    property int padding: 10
                }
                property JsonObject annotation: JsonObject {
                    property bool useSatty: false
                    property bool enableInlineEditor: true
                    property real fillOpacity: 0.25
                    property real highlighterOpacity: 0.4
                    property int badgeStartNumber: 1
                    // Pixelation coarseness for the blur tool (source-px divisor):
                    // bigger = chunkier blocks. Independent of line thickness.
                    property int blurStrength: 24
                }
            }

            property JsonObject resources: JsonObject {
                property int updateInterval: 3000
                property int historyLength: 60
                // New keys (zero-cost on AMD; only NVIDIA/Intel invoke nvidia-smi one-shot)
                property int diskInterval: 30000
                property int gpuInterval: 3000
                // Which GPU to monitor on hybrid iGPU+dGPU systems.
                // "auto" (NVIDIA → AMD → Intel priority) | "nvidia" | "amd" | "intel"
                property string gpuPreference: "auto"
                // Mount point / path to monitor with df for disk usage.
                // Default: "/" (root filesystem). Change to e.g. "/home" or "/mnt/data".
                property string diskMount: "/"
                // Toggle for Docker section popup. When false, all Docker
                // polls (docker stats, docker ps) are suppressed and the
                // events stream is not subscribed.
                property bool enableDocker: true
            }

            property JsonObject lyricsService: JsonObject {
                property bool enable: true
                property bool enableGenius: true
                property bool enableLrclib: true
                property bool enableYtmusic: false  // requires ytmusicapi in venv
                // "auto" | "lrclib" | "ytmusic" | "genius"
                // auto = lrclib synced → lrclib plain → ytmusic → genius
                property string lyricsProvider: "auto"
            }

            property JsonObject tray: JsonObject {
                property bool monochromeIcons: true
                property bool showItemId: false
                property bool invertPinnedItems: true // Makes the below a whitelist for the tray and blacklist for the pinned area
                property list<var> pinnedItems: ["Fcitx"]
                property bool filterPassive: false
            }

            // Settings app memory management. After the user closes the
            // settings window, we wait `unloadAfterSeconds` and then drop
            // the SettingsWindow component from memory. The next open
            // rebuilds it (one-time cold-boot cost). Set to 0 to keep it
            // permanently warm (old behavior, ~70 MB of resident QML).
            property JsonObject settingsApp: JsonObject {
                property int unloadAfterSeconds: 300
            }

            property JsonObject update: JsonObject {
                property string scriptPath: ""
                property string scriptFlags: "--no-backup --no-confirm"
            }

            property JsonObject musicRecognition: JsonObject {
                property int timeout: 16
                property int interval: 4
            }

            property JsonObject search: JsonObject {
                property bool enableSystemControls: true
                property bool enableMathPreview: true
                property bool alwaysListApps: false
                property int nonAppResultDelay: 30
                property string engineBaseUrl: "https://www.google.com/search?q="
                property list<string> excludedSites: ["quora.com", "facebook.com"]
                property bool sloppy: false
                property bool levenshtein: false
                property bool frecency: false
                property list<var> aliases: []
                property string fileSearchDirectory: "/home"
                property bool blurFileSearchResultPreviews: false
                property JsonObject prefix: JsonObject {
                    property bool showDefaultActionsWithoutPrefix: true
                    property string action: "/"
                    property string app: ">"
                    property string bluetooth: "&"
                    property string clipboard: ";"
                    property string fileSearch: ","
                    property string emojis: ":"
                    property string math: "="
                    property string shellCommand: "$"
                    property string webSearch: "?"
                    property string windowSearch: "#"
                    property string fileBrowser: "~"
                    property string translator: "@"
                    property string mediaDownloader: "!"
                    property string materialSymbols: "*"
                }
                property JsonObject imageSearch: JsonObject {
                    property string imageSearchEngineBaseUrl: "https://lens.google.com/uploadbyurl?url="
                    property bool useCircleSelection: true
                }
                property JsonObject clipboard: JsonObject {
                    property int panelWidth: 860
                    property real listColumnRatio: 0.40
                    property bool showMetadata: true
                    property int imageHeight: 200
                    property int previewFontSize: 12
                    property bool enableSloppySearch: false
                    property JsonObject detectors: JsonObject {
                        property bool hexColor: true
                        property bool url: true
                        property bool email: true
                        property bool phone: true
                        property bool json: true
                        property bool filePath: true
                        property bool markdown: true
                        property bool number: true
                        property bool multiline: true
                    }
                }
                property bool showNowPlayingBubble: false
                property string connectStyle: "connect"  // Search rendered as embedded drop in Connect Mode
                property int baseWidth: 500
                property int baseHeight: 500
                property string positionStyle: "default"
                property real centerVerticalRatio: 0.38
                property JsonObject suggestions: JsonObject {
                    property bool enable: false
                    property int maxSuggestionsPerSection: 5
                    property bool showFrecency: true
                    property bool showCommands: false
                    property bool showApps: true
                    property bool showAliases: true
                }
            }

            property JsonObject mediaDownloader: JsonObject {
                property bool enabled: true
                property string downloadPath: FileUtils.trimFileProtocol(`${Directories.home}/Downloads`)
                property int maxConcurrent: 2
                property string defaultFormat: "best"
                property bool embedMetadata: true
                property bool writeThumbnail: false
                property bool addChapters: true
                property string proxy: ""
                property int rateLimit: 0
                property bool throttleBypass: false
                property bool useAria2c: false
                property string extraArgs: ""
                property bool keepHistory: false
                property string lastUsedFormat: "best"
                property string videoResolution: "best"
                property string videoCodec: "any"
                property int audioBitrate: 0
                property string audioCodec: "any"
                property string lastUsedResolution: "best"
                property bool showAdvancedArgs: false
            }

            property JsonObject sidebar: JsonObject {
                property JsonObject dashboardHeader: JsonObject {
                    // "custom" was never a value SidebarDashboardContent.qml checks for —
                    // it only branches on "user_profile" | "distro" | "none" (falling through
                    // to nothing rendered otherwise). The real default renders the profile
                    // picture/uptime row, so this now matches "user_profile".
                    property string profileImageType: "user_profile" // "user_profile", "distro", "none"
                    property string profileImagePath: Directories.userProfileImagePath
                    property string textMode: "username" // "username", "uptime", "none", "custom"
                    property string customText: ""
                }
                property string position: "default"
                property string sidebarStyle: "connect" // "default" | "connect"
                property bool keepRightSidebarLoaded: true
                property bool volumeDialogMediaWidget: true
                property JsonObject translator: JsonObject {
                    property bool enable: false
                    property int delay: 300 // Delay before sending request. Reduces (potential) rate limits and lag.
                }
                property JsonObject ai: JsonObject {
                    property bool textFadeIn: false
                    property bool showProviderAndModelButtons: true
                    // When false, the Ai service never spawns its index
                    // probe at boot (saves one Python fork + ollama
                    // listing). The panel itself still loads on demand
                    // via policies.ai; this only gates the proactive
                    // model listing.
                    property bool enable: true
                }
                property JsonObject booru: JsonObject {
                    property bool allowNsfw: false
                    property string defaultProvider: "yandere"
                    property int limit: 20
                    property JsonObject zerochan: JsonObject {
                        property string username: "[unset]"
                    }
                }
                property JsonObject cornerOpen: JsonObject {
                    property bool enable: false
                    property bool bottom: false
                    property bool valueScroll: true
                    property bool clickless: false
                    property int cornerRegionWidth: 250
                    property int cornerRegionHeight: 5
                    property bool visualize: false
                    property bool clicklessCornerEnd: true
                    property int clicklessCornerVerticalOffset: 1
                }

                property JsonObject quickToggles: JsonObject {
                    property string style: "android" // Options: classic, android
                    property bool useThreeWaySliders: true
                    property JsonObject android: JsonObject {
                        property int columns: 5
                        property list<var> pages: [[
                                {
                                    "size": 2,
                                    "type": "network"
                                },
                                {
                                    "size": 1,
                                    "type": "idleInhibitor"
                                },
                                {
                                    "size": 2,
                                    "type": "darkMode"
                                },
                                {
                                    "size": 1,
                                    "type": "mic"
                                },
                                {
                                    "size": 2,
                                    "type": "audio"
                                },
                                {
                                    "size": 2,
                                    "type": "nightLight"
                                },
                                {
                                    "size": 1,
                                    "type": "soundcoreAnc"
                                },
                                {
                                    "size": 1,
                                    "type": "autoDnd"
                                }
                            ]]
                    }
                }

                property JsonObject quickSliders: JsonObject {
                    property bool enable: true
                    property bool vertical: false
                    property bool showMic: true
                    property bool showGamma: true
                    property bool showVolume: true
                    property bool showBrightness: false // gamma setting also works for brightness
                }
            }

            property JsonObject screenRecord: JsonObject {
                property string savePath: Directories.videos.replace("file://", "") // strip "file://"
                property string service: "wf-recorder"
                property bool useGpu: true
                property string codec: "auto"
                property int bitrate: 8
                property int framerate: 60
                property bool showNotifications: true
            }

            property JsonObject screenSnip: JsonObject {
                property string savePath: "" // only copy to clipboard when empty
            }

            property JsonObject sounds: JsonObject {
                property bool enable: true
                property string theme: "freedesktop"
                property bool monoAudio: false

                property bool notifications: true
                property bool volumeChange: true
                property bool battery: false
                property bool screenshot: true
                property bool pomodoro: false
                property bool alarm: true
                property bool session: false
                property bool devices: true
                property bool lock: false

                property bool alarmFadeIn: false

                property string notificationDefaultPolicy: "play" // "play" | "mute"
                property list<string> alwaysPlayApps: []
                property list<string> neverPlayApps: []
                property JsonObject custom: JsonObject {
                    property string notifications: ""
                    property string volumeChange: ""
                    property string battery: ""
                    property string screenshot: ""
                    property string pomodoro: ""
                    property string alarm: ""
                    property string session: ""
                    property string devices: ""
                    property string lock: ""
                }
            }

            property JsonObject soundcore: JsonObject {
                property string macAddress: ""
                property string model: "SoundcoreA3028"
            }

            // Window tiling assistant: zone overlay while a window is dragged,
            // quick-tile on drop. Zones are stored as fractions of the usable
            // monitor area, so a layout survives resolution and scale changes.
            property JsonObject tiling: JsonObject {
                property bool enable: false
                // "quickTile": float the window and set exact geometry on drop
                // "preview": only draw the overlay, never touch the window
                // "hybrid": quick-tile floating windows, preview-only for
                //           windows currently in the Hyprland layout tree
                property string mode: "quickTile"
                // Off means the overlay only appears for keyboard quick-tile.
                property bool showOnDragStart: true
                // Restore pre-tile geometry and float state when a tiled window
                // is dragged back out of its zone.
                property bool restoreOnUntile: true
                // Super + Alt + arrow moves the focused window zone by zone, and
                // untiles it when it is already against that side of the screen.
                property bool keyboardQuickTile: true

                property JsonObject detection: JsonObject {
                    // Companion Hyprland binds on the drag/resize mouse combos.
                    // The only way a drag is detected: client-side titlebar
                    // drags fire no bind, and inferring them from window motion
                    // was dropped because nothing reports the button coming up.
                    property bool useKeybinds: true
                    // How often the active window is sampled between gestures.
                    // Only used to keep a pre-drag geometry worth restoring to,
                    // so there is nothing to gain by doing it often.
                    property int idleHz: 5
                    property int activeHz: 90
                    // How far the window has to move before a drag counts as
                    // having left the place Hyprland would put it back to.
                    property int trackingTolerancePx: 2
                }

                property JsonObject coResize: JsonObject {
                    property bool enable: true
                    // How near a shared edge a resize has to land to pull its
                    // neighbours along.
                    property int edgeTolerancePx: 8
                    // Tiling one window takes the whole workspace with it:
                    // every other window on it is floated and given a zone, so
                    // they all share edges and one divider drag moves the lot.
                    // Off by default - it hands the workspace over wholesale
                    // and leaves Hyprland's own layout with nothing to tile.
                    property bool adoptWorkspace: false
                    // The reverse: untiling one window hands the whole
                    // workspace back, every window the assistant placed on it
                    // returning to where it was. Closing a window is not
                    // untiling it - what it leaves behind is still the
                    // arrangement that was asked for.
                    property bool releaseWorkspace: false
                }

                property JsonObject overlay: JsonObject {
                    property real zoneOpacity: 0.28
                    property real hoveredOpacity: 0.55
                    property int cornerRadius: 12
                    property bool showLabels: true
                    property int fadeDuration: 150
                    // How long the strip of layout names stays up after the
                    // layout is cycled.
                    property int layoutHintDuration: 1400
                    // How long the zones are shown after a keyboard
                    // quick-tile, which has no drag to show them during. Long
                    // enough to see where the window landed, short enough that
                    // arrowing a window across the screen is not one continuous
                    // flash.
                    property int quickTileDuration: 500
                    // Marks a zone holding more than one window while nothing is
                    // being dragged. Windows stacked in a zone are otherwise
                    // indistinguishable from one window sitting there.
                    property bool stackIndicator: true
                }

                property JsonObject gaps: JsonObject {
                    // Read gaps_in / gaps_out from Hyprland instead of the
                    // values below.
                    property bool followHyprland: true
                    property int outer: 8
                    property int inner: 4
                }

                // Preset id used by any monitor without an entry below.
                property string defaultPreset: "kde"
                // Per-monitor layouts. Each entry looks like:
                //   { name: "DP-1", preset: "custom", gapsOverride: null,
                //     zones: [{ x, y, w, h, label }] }
                // where x/y/w/h are 0..1 fractions of the usable area.
                property list<var> monitors: []
            }

            property JsonObject time: JsonObject {
                // https://doc.qt.io/qt-6/qtime.html#toString
                property string format: "hh:mm"
                property string secondsFormat: "ss"
                property string shortDateFormat: "dd/MM"
                property string longDateFormat: "dd/MM/yyyy"
                property string dateWithYearFormat: "dd/MM/yyyy"
                property string dateFormat: "dd/MM, ddd"
                property int firstDayOfWeek: 6 // 0: Monday, 1: Tuesday, 2: Wednesday, 3: Thursday, 4: Friday, 5: Saturday, 6: Sunday

                property JsonObject pomodoro: JsonObject {
                    property int breakTime: 300
                    property int cyclesBeforeLongBreak: 4
                    property int focus: 1500
                    property int longBreak: 900
                }
                property list<var> worldClocks: []
                property bool secondPrecision: true

                property JsonObject alarms: JsonObject {
                    property bool useFullscreenPopup: false
                    property bool showAnalogClock: true
                    property bool showWorldClocks: true
                    property bool showAlarmsSection: true
                }
            }

            property JsonObject updates: JsonObject {
                property bool enableCheck: true
                property int checkInterval: 120 // minutes
                property int adviseUpdateThreshold: 75 // packages
                property int stronglyAdviseUpdateThreshold: 200 // packages
            }

            property JsonObject wallpaperSelector: JsonObject {
                property bool useSystemFileDialog: false
                property list<var> directories: []
                property bool useCustomDefaultPath: false
                property string customDefaultPath: FileUtils.trimFileProtocol(`${Directories.pictures}/Wallpapers`)
            }

            property JsonObject windows: JsonObject {
                property bool showTitlebar: true // Client-side decoration for shell apps
                property bool centerTitle: true
            }

            property JsonObject hacks: JsonObject {
                property int arbitraryRaceConditionDelay: 20 // milliseconds
            }

            property JsonObject workSafety: JsonObject {
                property JsonObject enable: JsonObject {
                    property bool wallpaper: false
                    property bool clipboard: false
                }
                property JsonObject triggerCondition: JsonObject {
                    property list<string> networkNameKeywords: ["airport", "cafe", "college", "company", "eduroam", "free", "guest", "public", "school", "university"]
                    property list<string> fileKeywords: ["anime", "booru", "ecchi", "hentai", "yande.re", "konachan", "breast", "nipples", "pussy", "nsfw", "spoiler", "girl"]
                    property list<string> linkKeywords: ["hentai", "porn", "sukebei", "hitomi.la", "rule34", "gelbooru", "fanbox", "dlsite"]
                }
            }

            property JsonObject wallpapers: JsonObject {
                property string service: "wallhaven" // "unsplash" or "wallhaven"
                property string sort: "favourites"
                property bool showAnimeResults: false // only for wallhaven service
                property JsonObject paths: JsonObject {
                    property string download: FileUtils.trimFileProtocol(`${Directories.home}/Pictures/Wallpapers`)
                    property string nsfw: FileUtils.trimFileProtocol(`${Directories.home}/Pictures/Wallpapers/NSFW`)
                }
            }

            property JsonObject waffles: JsonObject {
                // Some spots are kinda janky/awkward. Setting the following to
                // false will make (some) stuff also be like that for accuracy.
                // Example: the right-click menu of the Start button
                property JsonObject tweaks: JsonObject {
                    property bool switchHandlePositionFix: true
                    property bool smootherMenuAnimations: true
                    property bool smootherSearchBar: true
                }
                property JsonObject bar: JsonObject {
                    property bool bottom: true
                    property bool leftAlignApps: false
                }
                property JsonObject actionCenter: JsonObject {
                    property list<string> toggles: ["network", "bluetooth", "easyEffects", "powerProfile", "idleInhibitor", "nightLight", "darkMode", "antiFlashbang", "cloudflareWarp", "mic", "musicRecognition", "notifications", "onScreenKeyboard", "gameMode", "screenSnip", "colorPicker", "videoEditor"]
                }
                property JsonObject calendar: JsonObject {
                    property bool force2CharDayOfWeek: true
                }
            }
        }
    }
}
