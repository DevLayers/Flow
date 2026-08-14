import QtQuick
import qs.modules.common

QtObject {
    function buildEndpoint(model: AiModel): string { throw new Error("Not implemented") }
    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) { throw new Error("Not implemented") }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { throw new Error("Not implemented") }
    function parseResponseLine(line: string, message: AiMessageData) { throw new Error("Not implemented") }
    function onRequestFinished(message: AiMessageData): var { return {} } // Default: no special handling
    function buildScriptFileSetup(filePath) { return "" } // Default: no setup
    function finalizeScriptContent(scriptContent: string): string { return scriptContent } // Optionally modify/finalize script

    /** Cleared before every request. Subclasses override this, not `reset()`. */
    function resetState() {}

    function reset() {
        thoughtOpen = false;
        resetState();
    }

    /**
     * Output cap for a request. The model's own limit is the default, so no
     * answer is cut short by a number that predates the model; the config
     * option lowers it (to save tokens, or to keep answers short) and is
     * clamped to what the model actually accepts.
     */
    function maxOutputTokens(model: AiModel): int {
        const configured = Config.options?.ai?.maxOutputTokens ?? 0;
        const supported = model?.maxOutput ?? 0;
        if (configured > 0)
            return supported > 0 ? Math.min(configured, supported) : configured;
        return supported > 0 ? supported : 4096;
    }

    // ── Reasoning ─────────────────────────────────────────────────────────
    // Every provider streams thought and answer as two interleaved streams and
    // only the wire format differs, so all of them push through here. The
    // message keeps the thought as a field of its own, and the markdown
    // <think> block the current renderer keys on is written alongside it.

    property bool thoughtOpen: false

    function appendThought(message: AiMessageData, text: string) {
        if (!message || !text || text.length === 0)
            return;
        if (!thoughtOpen) {
            thoughtOpen = true;
            const startBlock = "\n\n<think>\n\n";
            message.content += startBlock;
            message.rawContent += startBlock;
        }
        message.thought += text;
        message.content += text;
        message.rawContent += text;
    }

    function appendAnswer(message: AiMessageData, text: string) {
        if (!message || !text || text.length === 0)
            return;
        closeThought(message);
        message.content += text;
        message.rawContent += text;
    }

    function closeThought(message: AiMessageData) {
        if (!thoughtOpen || !message)
            return;
        thoughtOpen = false;
        const endBlock = "\n\n</think>\n\n";
        message.content += endBlock;
        message.rawContent += endBlock;
    }
}
