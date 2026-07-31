import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: root

    forceWidth: false

    ContentSection {
        icon: "neurology"
        title: Translation.tr("AI Assistant")

        HelperLinkBox {
            Layout.fillWidth: true
            title: Translation.tr("Google AI Studio")
            text: Translation.tr("Get your Gemini API Key here for free.")
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
                    Qt.openUrlExternally("https://aistudio.google.com/app/apikey")
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "smart_toy"
            text: Translation.tr("Show AI provider and model buttons")
            checked: Config.options.sidebar.ai.showProviderAndModelButtons
            onCheckedChanged: {
                Config.options.sidebar.ai.showProviderAndModelButtons = checked;
            }
        }
    }

    ContentSection {
        icon: "extension"
        title: Translation.tr("OpenRouter & Custom Models")

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
                    Qt.openUrlExternally("https://openrouter.ai/models")
                }
            }
        }

        HelperCodeBox {
            Layout.fillWidth: true
            title: Translation.tr("Custom OpenRouter & Provider Models")
            text: Translation.tr("Add custom models to your AI selector in JSON format. Each OpenRouter model item must include:\n• title: Display name\n• value: Model ID (e.g. 'deepseek-v4-flash')\n• modelProvider: Provider namespace (e.g. 'deepseek')")
            codeSnippet: '[\n  {\n    "openrouter": [\n      {\n        "title": "DeepSeek V4 Flash",\n        "value": "deepseek-v4-flash",\n        "modelProvider": "deepseek"\n      }\n    ]\n  }\n]'
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Custom OpenRouter models (JSON array)")
            text: JSON.stringify(Config.options.ai.models || [], null, 2)
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Qt.callLater(() => {
                    try {
                        const parsed = JSON.parse(text);
                        if (Array.isArray(parsed)) {
                            Config.options.ai.models = parsed;
                        }
                    } catch(e) {}
                });
            }
        }
    }

    ContentSection {
        icon: "description"
        title: Translation.tr("System Prompt")

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
