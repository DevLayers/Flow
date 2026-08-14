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
 * Basic service to handle LLM chats. Supports Google's and OpenAI's API formats.
 * Supports Gemini and OpenAI models.
 * Limitations:
 * - For now functions only work with Gemini API format
 */
Singleton {
    id: root

    property Component aiMessageComponent: AiMessageData {}
    property Component geminiApiStrategy: GeminiApiStrategy {}
    property Component openaiApiStrategy: OpenAiApiStrategy {}
    property Component mistralApiStrategy: MistralApiStrategy {}
    readonly property string interfaceRole: "interface"
    readonly property string apiKeyEnvVarName: "API_KEY"

    signal responseFinished
    readonly property bool isGenerating: requester.running
    // Set while a failed request waits to be sent again, so the UI can say so
    // instead of looking stuck.
    property string retryNotice: ""

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
        property int total: -1
    }

    function idForMessage(message) {
        // Generate a unique ID using timestamp and random value
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 8);
    }

    property list<var> defaultPrompts: []
    property list<var> userPrompts: []
    property list<var> promptFiles: [...defaultPrompts, ...userPrompts]
    property list<var> savedChats: []

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
        "mistral": {
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
        "openai": openaiApiStrategy.createObject(this),
        "gemini": geminiApiStrategy.createObject(this),
        "mistral": mistralApiStrategy.createObject(this)
    }
    property ApiStrategy currentApiStrategy: apiStrategies[root.currentModelEntry?.api_format || "openai"]

    property string requestScriptFilePath: `/tmp/quickshell-${SystemInfo.username}/ai/request.sh`
    property string pendingFilePath: ""

    Component.onCompleted: {
        setModel(currentModelId, false, false); // Do necessary setup for model
    }

    // Boot-time index: Ollama models + default prompts + user prompts +
    // saved chats — all in ONE Process spawn. Replaces four parallel
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
            Directories.userAiPrompts.toString().replace(/file:\/\//, ""),
            Directories.aiChats.toString().replace(/file:\/\//, "")
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

                // Prompts + chats (already absolute, filtered by extension)
                if (Array.isArray(parsed.default_prompts))
                    root.defaultPrompts = parsed.default_prompts
                if (Array.isArray(parsed.user_prompts))
                    root.userPrompts = parsed.user_prompts
                if (Array.isArray(parsed.saved_chats))
                    root.savedChats = parsed.saved_chats
            }
        }
    }

    // Re-lists saved chats only, after a save or load. Deliberately not
    // aiIndexProc: re-running the boot index would probe ollama again and
    // re-append its models to modelList on every single save.
    Process {
        id: savedChatsProc
        command: [
            "python3",
            Directories.scriptPath + "/ai/ai_index.py".replace(/file:\/\//, ""),
            "--chats-only",
            Directories.aiChats.toString().replace(/file:\/\//, "")
        ]
        stdout: StdioCollector {
            id: savedChatsCollector
            onStreamFinished: {
                const raw = savedChatsCollector.text.trim()
                if (raw.length === 0)
                    return
                try {
                    const parsed = JSON.parse(raw)
                    if (Array.isArray(parsed.saved_chats))
                        root.savedChats = parsed.saved_chats
                } catch (e) {
                    console.log("[AI] Saved chats parse error:", e)
                }
            }
        }
    }

    /**
     * Re-reads the saved chat directory into `savedChats`.
     */
    function refreshSavedChats() {
        savedChatsProc.running = false;
        savedChatsProc.running = true;
    }

    FileView {
        id: promptLoader
        watchChanges: false
        onLoadedChanged: {
            if (!promptLoader.loaded)
                return;
            Config.options.ai.systemPrompt = promptLoader.text();
            root.addMessage(Translation.tr("Loaded the following system prompt\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
        }
    }

    function printPrompt() {
        root.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
    }

    function loadPrompt(filePath) {
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

    function removeMessage(index) {
        if (index < 0 || index >= messageIDs.length)
            return;
        const id = root.messageIDs[index];
        root.messageIDs.splice(index, 1);
        root.messageIDs = [...root.messageIDs];
        delete root.messageByID[id];
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
        }
        if (feedback)
            root.addMessage(Translation.tr("Model set to %1").arg(model.name), root.interfaceRole);
        if (model.requires_key && root.apiKeysLoaded && !(root.apiKeys[model.key_id]?.length > 0))
            root.addApiKeyAdvice(model);
        return true;
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
        const toolsOfFormat = root.tools[root.currentModelEntry?.api_format];
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

    function setTemperature(value) {
        if (value == NaN || value < 0 || value > 2) {
            root.addMessage(Translation.tr("Temperature must be between 0 and 2"), Ai.interfaceRole);
            return;
        }
        Persistent.states.ai.temperature = value;
        root.temperature = value;
        root.addMessage(Translation.tr("Temperature set to %1").arg(value), Ai.interfaceRole);
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
        root.tokenCount.total = -1;
    }

    function markDone(message: AiMessageData) {
        if (!message)
            return;
        message.done = true;
        if (root.postResponseHook) {
            root.postResponseHook();
            root.postResponseHook = null; // Reset hook after use
        }
        root.saveChat("lastSession");
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
        return requester.abort();
    }

    function sendUserMessage(message) {
        if (message.length === 0)
            return;
        root.addMessage(message, "user");
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

    function regenerate(messageIndex) {
        if (messageIndex < 0 || messageIndex >= messageIDs.length)
            return;
        const id = root.messageIDs[messageIndex];
        const message = root.messageByID[id];
        if (message.role !== "assistant")
            return;
        // Remove all messages after this one
        for (let i = root.messageIDs.length - 1; i >= messageIndex; i--) {
            root.removeMessage(i);
        }
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
            root.makeRequest(); // Continue
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
            root.makeRequest();
        } else if (name === "get_shell_config") {
            const configJson = CF.ObjectUtils.toPlainObject(Config.options);
            addFunctionOutputMessage(name, JSON.stringify(configJson));
            root.makeRequest();
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
            root.makeRequest();
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

    function chatToJson() {
        return root.messageIDs.map(id => {
            const message = root.messageByID[id];
            return ({
                    "role": message.role,
                    "rawContent": message.rawContent,
                    "fileMimeType": message.fileMimeType,
                    "fileUri": message.fileUri,
                    "localFilePath": message.localFilePath,
                    "model": message.model,
                    "thinking": false,
                    "done": true,
                    "annotations": message.annotations,
                    "annotationSources": message.annotationSources,
                    "functionName": message.functionName,
                    "functionCall": message.functionCall,
                    "functionResponse": message.functionResponse,
                    "visibleToUser": message.visibleToUser
                });
        });
    }

    FileView {
        id: chatSaveFile
        property string chatName: ""
        path: chatName.length > 0 ? `${Directories.aiChats}/${chatName}.json` : ""
        blockLoading: true // Prevent race conditions
    }

    /**
     * Saves chat to a JSON list of message objects.
     * @param chatName name of the chat
     */
    function saveChat(chatName) {
        chatSaveFile.chatName = chatName.trim();
        const saveContent = JSON.stringify(root.chatToJson());
        chatSaveFile.setText(saveContent);
        root.refreshSavedChats();
    }

    /**
     * Loads chat from a JSON list of message objects.
     * @param chatName name of the chat
     */
    function loadChat(chatName) {
        try {
            chatSaveFile.chatName = chatName.trim();
            chatSaveFile.reload();
            const saveContent = chatSaveFile.text();
            // console.log(saveContent)
            const saveData = JSON.parse(saveContent);
            root.clearMessages();
            root.messageIDs = saveData.map((_, i) => {
                return i;
            });
            // console.log(JSON.stringify(messageIDs))
            for (let i = 0; i < saveData.length; i++) {
                const message = saveData[i];
                root.messageByID[i] = root.aiMessageComponent.createObject(root, {
                    "role": message.role,
                    "rawContent": message.rawContent,
                    "content": message.rawContent,
                    "fileMimeType": message.fileMimeType,
                    "fileUri": message.fileUri,
                    "localFilePath": message.localFilePath,
                    "model": message.model,
                    "thinking": message.thinking,
                    "done": message.done,
                    "annotations": message.annotations,
                    "annotationSources": message.annotationSources,
                    "functionName": message.functionName,
                    "functionCall": message.functionCall,
                    "functionResponse": message.functionResponse,
                    "visibleToUser": message.visibleToUser
                });
            }
        } catch (e) {
            console.log("[AI] Could not load chat: ", e);
        } finally {
            root.refreshSavedChats();
        }
    }
}
