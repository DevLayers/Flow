pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
        env: `${root.customDir}/env.lua`
    })
    readonly property var targetForKind: ({
        config: "general",
        device: "general",
        windowrule: "rules",
        layerrule: "rules",
        workspacerule: "rules",
        bind: "keybinds",
        unbind: "keybinds",
        env: "env"
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

    signal changed
    signal wrote(string target)
    signal writeFailed(string target, string message)

    // ---------------------------------------------------------------- reading

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
        root._drainOptions();
    }

    // ------------------------------------------------------ value resolution

    function effectiveValue(key: string): var {
        const entry = root.effective[key];
        return entry === undefined ? undefined : entry.value;
    }

    function managedValue(key: string): var {
        const entry = root._findManaged("config", key);
        return entry === undefined ? undefined : entry.value;
    }

    /// What a hand-written line above the fence, or another custom file, sets this key to.
    function inheritedValue(key: string): var {
        for (const target of Object.keys(root.targetFiles)) {
            const file = root.files[target];
            if (!file) continue;
            const hits = (file.unmanaged ?? []).filter(entry => entry.kind === "config" && entry.key === key);
            if (hits.length === 0) continue;
            const last = hits[hits.length - 1];
            return { value: last.value, file: file.file, line: last.line };
        }
        return null;
    }

    /// Everything a control needs to render itself honestly.
    function resolve(key: string): var {
        return {
            key: key,
            effective: root.effectiveValue(key),
            type: root.effective[key]?.type ?? "",
            managed: root.managedValue(key),
            isManaged: root._findManaged("config", key) !== undefined,
            inherited: root.inheritedValue(key),
            shadowedBy: root.shadowed[key] ?? null,
            shellOwnedBy: root.shellOwnedKeys[key] ?? ""
        };
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

    function setDevice(id: string, spec: var) {
        root._upsert({ kind: "device", id: id, spec: spec });
    }
    function removeDevice(id: string) {
        root._remove("device", id);
    }

    function setEnv(name: string, value: string) {
        root._upsert({ kind: "env", id: name, name: name, value: String(value) });
    }
    function removeEnv(name: string) {
        root._remove("env", name);
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

    function setUnbind(key: string) {
        root._upsert({ kind: "unbind", id: key, key: key });
    }
    function removeUnbind(key: string) {
        root._remove("unbind", key);
    }

    /// Push a value straight into the running compositor so a slider feels live. Volatile:
    /// the next reload drops it unless the region was written too.
    function previewKey(key: string, value: var) {
        if (!root._validKey(key)) return;
        const expression = root._renderTable(root._nest(key, value));
        Quickshell.execDetached(["hyprctl", "eval", `hl.config(${expression})`]);
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

    /// Ask for a unified diff of what `flush()` would do to one target. `callback(diff)`.
    function previewDiff(target: string, callback: var) {
        root._diffCallback = callback;
        diffProc.target = target;
        diffProc.payload = JSON.stringify({ version: 1, entries: root._entriesFor(target) });
        diffProc.command = [root.scriptPath, "write", "--file", root.targetFiles[target],
            "--json", "-", "--custom-dir", root.customDir, "--dry-run"];
        diffProc.stdinEnabled = true;
        diffProc.running = true;
    }

    // ------------------------------------------------------------- internals

    /// target -> array of entries, present only once that target has an unwritten edit
    property var _desired: ({})
    property var _readQueue: []
    property var _optionQueue: []
    property var _writeQueue: []
    property var _diffCallback: null
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

    function _drainOptions() {
        if (optionProc.running || root._optionQueue.length === 0) return;
        const chunk = root._optionQueue.slice(0, 60);
        root._optionQueue = root._optionQueue.slice(60);
        optionProc.command = ["hyprctl", "-j", "--batch",
            chunk.map(key => `getoption ${key}`).join(" ; ")];
        optionProc.running = true;
    }

    function _finishOptions() {
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
            updated[object.option] = {
                value: type ? object[type] : undefined,
                type: type ?? "",
                set: object.set === true
            };
        }
        root.effective = updated;
    }

    // Writing -------------------------------------------------------------

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
        stdout: StdioCollector {
            onStreamFinished: {
                let diff = "";
                try {
                    diff = JSON.parse(text).diff ?? "";
                } catch (e) {
                    diff = "";
                }
                if (root._diffCallback) root._diffCallback(diff);
                root._diffCallback = null;
            }
        }
        onRunningChanged: {
            if (!diffProc.running || !diffProc.stdinEnabled) return;
            diffProc.write(diffProc.payload);
            diffProc.stdinEnabled = false;
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
            root.refresh();
            root.refreshEffective(root.watchedKeys);
        }
    }

    Component.onCompleted: root.refresh()
}
