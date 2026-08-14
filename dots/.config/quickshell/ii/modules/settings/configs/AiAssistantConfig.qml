import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * The AI settings page.
 *
 * What used to be here was one switch for buttons that no longer exist, a raw
 * JSON box, and the system prompt — while everything that governs a request
 * (how long it may take, how much it may send, what it may run) had no page
 * at all. Keys are deliberately still absent: they belong in the chat's key
 * panel, next to the model that needs one.
 */
ContentPage {
    id: root

    forceWidth: false

    readonly property var toolDefinitions: Array.from(Ai.toolbox.definitions)

    ContentSection {
        icon: "neurology"
        title: Translation.tr("AI Assistant")

        HelperLinkBox {
            Layout.fillWidth: true
            title: Translation.tr("Google AI Studio")
            text: Translation.tr("Get your Gemini API Key here for free. Keys are entered from the key panel in the chat, and kept in the system keyring.")
            isFirst: true

            RippleButtonWithIcon {
                mainText: Translation.tr("Open Website")
                materialIcon: "open_in_new"
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                colBackground: Appearance.colors.colLayer0
                colBackgroundHover: Appearance.colors.colLayer0Hover
                colRipple: Appearance.colors.colLayer0Active
                downAction: () => {
                    Qt.openUrlExternally("https://aistudio.google.com/app/apikey");
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "smart_toy"
            text: Translation.tr("List available models at startup")
            checked: Config.options.sidebar.ai.enable
            onCheckedChanged: {
                Config.options.sidebar.ai.enable = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "text_fields"
            text: Translation.tr("Fade answers in as they arrive")
            checked: Config.options.sidebar.ai.textFadeIn
            onCheckedChanged: {
                Config.options.sidebar.ai.textFadeIn = checked;
            }
        }
    }

    ContentSection {
        icon: "service_toolbox"
        title: Translation.tr("Tools")

        ConfigSelectionArray {
            Layout.fillWidth: true
            currentValue: Config.options.ai.tools.mode
            onSelected: newValue => {
                Config.options.ai.tools.mode = newValue;
            }
            options: [
                {
                    displayName: Translation.tr("Tools"),
                    icon: "build",
                    value: "functions"
                },
                {
                    displayName: Translation.tr("Web search"),
                    icon: "travel_explore",
                    value: "search"
                },
                {
                    displayName: Translation.tr("None"),
                    icon: "block",
                    value: "none"
                }
            ]
        }

        ContentSubsection {
            title: Translation.tr("When each tool may run")
            tooltip: Translation.tr("Applies to the Tools mode. A tool set to ask stops for approval every time, and shows what it would do first.")

            Repeater {
                model: root.toolDefinitions

                ColumnLayout {
                    id: toolEntry
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            text: toolEntry.modelData.icon
                            iconSize: Appearance.font.pixelSize.huge
                            color: toolEntry.modelData.risk === "danger" ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: toolEntry.modelData.title
                                wrapMode: Text.Wrap
                                color: Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: toolEntry.modelData.summary
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: Ai.toolbox.permission(toolEntry.modelData.id)
                        onSelected: newValue => {
                            Ai.toolbox.setPermission(toolEntry.modelData.id, newValue);
                        }
                        options: [
                            {
                                displayName: Translation.tr("Always"),
                                icon: "check_circle",
                                value: "allow"
                            },
                            {
                                displayName: Translation.tr("Ask first"),
                                icon: "help",
                                value: "ask"
                            },
                            {
                                displayName: Translation.tr("Never"),
                                icon: "block",
                                value: "deny"
                            }
                        ]
                    }
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "rate_review"
            text: Translation.tr("Show settings changes before applying them")
            checked: Config.options.ai.tools.reviewConfigChanges
            onCheckedChanged: {
                Config.options.ai.tools.reviewConfigChanges = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "home_storage"
            text: Translation.tr("Let local models use tools")
            checked: Config.options.ai.tools.localModels
            onCheckedChanged: {
                Config.options.ai.tools.localModels = checked;
            }
        }

        ConfigSpinBox {
            icon: "history"
            text: Translation.tr("Tool calls to remember")
            value: Config.options.ai.tools.logSize
            from: 0
            to: 200
            stepSize: 10
            onValueChanged: {
                Config.options.ai.tools.logSize = value;
            }
        }
    }

    ContentSection {
        icon: "tune"
        title: Translation.tr("Requests")

        ConfigSpinBox {
            icon: "notes"
            text: Translation.tr("Longest answer, in tokens (0 = the model's own limit)")
            value: Config.options.ai.maxOutputTokens
            from: 0
            to: 200000
            stepSize: 1024
            onValueChanged: {
                Config.options.ai.maxOutputTokens = value;
            }
        }

        ConfigSpinBox {
            icon: "cloud_sync"
            text: Translation.tr("Seconds to reach the provider")
            value: Config.options.ai.connectTimeout
            from: 5
            to: 120
            stepSize: 5
            onValueChanged: {
                Config.options.ai.connectTimeout = value;
            }
        }

        ConfigSpinBox {
            icon: "hourglass_top"
            text: Translation.tr("Seconds to finish an answer")
            value: Config.options.ai.requestTimeout
            from: 30
            to: 1800
            stepSize: 30
            onValueChanged: {
                Config.options.ai.requestTimeout = value;
            }
        }

        ConfigSpinBox {
            icon: "refresh"
            text: Translation.tr("Retries after a rate limit or a server error")
            value: Config.options.ai.maxRetries
            from: 0
            to: 5
            stepSize: 1
            onValueChanged: {
                Config.options.ai.maxRetries = value;
            }
        }
    }

    ContentSection {
        icon: "attach_file"
        title: Translation.tr("Attachments")

        TipBox {
            Layout.fillWidth: true
            text: Translation.tr("Every attached file is sent again with every following turn of the same chat, so a large one is paid for more than once.")
        }

        ConfigSpinBox {
            icon: "database"
            text: Translation.tr("Biggest file, in MiB")
            value: Config.options.ai.maxAttachmentMib
            from: 1
            to: 20
            stepSize: 1
            onValueChanged: {
                Config.options.ai.maxAttachmentMib = value;
            }
        }

        ConfigSpinBox {
            icon: "counter_1"
            text: Translation.tr("Files per message")
            value: Config.options.ai.maxAttachments
            from: 1
            to: 20
            stepSize: 1
            onValueChanged: {
                Config.options.ai.maxAttachments = value;
            }
        }
    }

    ContentSection {
        icon: "extension"
        title: Translation.tr("Custom models")

        HelperLinkBox {
            Layout.fillWidth: true
            title: Translation.tr("OpenRouter Models")
            text: Translation.tr("Explore thousands of AI models available on OpenRouter.")
            isFirst: true

            RippleButtonWithIcon {
                mainText: Translation.tr("Browse OpenRouter Models")
                materialIcon: "open_in_new"
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                colBackground: Appearance.colors.colLayer0
                colBackgroundHover: Appearance.colors.colLayer0Hover
                colRipple: Appearance.colors.colLayer0Active
                downAction: () => {
                    Qt.openUrlExternally("https://openrouter.ai/models");
                }
            }
        }

        HelperCodeBox {
            Layout.fillWidth: true
            title: Translation.tr("One list, two kinds of entry")
            text: Translation.tr("An entry with `provider` is added to that built-in provider and needs only:\n• value: Model ID (e.g. 'deepseek-v4-flash')\n• title: Display name\n• modelProvider: Namespace on that provider (e.g. 'deepseek')\n\nAn entry without `provider` stands on its own under Others, and brings its own endpoint, dialect and key id.")
            codeSnippet: '[\n  {\n    "provider": "openrouter",\n    "title": "DeepSeek V4 Flash",\n    "value": "deepseek-v4-flash",\n    "modelProvider": "deepseek"\n  },\n  {\n    "name": "My Server",\n    "model": "llama-4-70b",\n    "endpoint": "https://example.com/v1/chat/completions",\n    "api_format": "openai",\n    "key_id": "myserver",\n    "requires_key": true\n  }\n]'
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Custom models (JSON array)")
            text: JSON.stringify(Array.from(Config.options.ai.customModels ?? []), null, 2)
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Qt.callLater(() => {
                    try {
                        const parsed = JSON.parse(text);
                        if (Array.isArray(parsed)) {
                            Config.options.ai.customModels = parsed;
                        }
                    } catch (e) {}
                });
            }
        }
    }

    ContentSection {
        icon: "description"
        title: Translation.tr("System Prompt")

        TipBox {
            Layout.fillWidth: true
            text: Translation.tr("A persona replaces this while it is picked. This is what the assistant falls back to.")
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("System prompt")
            text: Config.options.ai.systemPrompt
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Qt.callLater(() => {
                    Config.options.ai.systemPrompt = text;
                });
            }
        }
    }
}
