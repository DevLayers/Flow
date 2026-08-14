import QtQuick
import qs.services
import qs.modules.common

/**
 * The single source of truth for which AI providers and models exist.
 *
 * Everything the shell knows about a model — endpoint, API dialect, key,
 * display name and capabilities — is assembled here, from three inputs:
 *
 *   1. the built-in provider definitions below
 *   2. the user's config (`ai.models` adds models to a provider,
 *      `ai.otherModels` defines standalone custom models)
 *   3. models discovered on the local Ollama daemon
 *
 * Consumers look models up by id, which is always "provider:value". Nothing
 * outside this file should special-case a provider name or sniff an endpoint
 * for substrings.
 */

QtObject {
    id: catalog

    property Component modelComponent: AiModel {}
    property Component providerComponent: AiProvider {}

    /** Model names reported by the local Ollama daemon. Set by the Ai service. */
    property var ollamaModelNames: []

    /** Keys accepted from a user-defined `ai.otherModels` entry. */
    readonly property var customModelKeys: ["name", "title", "icon", "description", "homepage", "endpoint", "model", "value", "requires_key", "key_id", "key_get_link", "key_get_description", "api_format", "extraParams", "modelProvider", "thinking", "thinkingKind", "attachments", "vision", "tools", "builtinSearch", "samplingParams", "contextWindow", "maxOutput"]

    readonly property var providerDefs: [
        {
            id: "google",
            name: "Google",
            icon: "google-gemini-symbolic",
            description: Translation.tr("Online | Google's models, straight from AI Studio"),
            homepage: "https://aistudio.google.com",
            endpoint: "https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent",
            api_format: "gemini",
            key_id: "gemini",
            key_get_link: "https://aistudio.google.com/app/apikey",
            key_get_description: Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            capabilities: {
                attachments: true,
                vision: true,
                tools: true,
                builtinSearch: true,
                contextWindow: 1048576,
                maxOutput: 65536
            },
            models: [
                {
                    value: "gemini-2.5-flash-lite",
                    title: "Gemini 2.5 Flash-Lite",
                    thinking: true,
                    thinkingKind: "gemini"
                },
                {
                    value: "gemini-2.5-flash",
                    title: "Gemini 2.5 Flash",
                    thinking: true,
                    thinkingKind: "gemini"
                },
                {
                    value: "gemini-3-flash-preview",
                    title: "Gemini 3 Flash Preview",
                    thinking: true,
                    thinkingKind: "gemini",
                    samplingParams: false
                }
            ]
        },
        {
            id: "openrouter",
            name: "OpenRouter",
            icon: "openrouter-symbolic",
            description: Translation.tr("Online | One key for models from many vendors"),
            homepage: "https://openrouter.ai",
            endpoint: "https://openrouter.ai/api/v1/chat/completions",
            key_id: "openrouter",
            key_get_link: "https://openrouter.ai/settings/keys",
            key_get_description: Translation.tr("**Pricing**: Pay-as-you-go (token based).\n\n" + "**Instructions**: Log into your OpenRouter account, " + "go to Keys in the top-right menu, and create an API key."),
            capabilities: {
                tools: true
            },
            models: [
                {
                    value: "gemini-2.5-flash-lite",
                    title: "Gemini 2.5 Flash-Lite",
                    modelProvider: "google",
                    thinking: true,
                    thinkingKind: "effort"
                },
                {
                    value: "deepseek-v4-flash",
                    title: "DeepSeek V4 Flash",
                    modelProvider: "deepseek"
                }
            ]
        },
        {
            id: "deepseek",
            name: "DeepSeek",
            icon: "deepseek-symbolic",
            description: Translation.tr("Online | DeepSeek Official API\nHigh intelligence AI models for coding and general tasks"),
            homepage: "https://platform.deepseek.com",
            endpoint: "https://api.deepseek.com/chat/completions",
            key_id: "deepseek",
            key_get_link: "https://platform.deepseek.com/api_keys",
            key_get_description: Translation.tr("**Pricing**: Pay-as-you-go.\n\n**Instructions**: Log into DeepSeek Platform, go to API Keys and create a key."),
            capabilities: {
                tools: true
            },
            models: [
                {
                    value: "deepseek-v4-flash",
                    title: "DeepSeek V4 Flash"
                },
                {
                    value: "deepseek-v4-pro",
                    title: "DeepSeek V4 Pro"
                }
            ]
        },
        {
            id: "opencode",
            name: "OpenCode",
            materialIcon: "code",
            description: Translation.tr("Online | OpenCode Zen API\nPowered by DeepSeek V4 Flash"),
            homepage: "https://opencode.ai",
            endpoint: "https://api.opencode.ai/v1/chat/completions",
            key_id: "opencode",
            key_get_link: "https://opencode.ai",
            key_get_description: Translation.tr("**Pricing**: OpenCode subscription or API key.\n\n**Instructions**: Enter your OpenCode API key."),
            capabilities: {
                tools: true
            },
            models: [
                {
                    value: "deepseek-v4-flash",
                    title: "DeepSeek V4 Flash (Zen)"
                }
            ]
        },
        {
            id: "ollama",
            name: "Ollama",
            icon: "ollama-symbolic",
            description: Translation.tr("Local | Models installed on this machine"),
            homepage: "https://ollama.com",
            endpoint: "http://localhost:11434/v1/chat/completions",
            requires_key: false,
            local: true,
            capabilities: {
                // Plenty of local models do handle function calling, but the
                // daemon does not tell us which. Off unless the user opts in.
                tools: false
            },
            models: []
        },
        {
            id: "others",
            name: Translation.tr("Others"),
            materialIcon: "more_horiz",
            description: Translation.tr("Your own models, from the AI settings page"),
            models: []
        }
    ]

    readonly property var providers: {
        const result = {};
        const onlineDisallowed = Config.options?.policies?.ai === 2;
        const extras = catalog.extraModelsByProvider;

        for (let i = 0; i < catalog.providerDefs.length; i++) {
            const def = catalog.providerDefs[i];
            if (onlineDisallowed && !def.local)
                continue;
            let entries = (def.models ?? []).slice();
            if (def.id === "ollama")
                entries = catalog.ollamaEntries;
            else if (def.id === "others")
                entries = catalog.customEntries;
            if (extras[def.id])
                entries = entries.concat(extras[def.id]);
            result[def.id] = catalog.buildProvider(def, entries);
        }
        return result;
    }

    readonly property var providerIds: Object.keys(catalog.providers)

    /** Every model in the catalog, keyed by "provider:value". */
    readonly property var models: {
        const result = {};
        const ids = catalog.providerIds;
        for (let i = 0; i < ids.length; i++) {
            const list = catalog.providers[ids[i]].models;
            for (let j = 0; j < list.length; j++) {
                result[list[j].id] = list[j];
            }
        }
        return result;
    }

    readonly property var modelIds: Object.keys(catalog.models)

    /** `ai.models` config entries, flattened to {providerId: [modelDef, ...]}. */
    readonly property var extraModelsByProvider: {
        const result = {};
        const configList = Config.options?.ai?.models;
        if (!configList)
            return result;
        for (let i = 0; i < configList.length; i++) {
            const item = configList[i];
            for (const providerId in item) {
                const entries = item[providerId];
                if (!entries || entries.length === 0)
                    continue;
                const collected = result[providerId] ?? [];
                for (let j = 0; j < entries.length; j++) {
                    collected.push(entries[j]);
                }
                result[providerId] = collected;
            }
        }
        return result;
    }

    /** Discovered Ollama models, as model definitions. */
    readonly property var ollamaEntries: {
        const names = catalog.ollamaModelNames ?? [];
        const toolsAllowed = Config.options?.ai?.localModelTools ?? false;
        const result = [];
        for (let i = 0; i < names.length; i++) {
            result.push({
                value: names[i],
                title: catalog.guessModelName(names[i]),
                icon: catalog.guessModelLogo(names[i]),
                description: Translation.tr("Local Ollama model | %1").arg(names[i]),
                homepage: `https://ollama.com/library/${names[i]}`,
                tools: toolsAllowed
            });
        }
        return result;
    }

    /** `ai.otherModels` config entries, sanitised into model definitions. */
    readonly property var customEntries: {
        const configList = Config.options?.ai?.otherModels;
        const result = [];
        if (!configList)
            return result;
        for (let i = 0; i < configList.length; i++) {
            const entry = catalog.sanitizeCustomModel(configList[i]);
            if (entry)
                result.push(entry);
        }
        return result;
    }

    /**
     * Drops unknown keys so a typo in the user's config cannot blow up object
     * creation, and settles on a stable selection key.
     */
    function sanitizeCustomModel(raw): var {
        if (!raw)
            return null;
        const entry = {};
        for (let i = 0; i < catalog.customModelKeys.length; i++) {
            const key = catalog.customModelKeys[i];
            if (raw[key] !== undefined)
                entry[key] = raw[key];
        }
        entry.value = raw.id || raw.value || raw.model || raw.name;
        if (!entry.value)
            return null;
        if (!entry.title)
            entry.title = raw.name || entry.value;
        return entry;
    }

    function buildProvider(def, entries) {
        const provider = catalog.providerComponent.createObject(catalog, {
            id: def.id,
            name: def.name,
            icon: def.icon ?? "",
            materialIcon: def.materialIcon ?? "",
            description: def.description ?? "",
            homepage: def.homepage ?? "",
            endpoint: def.endpoint ?? "",
            api_format: def.api_format ?? "openai",
            requires_key: def.requires_key ?? true,
            key_id: def.key_id ?? def.id,
            key_get_link: def.key_get_link ?? "",
            key_get_description: def.key_get_description ?? "",
            local: def.local ?? false
        });
        const models = [];
        for (let i = 0; i < entries.length; i++) {
            const model = catalog.buildModel(def, provider, entries[i]);
            if (model)
                models.push(model);
        }
        provider.models = models;
        return provider;
    }

    function buildModel(def, provider, entry) {
        const value = entry.value ?? entry.model ?? "";
        if (value.length === 0)
            return null;
        const caps = def.capabilities ?? {};
        const pick = (key, fallback) => entry[key] ?? caps[key] ?? fallback;
        const title = entry.title ?? value;
        const endpoint = (entry.endpoint ?? provider.endpoint ?? "").replace("{model}", entry.model ?? value);
        const modelProvider = entry.modelProvider ?? "";
        return catalog.modelComponent.createObject(catalog, {
            id: `${provider.id}:${value}`,
            providerId: provider.id,
            value: value,
            title: title,
            modelProvider: modelProvider,
            name: provider.id === "others" ? title : `${provider.name} - ${title}`,
            icon: entry.icon ?? provider.icon,
            materialIcon: (entry.icon ?? provider.icon).length > 0 ? "" : (provider.materialIcon.length > 0 ? provider.materialIcon : "wand_stars"),
            description: entry.description ?? provider.description,
            homepage: entry.homepage ?? provider.homepage,
            endpoint: endpoint,
            model: modelProvider.length > 0 ? `${modelProvider}/${value}` : (entry.model ?? value),
            requires_key: entry.requires_key ?? provider.requires_key,
            key_id: entry.key_id ?? provider.key_id,
            key_get_link: entry.key_get_link ?? provider.key_get_link,
            key_get_description: entry.key_get_description ?? provider.key_get_description,
            api_format: entry.api_format ?? provider.api_format,
            extraParams: entry.extraParams ?? ({}),
            thinking: pick("thinking", false),
            thinkingKind: pick("thinkingKind", ""),
            attachments: pick("attachments", false),
            vision: pick("vision", false),
            tools: pick("tools", true),
            builtinSearch: pick("builtinSearch", false),
            samplingParams: pick("samplingParams", true),
            contextWindow: pick("contextWindow", 0),
            maxOutput: pick("maxOutput", 0)
        });
    }

    /** The model at "provider:value", or null. */
    function resolve(providerId, value) {
        return catalog.models[`${providerId}:${value}`] ?? null;
    }

    /** Selection entries for a provider, in the shape the model pickers want. */
    function selectionEntries(providerId: string): var {
        const provider = catalog.providers[providerId];
        if (!provider)
            return [];
        return provider.models.map(model => ({
                    title: model.title,
                    value: model.value,
                    modelProvider: model.modelProvider
                }));
    }

    function guessModelLogo(model: string): string {
        if (model.includes("llama"))
            return "ollama-symbolic";
        if (model.includes("gemma"))
            return "google-gemini-symbolic";
        if (model.includes("deepseek"))
            return "deepseek-symbolic";
        if (/^phi\d*:/i.test(model))
            return "microsoft-symbolic";
        return "ollama-symbolic";
    }

    function guessModelName(model: string): string {
        const replaced = model.replace(/-/g, ' ').replace(/:/g, ' ');
        let words = replaced.split(' ');
        words[words.length - 1] = words[words.length - 1].replace(/(\d+)b$/, (_, num) => `${num}B`);
        words = words.map(word => {
            return (word.charAt(0).toUpperCase() + word.slice(1));
        });
        if (words[words.length - 1] === "Latest")
            words.pop();
        else
            words[words.length - 1] = `(${words[words.length - 1]})`;
        return words.join(' ');
    }
}
