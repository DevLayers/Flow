import QtQuick
import qs.modules.common

QtObject {
    function buildEndpoint(model: AiModel): string { throw new Error("Not implemented") }
    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) { throw new Error("Not implemented") }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { throw new Error("Not implemented") }
    function parseResponseLine(line: string, message: AiMessageData) { throw new Error("Not implemented") }
    function onRequestFinished(message: AiMessageData): var { return {} } // Default: no special handling
    function reset() { } // Reset any internal state if needed
    function buildScriptFileSetup(filePath) { return "" } // Default: no setup
    function finalizeScriptContent(scriptContent: string): string { return scriptContent } // Optionally modify/finalize script

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
}
