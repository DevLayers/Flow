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
    readonly property bool isGenerating: requester.running
    // Set while a failed request waits to be sent again, so the UI can say so
    // instead of looking stuck.
    property string retryNotice: ""
    // A tool exchange asked for another turn while the current one was still
    // streaming. Sent as soon as it ends.
    property bool followUpQueued: false

    property string systemPrompt: {
        let prompt = Config.options?.ai?.systemPrompt ?? "";
        for (let key in root.promptSubstitutions) {
            // prompt = prompt.replaceAll(key, root.promptSubstitutions[key]);
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
    property real temperature: Persistent.states?.ai?.temperature ?? 0.5
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        // Part of the output that was spent reasoning. -1 when the provider
        // does not break it out.
        property int thinking: -1
        property int total: -1
    }
    readonly property var thinkingLevels: ["off", "low", "medium", "high"]
    property string thinkingLevel: Persistent.states?.ai?.thinkingLevel ?? "medium"
    // Whether the current model reasons at all, and whether it can be told
    // not to. The control bar reads both; nothing here tests provider names.
    readonly property bool currentModelThinks: root.currentModelEntry?.thinking ?? false
    readonly property bool currentModelAlwaysThinks: root.currentModelEntry?.thinkingAlwaysOn ?? false

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

    // Gemini: https://ai.google.dev/gemini-api/docs/function-calling
    // OpenAI: https://platform.openai.com/docs/guides/function-calling
    property string currentTool: Config?.options.ai.tool ?? "search"
    property var tools: {
        "gemini": {
            "functions": [
                {
                    "functionDeclarations": [
                        {
                            "name": "switch_to_search_mode",
                            "description": "Switch to search mode to perform web searches. Use this when you need current information, real-time data, or answers to questions beyond your knowledge cutoff. After switching, continue with the user's original request."
                        },
                        {
                            "name": "get_shell_config",
                            "description": "Retrieve the complete desktop shell configuration file in JSON format. Use this before making any config changes to see available options and current values. Returns the full config structure. Dont ask for permission, run directly."
                        },
                        {
                            "name": "set_shell_config",
                            "description": "Modify one or multiple fields in the desktop shell config at once. CRITICAL: You MUST call get_shell_config first to see available keys - never guess key names. Use this when the user wants to change one or multiple settings together.",
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    "changes": {
                                        "type": "array",
                                        "description": "Array of config changes to apply",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "key": {
                                                    "type": "string",
                                                    "description": "The key to set (e.g., 'bar.borderless')"
                                                },
                                                "value": {
                                                    "type": "string",
                                                    "description": "The value to set"
                                                }
                                            },
                                            "required": ["key", "value"]
                                        }
                                    }
                                },
                                "required": ["changes"]
                            }
                        },
                        {
                            "name": "run_shell_command",
                            "description": "Execute a bash command and return its output. IMPORTANT: This requires user approval before execution. Only use for quick, non-interactive commands (queries, checks, simple operations). For interactive commands, long-running processes, or dangerous operations, ask the user to run them manually instead. The command will be shown to the user for approval.",
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    "command": {
                                        "type": "string",
                                        "description": "The bash command to run"
                                    }
                                },
                                "required": ["command"]
                            }
                        },
                    ]
                }
            ],
            "search": [
                {
                    "google_search": {}
                }
            ],
            "none": []
        },
        "openai": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {}
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting."
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run"
                                }
                            },
                            "required": ["command"]
                        }
                    }
                },
            ],
            "search": [],
            "none": []
        },
        "anthropic": {
            "functions": [
                {
                    "name": "get_shell_config",
                    "description": "Get the desktop shell config file contents",
                    "input_schema": {
                        "type": "object",
                        "properties": {}
                    }
                },
                {
                    "name": "set_shell_config",
                    "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "key": {
                                "type": "string",
                                "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting."
                            },
                            "value": {
                                "type": "string",
                                "description": "The value to set, e.g. `true`"
                            }
                        },
                        "required": ["key", "value"]
                    }
                },
                {
                    "name": "run_shell_command",
                    "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "The bash command to run"
                            }
                        },
                        "required": ["command"]
                    }
                },
            ],
            "search": [
                {
                    "type": "web_search_20250305",
                    "name": "web_search"
                }
            ],
            "none": []
        }
    }
    // An unknown API format — or no model at all, which is what an empty
    // "others" list leaves behind — must not empty the tool selector.
    property list<var> availableTools: Object.keys(root.tools[root.currentModelEntry?.api_format] ?? root.tools["openai"])
    property var toolDescriptions: {
        "functions": Translation.tr("Commands, edit configs, search.\nTakes an extra turn to switch to search mode if that's needed"),
        "search": Translation.tr("Gives the model search capabilities (immediately)"),
        "none": Translation.tr("Disable tools")
    }

    // Providers and models are described once, in the catalog. Nothing here
    // builds a model object or tests a provider name for substrings.
    readonly property ModelCatalog catalog: ModelCatalog {
        ollamaModelNames: root.ollamaModels
    }
    property var ollamaModels: []

    readonly property var providers: root.catalog.providers
    readonly property var providerIds: root.catalog.providerIds

    // The persisted provider/model pair is validated on read: either half can
    // be stale (a renamed model, a provider dropped by policy, a config the
    // user edited), and a half-valid pair points one provider's endpoint at a
    // model it does not serve.
    readonly property string currentProvider: {
        const wanted = Persistent.states?.ai?.provider ?? "";
        return root.providers[wanted] ? wanted : (root.providerIds[0] ?? "");
    }
    readonly property string currentModel: {
        const provider = root.providers[root.currentProvider];
        if (!provider)
            return "";
        const wanted = Persistent.states?.ai?.model ?? "";
        return provider.modelFor(wanted) ? wanted : (provider.defaultModel?.value ?? "");
    }
    readonly property string currentModelId: `${root.currentProvider}:${root.currentModel}`
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
    property string pendingFilePath: ""

    Component.onCompleted: {
        setModel(currentModelId, false, false); // Do necessary setup for model
    }

    // Boot-time index: Ollama models + default prompts + user prompts —
    // all in ONE Process spawn. Replaces four parallel
    // `Process { running: true }` invocations that fired on every boot
    // even if the user had never opened the AI panel.
    // Gated by Config.options.ai.enable: when false, no fork happens
    // until the user opens the AI panel (which sets the flag). This is
    // particularly useful for users without ollama installed (the
    // previous incarnation spawned a script that blocked ~50ms probing
    // the daemon on every boot).
    Process {
        id: aiIndexProc
        running: Config?.options?.ai?.enable ?? true
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
            Config.options.ai.systemPrompt = promptLoader.text();
            if (promptLoader.announce)
                root.addMessage(Translation.tr("Loaded the following system prompt\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
        }
    }

    function printPrompt() {
        root.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
    }

    function loadPrompt(filePath, feedback = true) {
        promptLoader.announce = feedback;
        root.currentPromptFile = filePath;
        promptLoader.path = ""; // Unload
        promptLoader.path = filePath; // Load
        promptLoader.reload();
    }

    function addMessage(message, role) {
        if (message.length === 0)
            return;
        const aiMessage = aiMessageComponent.createObject(root, {
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true
        });
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

    function addApiKeyAdvice(model) {
        root.addMessage(Translation.tr('To set an API key, pass it with the %4 command\n\nTo view the key, pass "get" with the command<br/>\n\n### For %1:\n\n**Link**: %2\n\n%3').arg(model.name).arg(model.key_get_link).arg(model.key_get_description ?? Translation.tr("<i>No further instruction provided</i>")).arg("/key"), Ai.interfaceRole);
    }

    function getModel() {
        return root.currentModelEntry;
    }

    /**
     * Selects a model, by catalog id, provider name or bare model name.
     * Provider and model are always written together: setting one without the
     * other aims a provider's endpoint at a model it does not serve.
     */
    function setModel(modelId, feedback = true, setPersistentState = true) {
        const model = root.catalog.models[root.resolveModelId(modelId)] ?? null;
        if (!model) {
            if (feedback)
                root.addMessage(Translation.tr("Invalid model. Supported:\n\n- %1").arg(root.catalog.modelIds.join("\n- ")), root.interfaceRole);
            return false;
        }
        if (setPersistentState) {
            Persistent.states.ai.provider = model.providerId;
            Persistent.states.ai.model = model.value;
            root.rememberModel(model.id);
        }
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
        const toolsOfFormat = root.tools[root.currentModelEntry?.api_format] ?? root.tools["openai"];
        if (!toolsOfFormat || !(tool in toolsOfFormat)) {
            root.addMessage(Translation.tr("Invalid tool. Supported tools:\n- %1").arg(root.availableTools.join("\n- ")), root.interfaceRole);
            return false;
        }
        Config.options.ai.tool = tool;
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
        Persistent.states.ai.temperature = value;
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
        Persistent.states.ai.thinkingLevel = value;
        root.thinkingLevel = value;
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

    function printApiKey() {
        const model = root.currentModelEntry;
        if (!model)
            return;
        if (model.requires_key) {
            const key = root.apiKeys[model.key_id];
            if (key) {
                root.addMessage(Translation.tr("API key:\n\n```txt\n%1\n```").arg(key), Ai.interfaceRole);
            } else {
                root.addMessage(Translation.tr("No API key set for %1").arg(model.name), Ai.interfaceRole);
            }
        } else {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
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
        root.autoTitle(); // Names it first, so the write below carries the name
        root.commitSession();
        root.responseFinished();
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

        onLine: data => {
            if (requester.message.thinking)
                requester.message.thinking = false;
            // console.log("[Ai] Raw response line: ", data);

            try {
                const result = requester.strategy.parseResponseLine(data, requester.message);
                // console.log("[Ai] Parsed response result: ", JSON.stringify(result, null, 2));

                if (result.functionCall) {
                    requester.message.functionCall = result.functionCall;
                    root.handleFunctionCall(result.functionCall.name, result.functionCall.args, requester.message);
                }
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

            if (reason === "aborted") {
                root.followUpQueued = false;
                const note = Translation.tr("\n\n*[Stopped]*");
                message.rawContent += note;
                message.content += note;
            } else {
                requester.strategy.onRequestFinished(message);
                // An error the strategy could not describe itself — a body it
                // never saw, or no body at all — still has to be visible.
                if (reason === "error" && message.content.length === 0) {
                    const note = root.transportErrorText(status, code);
                    message.rawContent += note;
                    message.content += note;
                }
            }

            message.thinking = false;
            if (!message.done)
                root.markDone(message);

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
    function makeRequest() {
        const model = root.currentModelEntry;
        if (!model) {
            root.addMessage(Translation.tr("No model selected. Pick one with %1model MODEL").arg("/"), root.interfaceRole);
            return;
        }
        if (requester.running) {
            root.addMessage(Translation.tr("Still answering. Stop the current response before sending another."), root.interfaceRole);
            return;
        }

        // Fetch API keys if needed
        if (model.requires_key && !KeyringStorage.loaded)
            KeyringStorage.fetchKeyringData();

        const strategy = root.currentApiStrategy;
        const messageArray = root.messageIDs.map(id => root.messageByID[id]);
        const filteredMessageArray = messageArray.filter(message => message.role !== root.interfaceRole);
        // Tool support is a property of the model, not of its address. A
        // local model that can call functions keeps them; a remote one
        // that cannot does not get them handed over anyway.
        const toolsOfFormat = root.tools[model.api_format] ?? root.tools["openai"];
        const tools = model.tools ? (toolsOfFormat[root.currentTool] ?? toolsOfFormat["none"]) : null;
        const attachedFilePath = root.pendingFilePath;

        const data = strategy.buildRequestData(model, filteredMessageArray, root.systemPrompt, root.temperature, tools, attachedFilePath);
        // console.log("[Ai] Request data: ", JSON.stringify(data, null, 2));

        /* Create local message object */
        const message = root.aiMessageComponent.createObject(root, {
            "role": "assistant",
            "model": root.currentModelId,
            "content": "",
            "rawContent": "",
            "thinking": true,
            "done": false
        });
        if (attachedFilePath.length > 0) {
            message.localFilePath = attachedFilePath;
            root.pendingFilePath = "";
        }
        const id = idForMessage(message);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = message;

        requester.model = model;
        requester.strategy = strategy;
        requester.message = message;
        requester.endpoint = strategy.buildEndpoint(model);
        requester.requestData = data;
        requester.filePath = attachedFilePath;
        requester.apiKey = model.requires_key ? (root.apiKeys?.[model.key_id] ?? "") : "";
        requester.start();
    }

    /**
     * Stops the answer being written, keeping whatever arrived so far.
     */
    function stopGeneration(): bool {
        root.followUpQueued = false;
        return requester.abort();
    }

    /**
     * Sends the next turn of a tool exchange. The call that asks for it is
     * answered from inside the stream that is still running, and a request
     * never replaces one in flight, so it waits for that stream to end.
     */
    function requestFollowUp() {
        if (requester.running) {
            root.followUpQueued = true;
            return;
        }
        root.makeRequest();
    }

    function sendUserMessage(message) {
        if (message.length === 0)
            return;
        root.addMessage(message, "user");
        // Written before the answer comes back, so a question survives a reply
        // that never arrives.
        root.sessions.scheduleSave();
        root.makeRequest();
    }

    Process {
        id: decodeImageAndAttachProc
        property string imageDecodePath: Directories.cliphistDecode
        property string imageDecodeFileName: "image"
        property string imageDecodeFilePath: `${imageDecodePath}/${imageDecodeFileName}`
        function handleEntry(entry: string) {
            imageDecodeFileName = parseInt(entry.match(/^(\d+)\t/)[1]);
            decodeImageAndAttachProc.exec(["bash", "-c", `[ -f ${imageDecodeFilePath} ] || echo '${CF.StringUtils.shellSingleQuoteEscape(entry)}' | ${Cliphist.cliphistBinary} decode > '${imageDecodeFilePath}'`]);
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Ai.attachFile(imageDecodeFilePath);
            } else {
                console.error("[Ai] Failed to decode image in clipboard content");
            }
        }
    }

    // This is being called by RegionSelection.qml
    function handleClipboardAndAttach() {
        handleClipboardTimer.start();
    }
    // We have to delay this a little to make sure the clipboard is updated
    Timer {
        id: handleClipboardTimer
        interval: 450
        onTriggered: {
            const currentClipboardEntry = Cliphist.entries[0];
            const cleanCliphistEntry = CF.StringUtils.cleanCliphistEntry(currentClipboardEntry);
            if (/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(currentClipboardEntry)) {
                // First entry = currently copied entry = image?
                decodeImageAndAttachProc.handleEntry(currentClipboardEntry);
                return;
            } else if (cleanCliphistEntry.startsWith("file://")) {
                // First entry = currently copied entry = image?
                const fileName = decodeURIComponent(cleanCliphistEntry);
                Ai.attachFile(fileName);
                return;
            }
        }
    }

    function attachFile(filePath: string) {
        root.pendingFilePath = CF.FileUtils.trimFileProtocol(filePath);
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

    function createFunctionOutputMessage(name, output, includeOutputInChat = true) {
        return aiMessageComponent.createObject(root, {
            "role": "user",
            "content": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "rawContent": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "functionName": name,
            "functionResponse": output,
            "thinking": false,
            "done": true
        // "visibleToUser": false,
        });
    }

    function addFunctionOutputMessage(name, output) {
        const aiMessage = createFunctionOutputMessage(name, output);
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function rejectCommand(message: AiMessageData) {
        if (!message.functionPending)
            return;
        message.functionPending = false; // User decided, no more "thinking"
        addFunctionOutputMessage(message.functionName, Translation.tr("Command rejected by user"));
    }

    function approveCommand(message: AiMessageData) {
        if (!message.functionPending)
            return;
        message.functionPending = false; // User decided, no more "thinking"

        const responseMessage = createFunctionOutputMessage(message.functionName, "", false);
        const id = idForMessage(responseMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = responseMessage;

        commandExecutionProc.message = responseMessage;
        commandExecutionProc.baseMessageContent = responseMessage.content;
        commandExecutionProc.shellCommand = message.functionCall.args.command;
        commandExecutionProc.running = true; // Start the command execution
    }

    Process {
        id: commandExecutionProc
        property string shellCommand: ""
        property AiMessageData message
        property string baseMessageContent: ""
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
            root.requestFollowUp(); // Continue
        }
    }

    function handleFunctionCall(name, args: var, message: AiMessageData) {
        if (name === "switch_to_search_mode") {
            const modelId = root.currentModelId;
            root.currentTool = "search";
            root.postResponseHook = () => {
                root.currentTool = "functions";
            };
            addFunctionOutputMessage(name, Translation.tr("Switched to search mode. Continue with the user's request."));
            root.requestFollowUp();
        } else if (name === "get_shell_config") {
            const configJson = CF.ObjectUtils.toPlainObject(Config.options);
            addFunctionOutputMessage(name, JSON.stringify(configJson));
            root.requestFollowUp();
        } else if (name === "set_shell_config") {
            if (!args.changes || !Array.isArray(args.changes)) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `changes` array."));
                return;
            }
            let results = [];
            for (const change of args.changes) {
                if (!change.key || !change.value) {
                    results.push(`❌ Skipped invalid change: ${JSON.stringify(change)}`);
                    continue;
                }
                try {
                    Config.setNestedValue(change.key, change.value);
                    results.push(`✓ ${change.key} = ${change.value}`);
                } catch (e) {
                    results.push(`❌ Failed to set ${change.key}: ${e}`);
                }
            }
            addFunctionOutputMessage(name, results.join("\n"));
            root.requestFollowUp();
        } else if (name === "run_shell_command") {
            if (!args.command || args.command.length === 0) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `command`."));
                return;
            }
            const contentToAppend = `\n\n**Command execution request**\n\n\`\`\`command\n${args.command}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            message.functionPending = true; // Use thinking to indicate the command is waiting for approval
        } else
            root.addMessage(Translation.tr("Unknown function call: %1").arg(name), "assistant");
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
        onCurrentDropped: root.newChat()
    }

    readonly property int sessionSchema: 1
    /** Name of the conversation on screen. Empty until it earns one. */
    property string sessionTitle: ""
    property real sessionCreatedAt: 0
    /** Whether the model has already been asked to name this one. */
    property bool sessionTitleAsked: false

    function messageToJson(id: string): var {
        const message = root.messageByID[id];
        return ({
                "id": id,
                "role": message.role,
                "rawContent": message.rawContent,
                "fileMimeType": message.fileMimeType,
                "fileUri": message.fileUri,
                "localFilePath": message.localFilePath,
                "model": message.model,
                "thought": message.thought,
                "thoughtSignature": message.thoughtSignature,
                "thinkingBlocks": message.thinkingBlocks,
                "thoughtDurationMs": message.thoughtDurationMs,
                "thoughtTokens": message.thoughtTokens,
                "thinking": false,
                "done": true,
                "annotations": message.annotations,
                "annotationSources": message.annotationSources,
                "functionName": message.functionName,
                "functionCall": message.functionCall,
                "functionResponse": message.functionResponse,
                "visibleToUser": message.visibleToUser
            });
    }

    function chatToJson() {
        return root.messageIDs.map(id => root.messageToJson(id));
    }

    function messageFromJson(data: var): AiMessageData {
        return root.aiMessageComponent.createObject(root, {
            "role": data.role,
            "rawContent": data.rawContent,
            "content": data.rawContent,
            "fileMimeType": data.fileMimeType,
            "fileUri": data.fileUri,
            "localFilePath": data.localFilePath,
            "model": data.model,
            "thought": data.thought ?? "",
            "thoughtSignature": data.thoughtSignature ?? "",
            "thinkingBlocks": data.thinkingBlocks ?? [],
            "thoughtDurationMs": data.thoughtDurationMs ?? 0,
            "thoughtTokens": data.thoughtTokens ?? -1,
            "thinking": data.thinking ?? false,
            "done": data.done ?? true,
            "annotations": data.annotations ?? [],
            "annotationSources": data.annotationSources ?? [],
            "functionName": data.functionName ?? "",
            "functionCall": data.functionCall,
            "functionResponse": data.functionResponse ?? "",
            "visibleToUser": data.visibleToUser ?? true
        });
    }

    function sessionToJson(): var {
        return ({
                "schema": root.sessionSchema,
                "id": root.sessions.currentId,
                "title": root.sessionTitle,
                "createdAt": root.sessionCreatedAt > 0 ? root.sessionCreatedAt : Date.now(),
                "updatedAt": Date.now(),
                "pinned": root.sessions.currentEntry?.pinned ?? false,
                "modelId": root.currentModelId,
                "thinking": root.thinkingLevel,
                "temperature": root.temperature,
                "promptFile": root.currentPromptFile,
                "messages": root.chatToJson()
            });
    }

    /**
     * Writes the conversation on screen. An empty chat is not a session: one
     * is only started once there is something in it.
     */
    function commitSession() {
        if (root.messageIDs.length === 0)
            return;
        if (root.sessions.currentId.length === 0) {
            root.sessions.currentId = root.sessions.newId();
            root.sessionCreatedAt = Date.now();
        }
        root.sessions.commit(root.sessionToJson());
    }

    /** Puts the conversation away and starts an empty one. */
    function newChat() {
        root.commitSession();
        root.clearMessages();
        root.sessions.currentId = "";
        root.sessionTitle = "";
        root.sessionCreatedAt = 0;
        root.sessionTitleAsked = false;
        root.sessions.ensureLoaded();
    }

    function openSession(sessionId: string) {
        if (sessionId.length === 0 || sessionId === root.sessions.currentId)
            return;
        root.commitSession(); // Whatever is on screen keeps its own file
        root.sessions.openSession(sessionId);
    }

    /**
     * Replaces the conversation with one read from disk, settings included:
     * a chat is remembered as it was held, not as the sidebar happens to be
     * set right now.
     */
    function applySession(session: var) {
        root.stopGeneration();
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
        if (session.modelId && root.catalog.models[session.modelId])
            root.setModel(session.modelId, false);
        if (session.thinking && root.thinkingLevels.indexOf(session.thinking) >= 0)
            root.setThinkingLevel(session.thinking);
        if (typeof session.temperature === "number")
            root.setTemperature(session.temperature, false);
        root.currentPromptFile = session.promptFile ?? "";
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
        root.requestTitle(opening);
    }

    function requestTitle(opening: string) {
        const model = root.currentModelEntry;
        if (!model || titleRequester.running)
            return;
        if (model.requires_key && !(root.apiKeys?.[model.key_id]?.length > 0))
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
        const data = strategy.buildRequestData(model, [prompt], root.titleInstruction, 0.2, null, "");
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
            root.sessionTitle = suggested;
            root.commitSession();
        }
    }
}
