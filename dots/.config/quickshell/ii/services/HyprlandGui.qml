pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.modules.common
import qs.modules.common.functions

/**
 * Backing store for Settings -> Hyprland.
 *
 * Owns the `quickshell:managed` region at the end of each ~/.config/hypr/custom/*.lua file,
 * through `scripts/hyprland/hyprgui.py`. Reads three layers for every key and keeps them apart:
 *
 *   effective  - what Hyprland is actually doing, from a batched `hyprctl getoption`
 *   managed    - what this page put in the region
 *   inherited  - what hand-written Lua above the region, or another custom file, set
 *
 * A fourth layer sits above all of them: hyprland/shellOverrides/main.lua loads last, so Modes,
 * Game Mode and the screen shader shadow anything set here. Those keys are reported, not hidden.
 */
Singleton {
    id: root

    readonly property string scriptPath: Quickshell.shellPath("scripts/hyprland/hyprgui.py")
    readonly property string customDir: FileUtils.trimFileProtocol(`${Directories.config}/hypr/custom`)
    readonly property string shellOverridesPath: FileUtils.trimFileProtocol(
        `${Directories.config}/hypr/hyprland/shellOverrides/main.lua`)

    /// Which custom file each kind of entry belongs in. Order matches hyprland.lua's require order.
    readonly property var targetFiles: ({
        general: `${root.customDir}/general.lua`,
        rules: `${root.customDir}/rules.lua`,
        keybinds: `${root.customDir}/keybinds.lua`,
        env: `${root.customDir}/env.lua`,
        variables: `${root.customDir}/variables.lua`
    })
    /// The order hyprland.lua requires these files in. Later wins, so the maps below build in
    /// this order and let a later file overwrite an earlier one. variables.lua is the odd one:
    /// hyprland.lua never requires it, hyprland/keybinds.lua does, at its very top - which is
    /// exactly why the app names it holds still reach every bind built below them.
    readonly property var loadOrder: ["env", "variables", "general", "rules", "keybinds"]
    readonly property var targetForKind: ({
        config: "general",
        device: "general",
        windowrule: "rules",
        layerrule: "rules",
        workspacerule: "rules",
        bind: "keybinds",
        unbind: "keybinds",
        env: "env",
        global: "variables"
    })

    /// Keys Appearance.qml re-pushes with `hyprctl eval` after every reload. A file can't win
    /// against that, so the hub shows them read-only and points at the page that really owns them.
    readonly property var shellOwnedKeys: ({
        "general:gaps_in": "windows",
        "general:gaps_out": "windows",
        "general:border_size": "windows",
        "general:col.active_border": "appearance",
        "group:col.border_active": "appearance",
        "group:groupbar:col.active": "appearance",
        "decoration:rounding": "windows",
        "decoration:blur:size": "windows"
    })

    property bool ready: false
    property bool busy: false
    /// target name -> the `hyprgui.py read` result for that file
    property var files: ({})
    /// key -> { value, type, set } from hyprctl
    property var effective: ({})
    /// key -> { value, line } set by shellOverrides/main.lua, which loads after us
    property var shadowed: ({})
    /// Keys whose effective value the hub asks hyprctl about. Tabs add to this as they load.
    property var watchedKeys: []
    property bool dirty: false
    property string lastError: ""
    /// Pages hold a subscription while they are on screen. The service re-reads after every
    /// Hyprland reload only while something is looking at it, instead of forever.
    property int subscribers: 0

    /// key -> value, for every config key this page manages. One pass per change instead of
    /// one pass per control per change.
    readonly property var managedConfig: {
        const map = {};
        for (const target of root.loadOrder)
            for (const entry of root._entriesFor(target))
                if (entry.kind === "config" && entry.key) map[entry.key] = entry.value;
        return map;
    }

    /// key -> { value, file, line, target, removable } for the last hand-written line that sets
    /// it. `removable` is false when the parser could not pin the assignment down, in which case
    /// the page offers no cleanup for it.
    readonly property var inheritedConfig: {
        const map = {};
        for (const target of root.loadOrder) {
            const file = root.files[target];
            if (!file) continue;
            for (const entry of (file.unmanaged ?? [])) {
                if (entry.kind !== "config" || !entry.key) continue;
                map[entry.key] = {
                    value: entry.value,
                    line: entry.line ?? 0,
                    target: target,
                    file: String(file.file ?? "").split("/").pop(),
                    removable: (entry.span ?? null) !== null
                };
            }
        }
        return map;
    }

    /// global name -> the value this page wrote for it.
    readonly property var managedGlobals: {
        const map = {};
        for (const target of root.loadOrder)
            for (const entry of root._entriesFor(target))
                if (entry.kind === "global" && entry.name) map[entry.name] = entry.value;
        return map;
    }

    /// global name -> { value, file, line } for the last hand-written assignment of it.
    readonly property var inheritedGlobals: {
        const map = {};
        for (const target of root.loadOrder) {
            const file = root.files[target];
            if (!file) continue;
            for (const entry of (file.unmanaged ?? [])) {
                if (entry.kind !== "global" || !entry.name) continue;
                map[entry.name] = {
                    value: entry.value,
                    line: entry.line ?? 0,
                    target: target,
                    file: String(file.file ?? "").split("/").pop()
                };
            }
        }
        return map;
    }

    /// env name -> the value this page wrote for it.
    readonly property var managedEnv: {
        const map = {};
        for (const target of root.loadOrder)
            for (const entry of root._entriesFor(target))
                if (entry.kind === "env" && entry.name) map[entry.name] = entry.value;
        return map;
    }

    /// env name -> { value, file, line } for the last hand-written hl.env above the region.
    /// Only custom/env.lua is read here; what hyprland/env.lua sets before it, and what
    /// hyprland/variables.lua sets after it, are the Environment tab's own business.
    readonly property var inheritedEnv: {
        const map = {};
        for (const target of root.loadOrder) {
            const file = root.files[target];
            if (!file) continue;
            for (const entry of (file.unmanaged ?? [])) {
                if (entry.kind !== "env" || !entry.name) continue;
                map[entry.name] = {
                    value: entry.value,
                    line: entry.line ?? 0,
                    target: target,
                    file: String(file.file ?? "").split("/").pop()
                };
            }
        }
        return map;
    }

    /// device name -> the spec this page wrote for it, for the per-device cards.
    readonly property var managedDevices: {
        const map = {};
        for (const target of root.loadOrder)
            for (const entry of root._entriesFor(target))
                if (entry.kind === "device" && entry.spec?.name) map[entry.spec.name] = entry.spec;
        return map;
    }

    /// What the hub's health strip needs, in one place: how much this page owns, how old the
    /// safety net is, and which of our settings something else overrides after load.
    readonly property var status: {
        let managed = 0;
        let unrecognised = 0;
        const regionFiles = [];
        let backupAt = 0;
        const shadowedKeys = [];
        for (const target of root.loadOrder) {
            const file = root.files[target];
            if (file?.hasRegion) regionFiles.push(root.targetFiles[target].split("/").pop());
            const stamp = file?.backup?.mtime ?? 0;
            if (stamp > backupAt) backupAt = stamp;
            for (const entry of root._entriesFor(target)) {
                if (entry.kind === "raw") {
                    unrecognised += 1;
                    continue;
                }
                managed += 1;
                if (entry.kind === "config" && root.shadowed[entry.key] !== undefined)
                    shadowedKeys.push(entry.key);
            }
        }
        return {
            managed: managed,
            unrecognised: unrecognised,
            files: regionFiles,
            backupAt: backupAt,
            shadowed: shadowedKeys
        };
    }

    signal changed
    signal wrote(string target)
    signal writeFailed(string target, string message)

    // ------------------------------------------------------------- getting here

    /// Which tab the page should show the next time it lands. A request, not a state: the page
    /// clears it as it reads it, so opening Settings by hand afterwards lands where it was left.
    ///
    /// Section titles were the only way in before this, and they are translated - a deep link
    /// from elsewhere in the shell would have gone to the wrong tab in every language but one.
    property string pendingTab: ""

    /**
     * Opens Settings on this page, at `tab`.
     *
     * Callable from anywhere in the shell, including surfaces that have no settings window to
     * talk to yet - the tab is left here and picked up whenever the page finally loads.
     */
    function openTab(tab: string) {
        root.pendingTab = String(tab ?? "");
        GlobalStates.openSettingsPage("hyprland", "", "");
    }

    /// Reads the request and forgets it. Called by the page as it lands.
    function takePendingTab(): string {
        const tab = root.pendingTab;
        root.pendingTab = "";
        return tab;
    }

    // ---------------------------------------------------------------- reading

    /// Called by a page that wants live data for as long as it exists.
    function attach() {
        root.subscribers += 1;
        if (root.subscribers === 1 && root.ready) root.refresh();
    }

    function detach() {
        root.subscribers = Math.max(0, root.subscribers - 1);
        // Diff callbacks are closures owned by the page that asked. With nobody left watching,
        // delivering them would only reach objects that are being torn down.
        if (root.subscribers === 0) root._diffQueue = [];
    }

    function refresh() {
        if (root._readQueue.length > 0) {
            root._refreshAgain = true;
            return;
        }
        root._readQueue = Object.keys(root.targetFiles).concat(["_shellOverrides"]);
        root._drainReads();
    }

    /// Merge `keys` into the watched set and fetch their effective values.
    function watch(keys: var) {
        const wanted = Array.from(keys ?? []).filter(key => root._validKey(key));
        const merged = Array.from(root.watchedKeys);
        let added = false;
        for (const key of wanted) {
            if (merged.includes(key)) continue;
            merged.push(key);
            added = true;
        }
        if (!added) return;
        root.watchedKeys = merged;
        root.refreshEffective(wanted);
    }

    function refreshEffective(keys: var) {
        const wanted = Array.from(keys ?? root.watchedKeys).filter(key => root._validKey(key));
        if (wanted.length === 0) return;
        root._optionQueue = root._optionQueue.concat(wanted);
        // Coalesced: a page has dozens of controls and each one asks for its own key as it is
        // created, all within the same turn. One batch for the page beats one process per row.
        optionDebounce.restart();
    }

    // ------------------------------------------------------ value resolution

    function effectiveValue(key: string): var {
        const entry = root.effective[key];
        return entry === undefined ? undefined : entry.value;
    }

    function managedValue(key: string): var {
        return root.managedConfig[key];
    }

    /// What a hand-written line above the fence, or another custom file, sets this key to.
    function inheritedValue(key: string): var {
        return root.inheritedConfig[key] ?? null;
    }

    /// Everything a control needs to render itself honestly.
    function resolve(key: string): var {
        const live = root.effective[key];
        return {
            key: key,
            effective: live === undefined ? undefined : live.value,
            type: live?.type ?? "",
            known: live !== undefined,
            managed: root.managedConfig[key],
            isManaged: root.managedConfig.hasOwnProperty(key),
            inherited: root.inheritedConfig[key] ?? null,
            shadowedBy: root.shadowed[key] ?? null,
            shellOwnedBy: root.shellOwnedKeys[key] ?? ""
        };
    }

    /// The value a control should show: what this page set, else what Hyprland reports.
    function displayValue(key: string, fallback: var): var {
        if (root.managedConfig.hasOwnProperty(key)) return root.managedConfig[key];
        const live = root.effective[key];
        return live === undefined ? fallback : live.value;
    }

    /// The managed block of one file exactly as it sits on disk, for the review dialog.
    function regionText(target: string): string {
        return root.files[target]?.regionText ?? "";
    }

    function shellOwned(key: string): string {
        return root.shellOwnedKeys[key] ?? "";
    }

    function isShadowed(key: string): bool {
        return root.shadowed[key] !== undefined;
    }

    /// Layer rules for quickshell's own namespaces are re-pushed by Appearance.qml after each reload.
    function shellOwnedNamespace(namespace: string): bool {
        return /^\^?\(?quickshell/.test(String(namespace ?? ""));
    }

    // --------------------------------------------------------------- writing

    function setKey(key: string, value: var, options: var) {
        if (root.shellOwned(key) !== "") {
            console.warn("[HyprlandGui] refusing to manage shell-owned key:", key);
            return;
        }
        root._upsert({ kind: "config", id: key, key: key, value: value });
        if (!options || options.preview !== false) root.previewKey(key, value);
    }

    function resetKey(key: string) {
        root._remove("config", key);
    }

    /// The override this page wrote for one device, or null when it does not manage it.
    function deviceSpec(name: string): var {
        return root.managedDevices[name] ?? null;
    }

    function setDevice(id: string, spec: var) {
        root._upsert({ kind: "device", id: id, spec: spec });
    }
    function removeDevice(id: string) {
        root._remove("device", id);
    }

    /// A plain Lua global, which is how hyprland/variables.lua names the app each shortcut
    /// opens. Not a config key and not an env var: an ordinary assignment the binds read.
    function setGlobal(name: string, value: var) {
        root._upsert({ kind: "global", id: name, name: name, value: value });
    }
    function removeGlobal(name: string) {
        root._remove("global", name);
    }

    function setEnv(name: string, value: string) {
        root._upsert({ kind: "env", id: name, name: name, value: String(value) });
    }
    function removeEnv(name: string) {
        root._remove("env", name);
    }

    /// Every entry that will be written into one file, in the order it will be written. The
    /// rules page groups these into its own sections itself; nothing else needs the raw list.
    function entriesFor(target: string): var {
        return root._entriesFor(target);
    }

    function setRule(kind: string, id: string, spec: var) {
        root._upsert({ kind: kind, id: id, spec: spec });
    }
    function removeRule(kind: string, id: string) {
        root._remove(kind, id);
    }

    function setBind(id: string, entry: var) {
        root._upsert(Object.assign({ kind: "bind", id: id }, entry));
    }
    function removeBind(id: string) {
        root._remove("bind", id);
    }

    /// `id` defaults to the key. The shortcut editor passes a canonical id instead, so a
    /// release and the bind it belongs to are found together whichever way the key is spelled.
    function setUnbind(key: string, id: string) {
        const chosen = (id === undefined || id === null || id === "") ? key : id;
        root._upsert({ kind: "unbind", id: chosen, key: key });
    }
    function removeUnbind(key: string) {
        root._remove("unbind", key);
    }

    /// Push a value straight into the running compositor so a slider feels live. Volatile:
    /// the next reload drops it unless the region was written too. Coalesced, because dragging
    /// a slider changes its value on every frame and each push is a process.
    function previewKey(key: string, value: var) {
        if (!root._validKey(key)) return;
        const pending = Object.assign({}, root._previewPending);
        pending[key] = value;
        root._previewPending = pending;
        previewTimer.restart();
    }

    /// Delete the hand-written line outside the block that also sets `key`. `callback(result)`
    /// gets hyprgui.py's answer - `diff` on a dry run, `error` when it refused.
    function dropInherited(key: string, dryRun: bool, callback: var) {
        const info = root.inheritedConfig[key];
        if (!info || !info.removable || !root._validKey(key) || dropProc.running) {
            if (callback) callback({ ok: false, error: "nothing to remove" });
            return;
        }
        dropProc.callback = callback;
        dropProc.dryRun = dryRun;
        dropProc.result = null;
        dropProc.command = [root.scriptPath, "drop-key", "--file", root.targetFiles[info.target],
            "--key", key, "--custom-dir", root.customDir].concat(dryRun ? ["--dry-run"] : []);
        dropProc.running = true;
    }

    /// Write every dirty target now instead of waiting out the debounce.
    function flush() {
        writeDebounce.stop();
        root._flush();
    }

    /// Throw away edits that have not been written yet.
    function discard() {
        writeDebounce.stop();
        root._desired = ({});
        root.dirty = false;
        root.changed();
    }

    /// Remove the managed region from every file, leaving hand-written Lua alone.
    function stripAll() {
        writeDebounce.stop();
        root._desired = ({});
        root.dirty = false;
        root._writeQueue = Object.keys(root.targetFiles).map(target => ({ target: target, strip: true }));
        root._drainWrites();
    }

    /// Ask for a unified diff of what `flush()` would do to one target. `callback(target, diff)`.
    /// Queued: the review dialog asks about all four files in a row.
    function previewDiff(target: string, callback: var) {
        root._diffQueue = root._diffQueue.concat([{ target: target, callback: callback }]);
        root._drainDiffs();
    }

    // ------------------------------------------------------------- internals

    /// target -> array of entries, present only once that target has an unwritten edit
    property var _desired: ({})
    property var _readQueue: []
    property var _optionQueue: []
    property var _writeQueue: []
    property var _diffQueue: []
    property var _previewPending: ({})
    property bool _optionBusy: false
    property bool _awaitingReload: false
    property bool _refreshAgain: false

    function _validKey(key: string): bool {
        return /^[A-Za-z0-9_.:-]+$/.test(String(key ?? ""));
    }

    function _entriesFor(target: string): var {
        if (root._desired[target] !== undefined) return root._desired[target];
        const stored = root.files[target]?.entries ?? [];
        return stored.map(entry => {
            const copy = JSON.parse(JSON.stringify(entry));
            delete copy.line;
            delete copy.managed;
            delete copy.unrecognised;
            return copy;
        });
    }

    function _findManaged(kind: string, id: string): var {
        const target = root.targetForKind[kind];
        if (!target) return undefined;
        return root._entriesFor(target).find(entry => entry.kind === kind && entry.id === id);
    }

    function _upsert(entry: var) {
        const target = root.targetForKind[entry.kind];
        if (!target) {
            console.warn("[HyprlandGui] no file owns entry kind", entry.kind);
            return;
        }
        if (!root.ready) {
            console.warn("[HyprlandGui] ignoring edit before the managed regions were read:", entry.id);
            return;
        }
        const entries = Array.from(root._entriesFor(target));
        const index = entries.findIndex(existing => existing.kind === entry.kind && existing.id === entry.id);
        if (index >= 0) entries[index] = entry;
        else entries.push(entry);
        root._stage(target, entries);
    }

    function _remove(kind: string, id: string) {
        const target = root.targetForKind[kind];
        if (!target || !root.ready) return;
        const entries = root._entriesFor(target).filter(entry => !(entry.kind === kind && entry.id === id));
        root._stage(target, entries);
    }

    function _stage(target: string, entries: var) {
        const staged = Object.assign({}, root._desired);
        staged[target] = entries;
        root._desired = staged;
        root.dirty = true;
        root.changed();
        writeDebounce.restart();
    }

    function _flush() {
        const targets = Object.keys(root._desired);
        if (targets.length === 0) return;
        root._writeQueue = root._writeQueue.concat(targets.map(target => ({ target: target, strip: false })));
        root._drainWrites();
    }

    // Reading -------------------------------------------------------------

    function _drainReads() {
        if (readProc.running || root._readQueue.length === 0) return;
        root.busy = true;
        const next = root._readQueue[0];
        readProc.target = next;
        const path = next === "_shellOverrides" ? root.shellOverridesPath : root.targetFiles[next];
        readProc.command = [root.scriptPath, "read", "--file", path];
        readProc.running = true;
    }

    function _finishRead() {
        root._readQueue = root._readQueue.slice(1);
        if (root._readQueue.length > 0) {
            root._drainReads();
            return;
        }
        root.busy = false;
        root.ready = true;
        root.changed();
        if (!root._refreshAgain) return;
        root._refreshAgain = false;
        root.refresh();
    }

    function _applyRead(target: string, result: var) {
        if (target === "_shellOverrides") {
            const map = {};
            for (const entry of (result.unmanaged ?? [])) {
                if (entry.kind !== "config") continue;
                map[entry.key] = { value: entry.value, line: entry.line };
            }
            root.shadowed = map;
            return;
        }
        const updated = Object.assign({}, root.files);
        updated[target] = result;
        root.files = updated;
    }

    // Effective values ----------------------------------------------------

    /**
     * Ask hyprctl for the queued keys, in batches.
     *
     * The queue is emptied here rather than on completion, so the guard has to be a flag this
     * function sets itself. Trusting `optionProc.running` instead lost whole batches: several
     * controls watch in the same turn, the process has not reported itself as running yet, and
     * the second call takes its own chunk off the queue and overwrites the command with it. The
     * page then showed defaults for everything except the last control that asked.
     */
    function _drainOptions() {
        if (root._optionBusy || root._optionQueue.length === 0) return;
        const seen = {};
        const queue = root._optionQueue.filter(key => {
            if (seen[key] === true) return false;
            seen[key] = true;
            return true;
        });
        const chunk = queue.slice(0, 60);
        root._optionQueue = queue.slice(60);
        root._optionBusy = true;
        optionProc.command = ["hyprctl", "-j", "--batch",
            chunk.map(key => `getoption ${key}`).join(" ; ")];
        optionProc.running = true;
    }

    function _finishOptions() {
        root._optionBusy = false;
        if (root._optionQueue.length > 0) {
            root._drainOptions();
            return;
        }
        root.changed();
    }

    /// hyprctl --batch answers with bare JSON objects separated by blank lines, not an array.
    function _parseBatch(text: string): var {
        const out = [];
        let depth = 0;
        let start = -1;
        for (let i = 0; i < text.length; i++) {
            const c = text[i];
            if (c === "{") {
                if (depth === 0) start = i;
                depth++;
            } else if (c === "}") {
                depth--;
                if (depth !== 0 || start < 0) continue;
                try {
                    out.push(JSON.parse(text.slice(start, i + 1)));
                } catch (e) {
                    // A malformed chunk should not cost us the rest of the batch.
                }
                start = -1;
            }
        }
        return out;
    }

    function _applyOptions(objects: var) {
        const updated = Object.assign({}, root.effective);
        for (const object of objects) {
            if (!object.option) continue;
            const type = Object.keys(object).find(name => name !== "option" && name !== "set");
            let value = type ? object[type] : undefined;
            // hyprctl spells an unset string option "[[EMPTY]]". Controls want "".
            if (value === "[[EMPTY]]") value = "";
            updated[object.option] = {
                value: value,
                type: type ?? "",
                set: object.set === true
            };
        }
        root.effective = updated;
    }

    // Writing -------------------------------------------------------------

    function _drainDiffs() {
        if (diffProc.running || root._diffQueue.length === 0) return;
        const job = root._diffQueue[0];
        diffProc.diff = "";
        diffProc.target = job.target;
        diffProc.payload = JSON.stringify({ version: 1, entries: root._entriesFor(job.target) });
        diffProc.command = [root.scriptPath, "write", "--file", root.targetFiles[job.target],
            "--json", "-", "--custom-dir", root.customDir, "--dry-run"];
        diffProc.stdinEnabled = true;
        diffProc.running = true;
    }

    function _finishDiff() {
        const job = root._diffQueue[0];
        root._diffQueue = root._diffQueue.slice(1);
        if (job?.callback) job.callback(diffProc.target, diffProc.diff);
        root._drainDiffs();
    }

    function _drainWrites() {
        if (writeProc.running || root._writeQueue.length === 0) return;
        root.busy = true;
        const job = root._writeQueue[0];
        writeProc.job = job;
        writeProc.result = null;
        if (job.strip) {
            writeProc.payload = "";
            writeProc.command = [root.scriptPath, "strip", "--file", root.targetFiles[job.target],
                "--custom-dir", root.customDir];
            writeProc.stdinEnabled = false;
        } else {
            writeProc.payload = JSON.stringify({ version: 1, entries: root._entriesFor(job.target) });
            writeProc.command = [root.scriptPath, "write", "--file", root.targetFiles[job.target],
                "--json", "-", "--custom-dir", root.customDir];
            writeProc.stdinEnabled = true;
        }
        writeProc.running = true;
    }

    function _finishWrite() {
        root._afterWrite(writeProc.job, writeProc.exitCode === 0 ? writeProc.result : null);
        root._writeQueue = root._writeQueue.slice(1);
        if (root._writeQueue.length > 0) {
            root._drainWrites();
            return;
        }
        root.busy = false;
        root.refresh();
    }

    function _afterWrite(job: var, result: var) {
        if (!result || result.ok !== true) {
            root.lastError = result?.error ?? "hyprgui.py failed";
            root.writeFailed(job.target, root.lastError);
            return;
        }
        const staged = Object.assign({}, root._desired);
        delete staged[job.target];
        root._desired = staged;
        root.dirty = Object.keys(staged).length > 0;
        root.wrote(job.target);
        if (!result.changed) return;
        // A file Hyprland was not watching yet only loads after an explicit reload.
        if (result.created) Quickshell.execDetached(["hyprctl", "reload"]);
        root._awaitingReload = true;
        canaryTimer.target = job.target;
        canaryTimer.restart();
    }

    // Lua rendering, for `hyprctl eval` previews only -----------------------

    /// Merge one colon-separated key into a nested table, so a whole batch of previews renders
    /// as a single hl.config call.
    function _mergeKey(table: var, key: string, value: var) {
        const parts = String(key).split(":");
        let node = table;
        for (let i = 0; i < parts.length - 1; i++) {
            if (node[parts[i]] === undefined || typeof node[parts[i]] !== "object")
                node[parts[i]] = {};
            node = node[parts[i]];
        }
        node[parts[parts.length - 1]] = value;
    }

    function _nest(key: string, value: var): var {
        const parts = String(key).split(":");
        let node = value;
        for (let i = parts.length - 1; i >= 0; i--) {
            const wrapper = {};
            wrapper[parts[i]] = node;
            node = wrapper;
        }
        return node;
    }

    function _renderValue(value: var): string {
        if (typeof value === "boolean") return value ? "true" : "false";
        if (typeof value === "number") return String(value);
        if (Array.isArray(value)) return `{ ${value.map(item => root._renderValue(item)).join(", ")} }`;
        if (value !== null && typeof value === "object") return root._renderTable(value);
        return root._renderString(String(value));
    }

    function _renderString(value: string): string {
        return `"${value.replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n")}"`;
    }

    function _renderTable(table: var): string {
        const parts = Object.keys(table).map(key => {
            const name = /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? key : `[${root._renderString(key)}]`;
            return `${name} = ${root._renderValue(table[key])}`;
        });
        return parts.length === 0 ? "{}" : `{ ${parts.join(", ")} }`;
    }

    // Processes ------------------------------------------------------------

    Process {
        id: readProc
        property string target: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._applyRead(readProc.target, JSON.parse(text));
                } catch (e) {
                    console.error("[HyprlandGui] cannot parse read of", readProc.target, e);
                }
            }
        }
        onExited: (code, status) => Qt.callLater(root._finishRead)
    }

    Timer {
        id: optionDebounce
        interval: 40
        onTriggered: root._drainOptions()
    }

    Process {
        id: optionProc
        stdout: StdioCollector {
            onStreamFinished: root._applyOptions(root._parseBatch(text))
        }
        onExited: (code, status) => Qt.callLater(root._finishOptions)
    }

    Process {
        id: writeProc
        property var job: null
        property string payload: ""
        property var result: null
        property int exitCode: 0
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    writeProc.result = JSON.parse(text);
                } catch (e) {
                    writeProc.result = null;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") root.lastError = text.trim();
            }
        }
        onRunningChanged: {
            if (!writeProc.running || !writeProc.stdinEnabled) return;
            writeProc.write(writeProc.payload);
            writeProc.stdinEnabled = false;
        }
        onExited: (code, status) => {
            writeProc.exitCode = code;
            // stdout may still be draining; finish on the next turn so the result is in.
            Qt.callLater(root._finishWrite);
        }
    }

    Process {
        id: diffProc
        property string target: ""
        property string payload: ""
        property string diff: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    diffProc.diff = JSON.parse(text).diff ?? "";
                } catch (e) {
                    diffProc.diff = "";
                }
            }
        }
        onRunningChanged: {
            if (!diffProc.running || !diffProc.stdinEnabled) return;
            diffProc.write(diffProc.payload);
            diffProc.stdinEnabled = false;
        }
        // stdout may still be draining; hand the diff over on the next turn so it is in.
        onExited: (code, status) => Qt.callLater(root._finishDiff)
    }

    Process {
        id: dropProc
        property var callback: null
        property bool dryRun: false
        property var result: null
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    dropProc.result = JSON.parse(text);
                } catch (e) {
                    dropProc.result = null;
                }
            }
        }
        // stdout may still be draining; answer on the next turn so the result is in.
        onExited: (code, status) => Qt.callLater(() => {
            const result = dropProc.result ?? { ok: false, error: "hyprgui.py failed" };
            if (dropProc.callback) dropProc.callback(result);
            dropProc.callback = null;
            if (!dropProc.dryRun && result.ok) root.refresh();
        })
    }

    Timer {
        id: previewTimer
        interval: 40
        onTriggered: {
            const pending = root._previewPending;
            root._previewPending = ({});
            const merged = {};
            let any = false;
            for (const key of Object.keys(pending)) {
                root._mergeKey(merged, key, pending[key]);
                any = true;
            }
            if (!any) return;
            Quickshell.execDetached(["hyprctl", "eval", `hl.config(${root._renderTable(merged)})`]);
        }
    }

    /// A write that never produces a reload means Hyprland rejected the file or is not
    /// watching it. Say so, with the log, instead of leaving the UI showing a value that
    /// never took effect.
    Timer {
        id: canaryTimer
        property string target: ""
        interval: 2500
        onTriggered: {
            if (!root._awaitingReload) return;
            root._awaitingReload = false;
            logProc.target = canaryTimer.target;
            logProc.running = true;
        }
    }

    Process {
        id: logProc
        property string target: ""
        command: ["hyprctl", "rollinglog", "--num", "30"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastError = text.trim();
                root.writeFailed(logProc.target, "Hyprland did not reload after the write.\n" + text.trim());
            }
        }
    }

    Timer {
        id: writeDebounce
        // Long enough that a slider drag is one write, and that the write and the reload it
        // causes do not race a second write on top of it.
        interval: 400
        onTriggered: root._flush()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "configreloaded") return;
            root._awaitingReload = false;
            canaryTimer.stop();
            reloadDebounce.restart();
        }
    }

    /// One config write produces a burst of configreloaded events. Refresh once, after it settles.
    Timer {
        id: reloadDebounce
        interval: 250
        onTriggered: {
            if (root.subscribers === 0) return;
            root.refresh();
            root.refreshEffective(root.watchedKeys);
        }
    }

    Component.onCompleted: root.refresh()
}
