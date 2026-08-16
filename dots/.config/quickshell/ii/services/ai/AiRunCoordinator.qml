pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/** One global, session-bound run state machine for the MVP. */
Scope {
    id: root

    readonly property var states: ["idle", "preparing", "thinking", "searching", "toolRunning", "needsAction", "streaming", "completed", "failed", "cancelled", "interrupted", "needsInspection"]
    readonly property var terminalStates: ["completed", "failed", "cancelled", "interrupted", "needsInspection"]
    readonly property var activeStates: ["preparing", "thinking", "searching", "toolRunning", "needsAction", "streaming"]
    property var runs: ({})
    property string activeRunId: ""

    signal runStarted(var run)
    signal runActivity(var run, var event)
    signal runFinished(var run)
    signal runRejected(string reason)

    function newId(): string {
        return `run-${Date.now()}-${Math.random().toString(16).slice(2)}`;
    }

    function runFor(runId: string): var {
        return root.runs[String(runId ?? "")] ?? null;
    }

    function start(sessionId: string, requestMessageId: string, responseMessageId: string, modelId: string, surface = "unknown"): var {
        const current = root.runFor(root.activeRunId);
        if (current && root.activeStates.includes(current.state)) {
            root.runRejected("busy");
            return {
                accepted: false,
                reason: "busy",
                runId: current.runId,
                sessionId: current.sessionId
            };
        }
        const run = {
            runId: root.newId(),
            sessionId: String(sessionId ?? ""),
            requestMessageId: String(requestMessageId ?? ""),
            responseMessageId: String(responseMessageId ?? ""),
            modelId: String(modelId ?? ""),
            state: "preparing",
            startedAt: Date.now(),
            finishedAt: 0,
            resultReason: "",
            surfaceAtStart: String(surface ?? "unknown"),
            isSeen: true,
            notificationEmitted: false,
            executionStarted: false,
            activityEvents: []
        };
        root.runs = Object.assign({}, root.runs, {
            [run.runId]: run
        });
        root.activeRunId = run.runId;
        root.runStarted(run);
        return {
            accepted: true,
            runId: run.runId,
            sessionId: run.sessionId,
            state: run.state
        };
    }

    function transition(runId: string, state: string, reason = "", extra = null) {
        const run = root.runFor(runId);
        if (!run || !root.states.includes(state)) {
            console.warn("[AiRunCoordinator] Invalid transition", runId, state);
            return false;
        }
        if (root.terminalStates.includes(run.state))
            return false;
        const next = Object.assign({}, run, extra ?? ({}), {
            state: state,
            resultReason: reason || run.resultReason,
            finishedAt: root.terminalStates.includes(state) ? Date.now() : run.finishedAt
        });
        root.runs = Object.assign({}, root.runs, {
            [runId]: next
        });
        if (root.terminalStates.includes(state)) {
            if (root.activeRunId === runId)
                root.activeRunId = "";
            root.runFinished(next);
        } else {
            root.runActivity(next, {
                type: "state",
                state: state,
                at: Date.now(),
                reason: reason
            });
        }
        return true;
    }

    function activity(runId: string, type: string, data = null) {
        const run = root.runFor(runId);
        if (!run || root.terminalStates.includes(run.state))
            return false;
        const event = Object.assign({}, data ?? ({}), {
            type: String(type ?? "activity"),
            at: Date.now()
        });
        const next = Object.assign({}, run, {
            state: type === "search" ? "searching" : (type === "tool" ? "toolRunning" : "streaming"),
            activityEvents: [...(run.activityEvents ?? []), event].slice(-100)
        });
        root.runs = Object.assign({}, root.runs, {
            [runId]: next
        });
        root.runActivity(next, event);
        return true;
    }

    function finish(runId: string, state = "completed", reason = "done"): bool {
        return root.transition(runId, root.terminalStates.includes(state) ? state : "completed", reason);
    }

    function cancelByPolicy(localOnly = false): int {
        let count = 0;
        Object.keys(root.runs).forEach(runId => {
            const run = root.runs[runId];
            if (!run || !root.activeStates.includes(run.state))
                return;
            root.finish(runId, "cancelled", localOnly ? "cancelledByPolicy" : "disabledByPolicy");
            count += 1;
        });
        return count;
    }

    function restore(run: var): var {
        if (!run || !run.runId)
            return null;
        const restored = Object.assign({}, run, {
            state: run.executionStarted ? "needsInspection" : "interrupted",
            resultReason: "restart",
            finishedAt: Date.now(),
            isSeen: false
        });
        root.runs = Object.assign({}, root.runs, {
            [restored.runId]: restored
        });
        return restored;
    }
}
