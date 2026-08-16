import qs.services
import qs.services.ai
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    property string messageId
    property var messageData
    property var messageInputField

    property real messagePadding: 7
    property real contentSpacing: 3

    property bool enableMouseSelection: false
    property bool renderMarkdown: true
    property bool editing: false

    property list<var> messageBlocks: StringUtils.splitMarkdownBlocks(root.messageData?.content)

    /** Asks the control bar for a model to redo this answer with. */
    signal regenerateRequested(string messageId)

    readonly property bool isUser: root.messageData?.role === "user"
    readonly property var sentFiles: Array.from(root.messageData?.attachments ?? [])

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: columnLayout.implicitHeight + root.messagePadding * 2

    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    /** What the editor currently holds, back as one piece of markdown. */
    function composedContent(): string {
        // Get all Loader children (each represents a segment)
        const segments = messageContentColumnLayout.children
            .map(child => child.segment)
            .filter(segment => (segment));

        // Reconstruct markdown
        return segments.map(segment => {
            if (segment.type === "code") {
                const lang = segment.lang ? segment.lang : "";
                // Remove trailing newlines
                const code = segment.content.replace(/\n+$/, "");
                return "```" + lang + "\n" + code + "\n```";
            } else {
                return segment.content;
            }
        }).join("");
    }

    function saveMessage() {
        if (!root.editing) return;
        const newContent = root.composedContent();
        root.editing = false
        root.messageData.content = newContent;
    }

    /**
     * Rewrites the question and asks it again. Everything after it is put in a
     * chat of its own first, so no answer is lost by changing one's mind about
     * how the question was worded.
     */
    function saveAndResend() {
        if (!root.editing) return;
        const newContent = root.composedContent();
        root.editing = false;
        Ai.editAndResend(root.messageId, newContent);
    }

    Keys.onPressed: (event) => {
        if ( // Prevent de-select
            event.key === Qt.Key_Control || 
            event.key == Qt.Key_Shift || 
            event.key == Qt.Key_Alt || 
            event.key == Qt.Key_Meta
        ) {
            event.accepted = true
        }
        // Ctrl + S to save
        if ((event.key === Qt.Key_S) && event.modifiers == Qt.ControlModifier) {
            root.saveMessage();
            event.accepted = true;
        }
    }

    ColumnLayout { // Main layout of the whole thing
        id: columnLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: messagePadding
        spacing: root.contentSpacing

        Rectangle {
            Layout.fillWidth: true
            implicitWidth: headerRowLayout.implicitWidth + 4 * 2
            implicitHeight: headerRowLayout.implicitHeight + 4 * 2
            color: Appearance.colors.colSecondaryContainer
            radius: Appearance.rounding.small
        
            RowLayout { // Header
                id: headerRowLayout
                anchors {
                    fill: parent
                    margins: 4
                }
                spacing: 18

                Item { // Name
                    id: nameWrapper
                    implicitHeight: Math.max(nameRowLayout.implicitHeight + 5 * 2, 30)
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        id: nameRowLayout
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillHeight: true
                            implicitWidth: messageData?.role == 'assistant' ? modelIcon.width : roleIcon.implicitWidth
                            implicitHeight: messageData?.role == 'assistant' ? modelIcon.height : roleIcon.implicitHeight

                            CustomIcon {
                                id: modelIcon
                                anchors.centerIn: parent
                                // The model may be gone from the registry: renamed, removed
                                // from otherModels, or saved on another machine. Never deref
                                // the model object without a guard.
                                readonly property var messageModel: Ai.models[messageData?.model] ?? null

                                visible: messageData?.role == 'assistant' && !!messageModel?.icon
                                width: Appearance.font.pixelSize.large
                                height: Appearance.font.pixelSize.large
                                source: messageData?.role == 'assistant' ? (messageModel?.icon ?? "") :
                                    messageData?.role == 'user' ? 'linux-symbolic' : 'desktop-symbolic'

                                colorize: true
                                color: Appearance.m3colors.m3onSecondaryContainer
                            }

                            MaterialSymbol {
                                id: roleIcon
                                anchors.centerIn: parent
                                visible: !modelIcon.visible
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.m3colors.m3onSecondaryContainer
                                text: messageData?.role == 'user' ? 'person' : 
                                    messageData?.role == 'interface' ? 'settings' : 
                                    messageData?.role == 'assistant' ? 'neurology' : 
                                    'computer'
                            }
                        }

                        StyledText {
                            id: providerName
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onSecondaryContainer
                            text: messageData?.role == 'assistant' ? (Ai.models[messageData?.model]?.name ?? messageData?.model ?? Translation.tr("Assistant")) :
                                (messageData?.role == 'user' && SystemInfo.username) ? SystemInfo.username :
                                Translation.tr("Interface")
                        }
                    }
                }

                Button { // Not visible to model
                    id: modelVisibilityIndicator
                    visible: messageData?.role == 'interface'
                    implicitWidth: 16
                    implicitHeight: 30
                    Layout.alignment: Qt.AlignVCenter

                    background: Item

                    MaterialSymbol {
                        id: notVisibleToModelText
                        anchors.centerIn: parent
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        text: "visibility_off"
                    }
                    StyledToolTip {
                        text: Translation.tr("Not visible to model")
                    }
                }

                ButtonGroup {
                    spacing: 5

                    AiMessageControlButton {
                        id: regenButton
                        buttonIcon: "refresh"
                        visible: messageData?.role === 'assistant'

                        onClicked: {
                            Ai.regenerate(root.messageId)
                        }

                        StyledToolTip {
                            text: Translation.tr("Regenerate. The answer being replaced stays in its own chat")
                        }
                    }

                    AiMessageControlButton {
                        // Same answer, another model. The old way to compare
                        // two models was to switch the chat's model and ask
                        // the question again by hand.
                        id: regenWithButton
                        buttonIcon: "swap_horiz"
                        visible: messageData?.role === 'assistant'

                        onClicked: {
                            root.regenerateRequested(root.messageId);
                        }

                        StyledToolTip {
                            text: Translation.tr("Regenerate with another model")
                        }
                    }

                    AiMessageControlButton {
                        // Only while editing a question: saving alone leaves
                        // the old answer under a question that no longer asks
                        // for it.
                        id: resendButton
                        buttonIcon: "send"
                        visible: root.editing && root.isUser

                        onClicked: {
                            root.saveAndResend();
                        }

                        StyledToolTip {
                            text: Translation.tr("Save and ask again")
                        }
                    }

                    AiMessageControlButton {
                        id: forkButton
                        buttonIcon: "alt_route"

                        onClicked: {
                            Ai.forkFrom(root.messageId)
                        }

                        StyledToolTip {
                            text: Translation.tr("Branch off here into a new chat")
                        }
                    }

                    AiMessageControlButton {
                        id: copyButton
                        buttonIcon: activated ? "inventory" : "content_copy"

                        onClicked: {
                            // The reasoning is never part of what gets copied.
                            // Chats saved before it had a field of its own
                            // still carry it inline, so it is stripped too.
                            AiOutputController.copyText((root.messageData?.content ?? "").replace(/<think>[\s\S]*?<\/think>/g, "").trim())
                            copyButton.activated = true
                            copyIconTimer.restart()
                        }

                        Timer {
                            id: copyIconTimer
                            interval: 1500
                            repeat: false
                            onTriggered: {
                                copyButton.activated = false
                            }
                        }
                        
                        StyledToolTip {
                            text: Translation.tr("Copy")
                        }
                    }
                    AiMessageControlButton {
                        id: editButton
                        activated: root.editing
                        enabled: root.messageData?.done ?? false
                        buttonIcon: "edit"
                        onClicked: {
                            root.editing = !root.editing
                            if (!root.editing) { // Save changes
                                root.saveMessage()
                            }
                        }
                        StyledToolTip {
                            text: root.editing ? Translation.tr("Save") : Translation.tr("Edit")
                        }
                    }
                    AiMessageControlButton {
                        id: toggleMarkdownButton
                        activated: !root.renderMarkdown
                        buttonIcon: "code"
                        onClicked: {
                            root.renderMarkdown = !root.renderMarkdown
                        }
                        StyledToolTip {
                            text: Translation.tr("View Markdown source")
                        }
                    }
                    AiMessageControlButton {
                        id: deleteButton
                        buttonIcon: "close"
                        onClicked: {
                            Ai.removeMessage(root.messageId)
                        }
                        StyledToolTip {
                            text: Translation.tr("Delete")
                        }
                    }
                }
            }
        }

        Loader {
            // Chats saved before a message could carry several files.
            Layout.fillWidth: true
            active: root.sentFiles.length === 0 && (root.messageData?.localFilePath?.length ?? 0) > 0
            visible: active
            sourceComponent: AttachedFileIndicator {
                filePath: root.messageData?.localFilePath
                canRemove: false
            }
        }

        Flow {
            // What went out with this message, kept with it: a reopened chat
            // still shows what the model was actually looking at.
            visible: root.sentFiles.length > 0
            spacing: 5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft

            Repeater {
                model: ScriptModel {
                    values: root.sentFiles
                }

                delegate: Rectangle {
                    id: sentFile
                    required property var modelData

                    implicitWidth: sentFileRowLayout.implicitWidth + 10 * 2
                    implicitHeight: 28
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: sentFileRowLayout
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: {
                                const kind = sentFile.modelData.kind ?? "";
                                if (kind === "image")
                                    return "image";
                                if (kind === "pdf")
                                    return "picture_as_pdf";
                                if (kind === "audio")
                                    return "music_note";
                                if (kind === "video")
                                    return "movie";
                                if (kind === "text")
                                    return "description";
                                return "file_present";
                            }
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.maximumWidth: 180
                            text: sentFile.modelData.name ?? ""
                            elide: Text.ElideMiddle
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    StyledToolTip {
                        text: `${sentFile.modelData.path ?? ""}\n${Ai.humanSize(sentFile.modelData.bytes ?? 0)}`
                    }
                }
            }
        }

        ColumnLayout { // Message content
            id: messageContentColumnLayout
            spacing: 0

            Loader { // Reasoning, when the model showed its work
                Layout.fillWidth: true
                Layout.bottomMargin: active ? root.contentSpacing : 0
                active: (root.messageData?.thought?.length ?? 0) > 0
                sourceComponent: MessageThinkBlock {
                    editing: root.editing
                    renderMarkdown: root.renderMarkdown
                    enableMouseSelection: root.enableMouseSelection
                    messageData: root.messageData
                    done: root.messageData?.done ?? false
                    thoughtText: root.messageData?.thought ?? ""
                    // The answer starting is what makes the thinking over,
                    // long before the message itself is done.
                    completed: ((root.messageData?.content?.length ?? 0) > 0) || (root.messageData?.done ?? false)
                    durationMs: root.messageData?.thoughtDurationMs ?? 0
                    tokens: root.messageData?.thoughtTokens ?? -1
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: loadingIndicatorLoader.shown ? loadingIndicatorLoader.implicitHeight : 0
                implicitWidth: loadingIndicatorLoader.implicitWidth
                visible: implicitHeight > 0

                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                FadeLoader {
                    id: loadingIndicatorLoader
                    anchors.centerIn: parent
                    shown: (root.messageBlocks.length < 1) && ((root.messageData?.thought?.length ?? 0) === 0) && (!root.messageData.done)
                    sourceComponent: MaterialLoadingIndicator {
                        loading: true
                    }
                }
            }
            Repeater {
                model: ScriptModel {
                    values: root.messageBlocks
                }
                delegate: DelegateChooser {
                    id: messageDelegate
                    role: "type"

                    DelegateChoice { roleValue: "code"; MessageCodeBlock {
                        editing: root.editing
                        renderMarkdown: root.renderMarkdown
                        enableMouseSelection: root.enableMouseSelection
                        segmentContent: modelData.content
                        segmentLang: modelData.lang
                        messageData: root.messageData
                    } }
                    DelegateChoice { roleValue: "think"; MessageThinkBlock {
                        editing: root.editing
                        renderMarkdown: root.renderMarkdown
                        enableMouseSelection: root.enableMouseSelection
                        segmentContent: modelData.content
                        messageData: root.messageData
                        done: root.messageData?.done ?? false
                        completed: modelData.completed ?? false
                    } }
                    DelegateChoice { roleValue: "text"; MessageTextBlock {
                        editing: root.editing
                        renderMarkdown: root.renderMarkdown
                        enableMouseSelection: root.enableMouseSelection
                        segmentContent: modelData.content
                        messageData: root.messageData
                        done: root.messageData?.done ?? false
                        forceDisableChunkSplitting: root.messageData?.content.includes("```") ?? true
                    } }
                }
            }
        }

        Loader {
            // Settings the model wants to write, shown against what they
            // would replace. Only ever loaded while an answer is waiting.
            Layout.fillWidth: true
            active: (root.messageData?.pendingChanges?.length ?? 0) > 0 && (root.messageData?.functionPending ?? false)
            visible: active

            sourceComponent: ConfigDiffCard {
                messageData: root.messageData
            }
        }

        Loader {
            // A failed request used to leave a message that stopped, with the
            // reason in the log. What went wrong and what to do about it both
            // belong here, next to a button that tries again.
            Layout.fillWidth: true
            active: (root.messageData?.errorKind?.length ?? 0) > 0
            visible: active

            sourceComponent: Rectangle {
                implicitHeight: errorColumnLayout.implicitHeight + 10 * 2
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(Appearance.m3colors.m3error, 0.88)

                ColumnLayout {
                    id: errorColumnLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            text: "error"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.m3colors.m3error
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: root.messageData?.errorText ?? Translation.tr("The request failed.")
                                wrapMode: Text.Wrap
                                color: Appearance.m3colors.m3error
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: Ai.transportErrorAdvice(root.messageData?.errorKind ?? "")
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    StyledText {
                        // The provider's own words, folded away. They are
                        // usually a page of JSON that repeats what the line
                        // above already said, and occasionally the only place
                        // the real reason appears.
                        Layout.fillWidth: true
                        Layout.maximumHeight: 160
                        visible: errorDetailsToggle.visible && errorDetailsToggle.unfolded
                        text: root.messageData?.errorDetails ?? ""
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RippleButton {
                            id: errorDetailsToggle
                            property bool unfolded: false

                            visible: (root.messageData?.errorDetails?.length ?? 0) > 0
                            leftPadding: 10
                            rightPadding: 10
                            topPadding: 5
                            bottomPadding: 5
                            buttonRadius: Appearance.rounding.full
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            colRipple: Appearance.colors.colLayer2Active
                            onClicked: errorDetailsToggle.unfolded = !errorDetailsToggle.unfolded

                            contentItem: StyledText {
                                text: errorDetailsToggle.unfolded ? Translation.tr("Hide details") : Translation.tr("Details")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer2
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        RippleButton {
                            visible: (root.messageData?.errorKind ?? "") === "auth"
                            leftPadding: 12
                            rightPadding: 12
                            topPadding: 5
                            bottomPadding: 5
                            buttonRadius: Appearance.rounding.full
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            colRipple: Appearance.colors.colLayer2Active
                            onClicked: Ai.keyManagerRequested()

                            contentItem: StyledText {
                                text: Translation.tr("Keys")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer2
                            }
                        }

                        RippleButton {
                            leftPadding: 12
                            rightPadding: 12
                            topPadding: 5
                            bottomPadding: 5
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colPrimary
                            colBackgroundHover: Appearance.colors.colPrimaryHover
                            colRipple: Appearance.colors.colPrimaryActive
                            onClicked: Ai.retryMessage(root.messageId)

                            contentItem: RowLayout {
                                spacing: 5

                                MaterialSymbol {
                                    text: "refresh"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.m3colors.m3onPrimary
                                }

                                StyledText {
                                    text: Translation.tr("Try again")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.m3colors.m3onPrimary
                                }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            // "Set a key with /key VALUE" was the whole of the old advice, and
            // it meant typing a secret into the transcript.
            Layout.fillWidth: true
            active: (root.messageData?.notice ?? "") === "apiKey"
            visible: active

            sourceComponent: RowLayout {
                spacing: 6

                Item {
                    Layout.fillWidth: true
                }

                RippleButton {
                    leftPadding: 12
                    rightPadding: 12
                    topPadding: 5
                    bottomPadding: 5
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    onClicked: Ai.keyManagerRequested()

                    contentItem: RowLayout {
                        spacing: 5

                        MaterialSymbol {
                            text: "key"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.m3colors.m3onSecondaryContainer
                        }

                        StyledText {
                            text: Translation.tr("Open the key panel")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.m3colors.m3onSecondaryContainer
                        }
                    }
                }
            }
        }

        Flow { // Annotations
            visible: root.messageData?.annotationSources?.length > 0
            spacing: 5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft

            Repeater {
                model: ScriptModel {
                    values: root.messageData?.annotationSources || []
                }
                delegate: AnnotationSourceButton {
                    required property var modelData
                    displayText: modelData.text
                    url: modelData.url
                }
            }
        }

        Flow { // Search queries
            visible: root.messageData?.searchQueries?.length > 0
            spacing: 5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft

            Repeater {
                model: ScriptModel {
                    values: root.messageData?.searchQueries || []
                }
                delegate: SearchQueryButton {
                    required property var modelData
                    query: modelData
                }
            }
        }

    }
}
