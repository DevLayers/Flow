pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/**
 * TickTick API integration service.
 * Uses the TickTick Open API v1 to sync tasks.
 * Credentials are loaded from .env file in the shell root.
 */
Singleton {
    id: root

    // ── State ─────────────────────────────────────────────────────
    property bool available: root.accessToken.length > 0
    property bool syncing: false
    property var tasks: []
    property string inboxProjectId: "inbox"
    // Why the last request failed, empty when it did not. The service used to
    // log "Task created." whatever came back, including an expired token.
    property string lastError: ""

    /** Emitted with the id TickTick assigned, so a caller can point at it. */
    signal taskCreated(string taskId, string title)
    signal requestFailed(string operation, string reason)

    // ── Credentials (loaded from .env) ────────────────────────────
    property string clientId: ""
    property string clientSecret: ""
    property string accessToken: ""

    readonly property string apiBase: "https://api.ticktick.com/open/v1"
    readonly property string envPath: Quickshell.shellPath(".env")
    readonly property string helperPath: FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/ticktick/api.py"))

    // ── Refresh interval (5 minutes) ──────────────────────────────
    readonly property int refreshInterval: 5 * 60 * 1000

    // ── Public API ────────────────────────────────────────────────

    /**
     * Sends one request to the helper.
     *
     * The token and every field travel as JSON on the helper's stdin. Nothing
     * is interpolated into a command line: a task title is data, and a title
     * with an apostrophe in it — or a semicolon, which is the same bug with a
     * worse ending — has to stay data all the way to the API.
     */
    function send(process, payload) {
        if (!root.available) {
            root.lastError = qsTr("TickTick is not connected.");
            return false;
        }
        if (process.running) {
            root.lastError = qsTr("That request is already running.");
            return false;
        }
        process.running = true;
        process.write(JSON.stringify(Object.assign({
            token: root.accessToken,
            projectId: root.inboxProjectId
        }, payload)) + "\n");
        return true;
    }

    function refresh() {
        if (!root.available)
            return;
        root.syncing = true;
        root.fetchTasksFromInbox();
    }

    function fetchTasksFromInbox() {
        if (!root.send(fetchTasksProcess, { op: "list" }))
            root.syncing = false;
    }

    function createTask(title, extra = null) {
        return root.send(createTaskProcess, Object.assign({
            op: "create",
            title: String(title ?? "")
        }, extra ?? ({})));
    }

    function completeTask(taskId, projectId) {
        return root.send(completeTaskProcess, {
            op: "complete",
            taskId: String(taskId ?? ""),
            projectId: projectId || root.inboxProjectId
        });
    }

    function deleteTask(taskId, projectId) {
        return root.send(deleteTaskProcess, {
            op: "delete",
            taskId: String(taskId ?? ""),
            projectId: projectId || root.inboxProjectId
        });
    }

    /** Turns one helper reply into either an error or its payload. */
    function readReply(line, what): var {
        let reply = null;
        try {
            reply = JSON.parse(line);
        } catch (e) {
            root.lastError = qsTr("TickTick sent something unreadable.");
            console.warn("[TickTick] unreadable reply for", what, ":", String(line).substring(0, 200));
            return null;
        }
        if (!reply.ok) {
            root.lastError = String(reply.error ?? qsTr("The request failed."));
            console.warn("[TickTick]", what, "failed:", root.lastError);
            return null;
        }
        root.lastError = "";
        return reply;
    }

    // ── Init ──────────────────────────────────────────────────────

    Component.onCompleted: {
        loadCredentials();
    }

    Connections {
        target: KeyringStorage
        function onLoadedChanged() {
            if (KeyringStorage.loaded) {
                root.loadCredentials();
            }
        }
        function onDataChanged() {
            root.loadCredentials();
        }
    }

    function loadCredentials() {
        if (KeyringStorage.loaded) {
            let kr = KeyringStorage.keyringData?.apiKeys;
            if (kr && kr.ticktick_access_token) {
                root.clientId = kr.ticktick_client_id || "";
                root.clientSecret = kr.ticktick_client_secret || "";
                root.accessToken = kr.ticktick_access_token || "";
                console.log("[TickTick] Credentials loaded from Gnome Keyring.");
                if (root.available) {
                    root.refresh();
                }
                return;
            }
        }
        // Fallback to .env
        loadEnv();
    }

    function loadEnv() {
        loadEnvProcess.running = true;
    }

    function parseEnv(text) {
        let lines = text.split("\n");
        let envClientId = "";
        let envClientSecret = "";
        let envAccessToken = "";
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (line.startsWith("#") || line.length === 0)
                continue;
            let eqIdx = line.indexOf("=");
            if (eqIdx < 0)
                continue;
            let key = line.substring(0, eqIdx).trim();
            let val = line.substring(eqIdx + 1).trim();
            if (key === "TICKTICK_CLIENT_ID")
                envClientId = val;
            else if (key === "TICKTICK_CLIENT_SECRET")
                envClientSecret = val;
            else if (key === "TICKTICK_ACCESS_TOKEN")
                envAccessToken = val;
        }

        // Only assign if we didn't load from Keyring or Keyring is not loaded/empty
        let kr = KeyringStorage.loaded ? KeyringStorage.keyringData?.apiKeys : null;
        if (!kr || !kr.ticktick_access_token) {
            root.clientId = envClientId;
            root.clientSecret = envClientSecret;
            root.accessToken = envAccessToken;
            if (root.available) {
                console.log("[TickTick] Credentials loaded from .env (fallback), fetching tasks...");
                root.refresh();
            } else {
                console.log("[TickTick] No access token found in Gnome Keyring or .env. Service disabled.");
            }
        }
    }

    // ── Processes ─────────────────────────────────────────────────

    // Load .env
    Process {
        id: loadEnvProcess
        command: ["cat", FileUtils.trimFileProtocol(root.envPath)]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseEnv(text);
            }
        }
        onExited: (exitCode, exitStatus) => {
            // No .env is the normal case once the keyring holds the token.
            if (exitCode !== 0)
                root.parseEnv("");
        }
    }

    // Fetch tasks from inbox
    Process {
        id: fetchTasksProcess
        command: ["python3", root.helperPath]
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                const reply = root.readReply(text, "list");
                root.syncing = false;
                if (!reply) {
                    root.requestFailed("list", root.lastError);
                    return;
                }
                const data = reply.data ?? ({});
                const rawTasks = data.tasks || [];
                const parsed = [];
                for (let i = 0; i < rawTasks.length; i++) {
                    const task = rawTasks[i];
                    parsed.push({
                        "id": task.id || "",
                        "projectId": task.projectId || root.inboxProjectId,
                        "content": task.title || "",
                        "done": (task.status !== undefined) ? (task.status === 2) : false,
                        "date": task.dueDate ? new Date(task.dueDate) : new Date(),
                        "hasDate": task.dueDate !== undefined && task.dueDate !== null
                    });
                }
                root.tasks = parsed;
                console.log("[TickTick] Fetched " + parsed.length + " tasks.");
            }
        }
    }

    // Create task
    Process {
        id: createTaskProcess
        command: ["python3", root.helperPath]
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                const reply = root.readReply(text, "create");
                if (!reply) {
                    root.requestFailed("create", root.lastError);
                    return;
                }
                // The id TickTick assigned, rather than the assumption that
                // something was created because the process exited.
                const created = reply.data ?? ({});
                root.taskCreated(String(created.id ?? ""), String(created.title ?? ""));
                console.log("[TickTick] Task created:", created.id ?? "(no id)");
                root.refresh();
            }
        }
    }

    // Complete task
    Process {
        id: completeTaskProcess
        command: ["python3", root.helperPath]
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.readReply(text, "complete")) {
                    root.requestFailed("complete", root.lastError);
                    return;
                }
                console.log("[TickTick] Task completed. Refreshing...");
                root.refresh();
            }
        }
    }

    // Delete task
    Process {
        id: deleteTaskProcess
        command: ["python3", root.helperPath]
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.readReply(text, "delete")) {
                    root.requestFailed("delete", root.lastError);
                    return;
                }
                console.log("[TickTick] Task deleted. Refreshing...");
                root.refresh();
            }
        }
    }

    // ── Auto-refresh timer ────────────────────────────────────────
    Timer {
        running: root.available
        repeat: true
        interval: root.refreshInterval
        onTriggered: root.refresh()
    }
}
