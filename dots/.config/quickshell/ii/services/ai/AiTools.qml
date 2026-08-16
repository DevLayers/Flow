import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * What the assistant is allowed to reach for, and what it did with it.
 *
 * Every tool is described once, here. The three API dialects disagree only on
 * where the name, the description and the parameter schema go, so the wire
 * shape is generated rather than written out per format — which is what used
 * to make adding a tool a three-place edit, with the copies drifting apart
 * (the config tool took a list of changes on Gemini and a single key/value
 * everywhere else).
 *
 * Permission is per tool and lives in the config: a tool is either allowed
 * outright, refused outright, or asks first — and asking is the default for
 * anything that writes. Nothing here executes: the Ai service owns that, and
 * calls back in to log what happened.
 */
Scope {
    id: root

    /** API dialect of the model in use, and whether it has search of its own. */
    property string apiFormat: "openai"
    property bool searchAvailable: false
    /** Profile-level exposure; permissions below remain per-tool approvals. */
    property string functionExposure: "all"
    property bool localOnly: false

    // ── Registry ──────────────────────────────────────────────────────────
    // `description` is what the model reads, `title`/`summary` what the user
    // reads. `risk` is only for presentation: the lists in the config decide
    // what actually runs.
    readonly property var definitions: [
        {
            id: "switch_to_search_mode",
            title: Translation.tr("Switch to web search"),
            summary: Translation.tr("Lets it hand the turn over to the provider's own search when a question needs today's answer."),
            icon: "travel_explore",
            risk: "safe",
            description: "Switch to search mode to perform web searches. Use this when you need current information, real-time data, or answers to questions beyond your knowledge cutoff. After switching, continue with the user's original request.",
            parameters: null,
            formats: ["gemini"],
            needsSearch: true
        },
        {
            id: "get_shell_config",
            title: Translation.tr("Read the shell settings"),
            summary: Translation.tr("Reads config.json so it can name real settings instead of guessing them. Nothing is changed."),
            icon: "settings",
            risk: "safe",
            description: "Retrieve the complete desktop shell configuration file in JSON format. Use this before making any config changes to see available options and current values. Returns the full config structure. Don't ask for permission, run directly.",
            parameters: null,
            formats: ["gemini", "openai", "anthropic"],
            needsSearch: false
        },
        {
            id: "set_shell_config",
            title: Translation.tr("Change the shell settings"),
            summary: Translation.tr("Writes settings. Every change is shown with its current value before anything is applied."),
            icon: "tune",
            risk: "writes",
            description: "Modify one or multiple fields in the desktop shell config at once. CRITICAL: You MUST call get_shell_config first to see available keys — never guess key names. Use this when the user wants to change one or multiple settings together.",
            parameters: {
                type: "object",
                properties: {
                    changes: {
                        type: "array",
                        description: "Config changes to apply",
                        items: {
                            type: "object",
                            properties: {
                                key: {
                                    type: "string",
                                    description: "The key to set, e.g. `bar.borderless`"
                                },
                                value: {
                                    type: "string",
                                    description: "The value to set, e.g. `true`"
                                }
                            },
                            required: ["key", "value"]
                        }
                    }
                },
                required: ["changes"]
            },
            formats: ["gemini", "openai", "anthropic"],
            needsSearch: false
        },
        {
            id: "run_shell_command",
            title: Translation.tr("Run a command"),
            summary: Translation.tr("Runs a command in bash and reads its output back. The command is shown before it runs."),
            icon: "terminal",
            risk: "danger",
            description: "Execute a bash command and return its output. Only use for quick, non-interactive commands (queries, checks, simple operations). For interactive commands, long-running processes, or dangerous operations, ask the user to run them manually instead.",
            parameters: {
                type: "object",
                properties: {
                    command: {
                        type: "string",
                        description: "The bash command to run"
                    }
                },
                required: ["command"]
            },
            formats: ["gemini", "openai", "anthropic"],
            needsSearch: false
        }
    ]

    /** The provider's own web search, which is a tool the shell never runs. */
    readonly property var searchPayloads: ({
            "gemini": [
                {
                    "google_search": {}
                }
            ],
            "anthropic": [
                {
                    "type": "web_search_20250305",
                    "name": "web_search"
                }
            ]
        })

    function definitionFor(id: string): var {
        const list = root.definitions;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i];
        }
        return null;
    }

    function titleFor(id: string): string {
        return root.definitionFor(id)?.title ?? id;
    }

    // ── Modes ─────────────────────────────────────────────────────────────
    readonly property string mode: Config.options?.ai?.tools?.mode ?? "functions"

    /**
     * Modes the model in use can actually deliver. A format with no search of
     * its own must not offer a search mode: picking it used to hand over an
     * empty tool list, so the model quietly answered from memory.
     */
    function modesFor(format: string): var {
        const modes = ["functions"];
        if (root.searchPayloads[format] !== undefined)
            modes.push("search");
        modes.push("none");
        return modes;
    }

    readonly property var availableModes: root.modesFor(root.apiFormat)

    readonly property var modeDescriptions: ({
            "functions": Translation.tr("Commands, settings, and a hop to search.\nEach tool asks or runs by its own rule"),
            "search": Translation.tr("Gives the model search capabilities (immediately)"),
            "none": Translation.tr("Disable tools")
        })

    readonly property var modeLabels: ({
            "functions": Translation.tr("Tools"),
            "search": Translation.tr("Search"),
            "none": Translation.tr("None")
        })

    // ── Permissions ───────────────────────────────────────────────────────
    // Two lists rather than a map: JsonAdapter stores list<string> honestly,
    // where a map with tool ids for keys has no schema to repair against.
    // A tool in neither list asks.
    readonly property var permissionValues: ["allow", "ask", "deny"]

    function permission(id: string): string {
        const tools = Config.options?.ai?.tools;
        if (!tools)
            return "ask";
        if (Array.from(tools.alwaysDeny ?? []).indexOf(id) !== -1)
            return "deny";
        if (Array.from(tools.alwaysAllow ?? []).indexOf(id) !== -1)
            return "allow";
        return "ask";
    }

    function setPermission(id: string, value: string) {
        const tools = Config.options?.ai?.tools;
        if (!tools || root.permissionValues.indexOf(value) === -1)
            return;
        const allow = Array.from(tools.alwaysAllow ?? []).filter(entry => entry !== id);
        const deny = Array.from(tools.alwaysDeny ?? []).filter(entry => entry !== id);
        if (value === "allow")
            allow.push(id);
        else if (value === "deny")
            deny.push(id);
        tools.alwaysAllow = allow;
        tools.alwaysDeny = deny;
    }

    readonly property var permissionLabels: ({
            "allow": Translation.tr("Always"),
            "ask": Translation.tr("Ask first"),
            "deny": Translation.tr("Never")
        })

    /** Whether a settings change is shown before it is written. */
    readonly property bool reviewsConfigChanges: Config.options?.ai?.tools?.reviewConfigChanges ?? true

    // ── Wire format ───────────────────────────────────────────────────────
    /** Tools offered to a model of this dialect, minus the refused ones. */
    function enabledFor(format: string): var {
        const list = root.definitions;
        const result = [];
        for (let i = 0; i < list.length; i++) {
            const def = list[i];
            if (def.formats.indexOf(format) === -1)
                continue;
            if (def.needsSearch && !root.searchAvailable)
                continue;
            if (root.functionExposure === "none")
                continue;
            if (root.functionExposure === "safe" && def.risk !== "safe")
                continue;
            if (root.localOnly && def.id === "run_shell_command")
                continue;
            if (root.permission(def.id) === "deny")
                continue;
            result.push(def);
        }
        return result;
    }

    function functionSchema(def: var, format: string): var {
        const parameters = def.parameters;
        if (format === "gemini") {
            const schema = {
                name: def.id,
                description: def.description
            };
            if (parameters)
                schema.parameters = parameters;
            return schema;
        }
        if (format === "anthropic")
            return {
                name: def.id,
                description: def.description,
                input_schema: parameters ?? {
                    type: "object",
                    properties: {}
                }
            };
        return {
            type: "function",
            function: {
                name: def.id,
                description: def.description,
                parameters: parameters ?? {}
            }
        };
    }

    /** What goes in the request body. Empty means "no tools this turn". */
    function wireTools(format: string, mode: string): var {
        if (mode === "none")
            return [];
        if (mode === "search")
            return root.searchPayloads[format] ?? [];
        const enabled = root.enabledFor(format);
        if (enabled.length === 0)
            return [];
        if (format === "gemini")
            return [
                {
                    functionDeclarations: enabled.map(def => root.functionSchema(def, format))
                }
            ];
        return enabled.map(def => root.functionSchema(def, format));
    }

    // ── Call log ──────────────────────────────────────────────────────────
    // A tool call is the one thing the assistant does that outlives the chat
    // it was asked in, so it is worth a record that is not a chat bubble.
    readonly property int logSize: Math.max(0, Config.options?.ai?.tools?.logSize ?? 50)
    property var callLog: []
    property int callSerial: 0
    signal callCheckpointChanged(var entry)

    function describeArgs(id: string, args: var): string {
        if (!args)
            return "";
        if (id === "run_shell_command")
            return String(args.command ?? "");
        if (id === "set_shell_config") {
            const changes = Array.from(args.changes ?? []);
            return changes.map(change => `${change.key} = ${change.value}`).join(", ");
        }
        return "";
    }

    /** Records a call as it starts and returns the handle to finish it with. */
    function noteCall(id: string, args: var): int {
        if (root.logSize === 0)
            return -1;
        root.callSerial += 1;
        const entry = {
            serial: root.callSerial,
            id: id,
            title: root.titleFor(id),
            icon: root.definitionFor(id)?.icon ?? "build",
            detail: root.describeArgs(id, args),
            status: "running",
            outcome: "",
            at: Date.now()
        };
        root.callLog = [entry].concat(Array.from(root.callLog)).slice(0, root.logSize);
        root.callCheckpointChanged(entry);
        return entry.serial;
    }

    /** status: "done" | "refused" | "failed". */
    function finishCall(serial: int, status: string, outcome: string) {
        if (serial < 0)
            return;
        root.callLog = Array.from(root.callLog).map(entry => {
            if (entry.serial !== serial)
                return entry;
            const updated = {};
            for (const key in entry) {
                updated[key] = entry[key];
            }
            updated.status = status;
            updated.outcome = outcome;
            root.callCheckpointChanged(updated);
            return updated;
        });
    }

    function clearLog() {
        root.callLog = [];
    }
}
