import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.configs.ai
import qs.modules.ii.usage

/**
 * The AI settings page.
 *
 * A dashboard, not a manual: the usage view and daily preferences stay on
 * this page, while focused configuration tasks live behind their own entry
 * buttons. Keys are deliberately still absent: they belong in the chat's
 * key panel, next to the model that needs one.
 */
Item {
    id: aiRoot
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

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
                checked: Config.options.ai.indexAtStartup
                onCheckedChanged: {
                    Config.options.ai.indexAtStartup = checked;
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
            icon: "account_tree"
            title: Translation.tr("Context")

            ConfigSwitch {
                buttonIcon: "summarize"
                text: Translation.tr("Manage long conversations")
                checked: Config.options.ai.context.manage
                onCheckedChanged: {
                    Config.options.ai.context.manage = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.ai.context.manage
                buttonIcon: "auto_awesome"
                text: Translation.tr("Summarise earlier messages when needed")
                checked: Config.options.ai.context.summarise
                onCheckedChanged: {
                    Config.options.ai.context.summarise = checked;
                }
            }

            ConfigSpinBox {
                enabled: Config.options.ai.context.manage
                icon: "data_usage"
                text: Translation.tr("Tokens reserved for each answer")
                value: Config.options.ai.context.reserveTokens
                from: 256
                to: 32768
                stepSize: 256
                onValueChanged: {
                    Config.options.ai.context.reserveTokens = value;
                }
            }

            ConfigSwitch {
                buttonIcon: "text_snippet"
                text: Translation.tr("Extract text from attached documents")
                checked: Config.options.ai.extractDocuments
                onCheckedChanged: {
                    Config.options.ai.extractDocuments = checked;
                }
            }

            ConfigSpinBox {
                enabled: Config.options.ai.memory.enabled
                icon: "memory"
                text: Translation.tr("Facts remembered between conversations")
                value: Config.options.ai.memory.limit
                from: 0
                to: 200
                stepSize: 1
                onValueChanged: {
                    Config.options.ai.memory.limit = value;
                }
            }
        }

        ContentSection {
            icon: "notifications"
            title: Translation.tr("Notifications")

            ConfigSwitch {
                buttonIcon: "notifications_active"
                text: Translation.tr("Notify when an answer is ready")
                checked: Config.options.ai.notify.whenDone
                onCheckedChanged: {
                    Config.options.ai.notify.whenDone = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.ai.notify.whenDone
                buttonIcon: "visibility_off"
                text: Translation.tr("Only while the chat is out of view")
                checked: Config.options.ai.notify.onlyWhenAway
                onCheckedChanged: {
                    Config.options.ai.notify.onlyWhenAway = checked;
                }
            }

            ConfigSpinBox {
                enabled: Config.options.ai.notify.whenDone
                icon: "timer"
                text: Translation.tr("Minimum answer time before notifying (seconds)")
                value: Config.options.ai.notify.minimumSeconds
                from: 0
                to: 60
                stepSize: 1
                onValueChanged: {
                    Config.options.ai.notify.minimumSeconds = value;
                }
            }
        }

        ContentSection {
            icon: "forum"
            title: Translation.tr("Conversation")

            ConfigSwitch {
                buttonIcon: "auto_awesome"
                text: Translation.tr("Name new conversations automatically")
                checked: Config.options.ai.autoTitle
                onCheckedChanged: Config.options.ai.autoTitle = checked
            }

            ConfigSwitch {
                buttonIcon: "inventory_2"
                text: Translation.tr("Keep status messages in saved conversations")
                checked: !Config.options.ai.ephemeralInterfaceMessages
                onCheckedChanged: Config.options.ai.ephemeralInterfaceMessages = !checked
            }

            ConfigSpinBox {
                icon: "delete_sweep"
                text: Translation.tr("Days to keep deleted conversations")
                value: Config.options.ai.sessions.retentionDays
                from: 1
                to: 3650
                stepSize: 1
                onValueChanged: Config.options.ai.sessions.retentionDays = value
            }
        }

        ContentSection {
            icon: "chat"
            title: Translation.tr("Chat experience")

            ContentSubsection {
                Layout.fillWidth: true
                title: Translation.tr("Transcript density")
                icon: "density_medium"

                ConfigSelectionArray {
                    currentValue: Config.options.sidebar.ai.density
                    onSelected: newValue => Config.options.sidebar.ai.density = newValue
                    options: [
                        { displayName: Translation.tr("Comfortable"), icon: "view_agenda", value: "comfortable" },
                        { displayName: Translation.tr("Compact"), icon: "view_headline", value: "compact" }
                    ]
                }
            }

            ContentSubsection {
                Layout.fillWidth: true
                title: Translation.tr("Default thinking")
                icon: "psychology"

                ConfigSelectionArray {
                    currentValue: Config.options.sidebar.ai.thinkingDefault
                    onSelected: newValue => Config.options.sidebar.ai.thinkingDefault = newValue
                    options: [
                        { displayName: Translation.tr("Remembered"), icon: "bookmark", value: "" },
                        { displayName: Translation.tr("Off"), icon: "block", value: "off" },
                        { displayName: Translation.tr("Low"), icon: "speed", value: "low" },
                        { displayName: Translation.tr("Medium"), icon: "balance", value: "medium" },
                        { displayName: Translation.tr("High"), icon: "psychology", value: "high" }
                    ]
                }
            }

            ContentSubsection {
                Layout.fillWidth: true
                title: Translation.tr("Activity details")
                icon: "pending_actions"

                ConfigSelectionArray {
                    currentValue: Config.options.sidebar.ai.activityDefault
                    onSelected: newValue => Config.options.sidebar.ai.activityDefault = newValue
                    options: [
                        { displayName: Translation.tr("Automatic"), icon: "auto_mode", value: "auto" },
                        { displayName: Translation.tr("Expanded"), icon: "unfold_more", value: "expanded" },
                        { displayName: Translation.tr("Collapsed"), icon: "unfold_less", value: "collapsed" }
                    ]
                }
            }

            ContentSubsection {
                Layout.fillWidth: true
                title: Translation.tr("Send message with")
                icon: "keyboard_return"

                ConfigSelectionArray {
                    currentValue: Config.options.sidebar.ai.sendKey
                    onSelected: newValue => Config.options.sidebar.ai.sendKey = newValue
                    options: [
                        { displayName: Translation.tr("Enter"), icon: "keyboard_return", value: "enter" },
                        { displayName: Translation.tr("Ctrl+Enter"), icon: "keyboard", value: "ctrlEnter" }
                    ]
                }
            }

            ConfigSwitch {
                buttonIcon: "schedule"
                text: Translation.tr("Show message timestamps")
                checked: Config.options.sidebar.ai.showTimestamps
                onCheckedChanged: Config.options.sidebar.ai.showTimestamps = checked
            }

            ConfigSwitch {
                buttonIcon: "timer"
                text: Translation.tr("Show answer time")
                checked: Config.options.sidebar.ai.showResponseTime
                onCheckedChanged: Config.options.sidebar.ai.showResponseTime = checked
            }

            ConfigSwitch {
                buttonIcon: "smart_toy"
                text: Translation.tr("Show the answering model")
                checked: Config.options.sidebar.ai.showAnswerModel
                onCheckedChanged: Config.options.sidebar.ai.showAnswerModel = checked
            }

            ConfigSwitch {
                buttonIcon: "vertical_align_bottom"
                text: Translation.tr("Follow new answers automatically")
                checked: Config.options.sidebar.ai.autoScroll
                onCheckedChanged: Config.options.sidebar.ai.autoScroll = checked
            }

            ConfigSwitch {
                buttonIcon: "motion_photos_off"
                text: Translation.tr("Reduce motion in AI chat")
                checked: Config.options.sidebar.ai.reducedMotion
                onCheckedChanged: Config.options.sidebar.ai.reducedMotion = checked
            }
        }

        ContentSection {
            icon: "code"
            title: Translation.tr("Answer formatting")

            ConfigSwitch {
                buttonIcon: "markdown"
                text: Translation.tr("Render Markdown")
                checked: Config.options.sidebar.ai.renderMarkdown
                onCheckedChanged: Config.options.sidebar.ai.renderMarkdown = checked
            }

            ConfigSwitch {
                buttonIcon: "functions"
                text: Translation.tr("Render mathematical notation")
                checked: Config.options.sidebar.ai.renderLatex
                onCheckedChanged: Config.options.sidebar.ai.renderLatex = checked
            }

            ConfigSwitch {
                buttonIcon: "wrap_text"
                text: Translation.tr("Wrap code blocks")
                checked: Config.options.sidebar.ai.codeWrap
                onCheckedChanged: Config.options.sidebar.ai.codeWrap = checked
            }

            ConfigSwitch {
                buttonIcon: "format_list_numbered"
                text: Translation.tr("Show code line numbers")
                checked: Config.options.sidebar.ai.codeLineNumbers
                onCheckedChanged: Config.options.sidebar.ai.codeLineNumbers = checked
            }

            ConfigSwitch {
                buttonIcon: "unfold_less"
                text: Translation.tr("Collapse long answers")
                checked: Config.options.sidebar.ai.collapseLongAnswers
                onCheckedChanged: Config.options.sidebar.ai.collapseLongAnswers = checked
            }

            ConfigSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Show empty-chat keyboard hints")
                checked: Config.options.sidebar.ai.emptyStateKeys
                onCheckedChanged: Config.options.sidebar.ai.emptyStateKeys = checked
            }

            ConfigSwitch {
                buttonIcon: "volume_up"
                text: Translation.tr("Play a sound when an answer is ready")
                checked: Config.options.sidebar.ai.soundOnAnswer
                onCheckedChanged: Config.options.sidebar.ai.soundOnAnswer = checked
            }

            ConfigTextField {
                Layout.fillWidth: true
                text: Translation.tr("Empty-chat greeting")
                icon: "waving_hand"
                placeholderText: Translation.tr("Use a rotating greeting")
                tooltip: Translation.tr("Leave empty to use the built-in rotating greeting.")
                inputText: Config.options.sidebar.ai.greeting
                textField.onEditingFinished: Config.options.sidebar.ai.greeting = textField.text
            }

            ConfigTextField {
                Layout.fillWidth: true
                text: Translation.tr("Toolbar items")
                icon: "toolbar"
                placeholderText: "keys, advanced, sessions, newChat"
                tooltip: Translation.tr("Comma-separated: keys, advanced, sessions, newChat, model, thinking, tools, prompt, projects, memory, slash.")
                inputText: Array.from(Config.options.sidebar.ai.barKeys ?? []).join(", ")
                textField.onEditingFinished: {
                    const allowed = ["keys", "advanced", "sessions", "newChat", "model", "thinking", "tools", "prompt", "projects", "memory", "slash"];
                    const items = textField.text.split(",").map(item => item.trim())
                        .filter((item, index, all) => allowed.indexOf(item) >= 0 && all.indexOf(item) === index);
                    Config.options.sidebar.ai.barKeys = items;
                }
            }
        }

        ContentSection {
            icon: "terminal"
            title: Translation.tr("Remote access")

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "dns"
                isFirst: true
                text: Translation.tr("This chat can be asked a question from outside the shell entirely — a script, a cron job, another shell over SSH — through Quickshell's own IPC socket. It runs like a message typed into the composer: same chat, same tools, same model, one exchange at a time.")
            }

            HelperCodeBox {
                Layout.fillWidth: true
                icon: "send"
                title: Translation.tr("Ask a question")
                text: Translation.tr("Returns immediately with accepted/rejected as JSON — busy, a missing key, a disabled policy. The answer itself is not in that reply; it lands separately once the model is done.")
                codeSnippet: "qs -c ii ipc call ai ask \"What is using the most memory right now?\""
                snippetWrapMode: Text.WrapAnywhere
            }

            HelperCodeBox {
                Layout.fillWidth: true
                icon: "chat"
                title: Translation.tr("Read the answer back")
                text: Translation.tr("Either works: the IPC call below returns the same JSON that is kept on disk, updated once per finished exchange.")
                codeSnippet: "qs -c ii ipc call ai lastAnswer\ncat " + Directories.aiLastAnswer
                snippetWrapMode: Text.WrapAnywhere
            }

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "warning"
                isLast: true
                text: Translation.tr("A real limit, not a bug: running a shell command always asks for approval first, and that approval has no deadline — it waits for a click in the transcript. Asked this way, with no window open to click anything, that wait never ends until you open the chat yourself and answer the card. Read-only tools (settings lookups, system status, file search) need no approval and work exactly as well remotely as they do in the composer.")
            }
        }

        ContentSection {
            icon: "extension"
            title: Translation.tr("Configuration")

            SubPageEntryButton {
                entryIcon: "key"
                entryTitle: Translation.tr("Models & Keys")
                entryDescription: Translation.tr("Manage provider credentials and add custom models")
                entryAccent: Appearance.colors.colPrimary
                entryOnAccent: Appearance.colors.colOnPrimary
                onClicked: aiRoot.activeSubPage = Qt.resolvedUrl("ai/AiModelsKeysConfig.qml")
            }

            SubPageEntryButton {
                entryIcon: "service_toolbox"
                entryTitle: Translation.tr("Tools & Permissions")
                entryDescription: Translation.tr("Choose available tools and decide when they need approval")
                entryAccent: Appearance.colors.colTertiary
                entryOnAccent: Appearance.colors.colOnTertiary
                onClicked: aiRoot.activeSubPage = Qt.resolvedUrl("ai/AiToolsPermissionsConfig.qml")
            }

            SubPageEntryButton {
                entryIcon: "attach_file"
                entryTitle: Translation.tr("Files, Vision & Voice")
                entryDescription: Translation.tr("Attachments, local file search, OCR and dictation")
                entryAccent: Appearance.colors.colSecondary
                entryOnAccent: Appearance.colors.colOnSecondary
                onClicked: aiRoot.activeSubPage = Qt.resolvedUrl("ai/AiFilesVisionVoiceConfig.qml")
            }

            SubPageEntryButton {
                entryIcon: "manage_search"
                entryTitle: Translation.tr("Local Retrieval (RAG)")
                entryDescription: Translation.tr("Index chosen folders locally through Ollama")
                entryAccent: Appearance.colors.colPrimary
                entryOnAccent: Appearance.colors.colOnPrimary
                onClicked: aiRoot.activeSubPage = Qt.resolvedUrl("ai/RagConfig.qml")
            }

            SubPageEntryButton {
                entryIcon: "tune"
                entryTitle: Translation.tr("Request Limits")
                entryDescription: Translation.tr("Answer size, timeouts, retries and chat-toolbar metrics")
                entryAccent: Appearance.colors.colTertiary
                entryOnAccent: Appearance.colors.colOnTertiary
                onClicked: aiRoot.activeSubPage = Qt.resolvedUrl("ai/AiRequestLimitsConfig.qml")
            }

        }

        ContentSection {
            icon: "monitoring"
            title: Translation.tr("Usage & Cost")
            customBackgroundColor: Appearance.colors.colLayer0

            AiUsageDashboard {
                Layout.fillWidth: true
            }
        }

        ContentSection {
            icon: "description"
            title: Translation.tr("System Prompt")

            TipBox {
                Layout.fillWidth: true
                text: Translation.tr("A persona replaces this while it is picked. This is what the assistant falls back to.")
            }

            // Height-capped so a long prompt cannot stretch the page: past the
            // cap the text scrolls inside the field instead of growing it.
            ScrollView {
                id: promptScroll
                Layout.fillWidth: true
                implicitHeight: Math.min(systemPromptArea.implicitHeight, 240)
                clip: true

                ScrollBar.vertical: ScrollBar {
                    id: promptScrollBar
                    policy: ScrollBar.AsNeeded
                    opacity: size < 1 ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2Active
                    }
                }

                MaterialTextArea {
                    id: systemPromptArea
                    width: promptScroll.width
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

        ContentSection {
            icon: "privacy_tip"
            title: Translation.tr("Privacy & context")

            TipBox {
                Layout.fillWidth: true
                text: Translation.tr("Clipboard text, a launcher result, and active-app metadata are sent only when you attach them in the composer. Each attachment shows its source, size, destination, and a remove action before sending.")
            }

            TipBox {
                Layout.fillWidth: true
                text: String(Config.options.ai.systemPrompt ?? "").includes("{WINDOWCLASS}")
                    ? Translation.tr("Your system prompt currently includes {WINDOWCLASS}; it is replaced with the active application's class on every request.")
                    : Translation.tr("Your system prompt does not include active-window metadata.")
            }

            RippleButton {
                Layout.fillWidth: true
                visible: String(Config.options.ai.systemPrompt ?? "").includes("{WINDOWCLASS}")
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: Config.options.ai.systemPrompt = String(Config.options.ai.systemPrompt ?? "").replace("{WINDOWCLASS}", "")

                contentItem: RowLayout {
                    spacing: 8

                    MaterialSymbol {
                        text: "visibility_off"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnSecondaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Remove active-window metadata from the prompt")
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }
    }

    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }

}
