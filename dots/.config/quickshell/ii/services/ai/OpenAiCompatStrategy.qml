import QtQuick

/**
 * The /v1/chat/completions dialect, as spoken by OpenAI, OpenRouter,
 * DeepSeek, Mistral, Ollama and most of what calls itself OpenAI-compatible.
 *
 * The providers differ in small ways only, and every difference is a flag on
 * the model (`model.quirks`) rather than a provider name tested here:
 *
 * - toolMessages   Tool results go back as their own `tool` turn carrying the
 *                  call id. Endpoints that never learnt that shape get the
 *                  output as plain user text instead.
 * - maxTokensKey   Newer reasoning models renamed `max_tokens` to
 *                  `max_completion_tokens` and reject the old name.
 * - usageInStream  Ask for a usage block at the end of the stream. Some
 *                  endpoints reject the option outright, so it is off unless
 *                  the provider is known to take it.
 */
ApiStrategy {
    // Tool calls arrive in fragments: the name in one delta, the arguments
    // split across the next several. Nothing can be dispatched until the
    // stream says the call is complete.
    property var pendingCalls: ({})

    function quirk(model: AiModel, key: string, fallback: var): var {
        const value = model?.quirks?.[key];
        return value === undefined ? fallback : value;
    }

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        const toolMessages = quirk(model, "toolMessages", true);
        let lastCallId = "";

        const history = messages.map(message => {
            const hasCall = message.functionName?.length > 0;
            if (hasCall && message.functionCall?.id)
                lastCallId = message.functionCall.id;
            if (!hasCall || !(message.functionResponse?.length > 0)) {
                // The turn where the model asked for the call. The result that
                // follows only means something next to it, so the call has to
                // be replayed as a call, not as the text describing it.
                if (toolMessages && message.role === "assistant" && message.functionCall?.id) {
                    return {
                        "role": "assistant",
                        "content": message.rawContent,
                        "tool_calls": [
                            {
                                "id": message.functionCall.id,
                                "type": "function",
                                "function": {
                                    "name": message.functionName,
                                    "arguments": JSON.stringify(message.functionCall.args ?? ({}))
                                }
                            }
                        ]
                    };
                }
                return {
                    "role": message.role,
                    "content": message.rawContent
                };
            }
            // The result of a call the model asked for. Pairing it with the id
            // of that call is what lets the model match them up; without one,
            // the exchange has to be flattened into ordinary text.
            if (!toolMessages || lastCallId.length === 0) {
                return {
                    "role": "user",
                    "content": `[[ Output of ${message.functionName} ]]\n${message.functionResponse}`
                };
            }
            const result = {
                "role": "tool",
                "name": message.functionName,
                "content": message.functionResponse,
                "tool_call_id": lastCallId
            };
            lastCallId = "";
            return result;
        });

        let baseData = {
            "model": model.model,
            "messages": [
                {
                    role: "system",
                    content: systemPrompt
                },
                ...history
            ],
            "stream": true
        };
        baseData[quirk(model, "maxTokensKey", "max_tokens")] = maxOutputTokens(model);
        if (model.samplingParams)
            baseData.temperature = temperature;
        // Reasoning models take a named effort here. Models that do not
        // reason reject the key outright, so it is only sent when the model
        // says that is the knob it has.
        if (model.thinkingKind === "effort" && thinkingOn(model))
            baseData[quirk(model, "reasoningKey", "reasoning_effort")] = thinkingLevel(model);
        if (quirk(model, "usageInStream", false))
            baseData.stream_options = {
                "include_usage": true
            };
        // A null tools list is not the same as an empty one: some endpoints
        // reject the key outright when the model cannot call functions.
        if (tools)
            baseData.tools = tools;
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        let cleanData = line.trim();
        if (cleanData.startsWith("data:"))
            cleanData = cleanData.slice(5).trim();

        if (!cleanData || cleanData.startsWith(":"))
            return {};
        if (cleanData === "[DONE]")
            return {
                finished: true
            };

        try {
            const dataJson = JSON.parse(cleanData);

            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                closeThought(message);
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return {
                    finished: true
                };
            }

            const choice = dataJson.choices?.[0];
            const delta = choice?.delta;

            if (delta?.tool_calls)
                collectToolCalls(delta.tool_calls);

            // Ollama's non-streaming shape puts the text one level up.
            appendThought(message, delta?.reasoning_content || delta?.reasoning || "");
            appendAnswer(message, delta?.content || dataJson.message?.content || "");

            // The call is only whole once the model stops adding to it.
            if (choice?.finish_reason === "tool_calls" || (choice?.finish_reason && hasPendingCalls())) {
                const call = takeToolCall(message);
                if (call)
                    return {
                        functionCall: call,
                        finished: false
                    };
            }

            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        thinking: dataJson.usage.completion_tokens_details?.reasoning_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (dataJson.done || choice?.finish_reason === "stop") {
                closeThought(message);
                return {
                    finished: true
                };
            }
        } catch (e) {
            console.log("[AI] OpenAI-compatible: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }

        return {};
    }

    /** Merges one delta's worth of tool-call fragments into what came before. */
    function collectToolCalls(fragments) {
        for (let i = 0; i < fragments.length; i++) {
            const fragment = fragments[i];
            const index = fragment.index ?? 0;
            const call = pendingCalls[index] ?? {
                id: "",
                name: "",
                args: ""
            };
            if (fragment.id)
                call.id = fragment.id;
            if (fragment.function?.name)
                call.name = fragment.function.name;
            if (fragment.function?.arguments)
                call.args += fragment.function.arguments;
            pendingCalls[index] = call;
        }
    }

    function hasPendingCalls(): bool {
        return Object.keys(pendingCalls).length > 0;
    }

    /** The first complete call, if there is one. Only one runs per turn. */
    function takeToolCall(message): var {
        const keys = Object.keys(pendingCalls);
        if (keys.length === 0)
            return null;
        const call = pendingCalls[keys[0]];
        pendingCalls = ({});
        if (!call.name || call.name.length === 0)
            return null;

        let args = {};
        try {
            args = call.args.length > 0 ? JSON.parse(call.args) : {};
        } catch (e) {
            console.log("[AI] OpenAI-compatible: Could not read call arguments: ", e);
        }
        const newContent = `\n\n[[ Function: ${call.name}(${JSON.stringify(args, null, 2)}) ]]\n`;
        closeThought(message);
        message.rawContent += newContent;
        message.content += newContent;
        message.functionName = call.name;
        message.functionCall = call.name;
        return {
            name: call.name,
            args: args,
            id: call.id
        };
    }

    function onRequestFinished(message) {
        closeThought(message);
        return {};
    }

    function resetState() {
        pendingCalls = ({});
    }
}
