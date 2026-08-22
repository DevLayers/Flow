pragma ComponentBehavior: Bound

import qs.services
import qs.services.ai
import qs.services.ai.blocks
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * One turn of the conversation.
 *
 * A question is a pill on the right; an answer is a block on the left, under
 * however many quiet lines it took to get there — the reasoning, a search,
 * whatever tools were reached for. What can be done with an answer lives on
 * a bar beneath it rather than in a header above it, because a header put
 * six controls between the question and the answer to it.
 *
 * Nothing here is sized in pixels: every measure comes off the type scale or
 * the rounding scale, so the whole transcript follows the user's font size
 * and their sharp-corner setting.
 */
Item {
    id: root

    property string messageId
    property var messageData

    /**
     * How much room the turn is allowed to take.
     *
     * "comfortable" is the sidebar: bubbles, activity rows and the action bar
     * under the answer. "compact" is the Search panel, which is a narrow
     * strip over the desktop — there the answer drops its bubble and the bar
     * becomes the two controls worth having, so one component serves both
     * instead of two that drift apart.
     */
    property string density: "comfortable"
    readonly property bool compact: root.density === "compact"

    /** Asks the control bar for another model to redo this answer with. */
    signal regenerateRequested(string messageId)
    /** Asks the control bar to open the model picker. */
    signal modelPickerRequested
    /** Asks the composer to take this question back for another go. */
    signal editRequested(string messageId, string content)

    readonly property string transcriptContent: String(root.messageData?.content ?? root.messageData?.rawContent ?? "")

    /**
     * The parsed content, rebuilt rather than re-bound.
     *
     * As a binding this ran the whole splitter on every token and handed back
     * fresh objects each time, so every block's delegate was destroyed and
     * built again sixty times a second. Now the rebuild is coalesced while an
     * answer is streaming, and the blocks that did not change keep their
     * identity so their delegates are left alone.
     */
    property list<var> messageBlocks: []

    function rebuildBlocks() {
        root.messageBlocks = AiTranscriptRegistry.reuseBlocks(root.messageBlocks, root.transcriptContent);
    }

    onTranscriptContentChanged: {
        if (!root.streaming) {
            blockRebuildTimer.stop();
            root.rebuildBlocks();
            return;
        }
        if (!blockRebuildTimer.running)
            blockRebuildTimer.start();
    }

    onDoneChanged: {
        blockRebuildTimer.stop();
        root.rebuildBlocks();
    }

    Timer {
        // Fast enough to read as text arriving, slow enough that a token does
        // not cost a full re-parse and re-layout of the whole answer.
        id: blockRebuildTimer
        interval: 60
        repeat: false
        onTriggered: root.rebuildBlocks()
    }

    readonly property string role: String(root.messageData?.role ?? "assistant")
    readonly property bool isUser: root.role === "user"
    readonly property bool isInterface: root.role === "interface"
    readonly property bool isAssistant: !root.isUser && !root.isInterface
    readonly property bool done: root.messageData?.done ?? false
    /** True while the answer is still being written into this turn. */
    readonly property bool streaming: root.isAssistant && !root.done
    readonly property var sentFiles: Array.from(root.messageData?.attachments ?? [])

    /**
     * Every message in the same exchange as this one, oldest first, ending
     * with this one. A tool round-trip issues one assistant message per
     * network turn — the model calling a tool, then continuing once the
     * result is back — and `Ai.leadingActivityMessages()` finds the ones
     * that led to this delegate's own message and only exist because of
     * that. `AiChat.qml`/`AiChatPanel.qml` already hide those from getting
     * a row of their own; this is what the terminal message folds them
     * into instead.
     */
    readonly property var stepGroup: root.isAssistant ? [...Ai.leadingActivityMessages(root.messageId), root.messageData] : [root.messageData]

    // ── Measures ──────────────────────────────────────────────────────────
    /** Inside a bubble, from its edge to its text. */
    readonly property real bubblePadding: root.compact ? Appearance.rounding.unsharpenmore : Appearance.rounding.small
    /** Between the parts of one turn. */
    readonly property real blockGap: Appearance.rounding.unsharpenmore
    /** How much of the width a turn may take, so the other side stays open. */
    readonly property real userMaximumWidth: root.width * 0.86
    readonly property real answerMaximumWidth: root.width * 0.96

    /**
     * A turn that has just arrived, as opposed to one a scrolling list has
     * just built again. Only the first kind is worth an entrance.
     */
    readonly property bool arriving: Ai.isFreshMessage(root.messageId)

    // ── Surfaces ──────────────────────────────────────────────────────────
    // A question sits a step above the transcript and an answer a step below
    // it, which is the contrast the design was drawn with: two bubbles that
    // are told apart by tone and side before a word of either is read.
    // `on`-prefixed names are read as signal handlers in QML, so the ink
    // colours are named for what they are rather than for what they sit on.
    // The turn the keyboard is standing on lifts its own surface. A ring
    // would be a border, and this design does not use them.
    /** Set by the transcript when this is the turn a search landed on. */
    property bool highlighted: false
    readonly property bool turnFocused: root.activeFocus || root.highlighted
    readonly property color questionSurface: root.turnFocused ? Appearance.colors.colLayer3Hover : Appearance.colors.colLayer3
    readonly property color questionInk: Appearance.colors.colOnLayer3
    readonly property color answerSurface: root.turnFocused ? Appearance.colors.colLayer2 : Appearance.m3colors.m3surfaceContainerLowest
    readonly property color answerInk: Appearance.colors.colOnLayer1

    focus: false
    activeFocusOnTab: true
    Accessible.role: Accessible.Paragraph
    Accessible.name: root.isUser
        ? Translation.tr("Your message: %1").arg(String(root.messageData?.content ?? ""))
        : Translation.tr("Assistant response")

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: turnColumn.implicitHeight

    // ── Arrival ───────────────────────────────────────────────────────────
    // A message that has just been sent lands, the way one does in a chat
    // app. One that a recycled delegate is merely rebuilding does not.
    opacity: root.arriving ? 0 : 1
    transform: Translate {
        id: arrivalTransform
        y: root.arriving ? Appearance.font.pixelSize.huge : 0
    }

    Component.onCompleted: {
        root.rebuildBlocks();
        if (root.arriving)
            arrivalAnimation.start();
    }

    ParallelAnimation {
        id: arrivalAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
        }

        NumberAnimation {
            target: arrivalTransform
            property: "y"
            to: 0
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }

        NumberAnimation {
            // The one bounce in the transcript, and it is the feedback for
            // having sent something rather than decoration.
            target: root
            property: "scale"
            from: 0.92
            to: 1
            duration: Appearance.animation.clickBounce.duration
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
    }

    ColumnLayout {
        id: turnColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.blockGap

        Loader {
            // Everything above this line is out of the model's reach now. The
            // alternative was a conversation that quietly started forgetting,
            // or one that the provider refused outright.
            Layout.fillWidth: true
            Layout.bottomMargin: active ? root.blockGap : 0
            active: Ai.contextCutMessageId.length > 0 && Ai.contextCutMessageId === root.messageId && Ai.prunedTurnCount > 0
            visible: active

            sourceComponent: RowLayout {
                spacing: Appearance.rounding.unsharpenmore

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                MaterialSymbol {
                    text: "content_cut"
                    fill: 1
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    text: Ai.contextSummary.length > 0
                        ? Translation.tr("%1 earlier turns, summarised for the model").arg(Ai.prunedTurnCount)
                        : Translation.tr("%1 earlier turns are past the model's window").arg(Ai.prunedTurnCount)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext

                    StyledToolTip {
                        text: Ai.contextSummary.length > 0
                            ? Translation.tr("They are still in this chat and still saved — the model gets them as a summary:\n\n%1").arg(Ai.contextSummary)
                            : Translation.tr("They are still in this chat and still saved; they are just not sent any more.")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }
            }
        }

        // ── The question ──────────────────────────────────────────────────

        Flow {
            // What went out with the question, kept with it: a reopened chat
            // still shows what the model was actually looking at.
            Layout.alignment: Qt.AlignRight
            Layout.maximumWidth: root.userMaximumWidth
            visible: root.isUser && root.sentFiles.length > 0
            spacing: root.blockGap
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: ScriptModel {
                    values: root.isUser ? root.sentFiles : []
                }

                delegate: Rectangle {
                    id: sentFile
                    required property var modelData

                    implicitWidth: sentFileRow.implicitWidth + Appearance.font.pixelSize.large
                    implicitHeight: Math.round(Appearance.font.pixelSize.huge * 1.5)
                    radius: Appearance.rounding.full
                    color: root.questionSurface

                    RowLayout {
                        id: sentFileRow
                        anchors.centerIn: parent
                        spacing: Appearance.rounding.unsharpenmore

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
                            fill: 1
                            iconSize: Appearance.font.pixelSize.larger
                            color: root.questionInk
                        }

                        StyledText {
                            Layout.maximumWidth: root.userMaximumWidth * 0.6
                            text: sentFile.modelData.name ?? ""
                            elide: Text.ElideMiddle
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.questionInk
                        }
                    }

                    StyledToolTip {
                        text: `${sentFile.modelData.path ?? ""}\n${Ai.humanSize(sentFile.modelData.bytes ?? 0)}`
                    }
                }
            }
        }

        RowLayout {
            // The pencil lives beside the bubble rather than inside it, so a
            // long question is never rewrapped by a control that is only
            // there while the pointer is.
            Layout.alignment: Qt.AlignRight
            Layout.maximumWidth: root.width
            visible: root.isUser
            spacing: Appearance.rounding.unsharpenmore

            HoverHandler {
                id: questionHover
                blocking: false
            }

            RippleButton {
                id: editButton
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Math.round(Appearance.font.pixelSize.huge * 1.35)
                implicitHeight: implicitWidth
                buttonRadius: Appearance.rounding.full
                topPadding: 0
                bottomPadding: 0
                leftPadding: 0
                rightPadding: 0
                focusPolicy: Qt.TabFocus
                opacity: questionHover.hovered || editButton.hovered || editButton.activeFocus ? 1 : 0
                visible: opacity > 0.01
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.editRequested(root.messageId, String(root.messageData?.content ?? ""))

                Accessible.name: Translation.tr("Edit this question")

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "edit"
                    fill: 1
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colSubtext
                }

                StyledToolTip {
                    text: Translation.tr("Edit and ask again")
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
            }

            Rectangle {
                id: questionBubble
                Layout.alignment: Qt.AlignRight
                Layout.maximumWidth: root.userMaximumWidth
                implicitWidth: visible ? Math.min(root.userMaximumWidth, questionText.implicitWidth + root.bubblePadding * 3) : 0
                implicitHeight: visible ? questionText.implicitHeight + root.bubblePadding * 2 : 0
                // A stadium while the question is one line, and a soft box once
                // it is many: a full radius on a tall block is a circle, and the
                // text ends up inside its arc rather than inside the bubble.
                radius: Math.min(questionBubble.height / 2, Appearance.rounding.verylarge)
                color: root.questionSurface

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                Behavior on implicitHeight {
                    animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
                }

                StyledText {
                    id: questionText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.bubblePadding * 1.5
                    anchors.rightMargin: root.bubblePadding * 1.5
                    text: String(root.messageData?.content ?? "")
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: root.questionInk
                }
            }
        }

        // ── What the interface itself had to say ──────────────────────────

        Rectangle {
            id: interfaceNote
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width
            visible: root.isInterface && interfaceText.text.length > 0
            implicitWidth: visible ? Math.min(root.width, interfaceText.implicitWidth + root.bubblePadding * 3) : 0
            implicitHeight: visible ? interfaceText.implicitHeight + root.bubblePadding * 1.6 : 0
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer2

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: root.bubblePadding * 1.2
                anchors.rightMargin: root.bubblePadding * 1.2
                spacing: Appearance.rounding.unsharpenmore

                MaterialSymbol {
                    Layout.alignment: Qt.AlignTop
                    text: "info"
                    fill: 1
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    id: interfaceText
                    Layout.fillWidth: true
                    text: String(root.messageData?.content ?? "")
                    wrapMode: Text.Wrap
                    textFormat: Text.MarkdownText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // ── What it did before answering ──────────────────────────────────

        ColumnLayout {
            id: activityColumn
            Layout.fillWidth: true
            Layout.maximumWidth: root.answerMaximumWidth
            visible: root.isAssistant
            spacing: 0

            // One message's own thinking + search + tool steps. Used
            // directly for the common single-message turn, and once per
            // message inside the "N steps" accordion below for a chain of
            // tool round-trips — each of those used to render as a full
            // turn of its own, which is what turned a several-step
            // exchange into a page-long scroll. Self-contained on purpose:
            // nothing here reads `root`, so it works the same whether it
            // is instantiated directly or from inside that accordion's
            // Repeater.
            component StepActivity: ColumnLayout {
                id: step
                required property var stepData
                readonly property bool stepDone: step.stepData?.done ?? true
                readonly property bool stepStreaming: !step.stepDone

                Layout.fillWidth: true
                spacing: 0

                AiActivityRow {
                    id: stepThinkingRow
                    property bool userChoice: false
                    property bool userExpanded: false

                    Layout.fillWidth: true
                    shown: (step.stepData?.thought?.length ?? 0) > 0
                    symbol: "lightbulb"
                    running: step.stepStreaming && !stepThinkingRow.thoughtComplete
                    expandable: true
                    expanded: stepThinkingRow.userChoice ? stepThinkingRow.userExpanded : !stepThinkingRow.thoughtComplete
                    maximumContentHeight: Appearance.font.pixelSize.huge * 8

                    readonly property bool thoughtComplete: ((step.stepData?.content?.length ?? 0) > 0) || step.stepDone
                    readonly property real durationMs: step.stepData?.thoughtDurationMs ?? 0
                    readonly property int thoughtTokens: step.stepData?.thoughtTokens ?? -1

                    label: {
                        if (!stepThinkingRow.thoughtComplete)
                            return Translation.tr("Thinking");
                        let parts = [];
                        if (stepThinkingRow.durationMs >= 100)
                            parts.push(Translation.tr("Thought for %1 s").arg((stepThinkingRow.durationMs / 1000).toFixed(1)));
                        else
                            parts.push(Translation.tr("Thought"));
                        if (stepThinkingRow.thoughtTokens > 0)
                            parts.push(Translation.tr("%1 tokens").arg(stepThinkingRow.thoughtTokens));
                        return parts.join(" · ");
                    }

                    onToggled: {
                        stepThinkingRow.userExpanded = !stepThinkingRow.expanded;
                        stepThinkingRow.userChoice = true;
                    }

                    onThoughtCompleteChanged: {
                        if (stepThinkingRow.thoughtComplete) {
                            stepThinkingRow.userChoice = false;
                            stepThinkingRow.userExpanded = false;
                        }
                    }

                    expandedContent: Component {
                        Flickable {
                            id: thoughtFlickable
                            implicitHeight: Math.min(thoughtColumn.implicitHeight, stepThinkingRow.maximumContentHeight)
                            height: implicitHeight
                            contentWidth: width
                            contentHeight: thoughtColumn.implicitHeight
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            // While it is still arriving, stay at the newest line.
                            onContentHeightChanged: {
                                if (step.stepStreaming)
                                    contentY = Math.max(0, contentHeight - height);
                            }

                            Column {
                                id: thoughtColumn
                                width: thoughtFlickable.width

                                AiMessageTextBlock {
                                    width: parent.width
                                    messageData: step.stepData
                                    done: step.stepDone
                                    segmentContent: step.stepData?.thought ?? ""
                                    forceDisableChunkSplitting: true
                                }
                            }
                        }
                    }
                }

                AiActivityRow {
                    // What it looked up. The queries are the interesting part and
                    // they are one click away rather than in the answer.
                    id: stepSearchRow
                    property bool searchExpanded: false

                    readonly property var queries: Array.from(step.stepData?.searchQueries ?? [])

                    Layout.fillWidth: true
                    shown: stepSearchRow.queries.length > 0
                    symbol: "language"
                    running: step.stepStreaming
                    expandable: true
                    expanded: stepSearchRow.searchExpanded
                    label: step.stepStreaming ? Translation.tr("Searching the web") : Translation.tr("Searched the web")
                    onToggled: stepSearchRow.searchExpanded = !stepSearchRow.searchExpanded

                    // A peek taken while it was still running should not
                    // linger once the turn is done and there is an answer to
                    // read instead.
                    Connections {
                        target: step
                        function onStepDoneChanged() {
                            if (step.stepDone)
                                stepSearchRow.searchExpanded = false;
                        }
                    }

                    expandedContent: Component {
                        Flow {
                            spacing: Appearance.rounding.unsharpenmore

                            Repeater {
                                model: ScriptModel {
                                    values: stepSearchRow.queries
                                }

                                delegate: AiSearchQueryButton {
                                    required property var modelData
                                    query: modelData
                                }
                            }
                        }
                    }
                }

                Repeater {
                    // Everything else it reached for, in the order it did.
                    model: ScriptModel {
                        values: Array.from(step.stepData?.toolCalls ?? [])
                    }

                    delegate: AiActivityRow {
                        id: stepToolRow
                        required property var modelData
                        property bool toolExpanded: false

                        readonly property string toolId: String(stepToolRow.modelData?.name ?? "")
                        readonly property var definition: Ai.toolbox.definitionFor(stepToolRow.toolId)
                        readonly property string detail: Ai.toolbox.describeArgs(stepToolRow.toolId, stepToolRow.modelData?.args)
                        // Written by the broker onto the call itself as it goes.
                        // A call with no state at all is one from a session saved
                        // before the broker existed.
                        readonly property string state: String(stepToolRow.modelData?.state ?? "")
                        readonly property string outcome: String(stepToolRow.modelData?.summary ?? "")
                        readonly property bool waiting: stepToolRow.state === "running"
                            || (stepToolRow.state.length === 0 && (step.stepStreaming || (step.stepData?.functionPending ?? false)))
                        readonly property bool wentWrong: ["error", "unavailable", "needsInspection"].indexOf(stepToolRow.state) >= 0
                        readonly property bool refused: ["denied", "cancelled"].indexOf(stepToolRow.state) >= 0

                        Layout.fillWidth: true
                        symbol: {
                            if (stepToolRow.state === "needsInspection")
                                return "help";
                            if (stepToolRow.wentWrong)
                                return "error";
                            if (stepToolRow.refused)
                                return "block";
                            return (stepToolRow.definition?.icon ?? "").length > 0 ? stepToolRow.definition.icon : "build";
                        }
                        // The outcome next to the name, because "Search the web"
                        // and "Search the web · nothing came back" are different
                        // things to have read in a transcript.
                        label: stepToolRow.outcome.length > 0 && !stepToolRow.waiting
                            ? `${Ai.toolbox.titleFor(stepToolRow.toolId)} · ${stepToolRow.outcome}`
                            : Ai.toolbox.titleFor(stepToolRow.toolId)
                        running: stepToolRow.waiting
                        expandable: stepToolRow.detail.length > 0
                        expanded: stepToolRow.expandable && stepToolRow.toolExpanded
                        onToggled: stepToolRow.toolExpanded = !stepToolRow.toolExpanded

                        Connections {
                            target: step
                            function onStepDoneChanged() {
                                if (step.stepDone)
                                    stepToolRow.toolExpanded = false;
                            }
                        }

                        expandedContent: Component {
                            ColumnLayout {
                                spacing: Appearance.rounding.unsharpenmore

                                StyledText {
                                    Layout.fillWidth: true
                                    text: stepToolRow.detail
                                    wrapMode: Text.Wrap
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: stepToolRow.modelData?.networkUsed === true || stepToolRow.modelData?.truncated === true
                                    spacing: Appearance.rounding.unsharpenmore

                                    StyledText {
                                        visible: stepToolRow.modelData?.networkUsed === true
                                        text: Translation.tr("used the network")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }

                                    StyledText {
                                        visible: stepToolRow.modelData?.truncated === true
                                        text: Translation.tr("result was cut to fit")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // The common case: the question was answered in one go.
            // Rendered exactly as a lone step, with no extra wrapper.
            StepActivity {
                visible: root.stepGroup.length <= 1
                stepData: root.messageData
            }

            // A chain of tool round-trips: every step folds into this one
            // line instead of each getting a full turn's worth of chrome.
            // Open while it is happening, so the steps are watchable live;
            // folded the moment the exchange is done, with the steps still
            // one click away.
            AiActivityRow {
                id: stepsSummaryRow
                property bool userChoice: false
                property bool userExpanded: false

                Layout.fillWidth: true
                shown: root.stepGroup.length > 1
                symbol: "checklist"
                running: root.streaming
                expandable: true
                expanded: stepsSummaryRow.userChoice ? stepsSummaryRow.userExpanded : root.streaming
                label: root.streaming
                    ? Translation.tr("Working through %1 steps…").arg(root.stepGroup.length)
                    : Translation.tr("%1 steps").arg(root.stepGroup.length)

                onToggled: {
                    stepsSummaryRow.userExpanded = !stepsSummaryRow.expanded;
                    stepsSummaryRow.userChoice = true;
                }

                Connections {
                    target: root
                    function onDoneChanged() {
                        if (root.done) {
                            stepsSummaryRow.userChoice = false;
                            stepsSummaryRow.userExpanded = false;
                        }
                    }
                }

                expandedContent: Component {
                    ColumnLayout {
                        spacing: Appearance.rounding.small

                        Repeater {
                            model: ScriptModel {
                                values: root.stepGroup
                            }

                            delegate: StepActivity {
                                id: groupedStep
                                required property var modelData
                                Layout.fillWidth: true
                                stepData: groupedStep.modelData
                            }
                        }
                    }
                }
            }
        }

        // ── The answer ────────────────────────────────────────────────────

        Rectangle {
            id: answerBubble
            Layout.alignment: Qt.AlignLeft
            Layout.fillWidth: true
            Layout.maximumWidth: root.answerMaximumWidth
            visible: root.isAssistant && (root.messageBlocks.length > 0 || root.streaming)
            implicitHeight: visible ? answerContent.implicitHeight + root.bubblePadding * 2 : 0
            radius: Math.min(answerBubble.height / 2, Appearance.rounding.large)
            // An empty bubble is a box with nothing in it. The ground arrives
            // with the first block, so the wait reads as the model about to
            // speak rather than as a card that failed to load.
            readonly property bool holdsOnlyTheWait: root.messageBlocks.length < 1
            color: answerBubble.holdsOnlyTheWait ? "transparent" : root.answerSurface

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            // Line by line rather than in jumps: the box follows the text
            // that is arriving in it instead of snapping to each new height.
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }

            Item {
                // No fade of its own: the only soft edges in the transcript
                // are the ones at the top and the bottom of the list, and a
                // second one inside a bubble read as the answer being cut.
                id: answerContentClip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: root.bubblePadding
                implicitHeight: answerContent.implicitHeight
                height: implicitHeight

                ColumnLayout {
                    id: answerContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: root.blockGap

                    Item {
                        // Before the first token there is nothing to show but
                        // that something is coming — centred, because an empty
                        // bubble with a mark in its corner reads as a fault.
                        Layout.fillWidth: true
                        implicitHeight: loadingIndicatorLoader.shown ? loadingIndicatorLoader.implicitHeight : 0
                        visible: implicitHeight > 0

                        Behavior on implicitHeight {
                            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                        }

                        FadeLoader {
                            // Left, where the first line of the answer will
                            // appear: the wait belongs in the place the words
                            // are about to take, not in the middle of a box.
                            id: loadingIndicatorLoader
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            shown: root.messageBlocks.length < 1 && root.streaming

                            sourceComponent: AiTypingIndicator {
                                active: loadingIndicatorLoader.shown
                                // Before the first token, a model with a thought
                                // in flight is reasoning; one without has not
                                // started saying anything yet.
                                reasoning: (root.messageData?.thought?.length ?? 0) > 0
                            }
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            values: root.messageBlocks
                        }

                        delegate: Item {
                            id: messageBlockItem
                            required property var modelData

                            Layout.fillWidth: true
                            implicitWidth: parent ? parent.width : 0
                            implicitHeight: messageBlockLoader.implicitHeight

                            Component {
                                id: codeBlockComponent
                                AiMessageCodeBlock {
                                    width: messageBlockItem.width
                                    segmentContent: messageBlockItem.modelData?.content ?? ""
                                    segmentLang: messageBlockItem.modelData?.lang ?? "txt"
                                    messageData: root.messageData
                                }
                            }

                            Component {
                                id: thinkBlockComponent
                                AiMessageThinkBlock {
                                    width: messageBlockItem.width
                                    segmentContent: messageBlockItem.modelData?.content ?? ""
                                    messageData: root.messageData
                                    done: root.done
                                    completed: messageBlockItem.modelData?.completed ?? false
                                }
                            }

                            Component {
                                id: tableBlockComponent
                                AiMessageTableBlock {
                                    width: messageBlockItem.width
                                    block: messageBlockItem.modelData
                                    messageData: root.messageData
                                }
                            }

                            Component {
                                id: textBlockComponent
                                AiMessageTextBlock {
                                    width: messageBlockItem.width
                                    segmentContent: messageBlockItem.modelData?.content ?? ""
                                    messageData: root.messageData
                                    done: root.done
                                    forceDisableChunkSplitting: root.transcriptContent.includes("```")
                                }
                            }

                            Loader {
                                id: messageBlockLoader
                                width: parent.width
                                sourceComponent: {
                                    const blockType = messageBlockItem.modelData?.type;
                                    if (blockType === "code")
                                        return codeBlockComponent;
                                    if (blockType === "think")
                                        return thinkBlockComponent;
                                    if (blockType === "table")
                                        return tableBlockComponent;
                                    return textBlockComponent;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── When it went wrong, or wants something ────────────────────────

        // ── Cards this turn carries ───────────────────────────────────────
        // A tool that needs to show something adds a card; the component is
        // picked by its `kind`. There used to be one Loader per tool here,
        // each testing a property of its own on the message, which is three
        // edits in three files every time a tool learns to ask something.

        Repeater {
            model: ScriptModel {
                values: Ai.visibleToolCards(root.messageData)
            }

            delegate: Loader {
                id: cardHost
                required property var modelData
                readonly property var card: cardHost.modelData

                Layout.fillWidth: true
                Layout.maximumWidth: root.answerMaximumWidth
                sourceComponent: {
                    switch (String(cardHost.card?.kind ?? "")) {
                    case "settingsDiff":
                        return settingsDiffCard;
                    case "settingsResults":
                        return settingsResultsCard;
                    case "reminderPreview":
                        return reminderPreviewCard;
                    case "memoryFact":
                        return memoryFactCard;
                    case "fileResults":
                        return fileResultsCard;
                    case "fileAttachPreview":
                        return fileAttachCard;
                    case "notesPreview":
                        return notesPreviewCard;
                    }
                    // A kind this build does not know: a session written by a
                    // newer one still opens, showing what the card says about
                    // itself rather than nothing at all.
                    return unknownCard;
                }

                Component {
                    id: settingsDiffCard

                    AiConfigDiffCard {
                        messageData: root.messageData
                        card: cardHost.card
                    }
                }

                Component {
                    id: settingsResultsCard

                    ColumnLayout {
                        spacing: Appearance.rounding.unsharpenmore

                        Repeater {
                            model: ScriptModel {
                                values: Array.from(cardHost.card?.data?.matches ?? [])
                            }

                            delegate: AiSettingResultCard {
                                required property var modelData
                                setting: modelData
                            }
                        }
                    }
                }

                Component {
                    id: fileResultsCard

                    ColumnLayout {
                        spacing: Appearance.rounding.unsharpenmore

                        Repeater {
                            model: ScriptModel {
                                values: Array.from(cardHost.card?.data?.files ?? [])
                            }

                            delegate: AiFileResultCard {
                                required property var modelData
                                file: modelData
                                compact: root.compact
                            }
                        }
                    }
                }

                Component {
                    id: fileAttachCard

                    AiFileAttachCard {
                        messageData: root.messageData
                        card: cardHost.card
                    }
                }

                Component {
                    id: reminderPreviewCard

                    AiReminderCard {
                        messageData: root.messageData
                        card: cardHost.card
                    }
                }

                Component {
                    id: notesPreviewCard

                    AiNotesCard {
                        messageData: root.messageData
                        card: cardHost.card
                    }
                }

                Component {
                    id: unknownCard

                    Rectangle {
                        implicitHeight: unknownRow.implicitHeight + root.bubblePadding * 2
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colLayer2

                        RowLayout {
                            id: unknownRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: root.bubblePadding
                            anchors.rightMargin: root.bubblePadding
                            spacing: Appearance.rounding.unsharpenmore

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignTop
                                text: "extension"
                                fill: 1
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: String(cardHost.card?.summary ?? "").length > 0
                                    ? cardHost.card.summary
                                    : Translation.tr("This needs a newer version of the shell to show.")
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                Component {
                    id: memoryFactCard

                    Rectangle {
                        implicitHeight: memoryColumn.implicitHeight + root.bubblePadding * 2
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colSecondaryContainer

                        ColumnLayout {
                            id: memoryColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: root.bubblePadding
                            anchors.rightMargin: root.bubblePadding
                            spacing: Appearance.rounding.unsharpenmore

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.rounding.unsharpenmore

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignTop
                                    text: "bookmark_add"
                                    fill: 1
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.m3colors.m3onSecondaryContainer
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("Remember this for later chats?")
                                        wrapMode: Text.Wrap
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.DemiBold
                                        color: Appearance.m3colors.m3onSecondaryContainer
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: cardHost.card?.data?.fact ?? ""
                                        wrapMode: Text.Wrap
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.m3colors.m3onSecondaryContainer
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.rounding.unsharpenmore

                                Item {
                                    Layout.fillWidth: true
                                }

                                RippleButton {
                                    leftPadding: Appearance.rounding.small
                                    rightPadding: Appearance.rounding.small
                                    topPadding: Appearance.rounding.unsharpenmore / 2
                                    bottomPadding: Appearance.rounding.unsharpenmore / 2
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                                    colBackgroundHover: Appearance.colors.colLayer2Hover
                                    colRipple: Appearance.colors.colLayer2Active
                                    onClicked: Ai.rejectMemory(root.messageData)

                                    contentItem: StyledText {
                                        text: Translation.tr("No")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.m3colors.m3onSecondaryContainer
                                    }
                                }

                                RippleButton {
                                    leftPadding: Appearance.rounding.small
                                    rightPadding: Appearance.rounding.small
                                    topPadding: Appearance.rounding.unsharpenmore / 2
                                    bottomPadding: Appearance.rounding.unsharpenmore / 2
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: Appearance.colors.colPrimary
                                    colBackgroundHover: Appearance.colors.colPrimaryHover
                                    colRipple: Appearance.colors.colPrimaryActive
                                    onClicked: Ai.commitMemory(root.messageData)

                                    contentItem: StyledText {
                                        text: Translation.tr("Remember it")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }
                            }
                        }
            }
                }
            }
        }

        Loader {
            // A failed request used to leave a message that stopped, with the
            // reason in the log. What went wrong and what to do about it both
            // belong here, next to a button that tries again.
            Layout.fillWidth: true
            Layout.maximumWidth: root.answerMaximumWidth
            active: (root.messageData?.errorKind?.length ?? 0) > 0
            visible: active

            sourceComponent: Rectangle {
                implicitHeight: errorColumn.implicitHeight + root.bubblePadding * 2
                radius: Appearance.rounding.large
                color: ColorUtils.transparentize(Appearance.m3colors.m3error, 0.88)

                ColumnLayout {
                    id: errorColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.bubblePadding
                    anchors.rightMargin: root.bubblePadding
                    spacing: Appearance.rounding.unsharpenmore

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.rounding.unsharpenmore

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            text: "error"
                            fill: 1
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
                                font.pixelSize: Appearance.font.pixelSize.small
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
                        Layout.maximumHeight: Appearance.font.pixelSize.huge * 7
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
                        spacing: Appearance.rounding.unsharpenmore

                        RippleButton {
                            id: errorDetailsToggle
                            property bool unfolded: false

                            visible: (root.messageData?.errorDetails?.length ?? 0) > 0
                            leftPadding: Appearance.rounding.small
                            rightPadding: Appearance.rounding.small
                            topPadding: Appearance.rounding.unsharpenmore / 2
                            bottomPadding: Appearance.rounding.unsharpenmore / 2
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
                            leftPadding: Appearance.rounding.small
                            rightPadding: Appearance.rounding.small
                            topPadding: Appearance.rounding.unsharpenmore / 2
                            bottomPadding: Appearance.rounding.unsharpenmore / 2
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
                            leftPadding: Appearance.rounding.small
                            rightPadding: Appearance.rounding.small
                            topPadding: Appearance.rounding.unsharpenmore / 2
                            bottomPadding: Appearance.rounding.unsharpenmore / 2
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colPrimary
                            colBackgroundHover: Appearance.colors.colPrimaryHover
                            colRipple: Appearance.colors.colPrimaryActive
                            onClicked: Ai.retryMessage(root.messageId)

                            contentItem: RowLayout {
                                spacing: Appearance.rounding.unsharpenmore / 2

                                MaterialSymbol {
                                    text: "refresh"
                                    fill: 1
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
            Layout.alignment: Qt.AlignHCenter
            active: (root.messageData?.notice ?? "") === "apiKey"
            visible: active

            sourceComponent: RippleButton {
                leftPadding: Appearance.rounding.small
                rightPadding: Appearance.rounding.small
                topPadding: Appearance.rounding.unsharpenmore
                bottomPadding: Appearance.rounding.unsharpenmore
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: Ai.keyManagerRequested()

                contentItem: RowLayout {
                    spacing: Appearance.rounding.unsharpenmore / 2

                    MaterialSymbol {
                        text: "key"
                        fill: 1
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

        Flow {
            // Where an answer with citations got them from.
            Layout.fillWidth: true
            Layout.maximumWidth: root.answerMaximumWidth
            visible: (root.messageData?.annotationSources?.length ?? 0) > 0
            spacing: Appearance.rounding.unsharpenmore

            Repeater {
                model: ScriptModel {
                    values: root.messageData?.annotationSources ?? []
                }

                delegate: AiAnnotationSourceButton {
                    required property var modelData
                    displayText: modelData.text
                    url: modelData.url
                }
            }
        }

        Loader {
            // The provider stopped at its output limit. Regenerating was the
            // only way out before, and it paid for the whole context again to
            // get a different answer instead of the rest of this one.
            Layout.fillWidth: true
            Layout.maximumWidth: root.answerMaximumWidth
            active: root.isAssistant && root.done && Ai.wasTruncated(root.messageData)
            visible: active

            sourceComponent: RippleButton {
                implicitHeight: Math.round(Appearance.font.pixelSize.huge * 1.7)
                leftPadding: Appearance.rounding.small
                rightPadding: Appearance.rounding.small
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: Ai.continueMessage(root.messageId)

                Accessible.name: Translation.tr("Continue this answer")

                contentItem: RowLayout {
                    spacing: Appearance.rounding.unsharpenmore

                    MaterialSymbol {
                        text: "more_horiz"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.m3colors.m3onSecondaryContainer
                    }

                    StyledText {
                        text: Translation.tr("Continue — it stopped at the length limit")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSecondaryContainer
                    }
                }
            }
        }

        // ── What can be done with it ──────────────────────────────────────

        AiMessageActions {
            id: answerActions
            Layout.fillWidth: true
            Layout.maximumWidth: root.answerMaximumWidth
            Layout.topMargin: visible ? root.blockGap / 2 : 0
            visible: root.isAssistant && root.done && root.messageBlocks.length > 0
            // The Search panel is a strip that is mostly composer: it gets
            // the same bar with the two actions a quick question needs.
            minimal: root.compact
            messageId: root.messageId
            messageData: root.messageData
            surfaceColor: root.answerSurface
            buttonColor: root.questionSurface
            buttonInk: root.questionInk
            onRegenerateRequested: id => root.regenerateRequested(id)
            onModelPickerRequested: root.modelPickerRequested()

            // It arrives when the answer is finished, from just under it.
            opacity: visible ? 1 : 0
            transform: Translate {
                y: answerActions.visible ? 0 : -Appearance.rounding.small

                Behavior on y {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
            }

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }
}
