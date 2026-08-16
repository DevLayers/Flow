pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions as CF
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services.ai

/**
 * Handles LLM chats: the conversation, the tools, and which model answers.
 *
 * Three wire formats are spoken, one strategy each: Google's Gemini API,
 * Anthropic's /v1/messages, and the OpenAI-compatible /v1/chat/completions
 * that OpenRouter, DeepSeek, Mistral and Ollama all serve. Which one a model
 * uses is its own `api_format`; nothing here tests provider names.
 */
Singleton {
    id: root

    property Component aiMessageComponent: AiMessageData {}
    property Component geminiApiStrategy: GeminiApiStrategy {}
    property Component openAiCompatStrategy: OpenAiCompatStrategy {}
    property Component anthropicApiStrategy: AnthropicApiStrategy {}
    readonly property string interfaceRole: "interface"
    readonly property string apiKeyEnvVarName: "API_KEY"

    signal responseFinished
    signal submissionStateChanged(var submission)
    signal submissionStarted(string submissionId, string runId, string sessionId)
    signal submissionFailed(string submissionId, string operationId, string errorCode, var recoveryActionIds)
    signal submissionCancelled(string submissionId, string reason)
    readonly property bool isGenerating: requester.running || root.pendingSubmissionId.length > 0
    /** Central AI availability contract shared by every host. */
    readonly property int aiPolicy: Number(Config.options?.policies?.ai ?? 1)
    readonly property bool enabled: root.aiPolicy !== 0
    readonly property bool onlineAllowed: root.aiPolicy === 1
    readonly property bool localOnly: root.aiPolicy === 2
    readonly property bool hasSelectableModel: root.catalog.modelIds.length > 0

    function canSubmit(modelId = ""): var {
        if (!root.enabled)
            return {
                allowed: false,
                reason: "disabled",
                recoveryActionIds: ["open-ai-policy"]
            };

        const id = String(modelId ?? "").trim() || root.currentModelId;
        const model = root.catalog.models[id] ?? null;
        if (!model)
            return {
                allowed: false,
                reason: "model-unavailable",
                recoveryActionIds: ["open-models"]
            };

        if (root.localOnly && !root.catalog.isModelLocal(model))
            return {
                allowed: false,
                reason: "remote-model-blocked",
                recoveryActionIds: ["open-models"]
            };

        if (model.requires_key && !KeyringStorage.loaded)
            return {
                allowed: false,
                reason: "keyring-loading",
                recoveryActionIds: ["retry-submit"]
            };

        if (model.requires_key && !(root.apiKeys?.[model.key_id]?.length > 0))
            return {
                allowed: false,
                reason: "missing-key",
                recoveryActionIds: ["open-keys"]
            };

        return {
            allowed: true,
            reason: "",
            recoveryActionIds: []
        };
    }

    function enforcePolicy() {
        root.runCoordinator.cancelByPolicy(root.localOnly);
        const blocksTransport = transport => transport.running && (!root.enabled || (root.localOnly && transport.model && !root.catalog.isModelLocal(transport.model)));
        if (blocksTransport(requester))
            root.stopGeneration();
        if (blocksTransport(keyTester))
            keyTester.abort();
        if (blocksTransport(titleRequester))
            titleRequester.abort();
        if (!root.onlineAllowed && commandExecutionProc.running)
            commandExecutionProc.running = false;
        if (!root.onlineAllowed && root.toolOverride === "search")
            root.toolOverride = "";
    }

    onAiPolicyChanged: root.enforcePolicy()

    // These are singletons owned by the facade. Visual hosts only observe
    // their projections; they never create a second repository or run slot.
    readonly property AiConversationRepository conversations: AiConversationRepository {}
    readonly property AiSurfaceRouter surfaceRouter: AiSurfaceRouter {}
    readonly property AiDraftStore draftStore: AiDraftStore {
        directory: Directories.aiDrafts
        scriptPath: Directories.aiDraftsScriptPath
        onStoreReady: root.onDraftStoreReady()
        onStoreError: reason => root.submissionNotice = reason
    }
    readonly property AiRunCoordinator runCoordinator: AiRunCoordinator {
        onRunStarted: run => root.onRunStarted(run)
        onRunActivity: (run, event) => root.onRunActivity(run, event)
        onRunFinished: run => root.onRunFinished(run)
    }
    property string currentRunId: ""
    property string currentRunSessionId: ""
    property string currentRunRequestId: ""
    property string currentRunResponseId: ""
    property var runningMessageIDs: []
    property var runningMessageByID: ({})
    property var pendingRunJournal: null
    property int submissionSequence: 0
    property string pendingSubmissionId: ""
    property var pendingSubmission: null
    property string submissionNotice: ""
    property int draftRevision: 0
    property bool restoringDraft: false

    onDraftChanged: {
        root.draftRevision += 1;
        if (!root.restoringDraft && root.draftStore.loaded)
            root.draftStore.setDraft(root.sessionDraftId(), root.draft);
    }

    function submissionOperationId(prefix) {
        root.submissionSequence += 1;
        return `${prefix}-${Date.now()}-${root.submissionSequence}`;
    }

    function rejectSubmission(errorCode, userMessage, recoveryActionIds) {
        root.submissionNotice = userMessage;
        root.submissionFailed("", "", errorCode, recoveryActionIds ?? []);
        root.addMessage(userMessage, root.interfaceRole, {
            "notice": "submission",
            "errorKind": errorCode
        });
        return {
            accepted: false,
            state: "rejected",
            errorCode: errorCode,
            userMessage: userMessage,
            recoveryActionIds: recoveryActionIds ?? []
        };
    }

    /**
     * Synchronous submit contract. It only validates immutable input and
     * reserves the one global pending slot; keyring and disk work continue
     * through correlated signals below.
     */
    function submit(text, context = null, source = "unknown") {
        const prompt = String(text ?? "");
        const files = Array.isArray(context?.attachments) ? context.attachments.slice() : root.attachments.slice();
        if (prompt.trim().length === 0 && files.length === 0)
            return root.rejectSubmission("empty-input", Translation.tr("Write a question or attach a file first."), ["focus-composer"]);
        if (root.pendingSubmissionId.length > 0 || requester.running || (root.runCoordinator.activeRunId.length > 0 && root.runCoordinator.activeStates.includes(root.runCoordinator.runFor(root.runCoordinator.activeRunId)?.state)))
            return root.rejectSubmission("busy", Translation.tr("AI is busy with another conversation. Open or stop the active run first."), ["open-active-run", "stop-active-run"]);

        const modelId = root.currentModelId;
        const model = root.catalog.models[modelId] ?? null;
        const profile = root.responseProfileForModel(modelId);
        const permission = root.canSubmit(modelId);
        const waitingForKeyring = !!model && model.requires_key && !KeyringStorage.loaded;
        if (!permission.allowed && !waitingForKeyring)
            return root.rejectSubmission(permission.reason || "unavailable", Translation.tr("This AI model is not ready to receive a message."), permission.recoveryActionIds ?? ["open-models"]);

        root.submissionSequence += 1;
        const submissionId = `submission-${Date.now()}-${root.submissionSequence}`;
        const pending = {
            submissionId: submissionId,
            operationId: root.submissionOperationId("submit"),
            source: String(source ?? "unknown"),
            text: prompt,
            attachments: files,
            modelId: modelId,
            responseMode: profile.responseMode,
            webMode: profile.webMode,
            functionExposure: profile.functionExposure,
            thinkingLevel: profile.thinkingLevel,
            temperature: root.temperature,
            systemPrompt: root.systemPrompt,
            toolOverride: profile.toolMode,
            profileFallback: profile.fallbackReason,
            profile: profile,
            draftRevisionAtSubmit: root.draftRevision,
            beforeSessionId: root.sessions.currentId,
            beforeSessionCreatedAt: root.sessionCreatedAt,
            baseMessageIDs: root.messageIDs.slice(),
            insertedIds: [],
            insertedObjects: ({}),
            state: waitingForKeyring ? "waitingKeyring" : "pending",
            cancelRequested: false,
            deferJournal: true
        };
        root.pendingSubmissionId = submissionId;
        root.pendingSubmission = pending;
        root.submissionStateChanged(pending);
        if (waitingForKeyring)
            KeyringStorage.fetchKeyringData();
        else
            Qt.callLater(root.resumePendingSubmission);
        return {
            accepted: true,
            submissionId: submissionId,
            operationId: pending.operationId,
            state: "pending"
        };
    }

    function resumePendingSubmission() {
        const pending = root.pendingSubmission;
        if (!pending || pending.submissionId !== root.pendingSubmissionId || pending.cancelRequested)
            return;
        if (pending.state === "preparing" || pending.state === "staging" || pending.state === "durableNotStarted" || pending.state === "networkStarting" || pending.state === "started")
            return;
        const model = root.catalog.models[pending.modelId] ?? null;
        const permission = root.canSubmit(pending.modelId);
        if (!permission.allowed) {
            if (permission.reason === "keyring-loading")
                return;
            root.failPendingSubmission(permission.reason || "unavailable", Translation.tr("This AI model is no longer available."), permission.recoveryActionIds ?? ["open-models"]);
            return;
        }
        if (!model || (root.sessions.currentId !== pending.beforeSessionId)) {
            root.failPendingSubmission("session-changed", Translation.tr("The chat changed while the request was preparing. Nothing was sent."), ["retry-submit"]);
            return;
        }
        for (let i = 0; i < pending.baseMessageIDs.length; i++) {
            if (root.messageIDs[i] !== pending.baseMessageIDs[i]) {
                root.failPendingSubmission("conversation-changed", Translation.tr("The conversation changed while the request was preparing. Nothing was sent."), ["retry-submit"]);
                return;
            }
        }
        pending.state = "preparing";
        root.submissionStateChanged(pending);
        Qt.callLater(() => {
            if (root.pendingSubmissionId === pending.submissionId)
                root.preparePendingSubmission(pending);
        });
    }

    function preparePendingSubmission(pending) {
        if (!pending || root.pendingSubmissionId !== pending.submissionId || pending.cancelRequested)
            return;
        if (root.sessions.currentId.length === 0) {
            root.sessions.currentId = root.sessions.newId();
            root.sessionCreatedAt = Date.now();
        }
        if (root.sessions.currentId !== pending.beforeSessionId && pending.beforeSessionId.length > 0) {
            root.failPendingSubmission("session-changed", Translation.tr("The chat changed while the request was preparing. Nothing was sent."), ["retry-submit"]);
            return;
        }
        pending.sessionId = root.sessions.currentId;
        const user = root.aiMessageComponent.createObject(root, {
            "role": "user",
            "content": pending.text.length > 0 ? pending.text : Translation.tr("(see attached)"),
            "rawContent": pending.text.length > 0 ? pending.text : Translation.tr("(see attached)"),
            "attachments": pending.attachments,
            "thinking": false,
            "done": true
        });
        const userId = root.idForMessage(user);
        pending.userMessageId = userId;
        pending.insertedIds = [userId];
        pending.insertedObjects[userId] = user;
        root.messageIDs = [...root.messageIDs, userId];
        root.messageByID[userId] = user;
        root.makeRequest(pending);
    }

    function rollbackPendingMessages(pending) {
        if (!pending)
            return;
        const removed = pending.insertedIds ?? [];
        for (let i = 0; i < removed.length; i++) {
            const id = removed[i];
            if (root.messageByID[id] !== pending.insertedObjects[id])
                continue;
            const message = root.messageByID[id];
            delete root.messageByID[id];
            root.messageIDs = root.messageIDs.filter(item => item !== id);
            message.destroy();
        }
        pending.insertedIds = [];
        if (pending.beforeSessionId.length === 0 && root.messageIDs.length === 0 && root.sessions.currentId === pending.sessionId) {
            root.sessions.currentId = "";
            root.sessionCreatedAt = pending.beforeSessionCreatedAt;
        }
    }

    function finishPendingSubmission(pending, cancelled, reason) {
        if (!pending || root.pendingSubmissionId !== pending.submissionId)
            return;
        const run = pending.runId ? root.runCoordinator.runFor(pending.runId) : null;
        if (run && !root.runCoordinator.terminalStates.includes(run.state))
            root.runCoordinator.finish(pending.runId, "cancelled", cancelled ? "cancelled" : "submissionFailed");
        root.rollbackPendingMessages(pending);
        if (pending.beforeSessionId.length === 0 && root.sessions.currentId === pending.sessionId) {
            root.sessions.currentId = "";
            root.sessionCreatedAt = pending.beforeSessionCreatedAt;
        }
        root.pendingSubmission = null;
        root.pendingSubmissionId = "";
        root.submissionNotice = cancelled ? Translation.tr("Message cancelled before it was sent.") : (pending.errorMessage ?? Translation.tr("The message could not be sent."));
        root.submissionStateChanged({
            submissionId: pending.submissionId,
            state: cancelled ? "cancelled" : "failed",
            reason: reason
        });
        if (cancelled)
            root.submissionCancelled(pending.submissionId, reason);
        else
            root.submissionFailed(pending.submissionId, pending.operationId ?? "", reason, pending.recoveryActionIds ?? []);
    }

    function failPendingSubmission(errorCode, userMessage, recoveryActionIds) {
        const pending = root.pendingSubmission;
        if (!pending || pending.state === "compensating")
            return;
        pending.errorCode = errorCode;
        pending.errorMessage = userMessage;
        pending.recoveryActionIds = recoveryActionIds ?? [];
        pending.cancelRequested = true;
        pending.state = "compensating";
        root.submissionStateChanged(pending);
        const pendingRun = pending.runId ? root.runCoordinator.runFor(pending.runId) : null;
        if (pendingRun && !root.runCoordinator.terminalStates.includes(pendingRun.state))
            root.runCoordinator.finish(pending.runId, "cancelled", "submissionFailed");
        root.rollbackPendingMessages(pending);
        if (pending.stateBeforeCompensation === "durableNotStarted" || pending.stateBeforeCompensation === "networkStarting" || pending.stateBeforeCompensation === "started") {
            const snapshot = root.messageIDs.length > 0 ? root.sessionToJson() : null;
            if (snapshot) {
                pending.compensationOperationId = root.sessions.commit(snapshot, root.submissionOperationId("compensate"), true);
                return;
            }
        }
        if (pending.stageOperationId) {
            pending.abortOperationId = root.sessions.abortSubmission(pending.sessionId, pending.stageOperationId, root.submissionOperationId("abort"));
            if (pending.abortOperationId)
                return;
        }
        root.finishPendingSubmission(pending, false, errorCode);
    }

    function cancelPendingSubmission(reason = "cancelled") {
        const pending = root.pendingSubmission;
        if (!pending)
            return false;
        pending.cancelRequested = true;
        pending.stateBeforeCompensation = pending.state;
        root.failPendingSubmission("cancelled", Translation.tr("Message cancelled before it was sent."), []);
        pending.cancelReason = reason;
        return true;
    }

    function handleSubmissionStageSucceeded(operationId, sessionId) {
        const pending = root.pendingSubmission;
        if (!pending || pending.stageOperationId !== operationId || pending.sessionId !== sessionId)
            return;
        if (pending.cancelRequested) {
            pending.stateBeforeCompensation = "durableNotStarted";
            root.failPendingSubmission("cancelled", Translation.tr("Message cancelled before it was sent."), []);
            return;
        }
        pending.state = "durableNotStarted";
        root.submissionStateChanged(pending);
        pending.commitOperationId = root.sessions.commitSubmissionForDispatch(sessionId, operationId, root.submissionOperationId("commit"));
    }

    function handleSubmissionCommitSucceeded(operationId, sessionId) {
        const pending = root.pendingSubmission;
        if (!pending || pending.commitOperationId !== operationId || pending.sessionId !== sessionId)
            return;
        if (pending.cancelRequested) {
            pending.stateBeforeCompensation = "durableNotStarted";
            root.failPendingSubmission("cancelled", Translation.tr("Message cancelled before it was sent."), []);
            return;
        }
        pending.state = "networkStarting";
        root.runCoordinator.transition(pending.runId, "thinking", "networkStarting", { "executionStarted": false });
        const snapshot = root.sessionToJson();
        pending.networkOperationId = root.sessions.commit(snapshot, root.submissionOperationId("network-start"), true);
        root.submissionStateChanged(pending);
    }

    function handleSubmissionSaveSucceeded(operationId, sessionId) {
        const pending = root.pendingSubmission;
        if (!pending || pending.networkOperationId !== operationId || pending.sessionId !== sessionId)
            if (!pending || pending.compensationOperationId !== operationId || pending.sessionId !== sessionId)
                return;
        if (pending.compensationOperationId === operationId) {
            if (pending.stageOperationId) {
                pending.abortOperationId = root.sessions.abortSubmission(sessionId, pending.stageOperationId, root.submissionOperationId("abort"));
                if (pending.abortOperationId)
                    return;
            }
            root.finishPendingSubmission(pending, pending.cancelReason === "user", "compensated");
            return;
        }
        root.dispatchPendingSubmission(pending);
    }

    function dispatchPendingSubmission(pending) {
        if (!pending || root.pendingSubmissionId !== pending.submissionId)
            return;
        if (pending.cancelRequested || !root.canSubmit(pending.modelId).allowed) {
            pending.stateBeforeCompensation = "networkStarting";
            root.failPendingSubmission("cancelled", Translation.tr("Message cancelled before it was sent."), []);
            return;
        }
        pending.state = "started";
        pending.deferJournal = false;
        root.runCoordinator.transition(pending.runId, "thinking", "networkStarted", {
            "executionStarted": true,
            "networkStartedAt": Date.now()
        });
        const prepared = pending.prepared;
        requester.model = prepared.model;
        requester.strategy = prepared.strategy;
        requester.message = prepared.message;
        requester.endpoint = prepared.endpoint;
        requester.requestData = prepared.requestData;
        requester.apiKey = prepared.apiKey;
        requester.parsedAny = false;
        if (root.draftRevision === pending.draftRevisionAtSubmit) {
            const sentDraft = root.draft;
            root.draft = "";
            root.draftStore.clearDraft(root.sessionDraftId(pending.beforeSessionId), sentDraft);
        }
        root.clearAttachments();
        root.submissionStateChanged(pending);
        root.submissionStarted(pending.submissionId, pending.runId, pending.sessionId);
        requester.start();
    }

    function handleSubmissionSaveFailed(operationId, sessionId, reason) {
        const pending = root.pendingSubmission;
        if (!pending)
            return;
        if (pending.compensationOperationId === operationId) {
            root.finishPendingSubmission(pending, pending.cancelReason === "user", reason);
            return;
        }
        if (pending.networkOperationId === operationId || pending.stageOperationId === operationId) {
            pending.stateBeforeCompensation = pending.state;
            root.failPendingSubmission("save-failed", Translation.tr("The message was not saved, so it was not sent."), ["retry-submit"]);
        }
    }

    function handleSubmissionStageFailed(operationId, sessionId, reason) {
        const pending = root.pendingSubmission;
        if (!pending || pending.stageOperationId !== operationId || pending.sessionId !== sessionId)
            return;
        pending.stateBeforeCompensation = "staging";
        root.finishPendingSubmission(pending, pending.cancelRequested, reason);
    }

    function handleSubmissionCommitFailed(operationId, sessionId, reason) {
        const pending = root.pendingSubmission;
        if (!pending || pending.commitOperationId !== operationId || pending.sessionId !== sessionId)
            return;
        pending.stateBeforeCompensation = "durableNotStarted";
        root.failPendingSubmission("save-failed", Translation.tr("The message was not saved, so it was not sent."), ["retry-submit"]);
    }

    function handleSubmissionAbortFinished(operationId, sessionId, reason) {
        const pending = root.pendingSubmission;
        if (!pending || pending.abortOperationId !== operationId || pending.sessionId !== sessionId)
            return;
        root.finishPendingSubmission(pending, pending.cancelReason === "user", reason);
    }

    Connections {
        target: KeyringStorage
        function onLoadedChanged() {
            if (KeyringStorage.loaded)
                root.resumePendingSubmission();
        }
    }

    function journalRun(sessionId: string, run: var) {
        root.pendingRunJournal = {
            sessionId: sessionId,
            run: run
        };
        runJournalTimer.restart();
    }

    function onRunStarted(run: var) {
        root.conversations.setRun(run.sessionId, run);
        const pending = root.pendingSubmission;
        if (pending && pending.submissionId === root.pendingSubmissionId && pending.sessionId === run.sessionId && pending.deferJournal) {
            pending.runPreview = run;
            return;
        }
        root.pendingRunJournal = {
            sessionId: run.sessionId,
            run: run
        };
        runJournalTimer.restart();
    }

    function onRunActivity(run: var, event: var) {
        root.conversations.setRun(run.sessionId, run);
        const pending = root.pendingSubmission;
        if (pending && pending.submissionId === root.pendingSubmissionId && pending.sessionId === run.sessionId && pending.deferJournal)
            return;
        if (run.sessionId === root.currentRunSessionId && root.runningMessageIDs.length > 0)
            root.conversations.capture(run.sessionId, root.runningSessionToJson());
        root.pendingRunJournal = {
            sessionId: run.sessionId,
            run: run
        };
        runJournalTimer.restart();
    }

    function onRunFinished(run: var) {
        root.conversations.setRun(run.sessionId, run);
        const pending = root.pendingSubmission;
        if (pending && pending.submissionId === root.pendingSubmissionId && pending.sessionId === run.sessionId && pending.state !== "started") {
            root.pendingRunJournal = null;
            if (root.currentRunId === run.runId)
                root.currentRunId = "";
            if (run.resultReason === "cancelledByPolicy" || run.resultReason === "disabledByPolicy") {
                pending.stateBeforeCompensation = pending.state;
                root.failPendingSubmission("policy-changed", Translation.tr("The AI policy changed before this message was sent."), ["retry-submit"]);
            }
            return;
        }
        if (run.sessionId === root.currentRunSessionId && root.runningMessageIDs.length > 0)
            root.conversations.capture(run.sessionId, root.runningSessionToJson());
        root.pendingRunJournal = null;
        root.commitRunSession(run.sessionId, true);
        if (root.currentRunId === run.runId)
            root.currentRunId = "";
        if (pending && pending.submissionId === root.pendingSubmissionId && pending.sessionId === run.sessionId) {
            root.pendingSubmission = null;
            root.pendingSubmissionId = "";
        }
    }

    function commitRunSession(sessionId: string, flushNow = false) {
        const id = String(sessionId ?? "");
        if (!id)
            return;
        if (id === root.sessions.currentId) {
            root.commitSession(flushNow);
            return;
        }
        if (id === root.currentRunSessionId && root.runningMessageIDs.length > 0)
            root.conversations.capture(id, root.runningSessionToJson());
        const snapshot = root.conversations.snapshot(id);
        if (snapshot)
            root.sessions.commit(snapshot, "", flushNow);
    }

    Timer {
        id: runJournalTimer
        interval: 700
        onTriggered: {
            const pending = root.pendingRunJournal;
            root.pendingRunJournal = null;
            if (!pending)
                return;
            root.commitRunSession(pending.sessionId, false);
        }
    }

    // Set while a failed request waits to be sent again, so the UI can say so
    // instead of looking stuck.
    property string retryNotice: ""
    // A tool exchange asked for another turn while the current one was still
    // streaming. Sent as soon as it ends.
    property bool followUpQueued: false
    /** Tool calls returned in one assistant turn, waiting for their turn. */
    property var pendingToolCalls: []
    property string activeToolCallId: ""
    // Session-owned metadata that survives a Search/sidebar handoff and a
    // restart. Message-level arrays remain the rich-rendering source.
    property list<string> sessionSearchQueries: []
    property var sessionSources: []
    property var sessionToolCheckpoints: []

    function recordToolCheckpoint(entry: var) {
        if (!entry || entry.serial === undefined)
            return;
        const sessionId = root.currentRunSessionId || root.sessions.currentId;
        const visible = sessionId === root.sessions.currentId;
        const snapshot = visible ? null : root.conversations.snapshot(sessionId);
        const current = Array.from(visible ? (root.sessionToolCheckpoints ?? []) : (snapshot?.toolCheckpoints ?? []));
        const index = current.findIndex(item => item.serial === entry.serial);
        const nextEntry = Object.assign({}, entry, {
            sessionId: sessionId
        });
        if (index >= 0)
            current[index] = nextEntry;
        else
            current.push(nextEntry);
        const checkpoints = current.slice(-100);
        if (visible) {
            root.sessionToolCheckpoints = checkpoints;
            root.sessions.scheduleSave();
        } else if (snapshot) {
            root.conversations.capture(sessionId, Object.assign({}, snapshot, {
                toolCheckpoints: checkpoints,
                updatedAt: Date.now()
            }));
            root.commitRunSession(sessionId, false);
        }
    }

    function updateSessionGrounding(message: AiMessageData, sessionId = "") {
        if (!message)
            return;
        const targetSessionId = String(sessionId || root.currentRunSessionId || root.sessions.currentId);
        const visible = targetSessionId === root.sessions.currentId;
        const snapshot = visible ? null : root.conversations.snapshot(targetSessionId);
        let sessionQueries = Array.from(visible ? root.sessionSearchQueries : (snapshot?.searchQueries ?? []));
        let sessionSources = Array.from(visible ? root.sessionSources : (snapshot?.sources ?? []));
        const queries = Array.from(message.searchQueries ?? []).map(value => String(value)).filter(value => value.length > 0);
        if (queries.length > 0)
            sessionQueries = [...new Set([...sessionQueries, ...queries])].slice(-50);
        const incoming = Array.from(message.annotationSources ?? []);
        if (incoming.length > 0) {
            const byUrl = {};
            sessionSources.concat(incoming).forEach(source => {
                const url = String(source?.url ?? "");
                const key = url.length > 0 ? url : JSON.stringify(source);
                byUrl[key] = source;
            });
            sessionSources = Object.values(byUrl).slice(-100);
        }
        if (visible) {
            root.sessionSearchQueries = sessionQueries;
            root.sessionSources = sessionSources;
        } else if (snapshot) {
            root.conversations.capture(targetSessionId, Object.assign({}, snapshot, {
                searchQueries: sessionQueries,
                sources: sessionSources,
                updatedAt: Date.now()
            }));
            root.commitRunSession(targetSessionId, false);
        }
    }

    /**
     * What the model is told before anything else, with the values filled in.
     *
     * Three places can hold a prompt and the nearest one wins: what this chat
     * was given, then the persona in force, then the one in the settings. A
     * chat that was opened with a prompt keeps answering the way it did, even
     * if the persona has moved on since.
     */
    readonly property string systemPrompt: root.substituted(root.basePrompt)

    readonly property string basePrompt: {
        if (root.promptOverride.length > 0)
            return root.promptOverride;
        const persona = root.personas.byId(root.sessionPersonaId);
        if (persona?.systemPrompt?.length > 0)
            return persona.systemPrompt;
        return Config.options?.ai?.systemPrompt ?? "";
    }

    /** This chat's own prompt. Saved with it, and empty for most chats. */
    property string promptOverride: ""

    function substituted(text: string): string {
        let prompt = String(text ?? "");
        for (let key in root.promptSubstitutions) {
            // QML/JS doesn't support replaceAll, so use split/join
            prompt = prompt.split(key).join(root.promptSubstitutions[key]);
        }
        return prompt;
    }
    // property var messages: []
    property var messageIDs: []
    property var messageByID: ({})
    readonly property var apiKeys: KeyringStorage.keyringData?.apiKeys ?? {}
    readonly property var apiKeysLoaded: KeyringStorage.loaded
    readonly property bool currentModelHasApiKey: {
        const model = root.currentModelEntry;
        if (!model || !model.requires_key)
            return true;
        if (!apiKeysLoaded)
            return false;
        const key = apiKeys[model.key_id];
        return (key?.length > 0);
    }
    property var postResponseHook
    property real temperature: 0.5
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        // Part of the output that was spent reasoning. -1 when the provider
        // does not break it out.
        property int thinking: -1
        property int total: -1
    }
    readonly property var thinkingLevels: ["off", "low", "medium", "high"]
    property string thinkingLevel: "medium"
    /** Session-scoped profile requests; empty response mode keeps legacy thinking levels. */
    property string sessionResponseMode: ""
    property string sessionWebMode: ""
    property string sessionFunctionExposure: ""
    readonly property string responseMode: sessionResponseMode.length > 0
        ? AiResponseProfiles.normalizeResponseMode(sessionResponseMode)
        : AiResponseProfiles.responseModeForThinking(thinkingLevel)
    readonly property var responseProfile: root.responseProfileForModel(root.currentModelId)
    readonly property string webMode: root.responseProfile.webMode
    readonly property string functionExposure: root.responseProfile.functionExposure
    readonly property bool canForceWeb: root.responseProfile.canForceWeb
    property string sessionModelId: ""
    property string sessionPersonaId: ""
    readonly property string defaultModelId: {
        const explicit = Persistent.states?.ai?.defaultModelId ?? "";
        return explicit.length > 0 ? explicit : (Persistent.states?.ai?.modelId ?? "");
    }
    readonly property real defaultTemperature: {
        const explicit = Persistent.states?.ai?.defaultTemperature ?? -1;
        return explicit >= 0 ? explicit : (Persistent.states?.ai?.temperature ?? 0.5);
    }
    readonly property string defaultThinkingLevel: {
        const explicit = Persistent.states?.ai?.defaultThinkingLevel ?? "";
        return explicit.length > 0 ? explicit : (Persistent.states?.ai?.thinkingLevel ?? "medium");
    }
    readonly property string defaultPersonaId: {
        const explicit = Persistent.states?.ai?.defaultPersonaId ?? "";
        return explicit.length > 0 ? explicit : (Persistent.states?.ai?.personaId ?? "");
    }
    // Whether the current model reasons at all, and whether it can be told
    // not to. The control bar reads both; nothing here tests provider names.
    readonly property bool currentModelThinks: root.currentModelEntry?.thinking ?? false
    readonly property bool currentModelAlwaysThinks: root.currentModelEntry?.thinkingAlwaysOn ?? false

    function responseProfileForModel(modelId) {
        const model = root.catalog.models[String(modelId ?? "")] ?? null;
        return AiResponseProfiles.reconcile(model, {
            responseMode: root.responseMode,
            thinkingLevel: root.sessionResponseMode.length === 0 ? root.thinkingLevel : "",
            webMode: root.sessionWebMode.length > 0 ? root.sessionWebMode : "auto",
            functionExposure: root.sessionFunctionExposure.length > 0 ? root.sessionFunctionExposure : "all"
        }, root.onlineAllowed, root.configuredTool);
    }

    /**
     * Ids are handed out once and kept: they are written to the session file
     * and read back with it, so a chat that has been reopened is still keyed
     * the way it was written. Everything that points at a message — deleting,
     * regenerating, forking — points at one of these.
     */
    function idForMessage(message) {
        return root.sessions.newId();
    }

    property list<var> defaultPrompts: []
    property list<var> userPrompts: []
    property list<var> promptFiles: [...defaultPrompts, ...userPrompts]
    /** Path of the prompt file last loaded, so the picker can show which one won. */
    property string currentPromptFile: ""

    property var promptSubstitutions: {
        "{DISTRO}": SystemInfo.distroName,
        "{DATETIME}": `${DateTime.time}, ${DateTime.collapsedCalendarFormat}`,
        "{WINDOWCLASS}": ToplevelManager.activeToplevel?.appId ?? "Unknown",
        "{DE}": `${SystemInfo.desktopEnvironment} (${SystemInfo.windowingSystem})`
    }

    // Which tools exist, what they are allowed to do, and what they did is
    // all in AiTools. What is tracked here is only the mode in use, which is
    // the config's answer unless a turn borrowed another one — the search
    // dance does exactly that. Assigning the mode directly would break the
    // binding to the config, and the settings page would stop reaching the
    // chat for the rest of the session.
    property string toolOverride: ""
    readonly property string configuredTool: root.toolOverride.length > 0 ? root.toolOverride : (Config.options?.ai?.tools?.mode ?? "functions")
    readonly property string currentTool: !root.onlineAllowed && root.configuredTool === "search" ? "none" : root.configuredTool
    readonly property AiTools toolbox: AiTools {
        apiFormat: root.currentModelEntry?.api_format ?? "openai"
        searchAvailable: root.currentModelEntry?.builtinSearch ?? false
        functionExposure: root.responseProfile.functionExposure
        localOnly: root.localOnly
        onCallCheckpointChanged: entry => root.recordToolCheckpoint(entry)
    }
    readonly property var availableTools: root.toolbox.availableModes.filter(mode => root.onlineAllowed || mode !== "search")
    readonly property var toolDescriptions: root.toolbox.modeDescriptions

    // Providers and models are described once, in the catalog. Nothing here
    // builds a model object or tests a provider name for substrings.
    readonly property ModelCatalog catalog: ModelCatalog {
        ollamaModelNames: root.ollamaModels
    }
    property var ollamaModels: []

    readonly property var providers: root.catalog.providers
    readonly property var providerIds: root.catalog.providerIds

    // The persisted id is validated on read: it can be stale (a renamed model,
    // a provider dropped by policy, a config the user edited). A stale id
    // falls back to its own provider's default before it falls back to the
    // first provider, so a model that disappeared keeps the account it was
    // billed to.
    readonly property string currentModelId: {
        const wanted = root.sessionModelId.length > 0 ? root.sessionModelId : root.defaultModelId;
        if (root.catalog.models[wanted])
            return wanted;
        const provider = root.providers[wanted.split(":")[0]] ?? root.providers[root.providerIds[0] ?? ""] ?? null;
        return provider?.defaultModel?.id ?? "";
    }
    // The two halves of the id, for the places that address one of them. A
    // model value can hold colons of its own (Ollama tags), the provider
    // cannot, so the split is at the first one only.
    readonly property string currentProvider: root.currentModelId.split(":")[0] ?? ""
    readonly property string currentModel: root.currentModelId.split(":").slice(1).join(":")
    readonly property AiModel currentModelEntry: root.catalog.models[root.currentModelId] ?? null

    /**
     * Every model by catalog id, plus one entry per provider id pointing at
     * that provider's current pick. Chats saved before ids became
     * "provider:model" stored the bare provider, so both shapes resolve.
     */
    readonly property var models: {
        const result = {};
        const catalogModels = root.catalog.models;
        for (const id in catalogModels) {
            result[id] = catalogModels[id];
        }
        const ids = root.providerIds;
        for (let i = 0; i < ids.length; i++) {
            const providerId = ids[i];
            const model = (providerId === root.currentProvider) ? root.currentModelEntry : root.providers[providerId].defaultModel;
            if (model)
                result[providerId] = model;
        }
        return result;
    }
    property var modelList: Object.keys(root.models)

    /** {providerId: [{title, value, modelProvider}, ...]}, for the pickers. */
    readonly property var modelsOfProviders: {
        const result = {};
        const ids = root.providerIds;
        for (let i = 0; i < ids.length; i++) {
            result[ids[i]] = root.catalog.selectionEntries(ids[i]);
        }
        return result;
    }

    function getModelProvider(providerKey, modelValue) {
        return root.catalog.resolve(providerKey, modelValue)?.modelProvider || null;
    }

    /**
     * Turns whatever the user typed into a catalog id: a full "provider:model"
     * id, a provider name (its default model), or a bare model name (looked up
     * in the current provider first, then anywhere).
     */
    function resolveModelId(query) {
        const wanted = String(query ?? "").trim();
        if (wanted.length === 0)
            return "";
        if (root.catalog.models[wanted])
            return wanted;
        const provider = root.providers[wanted.toLowerCase()];
        if (provider)
            return provider.defaultModel?.id ?? "";
        const inCurrentProvider = root.catalog.resolve(root.currentProvider, wanted);
        if (inCurrentProvider)
            return inCurrentProvider.id;
        const catalogModels = root.catalog.models;
        for (const id in catalogModels) {
            if (catalogModels[id].value === wanted)
                return id;
        }
        return "";
    }

    property var apiStrategies: {
        const openAiCompat = openAiCompatStrategy.createObject(this);
        return {
            "openai": openAiCompat,
            // Mistral speaks the same dialect. The name is kept because user
            // configs (and the shipped default) still ask for it.
            "mistral": openAiCompat,
            "gemini": geminiApiStrategy.createObject(this),
            "anthropic": anthropicApiStrategy.createObject(this)
        };
    }
    property ApiStrategy currentApiStrategy: apiStrategies[root.currentModelEntry?.api_format || "openai"]

    property string requestScriptFilePath: `/tmp/quickshell-${SystemInfo.username}/ai/request.sh`

    Component.onCompleted: {
        root.migrateAiDefaults();
        root.resetSessionSettings();
        root.sessions.ensureLoaded();
        root.draftStore.ensureLoaded();
        setModel(currentModelId, false, false); // Do necessary setup for model
    }

    // Boot-time index: Ollama models + default prompts + user prompts —
    // all in ONE Process spawn. Replaces four parallel
    // `Process { running: true }` invocations that fired on every boot
    // even if the user had never opened the AI panel.
    // Gated by Config.options.ai.indexAtStartup: when false, no fork happens
    // until the user opens the AI panel. Policy No also prevents indexing.
    // This is
    // particularly useful for users without ollama installed (the
    // previous incarnation spawned a script that blocked ~50ms probing
    // the daemon on every boot).
    Process {
        id: aiIndexProc
        running: root.enabled && (Config?.options?.ai?.indexAtStartup ?? true)
        command: [
            "python3",
            Directories.scriptPath + "/ai/ai_index.py".replace(/file:\/\//, ""),
            Directories.defaultAiPrompts.toString().replace(/file:\/\//, ""),
            Directories.userAiPrompts.toString().replace(/file:\/\//, "")
        ]
        stdout: StdioCollector {
            id: aiIndexCollector
            onStreamFinished: {
                const raw = aiIndexCollector.text.trim()
                if (raw.length === 0)
                    return
                let parsed
                try {
                    parsed = JSON.parse(raw)
                } catch (e) {
                    console.log("Ai index parse error:", e)
                    return
                }

                // Ollama models: handed to the catalog, which turns them into
                // the "ollama" provider's model list.
                if (Array.isArray(parsed.ollama_models))
                    root.ollamaModels = parsed.ollama_models

                // Prompts (already absolute, filtered by extension)
                if (Array.isArray(parsed.default_prompts))
                    root.defaultPrompts = parsed.default_prompts
                if (Array.isArray(parsed.user_prompts))
                    root.userPrompts = parsed.user_prompts
            }
        }
    }

    FileView {
        id: promptLoader
        watchChanges: false
        // The command prints the prompt it loaded; picking one from the
        // control bar does not, since the chip already shows which is active.
        property bool announce: true
        onLoadedChanged: {
            if (!promptLoader.loaded)
                return;
            // Loading a prompt gives it to this chat, not to every chat. The
            // one in the settings is what a chat falls back to, and it is not
            // rewritten from here any more.
            root.promptOverride = promptLoader.text();
            root.sessions.scheduleSave();
            if (promptLoader.announce)
                root.addMessage(Translation.tr("This chat now uses the prompt in %1.").arg(root.currentPromptFile), root.interfaceRole);
        }
    }

    function printPrompt() {
        root.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(root.systemPrompt), root.interfaceRole);
    }

    function loadPrompt(filePath, feedback = true) {
        promptLoader.announce = feedback;
        root.currentPromptFile = filePath;
        promptLoader.path = ""; // Unload
        promptLoader.path = filePath; // Load
        promptLoader.reload();
    }

    function addMessage(message, role, extra = null) {
        if (message.length === 0)
            return;
        const aiMessage = aiMessageComponent.createObject(root, Object.assign({
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true
        }, extra ?? ({})));
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function removeMessage(messageId: string) {
        if (!root.messageByID[messageId])
            return;
        root.messageIDs = root.messageIDs.filter(id => id !== messageId);
        delete root.messageByID[messageId];
        root.sessions.scheduleSave();
    }

    /**
     * Says a key is missing, as a card with a button rather than as a wall of
     * instructions. Nobody reads a paragraph telling them to type a command.
     */
    function addApiKeyAdvice(model) {
        root.addMessage(Translation.tr("%1 needs an API key.").arg(model.name), root.interfaceRole, {
            "notice": "apiKey"
        });
    }

    function getModel() {
        return root.currentModelEntry;
    }

    /** Selects a model, by catalog id, provider name or bare model name. */
    function setModel(modelId, feedback = true, setPersistentState = true) {
        const model = root.catalog.models[root.resolveModelId(modelId)] ?? null;
        if (!model) {
            if (feedback)
                root.addMessage(Translation.tr("Invalid model. Supported:\n\n- %1").arg(root.catalog.modelIds.join("\n- ")), root.interfaceRole);
            return false;
        }
        root.sessionModelId = model.id;
        root.thinkingLevel = root.responseProfileForModel(model.id).thinkingLevel;
        if (setPersistentState)
            root.rememberModel(model.id);
        if (feedback)
            root.addMessage(Translation.tr("Model set to %1").arg(model.name), root.interfaceRole);
        if (model.requires_key && root.apiKeysLoaded && !(root.apiKeys[model.key_id]?.length > 0))
            root.addApiKeyAdvice(model);
        return true;
    }

    /** Ids of models picked before, newest first, minus the one in use. */
    readonly property var recentModelIds: {
        const remembered = Array.from(Persistent.states?.ai?.recentModels ?? []);
        return remembered.filter(id => id !== root.currentModelId && root.catalog.models[id]);
    }

    function rememberModel(modelId: string) {
        if (!Persistent.states?.ai)
            return;
        const remembered = Array.from(Persistent.states.ai.recentModels ?? []).filter(id => id !== modelId);
        remembered.unshift(modelId);
        Persistent.states.ai.recentModels = remembered.slice(0, 6);
    }

    /** Switches provider, landing on that provider's first model. */
    function setProvider(providerId, feedback = true) {
        const provider = root.providers[String(providerId ?? "").trim().toLowerCase()] ?? null;
        if (!provider) {
            if (feedback)
                root.addMessage(Translation.tr("Invalid provider. Supported:\n\n- %1").arg(root.providerIds.join("\n- ")), root.interfaceRole);
            return false;
        }
        if (!provider.defaultModel) {
            if (feedback)
                root.addMessage(Translation.tr("%1 has no models yet. Add one in the AI settings page.").arg(provider.name), root.interfaceRole);
            return false;
        }
        return root.setModel(provider.defaultModel.id, feedback);
    }

    function setTool(tool) {
        if (Array.from(root.availableTools).indexOf(tool) === -1) {
            root.addMessage(Translation.tr("Invalid tool. Supported tools:\n- %1").arg(Array.from(root.availableTools).join("\n- ")), root.interfaceRole);
            return false;
        }
        Config.options.ai.tools.mode = tool;
        root.toolOverride = "";
        return true;
    }

    function getTemperature() {
        return root.temperature;
    }

    /** Top of the range the model in use accepts. Anthropic stops at 1. */
    readonly property real maxTemperature: root.currentModelEntry?.maxTemperature ?? 2.0

    function setTemperature(value, feedback = true) {
        const limit = root.maxTemperature;
        if (isNaN(value) || value < 0 || value > limit) {
            if (feedback)
                root.addMessage(Translation.tr("Temperature must be between 0 and %1").arg(limit), Ai.interfaceRole);
            return;
        }
        root.temperature = value;
        if (feedback)
            root.addMessage(Translation.tr("Temperature set to %1").arg(value), Ai.interfaceRole);
    }

    function setThinkingLevel(level): bool {
        const value = String(level).trim().toLowerCase();
        if (root.thinkingLevels.indexOf(value) < 0) {
            root.addMessage(Translation.tr("Thinking level must be one of:\n- %1").arg(root.thinkingLevels.join("\n- ")), root.interfaceRole);
            return false;
        }
        root.sessionResponseMode = "";
        root.thinkingLevel = (root.currentModelAlwaysThinks && value === "off") ? "low" : value;
        root.sessions.scheduleSave();
        return true;
    }

    function setResponseMode(mode, feedback = true) {
        const value = AiResponseProfiles.normalizeResponseMode(mode);
        root.sessionResponseMode = value;
        const profile = root.responseProfileForModel(root.currentModelId);
        root.thinkingLevel = profile.thinkingLevel;
        root.sessions.scheduleSave();
        if (feedback)
            root.addMessage(Translation.tr("Response mode: %1").arg(value), root.interfaceRole);
        return true;
    }

    function setWebMode(mode, feedback = true) {
        const value = AiResponseProfiles.normalizeWebMode(mode);
        root.sessionWebMode = value;
        const profile = root.responseProfileForModel(root.currentModelId);
        root.sessions.scheduleSave();
        if (feedback && profile.webMode !== value)
            root.addMessage(Translation.tr("Web mode fell back to %1 for this model.").arg(profile.webMode), root.interfaceRole);
        return true;
    }

    function setFunctionExposure(exposure, feedback = true) {
        const value = AiResponseProfiles.normalizeFunctionExposure(exposure);
        root.sessionFunctionExposure = value;
        root.sessions.scheduleSave();
        if (feedback)
            root.addMessage(Translation.tr("Tool exposure: %1").arg(value), root.interfaceRole);
        return true;
    }

    function setApiKey(key) {
        const model = root.currentModelEntry;
        if (!model)
            return;
        if (!model.requires_key) {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
            return;
        }
        if (!key || key.length === 0) {
            root.addApiKeyAdvice(model);
            return;
        }
        KeyringStorage.setNestedField(["apiKeys", model.key_id], key.trim());
        root.addMessage(Translation.tr("API key set for %1").arg(model.name), Ai.interfaceRole);
    }

    /**
     * Says whether a key is set. It never prints one: the chat is a visible,
     * screenshot-able, screen-shared surface, and a secret written into it
     * stays there.
     */
    function printApiKey() {
        const model = root.currentModelEntry;
        if (!model)
            return;
        if (!model.requires_key) {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), root.interfaceRole);
            return;
        }
        const key = root.apiKeys[model.key_id];
        if (!key) {
            root.addApiKeyAdvice(model);
            return;
        }
        root.addMessage(Translation.tr("A key is set for %1 (ending %2). Open the key panel to see or change it.").arg(model.name).arg(key.slice(-4)), root.interfaceRole, {
            "notice": "apiKey"
        });
    }

    /** Whether a provider has a key on file, for the key panel's state dots. */
    function hasApiKey(keyId: string): bool {
        return (root.apiKeys?.[keyId]?.length ?? 0) > 0;
    }

    function setApiKeyFor(keyId: string, key: string) {
        if (!keyId || keyId.length === 0)
            return;
        KeyringStorage.setNestedField(["apiKeys", keyId], String(key ?? "").trim());
    }

    // ── Does this key work? ───────────────────────────────────────────────
    // One very small request, whose answer nobody reads. The only thing worth
    // knowing is what the endpoint says about the key, in words rather than
    // as an HTTP number.

    property string keyTestId: ""
    /** "", "running", "ok" or "failed". */
    property string keyTestState: ""
    property string keyTestMessage: ""
    property AiMessageData keyTestMessageData: AiMessageData {}

    function testApiKey(keyId: string) {
        if (keyTester.running)
            return;
        const model = root.catalog.modelIds.map(id => root.catalog.models[id]).find(entry => entry.key_id === keyId && entry.requires_key);
        if (!model) {
            root.keyTestId = keyId;
            root.keyTestState = "failed";
            root.keyTestMessage = Translation.tr("No model uses this key.");
            return;
        }
        const permission = root.canSubmit(model.id);
        if (!permission.allowed) {
            root.keyTestId = keyId;
            root.keyTestState = "failed";
            root.keyTestMessage = Translation.tr("This model is unavailable under the current AI policy.");
            return;
        }
        const key = root.apiKeys?.[keyId] ?? "";
        if (key.length === 0) {
            root.keyTestId = keyId;
            root.keyTestState = "failed";
            root.keyTestMessage = Translation.tr("No key to test.");
            return;
        }
        const strategy = root.titleStrategyFor(model.api_format || "openai");
        const prompt = root.aiMessageComponent.createObject(root, {
            "role": "user",
            "content": "Hi",
            "rawContent": "Hi",
            "thinking": false,
            "done": true
        });
        strategy.thinkingOverride = "off";
        strategy.outputOverride = 16;
        const data = strategy.buildRequestData(model, [prompt], "Reply with one word.", 0, null);
        strategy.thinkingOverride = "";
        strategy.outputOverride = 0;
        prompt.destroy();

        root.keyTestId = keyId;
        root.keyTestState = "running";
        root.keyTestMessage = "";
        keyTester.model = model;
        keyTester.strategy = strategy;
        keyTester.message = root.keyTestMessageData;
        keyTester.endpoint = strategy.buildEndpoint(model);
        keyTester.requestData = data;
        keyTester.apiKey = key;
        keyTester.start();
    }

    AiRequest {
        id: keyTester
        apiKeyEnvVarName: root.apiKeyEnvVarName
        scriptPath: `/tmp/quickshell-${SystemInfo.username}/ai/keytest.sh`
        // One attempt: a key that is refused is refused, and waiting through
        // two backoffs to be told so is not a test.
        maxRetries: 0

        onFinished: (reason, status, code) => {
            if (reason === "done") {
                root.keyTestState = "ok";
                root.keyTestMessage = Translation.tr("The key works.");
                return;
            }
            root.keyTestState = "failed";
            const kind = root.transportErrorKind(status, code);
            if (kind === "auth")
                root.keyTestMessage = Translation.tr("Refused: the key is wrong, or not allowed to use this model.");
            else if (kind === "quota")
                root.keyTestMessage = Translation.tr("The key is valid but out of quota for now.");
            else if (kind === "network" || kind === "timeout")
                root.keyTestMessage = Translation.tr("Could not reach the provider.");
            else
                root.keyTestMessage = Translation.tr("The provider answered with HTTP %1.").arg(status);
        }
    }

    function printTemperature() {
        root.addMessage(Translation.tr("Temperature: %1").arg(root.temperature), Ai.interfaceRole);
    }

    function clearMessages() {
        root.messageIDs = [];
        root.messageByID = ({});
        root.tokenCount.input = -1;
        root.tokenCount.output = -1;
        root.tokenCount.thinking = -1;
        root.tokenCount.total = -1;
    }

    function markDone(message: AiMessageData) {
        // A stream can say it is over more than once — a finish reason, then a
        // trailing usage frame, then the process exiting. The chat is only
        // saved, and the hook only run, for the first of them.
        if (!message || message.done)
            return;
        message.done = true;
        if (root.postResponseHook) {
            root.postResponseHook();
            root.postResponseHook = null; // Reset hook after use
        }
        const runSessionId = root.currentRunSessionId;
        if (!runSessionId || runSessionId === root.sessions.currentId)
            root.autoTitle(); // Names it first, so the write below carries the name
        root.commitRunSession(runSessionId || root.sessions.currentId, true);
        root.responseFinished();
    }

    /**
     * What went wrong, as something the transcript can act on rather than as
     * prose in the bubble: a 429 and an answer used to look the same.
     */
    function transportErrorKind(status: int, code: int): string {
        if (status === 401 || status === 403)
            return "auth";
        if (status === 404)
            return "notFound";
        if (status === 429)
            return "quota";
        if (status >= 500)
            return "server";
        if (status >= 400)
            return "request";
        if (code === 28)
            return "timeout";
        if (code === 6 || code === 7)
            return "network";
        return "unknown";
    }

    /** What to try next, in one line, for the error card's second row. */
    function transportErrorAdvice(kind: string): string {
        const model = root.currentModelEntry;
        if (kind === "auth")
            return Translation.tr("Check the key for %1.").arg(model?.name ?? Translation.tr("this provider"));
        if (kind === "quota")
            return Translation.tr("Wait a moment, or use a model with room left.");
        if (kind === "notFound")
            return Translation.tr("The model name or endpoint is wrong. Pick another model.");
        if (kind === "server")
            return Translation.tr("The provider is having trouble. Sending it again usually works.");
        if (kind === "network")
            return Translation.tr("Nothing answered. Check the connection, or whether the local server is up.");
        if (kind === "timeout")
            return Translation.tr("No answer in time. A shorter question, or a longer timeout in settings.");
        return "";
    }

    function attachmentErrorText(raw: string): string {
        try {
            const result = JSON.parse(raw);
            if (Array.isArray(result.failed) && result.failed.length > 0)
                return Translation.tr("Could not attach: %1").arg(result.failed.join(", "));
            if (result.error)
                return Translation.tr("Could not attach the file: %1").arg(result.error);
        } catch (e) {
            // Keep a useful message even if a helper failure was not JSON.
        }
        return Translation.tr("Could not attach one or more files. Nothing was sent.");
    }

    /**
     * Sends the failed turn again. Nothing is forked: an answer that never
     * arrived is not a branch worth keeping.
     */
    function retryMessage(messageId: string) {
        const message = root.messageByID[messageId];
        if (!message || requester.running)
            return;
        const at = root.messageIDs.indexOf(messageId);
        if (at < 0)
            return;
        root.messageIDs = root.messageIDs.filter(id => id !== messageId);
        delete root.messageByID[messageId];
        root.makeRequest();
    }

    /**
     * Human-readable reason a request came back with nothing to show.
     */
    function transportErrorText(status: int, code: int): string {
        if (status === 401 || status === 403)
            return Translation.tr("**Request rejected** (HTTP %1). The API key is missing, wrong, or not allowed to use this model.").arg(status);
        if (status === 404)
            return Translation.tr("**Not found** (HTTP 404). The model name or the endpoint is wrong.");
        if (status === 429)
            return Translation.tr("**Rate limited** (HTTP 429). Too many requests, or the quota for this key is used up.");
        if (status >= 500)
            return Translation.tr("**The provider failed** (HTTP %1). Nothing to do but try again.").arg(status);
        if (status >= 400)
            return Translation.tr("**Request failed** (HTTP %1).").arg(status);
        if (code === 28)
            return Translation.tr("**Timed out.** No answer within %1 s.").arg(requester.requestTimeout);
        if (code === 6 || code === 7)
            return Translation.tr("**Could not reach the endpoint.** Check the connection, or whether the local server is running.");
        return Translation.tr("**Request failed** (exit code %1).").arg(code);
    }

    AiRequest {
        id: requester
        apiKeyEnvVarName: root.apiKeyEnvVarName
        scriptPath: root.requestScriptFilePath
        attachScriptPath: Directories.aiAttachScriptPath

        /**
         * Whether any line of this response parsed. curl reports the status
         * after the body, so a failing request looks exactly like a streaming
         * one until it ends: its error JSON goes through the parser, throws,
         * and lands in the bubble as text. Nothing having parsed by the end is
         * what says that text was never an answer.
         */
        onLine: data => {
            if (root.currentRunId.length > 0)
                root.runCoordinator.activity(root.currentRunId, "stream", { "bytes": String(data ?? "").length });
            if (requester.message.thinking)
                requester.message.thinking = false;
            // console.log("[Ai] Raw response line: ", data);

            try {
                const result = requester.strategy.parseResponseLine(data, requester.message);
                // console.log("[Ai] Parsed response result: ", JSON.stringify(result, null, 2));
                requester.parsedAny = true;
                root.updateSessionGrounding(requester.message, root.currentRunSessionId);

                const functionCalls = Array.isArray(result.functionCalls) ? result.functionCalls : (result.functionCall ? [result.functionCall] : []);
                if (functionCalls.length > 0)
                    root.handleFunctionCalls(functionCalls, requester.message);
                if (result.tokenUsage) {
                    root.tokenCount.input = result.tokenUsage.input;
                    root.tokenCount.output = result.tokenUsage.output;
                    root.tokenCount.total = result.tokenUsage.total;
                    const thinkingTokens = result.tokenUsage.thinking ?? -1;
                    root.tokenCount.thinking = thinkingTokens;
                    // Counted per message too: the think block says what this
                    // answer's reasoning cost, not what the chat has cost.
                    if (thinkingTokens >= 0)
                        requester.message.thoughtTokens = thinkingTokens;
                }
                if (result.finished)
                    root.markDone(requester.message);
            } catch (e) {
                console.log("[AI] Could not parse response: ", e);
                requester.message.rawContent += data;
                requester.message.content += data;
            }
        }

        onRetrying: (attempt, delaySeconds, status) => {
            // Whatever the failed attempt wrote has already been rolled back,
            // so the message goes back to looking like it is being thought
            // about — which it is.
            root.retryNotice = Translation.tr("Retrying in %1 s (%2/%3)").arg(delaySeconds).arg(attempt).arg(requester.maxRetries);
        }

        onFinished: (reason, status, code) => {
            const message = requester.message;
            root.retryNotice = "";
            if (!message)
                return;

            if (reason === "attachmentError") {
                root.attachmentNotice = root.attachmentErrorText(requester.attachmentError);
                const messageId = root.messageIDs.find(id => root.messageByID[id] === message);
                if (messageId !== undefined) {
                    root.messageIDs = root.messageIDs.filter(id => id !== messageId);
                    delete root.messageByID[messageId];
                }
                message.destroy();
                root.sessions.scheduleSave();
                return;
            }

            if (reason === "aborted") {
                root.followUpQueued = false;
                const note = Translation.tr("\n\n*[Stopped]*");
                message.rawContent += note;
                message.content += note;
            } else {
                requester.strategy.onRequestFinished(message);
                // An error is put on the message as an error, not as text: the
                // transcript draws it as a card with a way to send it again.
                // Whatever the provider said about it stays as the body.
                if (reason === "error") {
                    message.errorKind = root.transportErrorKind(status, code);
                    message.errorStatus = status;
                    message.errorText = root.transportErrorText(status, code);
                    // Nothing parsed, so whatever is in the bubble is the
                    // provider's complaint, not an answer. It belongs to the
                    // card, where it can be unfolded, not to the transcript.
                    if (!requester.parsedAny && message.content.length > 0) {
                        message.errorDetails = message.content.trim();
                        message.content = "";
                        message.rawContent = "";
                    }
                }
            }

            message.thinking = false;
            if (!message.done)
                root.markDone(message);

            if (root.currentRunId.length > 0) {
                const finalState = reason === "done" ? "completed" : (reason === "aborted" ? "cancelled" : "failed");
                root.runCoordinator.finish(root.currentRunId, finalState, reason);
            }

            if (message.content.includes("API key not valid") || status === 401 || status === 403) {
                const model = root.models[message.model];
                if (model)
                    root.addApiKeyAdvice(model);
            }

            if (root.followUpQueued && reason === "done") {
                root.followUpQueued = false;
                root.makeRequest();
            } else {
                root.followUpQueued = false;
            }
        }
    }

    /**
     * Builds and sends a request for the conversation as it currently stands.
     */
    function makeRequest(submission = null) {
        const pending = submission;
        if (pending && root.pendingSubmissionId !== pending.submissionId)
            return;
        const candidate = pending ? (root.catalog.models[pending.modelId] ?? null) : root.currentModelEntry;
        if (!pending && candidate?.requires_key && !KeyringStorage.loaded)
            KeyringStorage.fetchKeyringData();
        const permission = root.canSubmit(pending ? pending.modelId : root.currentModelId);
        if (!permission.allowed) {
            if (pending && permission.reason !== "keyring-loading") {
                root.failPendingSubmission(permission.reason || "unavailable", Translation.tr("This AI model is no longer available."), permission.recoveryActionIds ?? ["open-models"]);
                return;
            }
            const model = pending ? candidate : root.currentModelEntry;
            if (permission.reason === "missing-key" && model)
                root.addApiKeyAdvice(model);
            else if (permission.reason === "keyring-loading")
                root.addMessage(Translation.tr("The system keyring is still loading. Try sending again in a moment."), root.interfaceRole);
            else if (permission.reason === "disabled")
                root.addMessage(Translation.tr("AI is disabled by the current policy."), root.interfaceRole);
            else
                root.addMessage(Translation.tr("No usable AI model is available. Open Models or AI settings to configure one."), root.interfaceRole);
            return;
        }

        const model = candidate;
        if (!model) {
            if (pending)
                root.failPendingSubmission("model-unavailable", Translation.tr("This AI model is no longer available."), ["open-models"]);
            return;
        }
        if (!pending && requester.running) {
            root.addMessage(Translation.tr("Still answering. Stop the current response before sending another."), root.interfaceRole);
            return;
        }

        // Give the run a stable destination before creating its placeholder.
        // The first user turn may not have been flushed yet because it was
        // typed into a brand-new chat.
        if (!pending && root.sessions.currentId.length === 0)
            root.commitSession(true);
        let requestMessageId = "";
        for (let at = root.messageIDs.length - 1; at >= 0; at--) {
            const candidateMessage = root.messageByID[root.messageIDs[at]];
            if (candidateMessage?.role === "user") {
                requestMessageId = root.messageIDs[at];
                break;
            }
        }

        // Fetch API keys if needed
        if (!pending && model.requires_key && !KeyringStorage.loaded)
            KeyringStorage.fetchKeyringData();

        const profile = pending ? (pending.profile ?? root.responseProfileForModel(model.id)) : root.responseProfileForModel(model.id);
        const strategy = pending ? root.apiStrategies[model.api_format || "openai"] : root.currentApiStrategy;
        strategy.activeThinkingLevel = profile.thinkingLevel;
        const messageArray = root.messageIDs.map(id => root.messageByID[id]);
        const filteredMessageArray = messageArray.filter(message => message.role !== root.interfaceRole);
        // Tool support is a property of the model, not of its address. A
        // local model that can call functions keeps them; a remote one
        // that cannot does not get them handed over anyway.
        const toolOverride = profile.toolMode;
        const tools = model.tools && (root.onlineAllowed || toolOverride !== "search")
                ? root.toolbox.wireTools(model.api_format, toolOverride)
                : null;

        const data = strategy.buildRequestData(model, filteredMessageArray, pending ? pending.systemPrompt : root.systemPrompt, pending ? pending.temperature : root.temperature, tools);
        // console.log("[Ai] Request data: ", JSON.stringify(data, null, 2));


        /* Create local message object */
        const message = root.aiMessageComponent.createObject(root, {
            "role": "assistant",
            "model": model.id,
            "responseMode": profile.responseMode,
            "webMode": profile.webMode,
            "functionExposure": profile.functionExposure,
            "profileFallback": profile.fallbackReason,
            "content": "",
            "rawContent": "",
            "thinking": true,
            "done": false
        });
        const id = idForMessage(message);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = message;

        const runResult = root.runCoordinator.start(root.sessions.currentId, requestMessageId, id, model.id, "ai");
        if (!runResult.accepted) {
            root.messageIDs = root.messageIDs.filter(messageId => messageId !== id);
            delete root.messageByID[id];
            message.destroy();
            if (pending) {
                root.failPendingSubmission("busy", Translation.tr("AI is busy with another conversation. Open or stop the active run first."), ["open-active-run", "stop-active-run"]);
            } else {
                root.addMessage(Translation.tr("AI is busy with another conversation. Open or stop the active run first."), root.interfaceRole);
            }
            return;
        }
        root.currentRunId = runResult.runId;
        root.currentRunSessionId = runResult.sessionId;
        root.currentRunRequestId = requestMessageId;
        root.currentRunResponseId = id;
        root.runningMessageIDs = root.messageIDs.slice();
        root.runningMessageByID = Object.assign({}, root.messageByID);
        root.conversations.capture(root.currentRunSessionId, root.sessionToJson());
        if (pending) {
            pending.responseMessageId = id;
            pending.insertedIds = [...pending.insertedIds, id];
            pending.insertedObjects[id] = message;
            pending.runId = runResult.runId;
            pending.sessionId = runResult.sessionId;
            pending.prepared = {
                model: model,
                strategy: strategy,
                message: message,
                endpoint: strategy.buildEndpoint(model),
                requestData: data,
                apiKey: model.requires_key ? (root.apiKeys?.[model.key_id] ?? "") : ""
            };
            pending.state = "staging";
            pending.stageOperationId = root.sessions.stageSubmission(root.sessionToJson(), root.submissionOperationId("stage"));
            root.submissionStateChanged(pending);
            if (!pending.stageOperationId)
                root.failPendingSubmission("save-failed", Translation.tr("The message could not be staged, so it was not sent."), ["retry-submit"]);
            return;
        }

        root.commitSession(true);
        requester.model = model;
        requester.strategy = strategy;
        requester.message = message;
        requester.endpoint = strategy.buildEndpoint(model);
        requester.requestData = data;
        requester.apiKey = model.requires_key ? (root.apiKeys?.[model.key_id] ?? "") : "";
        requester.parsedAny = false;
        requester.start();
    }

    /**
     * Stops the answer being written, keeping whatever arrived so far.
     */
    function stopGeneration(): bool {
        root.followUpQueued = false;
        root.pendingToolCalls = [];
        root.activeToolCallId = "";
        if (root.pendingSubmissionId.length > 0 && !requester.running)
            return root.cancelPendingSubmission("user");
        return requester.abort();
    }

    /**
     * Sends the next turn of a tool exchange. The call that asks for it is
     * answered from inside the stream that is still running, and a request
     * never replaces one in flight, so it waits for that stream to end.
     */
    function requestFollowUp() {
        if (root.pendingToolCalls.length > 0) {
            root.processNextToolCall();
            return;
        }
        if (requester.running) {
            root.followUpQueued = true;
            return;
        }
        root.makeRequest();
    }

    function sendUserMessage(message) {
        const files = root.attachments;
        if (root.pendingAttachmentCount > 0) {
            root.attachmentNotice = Translation.tr("Still checking attachments. Try sending again in a moment.");
            return {
                accepted: false,
                state: "rejected",
                errorCode: "attachments-pending"
            };
        }
        // The files go with the question, not the answer. `submit` keeps the
        // immutable copy until the durable checkpoint is acknowledged.
        return root.submit(message, {
            "attachments": files
        }, "chat");
    }

    /**
     * Attaches a region snip once the file exists.
     *
     * Called by RegionSelection.qml, whose own process is detached and whose
     * window is gone a moment later, so the waiting is done here: this is a
     * singleton and outlives the selector. What this replaced read the
     * clipboard after a fixed delay, and so attached the shot only when the
     * machine happened to be quick enough.
     */
    function attachSnip(path: string) {
        if (!path || path.length === 0)
            return;
        snipWaitProc.attachPath = path;
        snipWaitProc.running = false;
        snipWaitProc.running = true;
    }

    Process {
        id: snipWaitProc
        property string attachPath: ""
        // Four seconds at most: a crop of a screen takes a fraction of one,
        // and a wait that never ends would hold a stale path forever.
        command: ["bash", "-c", `for i in $(seq 1 40); do [ -s '${CF.StringUtils.shellSingleQuoteEscape(snipWaitProc.attachPath)}' ] && exit 0; sleep 0.1; done; exit 1`]
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[Ai] Region snip never appeared at", snipWaitProc.attachPath);
                return;
            }
            root.attachFile(snipWaitProc.attachPath);
        }
    }

    // ── Attachments ───────────────────────────────────────────────────────
    // Files waiting to go out with the next message. Each one is looked at
    // before it reaches the tray: what it is decides whether the model can
    // read it at all, and how big it is decides whether it may be sent.
    // Nothing is rejected silently — the old drop area simply ignored files
    // on any provider that was not Google, which reads as the drop not
    // registering.

    property var attachments: []
    /** Why the last file was turned away. The composer shows it and clears it. */
    property string attachmentNotice: ""

    readonly property int maxAttachments: Math.max(1, Config.options?.ai?.maxAttachments ?? 6)
    readonly property int maxAttachmentBytes: Math.max(1, Config.options?.ai?.maxAttachmentMib ?? 8) * 1024 * 1024
    // Text goes in as text, so the limit is about the context window rather
    // than about what the request can carry.
    readonly property int maxTextAttachmentBytes: 256 * 1024

    /** Whether the model in use can take files at all, kinds aside. */
    readonly property bool currentModelTakesFiles: root.currentModelEntry?.attachments ?? false

    function humanSize(bytes: int): string {
        if (bytes >= 1024 * 1024)
            return Translation.tr("%1 MB").arg((bytes / (1024 * 1024)).toFixed(1));
        if (bytes >= 1024)
            return Translation.tr("%1 kB").arg(Math.round(bytes / 1024));
        return Translation.tr("%1 B").arg(bytes);
    }

    /** Empty when the file may be sent, otherwise the reason it may not. */
    function attachmentRejection(file: var): string {
        const modelName = root.currentModelEntry?.title ?? Translation.tr("This model");
        if (file.kind === "text") {
            if (file.bytes > root.maxTextAttachmentBytes)
                return Translation.tr("%1 is %2 of text — too much to put in one message.").arg(file.name).arg(root.humanSize(file.bytes));
            return "";
        }
        if (!root.currentModelTakesFiles)
            return Translation.tr("%1 cannot read files. Pick a model that can, or paste the text in.").arg(modelName);
        if (file.kind === "image" && !(root.currentModelEntry?.vision ?? false))
            return Translation.tr("%1 cannot look at images.").arg(modelName);
        if (file.bytes > root.maxAttachmentBytes)
            return Translation.tr("%1 is %2. The limit is %3.").arg(file.name).arg(root.humanSize(file.bytes)).arg(root.humanSize(root.maxAttachmentBytes));
        return "";
    }

    /**
     * Adds a file to the next message. An empty path detaches everything,
     * which is what Escape in the composer and `/attach` with no argument
     * have always meant.
     */
    property int attachmentGeneration: 0
    property var probeQueue: []
    property var pendingAttachmentPaths: []
    property string activeProbePath: ""
    property int activeProbeGeneration: -1
    readonly property int pendingAttachmentCount: root.pendingAttachmentPaths.length

    function attachFile(filePath: string) {
        const path = CF.FileUtils.trimFileProtocol(String(filePath ?? "")).trim();
        if (path.length === 0) {
            root.clearAttachments();
            return;
        }
        if (root.attachments.some(file => file.path === path) || root.pendingAttachmentPaths.indexOf(path) >= 0)
            return;
        if (root.attachments.length + root.pendingAttachmentPaths.length >= root.maxAttachments) {
            root.attachmentNotice = Translation.tr("%1 files is as many as one message takes.").arg(root.maxAttachments);
            return;
        }
        root.pendingAttachmentPaths = [...root.pendingAttachmentPaths, path];
        root.probeQueue = [...root.probeQueue, {
                path: path,
                generation: root.attachmentGeneration
            }];
        root.runProbe();
    }

    function removeAttachment(index: int) {
        if (index < 0 || index >= root.attachments.length)
            return;
        root.attachments = root.attachments.filter((file, at) => at !== index);
    }

    function clearAttachments() {
        root.attachmentGeneration += 1;
        root.probeQueue = [];
        root.pendingAttachmentPaths = [];
        root.activeProbePath = "";
        root.activeProbeGeneration = -1;
        if (probeProc.running)
            probeProc.running = false;
        root.attachments = [];
        root.attachmentNotice = "";
    }

    function runProbe() {
        if (probeProc.running || root.probeQueue.length === 0)
            return;
        const job = root.probeQueue[0];
        root.probeQueue = root.probeQueue.slice(1);
        root.activeProbePath = job.path;
        root.activeProbeGeneration = job.generation;
        probeProc.command = ["python3", Directories.aiAttachScriptPath, "probe", job.path];
        probeProc.running = true;
    }

    function acceptProbed(raw: string, path: string, generation: int) {
        if (generation !== root.attachmentGeneration || path !== root.activeProbePath)
            return;
        root.pendingAttachmentPaths = root.pendingAttachmentPaths.filter(item => item !== path);
        let file;
        try {
            file = JSON.parse(raw.trim());
        } catch (e) {
            root.attachmentNotice = Translation.tr("Could not read that file.");
            return;
        }
        if (file.error) {
            root.attachmentNotice = file.error;
            return;
        }
        const rejection = root.attachmentRejection(file);
        if (rejection.length > 0) {
            root.attachmentNotice = rejection;
            return;
        }
        root.attachmentNotice = "";
        if (root.attachments.length >= root.maxAttachments)
            return;
        if (root.attachments.some(item => item.path === file.path))
            return;
        root.attachments = [...root.attachments, file];
    }

    Process {
        id: probeProc
        stdout: StdioCollector {
            id: probeCollector
            onStreamFinished: root.acceptProbed(probeCollector.text, probeProc.probePath, probeProc.probeGeneration)
        }
        property string probePath: ""
        property int probeGeneration: -1
        onRunningChanged: {
            if (probeProc.running) {
                probeProc.probePath = root.activeProbePath;
                probeProc.probeGeneration = root.activeProbeGeneration;
            }
        }
        onExited: {
            root.activeProbePath = "";
            root.activeProbeGeneration = -1;
            Qt.callLater(root.runProbe);
        }
    }

    /**
     * Asks again for an answer. The old one is not thrown away: the chat is
     * forked first, so the branch that held it stays in the list.
     */
    function regenerate(messageId: string) {
        if (root.messageByID[messageId]?.role !== "assistant")
            return;
        if (!root.forkFrom(messageId, false))
            return;
        root.makeRequest();
    }

    /**
     * Asks again, with another model. The natural next move after a weak
     * answer, and one that used to take four steps.
     */
    function regenerateWith(messageId: string, modelId: string) {
        if (!root.setModel(modelId, false))
            return;
        root.regenerate(messageId);
    }

    /**
     * Rewrites a question and asks it again. Everything that followed it
     * belonged to the old wording, so it stays behind in its own chat.
     */
    function editAndResend(messageId: string, content: string) {
        const message = root.messageByID[messageId];
        if (!message || message.role !== "user")
            return;
        const text = String(content ?? "").trim();
        if (text.length === 0)
            return;
        if (!root.forkFrom(messageId, true))
            return;
        message.content = text;
        message.rawContent = text;
        root.commitSession();
        root.makeRequest();
    }

    function createFunctionOutputMessage(name, output, includeOutputInChat = true, callId = "") {
        const resolvedCallId = callId || root.activeToolCallId;
        return aiMessageComponent.createObject(root, {
            "role": "user",
            "content": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "rawContent": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "functionName": name,
            "functionCallId": resolvedCallId,
            "functionResponse": output,
            "thinking": false,
            "done": true
        // "visibleToUser": false,
        });
    }

    function addFunctionOutputMessage(name, output, callId = "") {
        const aiMessage = createFunctionOutputMessage(name, output, true, callId);
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    // ── Tool calls ────────────────────────────────────────────────────────
    // A call either runs, asks first, or is refused, and which of the three
    // is the user's standing answer for that tool rather than a property of
    // the call. Everything the model asks for is written to the log either
    // way: a refusal that leaves no trace is indistinguishable from a tool
    // that was never offered.

    function rejectCommand(message: AiMessageData) {
        if (!message.functionPending)
            return;
        message.functionPending = false; // User decided, no more "thinking"
        root.toolbox.finishCall(message.toolCallSerial, "refused", Translation.tr("Rejected"));
        addFunctionOutputMessage(message.functionName, Translation.tr("Command rejected by user"));
        root.requestFollowUp();
    }

    function approveCommand(message: AiMessageData) {
        if (!message.functionPending)
            return;
        message.functionPending = false; // User decided, no more "thinking"
        root.runShellCommand(message, message.functionCall?.args?.command ?? "");
    }

    function runShellCommand(message: AiMessageData, command: string) {
        if (!root.onlineAllowed) {
            root.toolbox.finishCall(message.toolCallSerial, "refused", Translation.tr("Shell commands are disabled by the local-only AI policy."));
            addFunctionOutputMessage(message.functionName, Translation.tr("Shell commands are disabled while AI is restricted to local providers."), message.functionCallId);
            root.requestFollowUp();
            return;
        }

        const responseMessage = createFunctionOutputMessage(message.functionName, "", false, message.functionCallId);
        const id = idForMessage(responseMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = responseMessage;

        commandExecutionProc.message = responseMessage;
        commandExecutionProc.baseMessageContent = responseMessage.content;
        commandExecutionProc.serial = message.toolCallSerial;
        commandExecutionProc.shellCommand = command;
        commandExecutionProc.running = true; // Start the command execution
    }

    Process {
        id: commandExecutionProc
        property string shellCommand: ""
        property AiMessageData message
        property string baseMessageContent: ""
        property int serial: -1
        command: ["bash", "-c", shellCommand]
        stdout: SplitParser {
            onRead: output => {
                commandExecutionProc.message.functionResponse += output + "\n\n";
                const updatedContent = commandExecutionProc.baseMessageContent + `\n\n<think>\n<tt>${commandExecutionProc.message.functionResponse}</tt>\n</think>`;
                commandExecutionProc.message.rawContent = updatedContent;
                commandExecutionProc.message.content = updatedContent;
            }
        }
        onExited: (exitCode, exitStatus) => {
            commandExecutionProc.message.functionResponse += `[[ Command exited with code ${exitCode} (${exitStatus}) ]]\n`;
            root.toolbox.finishCall(commandExecutionProc.serial, exitCode === 0 ? "done" : "failed", Translation.tr("Exit code %1").arg(exitCode));
            root.requestFollowUp(); // Continue
        }
    }

    function describeConfigValue(value): string {
        if (value === undefined)
            return Translation.tr("not set");
        if (value === null)
            return "null";
        if (typeof value === "object") {
            try {
                return JSON.stringify(CF.ObjectUtils.toPlainObject(value));
            } catch (e) {
                return String(value);
            }
        }
        return String(value);
    }

    /**
     * Normalises a settings call into [{key, current, proposed}]. Two shapes
     * arrive: the `changes` list asked for now, and the single key/value pair
     * the older schemas asked for — which models still send from memory.
     * Each change carries the value it would replace, because a diff the user
     * cannot read against the current state is not a review.
     */
    function configChangeList(args: var): var {
        const incoming = [];
        const changes = args?.changes;
        if (changes && typeof changes.length === "number") {
            for (let i = 0; i < changes.length; i++) {
                incoming.push(changes[i]);
            }
        } else if (args?.key !== undefined) {
            incoming.push(args);
        }
        const result = [];
        for (let i = 0; i < incoming.length; i++) {
            const change = incoming[i];
            if (!change || change.key === undefined || change.value === undefined)
                continue;
            const key = String(change.key);
            result.push({
                key: key,
                current: root.describeConfigValue(Config.getNestedValue(Config.options, key.split("."))),
                proposed: String(change.value)
            });
        }
        return result;
    }

    /** Writes the changes the user kept, and tells the model which those were. */
    function applyConfigChanges(message: AiMessageData, changes: var) {
        const proposed = Array.from(message.pendingChanges ?? []).length;
        message.functionPending = false;
        message.pendingChanges = [];
        const kept = Array.from(changes ?? []);
        const results = [];
        let applied = 0;
        for (let i = 0; i < kept.length; i++) {
            const change = kept[i];
            try {
                Config.setNestedValue(change.key, change.proposed);
                results.push(`✓ ${change.key} = ${change.proposed}`);
                applied += 1;
            } catch (e) {
                results.push(`❌ Failed to set ${change.key}: ${e}`);
            }
        }
        if (results.length === 0)
            results.push(Translation.tr("The user kept every setting as it was."));
        root.toolbox.finishCall(message.toolCallSerial, applied > 0 ? "done" : "refused", Translation.tr("%1 of %2 applied").arg(applied).arg(Math.max(proposed, applied)));
        addFunctionOutputMessage("set_shell_config", results.join("\n"));
        root.requestFollowUp();
    }

    function rejectConfigChanges(message: AiMessageData) {
        if (!message.functionPending)
            return;
        message.functionPending = false;
        message.pendingChanges = [];
        root.toolbox.finishCall(message.toolCallSerial, "refused", Translation.tr("Rejected"));
        addFunctionOutputMessage("set_shell_config", Translation.tr("Settings change rejected by user"));
        root.requestFollowUp();
    }

    function handleFunctionCalls(calls: var, message: AiMessageData) {
        const list = Array.from(calls ?? []).filter(call => call?.name);
        if (list.length === 0)
            return;
        const known = Array.from(message.toolCalls ?? []);
        const fresh = [];
        list.forEach(call => {
            const normalized = {
                name: String(call.name),
                args: call.args ?? ({}),
                id: String(call.id ?? "")
            };
            const key = normalized.id.length > 0 ? normalized.id : `${normalized.name}:${JSON.stringify(normalized.args)}`;
            const exists = known.some(item => {
                const itemKey = String(item.id ?? "").length > 0 ? String(item.id) : `${item.name}:${JSON.stringify(item.args ?? ({}))}`;
                return itemKey === key;
            });
            if (exists)
                return;
            known.push(normalized);
            fresh.push(normalized);
        });
        if (fresh.length === 0)
            return;
        message.toolCalls = known;
        message.functionCalls = known.map(call => ({
                    name: call.name,
                    args: call.args,
                    id: call.id
                }));
        const wasEmpty = root.pendingToolCalls.length === 0;
        root.pendingToolCalls = root.pendingToolCalls.concat(fresh.map(call => ({
                    call: call,
                    message: message
                })));
        if (wasEmpty)
            root.processNextToolCall();
    }

    function processNextToolCall() {
        if (root.pendingToolCalls.length === 0) {
            root.activeToolCallId = "";
            root.requestFollowUp();
            return;
        }
        const next = root.pendingToolCalls[0];
        root.pendingToolCalls = root.pendingToolCalls.slice(1);
        root.activeToolCallId = String(next.call.id ?? "");
        root.handleFunctionCall(next.call.name, next.call.args, next.message, root.activeToolCallId);
    }

    function handleFunctionCall(name, args: var, message: AiMessageData, callId = "") {
        message.functionName = name;
        message.functionCallId = callId;
        message.functionCall = {
            name: name,
            args: args,
            id: callId
        };
        if (!root.toolbox.definitionFor(name)) {
            addFunctionOutputMessage(name, Translation.tr("Unknown function call: %1").arg(name));
            root.requestFollowUp();
            return;
        }
        const serial = root.toolbox.noteCall(name, args);
        message.toolCallSerial = serial;
        if (root.currentRunId.length > 0)
            root.runCoordinator.activity(root.currentRunId, "tool", { "tool": name, "serial": serial });

        if (root.toolbox.permission(name) === "deny") {
            root.toolbox.finishCall(serial, "refused", Translation.tr("Turned off"));
            addFunctionOutputMessage(name, Translation.tr("%1 is turned off. The user has to allow it in the AI settings before it can be used.").arg(name));
            root.requestFollowUp();
            return;
        }

        if (!root.onlineAllowed && (name === "switch_to_search_mode" || name === "run_shell_command")) {
            root.toolbox.finishCall(serial, "refused", Translation.tr("Blocked by local-only policy"));
            addFunctionOutputMessage(name, Translation.tr("This tool requires network or shell access and is disabled by the current AI policy."), callId);
            root.requestFollowUp();
            return;
        }

        if (name === "switch_to_search_mode") {
            root.toolOverride = "search";
            root.postResponseHook = () => {
                root.toolOverride = "";
            };
            root.toolbox.finishCall(serial, "done", Translation.tr("Search on for one turn"));
            addFunctionOutputMessage(name, Translation.tr("Switched to search mode. Continue with the user's request."));
            root.requestFollowUp();
            return;
        }

        if (name === "get_shell_config") {
            const configJson = CF.ObjectUtils.toPlainObject(Config.options);
            root.toolbox.finishCall(serial, "done", Translation.tr("Settings read"));
            addFunctionOutputMessage(name, JSON.stringify(configJson));
            root.requestFollowUp();
            return;
        }

        if (name === "set_shell_config") {
            const changes = root.configChangeList(args);
            if (changes.length === 0) {
                root.toolbox.finishCall(serial, "failed", Translation.tr("Nothing to change"));
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `changes`, each with a `key` and a `value`."));
                root.requestFollowUp();
                return;
            }
            // Permission says whether the tool may be used at all; the review
            // switch says whether its work is shown first. Only a tool that
            // is allowed outright, with review off, writes unannounced.
            if (root.toolbox.permission(name) === "allow" && !root.toolbox.reviewsConfigChanges) {
                message.pendingChanges = changes;
                root.applyConfigChanges(message, changes);
                return;
            }
            message.pendingChanges = changes;
            message.functionPending = true;
            return;
        }

        if (name === "run_shell_command") {
            const command = String(args?.command ?? "");
            if (command.length === 0) {
                root.toolbox.finishCall(serial, "failed", Translation.tr("No command given"));
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `command`."));
                root.requestFollowUp();
                return;
            }
            const contentToAppend = `\n\n**Command execution request**\n\n\`\`\`command\n${command}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            if (root.toolbox.permission(name) === "allow") {
                root.runShellCommand(message, command);
                return;
            }
            message.functionPending = true; // Use thinking to indicate the command is waiting for approval
        }
    }

    // ── Sessions ──────────────────────────────────────────────────────────
    // A conversation is a file, and the one on screen is one of them. The
    // store does the disk work; what lives here is the shape of a session,
    // how it becomes messages, and when it is worth writing.

    readonly property AiSessions sessions: AiSessions {
        dir: Directories.aiSessions
        legacyDir: Directories.aiChats
        scriptPath: Directories.aiSessionsScriptPath
        exportDir: Directories.aiExports
        onSaveRequested: root.commitSession()
        onSessionOpened: session => root.applySession(session)
        onSaveSucceeded: (operationId, sessionId) => {
            root.conversations.markSaveAcknowledged(sessionId);
            root.handleSubmissionSaveSucceeded(operationId, sessionId);
        }
        onSaveFailed: (operationId, sessionId, reason) => {
            root.conversations.markSavePending(sessionId, true);
            root.handleSubmissionSaveFailed(operationId, sessionId, reason);
        }
        onStageSucceeded: (operationId, sessionId) => root.handleSubmissionStageSucceeded(operationId, sessionId)
        onStageFailed: (operationId, sessionId, reason) => root.handleSubmissionStageFailed(operationId, sessionId, reason)
        onCommitSubmissionSucceeded: (operationId, sessionId) => root.handleSubmissionCommitSucceeded(operationId, sessionId)
        onCommitSubmissionFailed: (operationId, sessionId, reason) => root.handleSubmissionCommitFailed(operationId, sessionId, reason)
        onAbortSubmissionSucceeded: (operationId, sessionId) => root.handleSubmissionAbortFinished(operationId, sessionId, "aborted")
        onAbortSubmissionFailed: (operationId, sessionId, reason) => root.handleSubmissionAbortFinished(operationId, sessionId, reason)
        onCurrentDropped: root.newChat()
    }

    // ── Personas ──────────────────────────────────────────────────────────
    // A persona is a prompt and the settings that go with it. Picking one
    // sets all of them; a chat remembers which one it was held with.

    readonly property AiPersonas personas: AiPersonas {}
    readonly property var currentPersona: root.personas.byId(root.sessionPersonaId)
    readonly property bool personaModified: root.personas.modified(root.currentPersona, root.currentModelId, root.thinkingLevel, root.temperature)

    /**
     * Puts a persona in force. Everything it names is applied at once — that
     * is the whole point of it being one thing instead of four settings.
     */
    function setPersona(personaId: string, feedback = true) {
        const persona = root.personas.byId(personaId);
        if (!persona && personaId.length > 0) {
            if (feedback)
                root.addMessage(Translation.tr("No persona called “%1”").arg(personaId), root.interfaceRole);
            return false;
        }
        root.sessionPersonaId = persona?.id ?? "";
        // A chat's own prompt was written for this chat, not for the persona
        // that happens to be picked now, so it goes when the persona changes.
        root.promptOverride = "";
        root.currentPromptFile = "";
        if (persona?.modelId && root.catalog.models[persona.modelId])
            root.setModel(persona.modelId, false);
        if (persona?.thinking && root.thinkingLevels.indexOf(persona.thinking) >= 0)
            root.setThinkingLevel(persona.thinking);
        if (typeof persona?.temperature === "number")
            root.setTemperature(persona.temperature, false);
        if (feedback)
            root.addMessage(persona ? Translation.tr("Persona: %1").arg(persona.name) : Translation.tr("Persona cleared"), root.interfaceRole);
        root.sessions.scheduleSave();
        return true;
    }

    /** Opening lines offered on an empty chat, from the persona in force. */
    readonly property var starters: {
        const own = root.currentPersona?.starters;
        if (own?.length > 0)
            return Array.from(own);
        return [Translation.tr("Explain what this command does"), Translation.tr("Summarise this in three points"), Translation.tr("What is wrong with this code?"), Translation.tr("Help me word this")];
    }

    /** Sets this chat's own prompt, leaving every other chat alone. */
    function setPromptOverride(text: string, feedback = true) {
        root.promptOverride = String(text ?? "").trim();
        if (root.promptOverride.length === 0)
            root.currentPromptFile = "";
        root.sessions.scheduleSave();
        if (feedback)
            root.addMessage(root.promptOverride.length > 0 ? Translation.tr("This chat now has a prompt of its own.") : Translation.tr("Back to the usual prompt."), root.interfaceRole);
    }

    // ── The composer's draft ──────────────────────────────────────────────
    // Half-typed text belongs to the chat it was being typed into, not to the
    // sidebar, so switching chats does not throw it away.

    property var drafts: ({})
    property string draft: ""
    signal draftRestored(string text)

    readonly property string newDraftId: "__new__"

    function sessionDraftId(sessionId = null) {
        if (sessionId !== null)
            return String(sessionId).length > 0 ? String(sessionId) : root.newDraftId;
        return root.sessions.currentId.length > 0 ? root.sessions.currentId : root.newDraftId;
    }

    function onDraftStoreReady() {
        root.restoreDraft();
    }

    function keepDraft() {
        if (!root.draftStore.loaded)
            return;
        root.draftStore.setDraft(root.sessionDraftId(), root.draft);
    }

    function restoreDraft() {
        const id = root.sessionDraftId();
        root.restoringDraft = true;
        root.draft = root.draftStore.loaded ? root.draftStore.textFor(id) : "";
        root.restoringDraft = false;
        root.draftRestored(root.draft);
    }

    /** The key panel was asked for, from a command or from a card in the chat. */
    signal keyManagerRequested

    readonly property int sessionSchema: 3
    /** Name of the conversation on screen. Empty until it earns one. */
    property string sessionTitle: ""
    property real sessionCreatedAt: 0
    /** Whether the model has already been asked to name this one. */
    property bool sessionTitleAsked: false
    property int titleRevision: 0
    property bool isProvisionalTitle: true
    property string titleRequestSessionId: ""
    property int titleRequestRevision: -1

    function serializeMessageFrom(id, source) {
        const message = source?.[id];
        if (!message)
            return null;
        return ({
                "id": id,
                "role": message.role,
                "rawContent": message.rawContent,
                "fileMimeType": message.fileMimeType,
                "fileUri": message.fileUri,
                "localFilePath": message.localFilePath,
                "attachments": message.attachments,
                "model": message.model,
                "responseMode": message.responseMode,
                "webMode": message.webMode,
                "functionExposure": message.functionExposure,
                "profileFallback": message.profileFallback,
                "thought": message.thought,
                "thoughtSignature": message.thoughtSignature,
                "thinkingBlocks": message.thinkingBlocks,
                "thoughtDurationMs": message.thoughtDurationMs,
                "thoughtTokens": message.thoughtTokens,
                "thinking": false,
                "done": true,
                "annotations": message.annotations,
                "annotationSources": message.annotationSources,
                "searchQueries": message.searchQueries,
                "functionName": message.functionName,
                "functionCall": message.functionCall,
                "functionCalls": message.functionCalls,
                "toolCalls": message.toolCalls,
                "functionCallId": message.functionCallId,
                "functionResponse": message.functionResponse,
                "visibleToUser": message.visibleToUser,
                "errorKind": message.errorKind,
                "errorDetails": message.errorDetails,
                "errorText": message.errorText,
                "errorStatus": message.errorStatus,
                "notice": message.notice
            });
    }

    function serializeMessage(id) {
        return root.serializeMessageFrom(id, root.messageByID);
    }

    function chatToJson() {
        return root.messageIDs.map(id => root.serializeMessage(id)).filter(message => message !== null);
    }

    function runningChatToJson() {
        return root.runningMessageIDs.map(id => root.serializeMessageFrom(id, root.runningMessageByID)).filter(message => message !== null);
    }

    function messageFromJson(data: var): AiMessageData {
        return root.aiMessageComponent.createObject(root, {
            "role": data.role,
            "rawContent": data.rawContent,
            "content": data.rawContent,
            "fileMimeType": data.fileMimeType,
            "fileUri": data.fileUri,
            "localFilePath": data.localFilePath,
            "attachments": data.attachments ?? [],
            "model": data.model,
            "responseMode": data.responseMode ?? "balanced",
            "webMode": data.webMode ?? "off",
            "functionExposure": data.functionExposure ?? "all",
            "profileFallback": data.profileFallback ?? "",
            "thought": data.thought ?? "",
            "thoughtSignature": data.thoughtSignature ?? "",
            "thinkingBlocks": data.thinkingBlocks ?? [],
            "thoughtDurationMs": data.thoughtDurationMs ?? 0,
            "thoughtTokens": data.thoughtTokens ?? -1,
            "thinking": data.thinking ?? false,
            "done": data.done ?? true,
            "annotations": data.annotations ?? [],
            "annotationSources": data.annotationSources ?? [],
            "searchQueries": data.searchQueries ?? [],
            "functionName": data.functionName ?? "",
            "functionCall": data.functionCall,
            "functionCalls": data.functionCalls ?? [],
            "toolCalls": data.toolCalls ?? data.functionCalls ?? [],
            "functionCallId": data.functionCallId ?? "",
            "functionResponse": data.functionResponse ?? "",
            "visibleToUser": data.visibleToUser ?? true,
            "errorKind": data.errorKind ?? "",
            "errorText": data.errorText ?? "",
            "errorStatus": data.errorStatus ?? 0,
            "errorDetails": data.errorDetails ?? "",
            "notice": data.notice ?? ""
        });
    }

    function sessionToJson(): var {
        return ({
                "schema": root.sessionSchema,
                "id": root.sessions.currentId,
                "title": root.sessionTitle,
                "titleRevision": root.titleRevision,
                "isProvisionalTitle": root.isProvisionalTitle,
                "createdAt": root.sessionCreatedAt > 0 ? root.sessionCreatedAt : Date.now(),
                "updatedAt": Date.now(),
                "pinned": root.sessions.currentEntry?.pinned ?? false,
                "modelId": root.currentModelId,
                "thinking": root.thinkingLevel,
                "responseMode": root.responseMode,
                "webMode": root.webMode,
                "functionExposure": root.functionExposure,
                "temperature": root.temperature,
                "promptFile": root.currentPromptFile,
                "personaId": root.sessionPersonaId,
                "promptOverride": root.promptOverride,
                "messages": root.chatToJson(),
                "run": root.conversations.records[root.sessions.currentId]?.run ?? null,
                "searchQueries": root.sessionSearchQueries,
                "sources": root.sessionSources,
                "toolCheckpoints": root.sessionToolCheckpoints,
                "activityEvents": root.conversations.records[root.sessions.currentId]?.run?.activityEvents ?? []
            });
    }

    function runningSessionToJson(): var {
        const sessionId = root.currentRunSessionId;
        const base = root.conversations.snapshot(sessionId) ?? ({
                "schema": root.sessionSchema,
                "id": sessionId,
                "title": "",
                "createdAt": Date.now(),
                "pinned": true,
                "modelId": root.currentModelId,
                "thinking": root.thinkingLevel,
                "responseMode": root.responseMode,
                "webMode": root.webMode,
                "functionExposure": root.functionExposure,
                "temperature": root.temperature,
                "promptFile": "",
                "personaId": "",
                "promptOverride": ""
            });
        return Object.assign({}, base, {
            schema: root.sessionSchema,
            id: sessionId,
            titleRevision: base.titleRevision ?? root.titleRevision,
            isProvisionalTitle: base.isProvisionalTitle ?? root.isProvisionalTitle,
            modelId: root.currentRunId.length > 0 ? (root.runCoordinator.runFor(root.currentRunId)?.modelId ?? base.modelId) : base.modelId,
            responseMode: root.responseMode,
            webMode: root.webMode,
            functionExposure: root.functionExposure,
            messages: root.runningChatToJson(),
            run: root.conversations.records[sessionId]?.run ?? null,
            searchQueries: sessionId === root.sessions.currentId ? root.sessionSearchQueries : (base.searchQueries ?? []),
            sources: sessionId === root.sessions.currentId ? root.sessionSources : (base.sources ?? []),
            toolCheckpoints: sessionId === root.sessions.currentId ? root.sessionToolCheckpoints : (base.toolCheckpoints ?? []),
            activityEvents: root.conversations.records[sessionId]?.run?.activityEvents ?? [],
            updatedAt: Date.now()
        });
    }

    /**
     * Writes the conversation on screen. An empty chat is not a session: one
     * is only started once there is something in it.
     */
    function commitSession(flushNow = false) {
        if (root.messageIDs.length === 0)
            return;
        if (root.sessions.currentId.length === 0) {
            root.sessions.currentId = root.sessions.newId();
            root.sessionCreatedAt = Date.now();
        }
        const snapshot = root.sessionToJson();
        root.conversations.capture(root.sessions.currentId, snapshot);
        root.conversations.markSavePending(root.sessions.currentId, true);
        root.sessions.commit(snapshot, "", flushNow);
    }

    /** Puts the conversation away and starts an empty one. */
    function newChat() {
        if (root.pendingSubmissionId.length > 0) {
            root.cancelPendingSubmission("new-chat");
            return;
        }
        root.commitSession();
        root.keepDraft();
        root.clearMessages();
        root.clearAttachments();
        root.sessions.currentId = "";
        root.sessionTitle = "";
        root.sessionCreatedAt = 0;
        root.sessionTitleAsked = false;
        root.titleRevision = 0;
        root.isProvisionalTitle = true;
        root.titleRequestSessionId = "";
        root.titleRequestRevision = -1;
        root.sessionSearchQueries = [];
        root.sessionSources = [];
        root.sessionToolCheckpoints = [];
        root.promptOverride = "";
        root.currentPromptFile = "";
        root.resetSessionSettings();
        root.restoreDraft();
        root.sessions.ensureLoaded();
    }

    function openSession(sessionId: string) {
        if (sessionId.length === 0 || sessionId === root.sessions.currentId)
            return;
        if (root.pendingSubmissionId.length > 0) {
            root.addMessage(Translation.tr("Wait for this message to finish saving, or stop it before switching chats."), root.interfaceRole, {
                "notice": "submission"
            });
            return;
        }
        root.commitSession(); // Whatever is on screen keeps its own file
        root.keepDraft();
        root.sessions.openSession(sessionId);
    }

    /**
     * Replaces the conversation with one read from disk, settings included:
     * a chat is remembered as it was held, not as the sidebar happens to be
     * set right now.
     */
    function applySession(session: var) {
        const sessionId = root.sessions.currentId;
        if (sessionId.length > 0) {
            let restoredRun = session.run ?? root.conversations.records[sessionId]?.run ?? null;
            if (restoredRun && !root.runCoordinator.terminalStates.includes(restoredRun.state)) {
                restoredRun = root.runCoordinator.restore(restoredRun);
                session.run = restoredRun;
            }
            root.conversations.capture(sessionId, session);
        }
        root.clearMessages();
        const ids = [];
        const byId = ({});
        const messages = session.messages ?? [];
        for (let i = 0; i < messages.length; i++) {
            const data = messages[i];
            const id = (data.id && String(data.id).length > 0) ? String(data.id) : root.sessions.newId();
            byId[id] = root.messageFromJson(data);
            ids.push(id);
        }
        root.messageByID = byId;
        root.messageIDs = ids;
        root.sessionTitle = session.title ?? "";
        root.sessionCreatedAt = session.createdAt ?? Date.now();
        root.sessionTitleAsked = root.sessionTitle.length > 0;
        root.titleRevision = Number(session.titleRevision ?? 0);
        root.isProvisionalTitle = session.isProvisionalTitle === true || (session.isProvisionalTitle === undefined && root.sessionTitle.length === 0);
        root.sessionSearchQueries = Array.from(session.searchQueries ?? []).map(value => String(value)).slice(-50);
        root.sessionSources = Array.from(session.sources ?? []).slice(-100);
        root.sessionToolCheckpoints = Array.from(session.toolCheckpoints ?? []).slice(-100);
        root.sessionModelId = session.modelId ?? root.defaultModelId;
        root.temperature = typeof session.temperature === "number" ? session.temperature : root.defaultTemperature;
        root.thinkingLevel = root.thinkingLevels.indexOf(session.thinking) >= 0 ? session.thinking : root.defaultThinkingLevel;
        root.sessionResponseMode = AiResponseProfiles.responseModes.indexOf(String(session.responseMode ?? "")) >= 0 ? String(session.responseMode) : "";
        root.sessionWebMode = AiResponseProfiles.webModes.indexOf(String(session.webMode ?? "")) >= 0 ? String(session.webMode) : "";
        root.sessionFunctionExposure = AiResponseProfiles.functionExposures.indexOf(String(session.functionExposure ?? "")) >= 0 ? String(session.functionExposure) : "";
        const restoredProfile = root.responseProfileForModel(root.sessionModelId);
        root.thinkingLevel = restoredProfile.thinkingLevel;
        root.currentPromptFile = session.promptFile ?? "";
        root.promptOverride = session.promptOverride ?? "";
        root.sessionPersonaId = session.personaId ?? root.defaultPersonaId;
        root.clearAttachments();
        root.restoreDraft();
    }

    function migrateAiDefaults() {
        const state = Persistent.states?.ai;
        if (!state)
            return;
        if (state.defaultModelId.length === 0)
            state.defaultModelId = state.modelId;
        if (state.defaultTemperature < 0)
            state.defaultTemperature = state.temperature;
        if (state.defaultThinkingLevel.length === 0)
            state.defaultThinkingLevel = state.thinkingLevel;
        if (state.defaultPersonaId.length === 0)
            state.defaultPersonaId = state.personaId;
    }

    function resetSessionSettings() {
        root.sessionModelId = root.defaultModelId;
        root.sessionPersonaId = root.defaultPersonaId;
        root.temperature = root.defaultTemperature;
        root.thinkingLevel = root.defaultThinkingLevel;
        root.sessionResponseMode = "";
        root.sessionWebMode = "";
        root.sessionFunctionExposure = "";
    }

    /**
     * Splits the conversation at a message. What came before becomes a new
     * chat and stays on screen; the chat it was split off keeps every message
     * it had, in its own file.
     */
    function forkFrom(messageId: string, keepMessage = true): bool {
        const cut = root.messageIDs.indexOf(messageId);
        if (cut < 0)
            return false;
        root.commitSession();
        const kept = root.messageIDs.slice(0, keepMessage ? cut + 1 : cut);
        for (let i = kept.length; i < root.messageIDs.length; i++) {
            delete root.messageByID[root.messageIDs[i]];
        }
        root.messageIDs = kept;
        root.sessions.currentId = root.sessions.newId();
        root.sessionCreatedAt = Date.now();
        if (root.sessionTitle.length > 0)
            root.sessionTitle = Translation.tr("%1 (fork)").arg(root.sessionTitle);
        root.sessionTitleAsked = root.sessionTitle.length > 0;
        root.titleRevision += 1;
        root.isProvisionalTitle = false;
        root.commitSession();
        return true;
    }

    /** Renames the conversation on screen, starting a session if there is none. */
    function nameCurrentChat(title: string) {
        const trimmed = String(title ?? "").trim();
        if (trimmed.length === 0)
            return;
        root.sessionTitle = trimmed;
        root.sessionTitleAsked = true;
        root.titleRevision += 1;
        root.isProvisionalTitle = false;
        if (root.messageIDs.length === 0) {
            root.addMessage(Translation.tr("Nothing to name yet — this chat is empty."), root.interfaceRole);
            return;
        }
        root.commitSession();
        root.addMessage(Translation.tr("Chat named “%1”").arg(trimmed), root.interfaceRole);
    }

    /** Opens a saved chat by title, for the %1load command. */
    function openChatByName(title: string): bool {
        const wanted = String(title ?? "").trim().toLowerCase();
        if (wanted.length === 0)
            return false;
        const match = root.sessions.index.find(entry => entry.title.toLowerCase() === wanted) ?? root.sessions.index.find(entry => entry.title.toLowerCase().includes(wanted));
        if (!match) {
            root.addMessage(Translation.tr("No saved chat called “%1”").arg(title), root.interfaceRole);
            return false;
        }
        root.openSession(match.id);
        return true;
    }

    // ── Naming a chat ─────────────────────────────────────────────────────
    // The first answer is followed by one small call asking the model what to
    // call the conversation. A truncation of the first message is written
    // first, so a chat is never nameless; the model's answer only replaces it
    // if one arrives. Nothing waits for either.

    property AiMessageData titleMessage: AiMessageData {}
    property var titleStrategies: ({})

    function titleStrategyFor(format: string): ApiStrategy {
        if (!root.titleStrategies[format]) {
            // Its own instance: strategies carry per-request state, and this
            // call must never be able to disturb an answer being streamed.
            const component = (format === "gemini") ? root.geminiApiStrategy : ((format === "anthropic") ? root.anthropicApiStrategy : root.openAiCompatStrategy);
            root.titleStrategies[format] = component.createObject(root);
        }
        return root.titleStrategies[format];
    }

    function shortTitle(text: string): string {
        const oneLine = String(text ?? "").replace(/[\r\n]+/g, " ").replace(/["'#*`_>]/g, "").replace(/\s+/g, " ").trim();
        if (oneLine.length <= 42)
            return oneLine;
        return oneLine.slice(0, 41).trim() + "…";
    }

    function firstTextOfRole(role: string): string {
        for (let i = 0; i < root.messageIDs.length; i++) {
            const message = root.messageByID[root.messageIDs[i]];
            if (message?.role === role)
                return String(message.rawContent ?? "").trim();
        }
        return "";
    }

    function autoTitle() {
        if (root.sessionTitleAsked || root.sessionTitle.length > 0)
            return;
        const opening = root.firstTextOfRole("user");
        if (opening.length === 0)
            return;
        root.sessionTitleAsked = true;
        root.sessionTitle = root.shortTitle(opening);
        root.titleRevision += 1;
        root.isProvisionalTitle = true;
        root.titleRequestSessionId = root.sessions.currentId;
        root.titleRequestRevision = root.titleRevision;
        root.requestTitle(opening, root.titleRequestSessionId, root.titleRequestRevision);
    }

    function requestTitle(opening: string, sessionId: string, expectedRevision: int) {
        const model = root.currentModelEntry;
        if (!model || titleRequester.running)
            return;
        if (!root.canSubmit(model.id).allowed)
            return;
        const strategy = root.titleStrategyFor(model.api_format || "openai");
        const answer = root.firstTextOfRole("assistant");
        const prompt = root.aiMessageComponent.createObject(root, {
            "role": "user",
            "content": `${opening.slice(0, 600)}\n\n---\n\n${answer.slice(0, 400)}`,
            "rawContent": "",
            "thinking": false,
            "done": true
        });
        strategy.thinkingOverride = "off";
        const data = strategy.buildRequestData(model, [prompt], root.titleInstruction, 0.2, null);
        strategy.thinkingOverride = "";
        prompt.destroy();

        root.titleMessage.content = "";
        root.titleMessage.rawContent = "";
        root.titleMessage.thought = "";
        titleRequester.model = model;
        titleRequester.strategy = strategy;
        titleRequester.message = root.titleMessage;
        titleRequester.endpoint = strategy.buildEndpoint(model);
        titleRequester.requestData = data;
        titleRequester.apiKey = model.requires_key ? (root.apiKeys?.[model.key_id] ?? "") : "";
        titleRequester.start();
    }

    readonly property string titleInstruction: "Name this conversation in at most six words. Answer with the name only: no quotes, no trailing punctuation, no explanation."

    AiRequest {
        id: titleRequester
        apiKeyEnvVarName: root.apiKeyEnvVarName
        scriptPath: `/tmp/quickshell-${SystemInfo.username}/ai/title.sh`

        onLine: data => {
            try {
                titleRequester.strategy.parseResponseLine(data, root.titleMessage);
            } catch (e) {
                // A name is not worth a message in the chat.
            }
        }

        onFinished: reason => {
            if (reason !== "done")
                return;
            const suggested = root.shortTitle(root.titleMessage.content);
            if (suggested.length === 0 || suggested.length > 60)
                return;
            if (root.sessions.currentId !== root.titleRequestSessionId || root.titleRevision !== root.titleRequestRevision || !root.isProvisionalTitle)
                return;
            root.sessionTitle = suggested;
            root.isProvisionalTitle = false;
            root.titleRevision += 1;
            root.commitSession();
        }
    }
}
