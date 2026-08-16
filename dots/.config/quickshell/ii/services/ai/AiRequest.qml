pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions as CF

/**
 * One request to a model endpoint, from script generation to exit.
 *
 * The caller fills in the inputs (model, strategy, message, endpoint,
 * payload), calls `start()`, and listens to `line`/`finished`. Everything
 * about the transport itself lives here: the generated bash script, the
 * process, the HTTP status, the timeout, the retries and the cancellation.
 *
 * The HTTP status is not otherwise observable — curl writes the body to
 * stdout and nothing else — so the script asks for it with `-w` and it
 * arrives as a trailing marker line, which is stripped before `line` fires.
 */
Scope {
    id: root

    // ── Inputs ────────────────────────────────────────────────────────────
    property AiModel model
    property ApiStrategy strategy
    property AiMessageData message
    property string endpoint: ""
    property var requestData: ({})
    property string apiKey: ""
    property string apiKeyEnvVarName: "API_KEY"
    property string scriptPath: ""
    /** Helper that writes attachments into the body. See `buildScript`. */
    property string attachScriptPath: ""

    /**
     * The request body is written next to the script and handed to curl as a
     * file. Nothing large is ever passed as an argument that way — a single
     * base64 image is already past what one may hold — and the body needs no
     * shell escaping at all.
     */
    readonly property string bodyPath: CF.FileUtils.trimFileProtocol(root.scriptPath) + ".json"

    // ── Tunables ──────────────────────────────────────────────────────────
    readonly property int connectTimeout: Math.max(1, Config.options?.ai?.connectTimeout ?? 15)
    readonly property int requestTimeout: Math.max(0, Config.options?.ai?.requestTimeout ?? 300)
    // Not readonly: a caller whose request is not worth retrying — testing
    // whether a key works — says so by setting it to zero.
    property int maxRetries: Math.max(0, Config.options?.ai?.maxRetries ?? 2)

    // ── State ─────────────────────────────────────────────────────────────
    readonly property bool running: requestProc.running || retryTimer.running
    readonly property string statusMarker: "@@II_HTTP_STATUS:"
    property int attempt: 0
    property int httpStatus: 0
    property int exitCode: 0
    property bool aborted: false
    readonly property int attachmentFailureExitCode: 65
    readonly property string attachmentErrorMarker: "@@II_ATTACHMENT_ERROR:"
    property string attachmentError: ""

    // Where the message stood when the current attempt started, so a retry
    // can drop whatever the failed attempt wrote before trying again.
    property int contentMark: 0
    property int rawContentMark: 0

    signal line(string data)
    signal retrying(int attempt, int delaySeconds, int status)
    /** reason: "done" | "error" | "aborted" | "attachmentError" */
    signal finished(string reason, int status, int code)

    /**
     * Starts the request. Returns false when one is already in flight —
     * a second send never silently replaces the first.
     */
    function start(): bool {
        if (root.running)
            return false;
        if (!root.strategy || !root.model)
            return false;
        root.aborted = false;
        root.attempt = 0;
        root.httpStatus = 0;
        root.exitCode = 0;
        root.attachmentError = "";
        root.contentMark = root.message?.content.length ?? 0;
        root.rawContentMark = root.message?.rawContent.length ?? 0;
        root.strategy.reset();
        root.launch();
        return true;
    }

    /**
     * Cancels the request, whether it is streaming or waiting to retry.
     */
    function abort(): bool {
        if (!root.running)
            return false;
        root.aborted = true;
        retryTimer.stop();
        watchdog.stop();
        if (requestProc.running) {
            requestProc.running = false; // onExited reports it
            return true;
        }
        root.finished("aborted", root.httpStatus, root.exitCode);
        return true;
    }

    function launch() {
        const scriptFilePath = CF.FileUtils.trimFileProtocol(root.scriptPath);
        // Written before the script that reads it, and rewritten on every
        // attempt: a retry re-runs the attachment step over a fresh body.
        bodyFile.path = Qt.resolvedUrl(root.bodyPath);
        bodyFile.setText(JSON.stringify(root.requestData));
        scriptFile.path = Qt.resolvedUrl(scriptFilePath);
        scriptFile.setText(root.buildScript());
        // Rebuilt every launch: a key must never outlive the model it
        // belongs to, and an unused variable must not linger either.
        requestProc.environment = root.model.requires_key ? ({
                [root.apiKeyEnvVarName]: root.apiKey
            }) : ({});
        requestProc.command = ["bash", scriptFilePath];
        requestProc.running = true;
        if (root.requestTimeout > 0) {
            // curl bounds itself with --max-time; this only catches the case
            // where curl or the shell around it stops responding entirely.
            watchdog.interval = (root.requestTimeout + 15) * 1000;
            watchdog.restart();
        }
    }

    function buildScript(): string {
        const headers = {
            "Content-Type": "application/json"
        };
        const headerString = Object.entries(headers).filter(([k, v]) => v && v.length > 0).map(([k, v]) => `-H '${k}: ${v}'`).join(" ");
        const authHeader = root.strategy.buildAuthorizationHeader(root.apiKeyEnvVarName);
        const quotedEndpoint = `'${CF.StringUtils.shellSingleQuoteEscape(root.endpoint)}'`;

        const quotedBody = `'${CF.StringUtils.shellSingleQuoteEscape(root.bodyPath)}'`;
        let content = "#!/usr/bin/env bash\n";

        // Attachments are put into the body here rather than when it was
        // built: a file is read once, at the last moment, and its bytes never
        // pass through QML.
        const injections = root.strategy.attachmentInjections ?? [];
        if (injections.length > 0 && root.attachScriptPath.length > 0) {
            const spec = CF.StringUtils.shellSingleQuoteEscape(JSON.stringify(injections));
            const attachScript = `'${CF.StringUtils.shellSingleQuoteEscape(CF.FileUtils.trimFileProtocol(root.attachScriptPath))}'`;
            content += `attachResult=$(python3 ${attachScript} inject ${quotedBody} '${spec}'); attachExit=$?; if [ $attachExit -ne 0 ]; then printf '%s%s\\n' '${root.attachmentErrorMarker}' "$attachResult"; exit ${root.attachmentFailureExitCode}; fi\n`;
        }

        content += "curl --no-buffer -sS" + ` --connect-timeout ${root.connectTimeout}` + (root.requestTimeout > 0 ? ` --max-time ${root.requestTimeout}` : "") + ` -w '\\n${root.statusMarker}%{http_code}@@\\n'` + ` ${quotedEndpoint}` + ` ${headerString}` + (authHeader ? ` ${authHeader}` : "") + ` --data-binary @${quotedBody}` + "\n";

        return content;
    }

    function retryable(): bool {
        if (root.aborted || root.attachmentError.length > 0 || root.attempt >= root.maxRetries)
            return false;
        if (root.httpStatus === 429 || root.httpStatus >= 500)
            return true;
        // No status at all means curl never got a reply: DNS, connection
        // refused, TLS, or its own timeout.
        return root.httpStatus === 0 && root.exitCode !== 0;
    }

    function rollbackMessage() {
        if (!root.message)
            return;
        root.message.content = root.message.content.slice(0, root.contentMark);
        root.message.rawContent = root.message.rawContent.slice(0, root.rawContentMark);
        root.message.thinking = true;
    }

    FileView {
        id: scriptFile
    }

    FileView {
        id: bodyFile
    }

    Timer {
        id: retryTimer
        onTriggered: root.launch()
    }

    Timer {
        id: watchdog
        onTriggered: {
            if (!requestProc.running)
                return;
            console.log("[AiRequest] No answer within the timeout, killing the request");
            root.httpStatus = 0;
            requestProc.running = false;
        }
    }

    Process {
        id: requestProc

        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith(root.statusMarker)) {
                    root.httpStatus = parseInt(data.slice(root.statusMarker.length)) || 0;
                    return;
                }
                if (data.startsWith(root.attachmentErrorMarker)) {
                    root.attachmentError = data.slice(root.attachmentErrorMarker.length);
                    return;
                }
                if (data.length === 0)
                    return;
                if (root.requestTimeout > 0)
                    watchdog.restart();
                root.line(data);
            }
        }

        onExited: (exitCode, exitStatus) => {
            watchdog.stop();
            root.exitCode = exitCode;

            if (root.aborted) {
                root.finished("aborted", root.httpStatus, exitCode);
                return;
            }
            if (root.attachmentError.length > 0) {
                root.finished("attachmentError", root.httpStatus, exitCode);
                return;
            }
            if (root.retryable()) {
                root.attempt += 1;
                const delay = Math.min(8, Math.pow(2, root.attempt - 1));
                root.rollbackMessage();
                root.retrying(root.attempt, delay, root.httpStatus);
                retryTimer.interval = delay * 1000;
                retryTimer.restart();
                return;
            }
            const ok = exitCode === 0 && (root.httpStatus === 0 || (root.httpStatus >= 200 && root.httpStatus < 300));
            root.finished(ok ? "done" : "error", root.httpStatus, exitCode);
        }
    }
}
