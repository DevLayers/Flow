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

    /**
     * Turns a plain-text turn into the parts form when it carries files.
     * Images ride as data URIs; anything else is inlined as text, since this
     * dialect has no block for a document and a base64 blob in a text field
     * is worth nothing to the model.
     */
    function withAttachments(turn: var, message, model: AiModel): var {
        const files = attachmentsOf(message, model);
        if (files.length === 0)
            return turn;
        const parts = [];
        if ((turn.content ?? "").length > 0)
            parts.push({
                "type": "text",
                "text": turn.content
            });
        for (const file of files) {
            if (file.kind === "image" && (model?.vision ?? false)) {
                parts.push({
                    "type": "image_url",
                    "image_url": {
                        "url": `data:${file.mime};base64,${attachmentMarker(file.path, "b64")}`
                    }
                });
                continue;
            }
            if (file.kind !== "text")
                continue;
            parts.push({
                "type": "text",
                "text": `[[ ${file.name} ]]\n${attachmentMarker(file.path, "text")}`
            });
        }
        if (parts.length === 0)
            return turn;
        return Object.assign({}, turn, {
            "content": parts
        });
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>) {
        beginAttachments();
        const toolMessages = quirk(model, "toolMessages", true);
        let lastCallId = "";

        const history = messages.map(message => {
            const hasCall = message.functionName?.length > 0;
            const storedCalls = Array.isArray(message.functionCalls) && message.functionCalls.length > 0 ? message.functionCalls : (message.functionCall?.id ? [message.functionCall] : []);
            const calls = Array.from(storedCalls);
            if (calls.length > 0 && calls[calls.length - 1]?.id)
                lastCallId = calls[calls.length - 1].id;
            if (!hasCall || !(message.functionResponse?.length > 0)) {
                // The turn where the model asked for the call. The result that
                // follows only means something next to it, so the call has to
                // be replayed as a call, not as the text describing it.
                if (toolMessages && message.role === "assistant" && calls.length > 0) {
                    return {
                        "role": "assistant",
                        "content": message.rawContent,
                        "tool_calls": calls.map(call => ({
                            "id": call.id,
                            "type": "function",
                            "function": {
                                "name": call.name,
                                "arguments": JSON.stringify(call.args ?? ({}))
                            }
                        }))
                    };
                }
                return withAttachments({
                    "role": message.role,
                    "content": message.rawContent
                }, message, model);
            }
            // The result of a call the model asked for. Pairing it with the id
            // of that call is what lets the model match them up; without one,
            // the exchange has to be flattened into ordinary text.
            const callId = message.functionCallId || message.functionCall?.id || lastCallId;
            if (!toolMessages || callId.length === 0) {
                return {
                    "role": "user",
                    "content": `[[ Output of ${message.functionName} ]]\n${message.functionResponse}`
                };
            }
            const result = {
                "role": "tool",
                "name": message.functionName,
                "content": message.functionResponse,
                "tool_call_id": callId
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
        const nativeOllama = quirk(model, "nativeOllama", false);
        if (nativeOllama) {
            const baseName = String(model.value ?? model.model ?? "").split(":")[0].toLowerCase();
            const level = thinkingLevel(model);
            // Ollama accepts booleans for Qwen/DeepSeek and named levels for
            // GPT-OSS. Explicitly sending this prevents a thinking model from
            // spending the whole response in its reasoning channel.
            baseData.think = !model.thinking || level === "off"
                ? false
                : baseName.startsWith("gpt-oss") ? level : true;
            // `/api/chat` does not understand OpenAI's `max_tokens`.  Without
            // its native cap, a reasoning model can exhaust Ollama's default
            // generation budget on thought alone and finish with no answer.
            baseData.options = Object.assign({}, baseData.options ?? {}, {
                num_predict: maxOutputTokens(model)
            });
        } else {
            baseData[quirk(model, "maxTokensKey", "max_tokens")] = maxOutputTokens(model);
        }
        if (model.samplingParams) {
            // The native API keeps sampling parameters in `options`; placing
            // temperature at the OpenAI-compatible top level makes Ollama
            // silently ignore the user's selected value.
            if (nativeOllama)
                baseData.options = Object.assign({}, baseData.options ?? ({}), { temperature: temperature });
            else
                baseData.temperature = temperature;
        }
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

            // OpenAI-compatible streams normally put reasoning/content in the
            // delta. Ollama's native streaming shape keeps both fields under
            // `message` instead (Qwen emits `message.thinking` for a long
            // time before it emits answer content). Keep that reasoning in
            // the transcript instead of leaving the message looking like a
            // permanent loading indicator.
            const nativeMessage = dataJson.message ?? ({});
            const nativeThought = textFromValue(nativeMessage.thinking ?? nativeMessage.reasoning);
            const nativeContent = textFromValue(nativeMessage.content);
            appendThought(message, textFromValue(delta?.reasoning_content ?? delta?.reasoning ?? delta?.thinking) || nativeThought);
            appendAnswer(message, textFromValue(delta?.content) || nativeContent);

            // The call is only whole once the model stops adding to it.
            if (hasPendingCalls() && (choice?.finish_reason || dataJson.done)) {
                const calls = takeToolCalls(message);
                if (calls.length > 0)
                    return {
                        functionCalls: calls,
                        finished: false
                    };
            }

            const tokenUsage = tokenUsageFrom(dataJson);
            const finished = dataJson.done === true || (choice?.finish_reason !== undefined && choice?.finish_reason !== null);
            if (finished)
                closeThought(message);
            if (tokenUsage || finished)
                return Object.assign({}, tokenUsage ? { tokenUsage: tokenUsage } : ({}), {
                    finished: finished
                });
        } catch (e) {
            console.log("[AI] OpenAI-compatible: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }

        return {};
    }

    /** Text may be a string or a provider's typed content-parts array. */
    function textFromValue(value): string {
        if (typeof value === "string")
            return value;
        if (!Array.isArray(value))
            return "";
        return value.map(part => {
            if (typeof part === "string")
                return part;
            if (!part || typeof part !== "object")
                return "";
            return typeof part.text === "string" ? part.text
                : typeof part.content === "string" ? part.content : "";
        }).join("");
    }

    /** Normalises OpenAI-compatible and native Ollama terminal token fields. */
    function tokenUsageFrom(data): var {
        const usage = data?.usage ?? ({});
        const input = knownToken(usage.prompt_tokens ?? usage.input_tokens ?? data?.prompt_eval_count);
        const output = knownToken(usage.completion_tokens ?? usage.output_tokens ?? data?.eval_count);
        const thinking = knownToken(usage.completion_tokens_details?.reasoning_tokens
            ?? usage.output_tokens_details?.reasoning_tokens ?? data?.thinking_eval_count);
        let total = knownToken(usage.total_tokens ?? usage.total_token_count);
        if (total < 0 && input >= 0 && output >= 0)
            total = input + output;
        if (input < 0 && output < 0 && thinking < 0 && total < 0)
            return null;
        return {
            input: input,
            output: output,
            thinking: thinking,
            total: total
        };
    }

    function knownToken(value): int {
        const number = Number(value);
        return isFinite(number) && number >= 0 ? Math.round(number) : -1;
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

    /** All complete calls, in their wire order. None are silently discarded. */
    function takeToolCalls(message): var {
        const keys = Object.keys(pendingCalls);
        if (keys.length === 0)
            return [];
        keys.sort((a, b) => Number(a) - Number(b));
        const calls = [];
        const collected = pendingCalls;
        pendingCalls = ({});
        for (const key of keys) {
            const call = collected[key];
            if (!call.name || call.name.length === 0)
                continue;
            let args = {};
            try {
                args = call.args.length > 0 ? JSON.parse(call.args) : {};
            } catch (e) {
                console.log("[AI] OpenAI-compatible: Could not read call arguments: ", e);
            }
            const parsedCall = {
                name: call.name,
                args: args,
                id: call.id
            };
            calls.push(parsedCall);
            const newContent = `\n\n[[ Function: ${call.name}(${JSON.stringify(args, null, 2)}) ]]\n`;
            closeThought(message);
            message.rawContent += newContent;
            message.content += newContent;
        }
        return calls;
    }

    function onRequestFinished(message) {
        closeThought(message);
        return {};
    }

    function resetState() {
        pendingCalls = ({});
    }
}
