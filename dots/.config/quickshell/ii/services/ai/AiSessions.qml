pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * The store behind the chat list: one file per conversation, an index that
 * lists them, and every operation that touches the disk.
 *
 * Nothing here knows about messages, models or the request pipeline — it is
 * handed a finished session object and gives one back. `Ai` owns the
 * conversation and drives this; keeping the dependency one-way is what stops
 * the two from having to be loaded in a particular order.
 *
 * All file work goes through `ai_sessions.py`, which owns the index and writes
 * session files atomically. That is also why saving no longer blocks: the old
 * `blockLoading: true` save file was there to avoid a race this design does not
 * have.
 */
Scope {
    id: root

    /** Where sessions live, and where the pre-session chats were. */
    property string dir: ""
    property string legacyDir: ""
    property string scriptPath: ""
    property string exportDir: ""

    /** Index entries: {id, title, createdAt, updatedAt, pinned, modelId, messageCount, preview}. */
    property var index: []
    property string currentId: ""
    property bool loaded: false
    property string lastError: ""

    /** Ids matching the running search, or null when nothing is being searched. */
    property var matchedIds: null
    property string query: ""

    /** The chat just deleted, kept until the undo offer goes away. */
    property var deletedEntry: null

    readonly property var currentEntry: root.entryFor(root.currentId)

    /** A save is due. `Ai` answers by calling `commit()` with the session. */
    signal saveRequested
    /** A session came back from disk and should replace the conversation. */
    signal sessionOpened(var session)
    /** A chat the user was reading was deleted elsewhere in the list. */
    signal currentDropped

    function newId(): string {
        // A v4-shaped id. Uniqueness is what matters here, not entropy quality.
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
            const random = Math.floor(Math.random() * 16);
            const value = c === "x" ? random : ((random & 0x3) | 0x8);
            return value.toString(16);
        });
    }

    function entryFor(id: string): var {
        return root.index.find(entry => entry.id === id) ?? null;
    }

    function titleFor(id: string): string {
        return root.entryFor(id)?.title ?? "";
    }

    function ensureLoaded() {
        if (root.loaded || root.dir.length === 0)
            return;
        root.loaded = true; // One bootstrap per shell run, even if it fails.
        root.enqueue({
            kind: "bootstrap",
            args: ["bootstrap", root.dir, root.legacyDir]
        });
    }

    // ── Writing ───────────────────────────────────────────────────────────
    // Saves are debounced: a streamed answer changes the last message on every
    // frame, and none of those intermediate states is worth a file write.

    function scheduleSave() {
        if (root.dir.length === 0)
            return;
        saveTimer.restart();
    }

    function saveNow() {
        saveTimer.stop();
        root.saveRequested();
    }

    /**
     * Writes a session object. The caller owns the shape; only the id is
     * forced, so a fork cannot overwrite the chat it came from.
     */
    function commit(session: var) {
        if (!session || root.dir.length === 0)
            return;
        const id = session.id ?? root.currentId;
        if (!id || id.length === 0)
            return;
        root.enqueue({
            kind: "save",
            args: ["save", root.dir, id],
            stdin: JSON.stringify(session)
        });
    }

    // ── Reading and editing ───────────────────────────────────────────────

    function openSession(id: string) {
        if (!id || id.length === 0)
            return;
        root.enqueue({
            kind: "open",
            args: ["open", root.dir, id],
            id: id
        });
    }

    function rename(id: string, title: string) {
        const trimmed = (title ?? "").trim();
        if (!id || trimmed.length === 0)
            return;
        root.enqueue({
            kind: "index",
            args: ["patch", root.dir, id, "--title", trimmed]
        });
    }

    function setPinned(id: string, pinned: bool) {
        if (!id)
            return;
        root.enqueue({
            kind: "index",
            args: ["patch", root.dir, id, "--pinned", pinned ? "1" : "0"]
        });
    }

    function duplicate(id: string) {
        if (!id)
            return;
        root.enqueue({
            kind: "index",
            args: ["duplicate", root.dir, id, root.newId()]
        });
    }

    function remove(id: string) {
        if (!id)
            return;
        root.deletedEntry = root.entryFor(id);
        undoTimer.restart();
        root.enqueue({
            kind: "index",
            args: ["delete", root.dir, id]
        });
        if (root.currentId === id) {
            root.currentId = "";
            root.currentDropped();
        }
    }

    function undoDelete() {
        const entry = root.deletedEntry;
        if (!entry)
            return;
        root.deletedEntry = null;
        undoTimer.stop();
        root.enqueue({
            kind: "index",
            args: ["restore", root.dir, entry.id]
        });
    }

    function exportMarkdown(id: string) {
        const entry = root.entryFor(id);
        if (!entry)
            return;
        const safeTitle = (entry.title || "chat").replace(/[^\w\- ]+/g, "").trim().replace(/\s+/g, "-");
        root.enqueue({
            kind: "export",
            args: ["export", root.dir, id, `${root.exportDir}/${safeTitle || "chat"}.md`]
        });
    }

    /**
     * Titles are matched in the index; message bodies need the files, so the
     * helper does that part. Both halves land in `matchedIds`.
     */
    function search(text: string) {
        root.query = (text ?? "").trim();
        if (root.query.length === 0) {
            root.matchedIds = null;
            searchProc.running = false;
            return;
        }
        searchProc.running = false;
        searchProc.query = root.query;
        searchProc.running = true;
    }

    // ── The queue ─────────────────────────────────────────────────────────
    // One helper process at a time, in the order the user asked for things.
    // Anything else would race the index against itself.

    property var pending: []

    function enqueue(op: var) {
        if (root.scriptPath.length === 0 || root.dir.length === 0)
            return;
        root.pending.push(op);
        if (!opProc.running)
            root.runNext();
    }

    function runNext() {
        if (opProc.running || root.pending.length === 0)
            return;
        const op = root.pending.shift();
        opProc.op = op;
        opProc.payload = op.stdin ?? "";
        opProc.command = ["python3", root.scriptPath, ...op.args];
        opProc.stdinEnabled = (op.stdin ?? "").length > 0;
        opProc.running = true;
    }

    function applyResult(op: var, raw: string) {
        if (!op || raw.trim().length === 0)
            return;
        let parsed;
        try {
            parsed = JSON.parse(raw);
        } catch (error) {
            console.log("[AiSessions] Unreadable helper output:", error);
            return;
        }
        if (parsed.error) {
            root.lastError = parsed.error;
            return;
        }
        root.lastError = "";
        if (Array.isArray(parsed.sessions))
            root.index = parsed.sessions;
        if (op.kind === "open" && parsed.session) {
            root.currentId = parsed.session.id;
            root.sessionOpened(parsed.session);
        }
    }

    Timer {
        id: saveTimer
        interval: 1200
        onTriggered: root.saveRequested()
    }

    Timer {
        // How long the undo offer stands. After that the chat is only in the
        // trash folder, which the user can still dig out by hand.
        id: undoTimer
        interval: 12000
        onTriggered: root.deletedEntry = null
    }

    Process {
        id: opProc
        property var op: null
        property string payload: ""

        onRunningChanged: {
            if (!opProc.running || opProc.payload.length === 0)
                return;
            opProc.write(opProc.payload);
            opProc.stdinEnabled = false; // Closing stdin is what makes it read
        }

        stdout: StdioCollector {
            id: opCollector
            // `op` is left alone until the next one starts: whether this fires
            // before or after the process exits is not worth depending on.
            onStreamFinished: root.applyResult(opProc.op, opCollector.text)
        }

        onExited: Qt.callLater(root.runNext)
    }

    Process {
        id: searchProc
        property string query: ""
        command: ["python3", root.scriptPath, "search", root.dir, searchProc.query]

        stdout: StdioCollector {
            id: searchCollector
            onStreamFinished: {
                const raw = searchCollector.text.trim();
                if (raw.length === 0)
                    return;
                try {
                    const parsed = JSON.parse(raw);
                    // A slower search that finished after the user typed on is
                    // an answer to a question nobody is asking any more.
                    if (parsed.query === root.query.toLowerCase())
                        root.matchedIds = parsed.ids ?? [];
                } catch (error) {
                    console.log("[AiSessions] Unreadable search output:", error);
                }
            }
        }
    }
}
