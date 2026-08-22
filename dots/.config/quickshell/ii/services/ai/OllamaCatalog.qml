pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Curated local-model catalogue and the one owner of an Ollama pull.
 *
 * The catalogue never downloads anything by itself. A model is transferred
 * only after the user explicitly chooses Pull; then the request stays on the
 * loopback daemon and mirrors its streamed progress into the sidebar.
 */
Singleton {
    id: root

    readonly property string endpoint: "http://127.0.0.1:11434/api/pull"

    // These are useful starting points, not a claim that they are installed
    // or that every tag exposes the same capabilities. The daemon resolves
    // the real capabilities after a successful pull.
    readonly property var models: [
        {
            name: "qwen3.5:9b",
            title: "Qwen 3.5 · 9B",
            description: Translation.tr("Balanced local assistant for chat, reasoning and shell tools"),
            category: Translation.tr("Assistant")
        },
        {
            name: "gemma3:4b",
            title: "Gemma 3 · 4B",
            description: Translation.tr("Compact general-purpose model for a lighter local setup"),
            category: Translation.tr("Assistant")
        },
        {
            name: "llama3.2:3b",
            title: "Llama 3.2 · 3B",
            description: Translation.tr("Fast, small model for everyday local chat"),
            category: Translation.tr("Lightweight")
        },
        {
            name: "qwen2.5-coder:7b",
            title: "Qwen 2.5 Coder · 7B",
            description: Translation.tr("Local coding and terminal-oriented conversations"),
            category: Translation.tr("Coding")
        },
        {
            name: "nomic-embed-text",
            title: "Nomic Embed Text",
            description: Translation.tr("Embedding model for local retrieval, not chat"),
            category: Translation.tr("Local retrieval")
        }
    ]

    property string pullingModel: ""
    property string pullStatus: ""
    property string pullError: ""
    property real pullProgress: -1
    property string pullState: "idle" // idle | pulling | succeeded | failed | cancelled

    readonly property bool pulling: root.pullingModel.length > 0

    signal pullSucceeded(string modelName)

    function normalizeModelName(modelName): string {
        const normalized = String(modelName ?? "").trim();
        // Ollama names may have a namespace and tag, but are never URLs,
        // whitespace, shell syntax or a path beginning with a slash.
        if (!/^[A-Za-z0-9][A-Za-z0-9._/-]*(?::[A-Za-z0-9][A-Za-z0-9._/-]*)?$/.test(normalized))
            return "";
        const repository = normalized.split(":")[0];
        const unsafeSegment = repository.split("/").some(segment => segment.length === 0 || segment === "." || segment === "..");
        return unsafeSegment ? "" : normalized;
    }

    function pull(modelName): bool {
        if (root.pulling)
            return false;

        const normalized = root.normalizeModelName(modelName);
        if (normalized.length === 0) {
            root.pullState = "failed";
            root.pullError = Translation.tr("Enter a valid Ollama model name, for example qwen3.5:9b.");
            return false;
        }

        root.pullingModel = normalized;
        root.pullStatus = Translation.tr("Preparing download…");
        root.pullError = "";
        root.pullProgress = -1;
        root.pullState = "pulling";
        pullProc.modelName = normalized;
        pullProc.succeeded = false;
        pullProc.cancelled = false;
        pullProc.stderrText = "";
        pullProc.stdinEnabled = true;
        pullProc.running = true;
        // /api/pull is NDJSON. Closing stdin matters: otherwise curl waits
        // for more request data and the daemon never begins the transfer.
        pullProc.write(JSON.stringify({ name: normalized, stream: true }) + "\n");
        pullProc.stdinEnabled = false;
        return true;
    }

    function cancelPull() {
        if (!root.pulling)
            return;
        pullProc.cancelled = true;
        if (pullProc.running)
            pullProc.running = false;
        root.pullingModel = "";
        root.pullStatus = Translation.tr("Download stopped");
        root.pullState = "cancelled";
        root.pullProgress = -1;
    }

    function acceptProgress(event) {
        if (!root.pulling || !event)
            return;

        const reportedError = String(event.error ?? "").trim();
        if (reportedError.length > 0) {
            root.pullError = reportedError;
            return;
        }

        const status = String(event.status ?? "").trim();
        if (status.length > 0)
            root.pullStatus = status;
        const total = Number(event.total ?? 0);
        const completed = Number(event.completed ?? 0);
        if (isFinite(total) && total > 0 && isFinite(completed))
            root.pullProgress = Math.max(0, Math.min(1, completed / total));
        if (status.toLowerCase() === "success") {
            pullProc.succeeded = true;
            root.pullProgress = 1;
        }
    }

    Process {
        id: pullProc

        property string modelName: ""
        property bool succeeded: false
        property bool cancelled: false
        property string stderrText: ""

        // Keep this request argv-only. The selected name is sent as JSON to
        // stdin, so no user string can become shell or curl syntax.
        command: [
            "curl", "--no-buffer", "--silent", "--show-error",
            "--connect-timeout", "5",
            "--request", "POST", root.endpoint,
            "--header", "Content-Type: application/json",
            "--data-binary", "@-"
        ]
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                const trimmed = String(line ?? "").trim();
                if (trimmed.length === 0)
                    return;
                try {
                    root.acceptProgress(JSON.parse(trimmed));
                } catch (error) {
                    // A non-JSON response is handled through curl's exit code
                    // and stderr below; never make parser noise a QML error.
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                const trimmed = String(line ?? "").trim();
                if (trimmed.length === 0)
                    return;
                pullProc.stderrText = (pullProc.stderrText + " " + trimmed).trim().slice(0, 400);
            }
        }

        onExited: exitCode => {
            if (pullProc.cancelled)
                return;

            const modelName = pullProc.modelName;
            root.pullingModel = "";
            if (pullProc.succeeded) {
                root.pullState = "succeeded";
                root.pullStatus = Translation.tr("Ready to use");
                root.pullProgress = 1;
                root.pullSucceeded(modelName);
                return;
            }

            root.pullState = "failed";
            root.pullProgress = -1;
            if (root.pullError.length === 0) {
                root.pullError = pullProc.stderrText.length > 0
                    ? pullProc.stderrText
                    : exitCode === 0
                        ? Translation.tr("Ollama did not confirm that the model was pulled.")
                        : Translation.tr("Could not reach Ollama. Start its local service and try again.");
            }
        }
    }
}
