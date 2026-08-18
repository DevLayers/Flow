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

    // ── Credentials (loaded from .env) ────────────────────────────
    property string clientId: ""
    property string clientSecret: ""
    property string accessToken: ""

    property bool _envLoading: false
    property bool _envLoaded: false

    readonly property string apiBase: "https://api.ticktick.com/open/v1"
    readonly property string envPath: Quickshell.shellPath(".env")

    // ── Refresh interval (5 minutes) ──────────────────────────────
    readonly property int refreshInterval: 5 * 60 * 1000

    // ── Public API ────────────────────────────────────────────────

    function refresh() {
        if (!root.available)
            return;
        root.syncing = true;
        root.fetchTasksFromInbox();
    }

    function fetchTasksFromInbox() {
        let cmd = `curl -s -X GET "${root.apiBase}/project/${root.inboxProjectId}/data" -H "Authorization: Bearer ${root.accessToken}"`;
        fetchTasksProcess.command[2] = cmd;
        fetchTasksProcess.running = true;
    }

    function createTask(title) {
        if (!root.available)
            return;
        let body = JSON.stringify({
            "title": title,
            "projectId": root.inboxProjectId
        });
        let cmd = `curl -s -X POST "${root.apiBase}/task" -H "Authorization: Bearer ${root.accessToken}" -H "Content-Type: application/json" -d '${body}'`;
        createTaskProcess.command[2] = cmd;
        createTaskProcess.running = true;
    }

    function completeTask(taskId, projectId) {
        if (!root.available)
            return;
        let pid = projectId || root.inboxProjectId;
        let cmd = `curl -s -X POST "${root.apiBase}/project/${pid}/task/${taskId}/complete" -H "Authorization: Bearer ${root.accessToken}"`;
        completeTaskProcess.command[2] = cmd;
        completeTaskProcess.running = true;
    }

    function deleteTask(taskId, projectId) {
        if (!root.available)
            return;
        let pid = projectId || root.inboxProjectId;
        let cmd = `curl -s -X DELETE "${root.apiBase}/project/${pid}/task/${taskId}" -H "Authorization: Bearer ${root.accessToken}"`;
        deleteTaskProcess.command[2] = cmd;
        deleteTaskProcess.running = true;
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
                const tokenChanged = root.accessToken !== (kr.ticktick_access_token || "");
                root.clientId = kr.ticktick_client_id || "";
                root.clientSecret = kr.ticktick_client_secret || "";
                root.accessToken = kr.ticktick_access_token || "";
                // Keyring emits both loadedChanged and dataChanged; only act on a real change
                if (!tokenChanged)
                    return;
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
        // The keyring signals re-enter loadCredentials after startup; the .env file
        // only needs reading once per session.
        if (root._envLoading || root._envLoaded)
            return;
        root._envLoading = true;
        loadEnvProcess.command[2] = `cat "${FileUtils.trimFileProtocol(root.envPath)}" 2>/dev/null || echo ""`;
        loadEnvProcess.running = true;
    }

    function parseEnv(text) {
        root._envLoading = false;
        root._envLoaded = true;
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
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseEnv(text);
            }
        }
    }

    // Fetch tasks from inbox
    Process {
        id: fetchTasksProcess
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    // The /project/{id}/data endpoint returns { tasks: [...], ... }
                    let rawTasks = data.tasks || data || [];
                    let parsed = [];
                    for (let i = 0; i < rawTasks.length; i++) {
                        let t = rawTasks[i];
                        parsed.push({
                            "id": t.id || "",
                            "projectId": t.projectId || root.inboxProjectId,
                            "content": t.title || "",
                            "done": (t.status !== undefined) ? (t.status === 2) : false,
                            "date": t.dueDate ? new Date(t.dueDate) : new Date(),
                            "hasDate": t.dueDate !== undefined && t.dueDate !== null
                        });
                    }
                    root.tasks = parsed;
                    console.log("[TickTick] Fetched " + parsed.length + " tasks.");
                } catch (e) {
                    console.error("[TickTick] Failed to parse tasks: " + e.message + " | raw: " + text.substring(0, 200));
                }
                root.syncing = false;
            }
        }
    }

    // Create task
    Process {
        id: createTaskProcess
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[TickTick] Task created. Refreshing...");
                root.refresh();
            }
        }
    }

    // Complete task
    Process {
        id: completeTaskProcess
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[TickTick] Task completed. Refreshing...");
                root.refresh();
            }
        }
    }

    // Delete task
    Process {
        id: deleteTaskProcess
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
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
