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

    /** Asks the control bar for another model to redo this answer with. */
    signal regenerateRequested(string messageId)
    /** Asks the control bar to open the model picker. */
    signal modelPickerRequested

    readonly property string transcriptContent: String(root.messageData?.content ?? root.messageData?.rawContent ?? "")
    property list<var> messageBlocks: AiTranscriptRegistry.blocksForContent(root.transcriptContent)

    readonly property string role: String(root.messageData?.role ?? "assistant")
    readonly property bool isUser: root.role === "user"
    readonly property bool isInterface: root.role === "interface"
    readonly property bool isAssistant: !root.isUser && !root.isInterface
    readonly property bool done: root.messageData?.done ?? false
    /** True while the answer is still being written into this turn. */
    readonly property bool streaming: root.isAssistant && !root.done
    readonly property var sentFiles: Array.from(root.messageData?.attachments ?? [])

    // ── Measures ──────────────────────────────────────────────────────────
    /** Inside a bubble, from its edge to its text. */
    readonly property real bubblePadding: Appearance.rounding.small
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
    readonly property color questionSurface: Appearance.colors.colLayer3
    readonly property color questionInk: Appearance.colors.colOnLayer3
    readonly property color answerSurface: Appearance.m3colors.m3surfaceContainerLowest
    readonly property color answerInk: Appearance.colors.colOnLayer1

    focus: false
    activeFocusOnTab: true
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

        Rectangle {
            id: questionBubble
            Layout.alignment: Qt.AlignRight
            Layout.maximumWidth: root.userMaximumWidth
            visible: root.isUser
            implicitWidth: visible ? Math.min(root.userMaximumWidth, questionText.implicitWidth + root.bubblePadding * 3) : 0
            implicitHeight: visible ? questionText.implicitHeight + root.bubblePadding * 2 : 0
            // A stadium while the question is one line, and a soft box once
            // it is many: a full radius on a tall block is a circle, and the
            // text ends up inside its arc rather than inside the bubble.
            radius: Math.min(questionBubble.height / 2, Appearance.rounding.verylarge)
            color: root.questionSurface

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

            AiActivityRow {
                // The reasoning, as an accordion: open while it is the only
                // thing happening, folded away once the answer starts, and
                // whichever of the two the reader last chose after that.
                id: thinkingRow
                property bool userChoice: false
                property bool userExpanded: false

                Layout.fillWidth: true
                shown: (root.messageData?.thought?.length ?? 0) > 0
                symbol: "lightbulb"
                running: root.streaming && !thinkingRow.thoughtComplete
                expandable: true
                expanded: thinkingRow.userChoice ? thinkingRow.userExpanded : !thinkingRow.thoughtComplete
                maximumContentHeight: Appearance.font.pixelSize.huge * 8

                readonly property bool thoughtComplete: ((root.messageData?.content?.length ?? 0) > 0) || root.done
                readonly property real durationMs: root.messageData?.thoughtDurationMs ?? 0
                readonly property int thoughtTokens: root.messageData?.thoughtTokens ?? -1

                label: {
                    if (!thinkingRow.thoughtComplete)
                        return Translation.tr("Thinking");
                    let parts = [];
                    if (thinkingRow.durationMs >= 100)
                        parts.push(Translation.tr("Thought for %1 s").arg((thinkingRow.durationMs / 1000).toFixed(1)));
                    else
                        parts.push(Translation.tr("Thought"));
                    if (thinkingRow.thoughtTokens > 0)
                        parts.push(Translation.tr("%1 tokens").arg(thinkingRow.thoughtTokens));
                    return parts.join(" · ");
                }

                onToggled: {
                    thinkingRow.userExpanded = !thinkingRow.expanded;
                    thinkingRow.userChoice = true;
                    // Only a deliberate choice on a finished thought is worth
                    // remembering: opening one still being written is simply
                    // what happens by default.
                    if (thinkingRow.thoughtComplete && Persistent.states?.ai)
                        Persistent.states.ai.expandThoughts = thinkingRow.userExpanded;
                }

                Component.onCompleted: {
                    if (Persistent.states?.ai?.expandThoughts) {
                        thinkingRow.userChoice = true;
                        thinkingRow.userExpanded = true;
                    }
                }

                expandedContent: Component {
                    Flickable {
                        id: thoughtFlickable
                        implicitHeight: Math.min(thoughtColumn.implicitHeight, thinkingRow.maximumContentHeight)
                        height: implicitHeight
                        contentWidth: width
                        contentHeight: thoughtColumn.implicitHeight
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        // While it is still arriving, stay at the newest line.
                        onContentHeightChanged: {
                            if (root.streaming)
                                contentY = Math.max(0, contentHeight - height);
                        }

                        Column {
                            id: thoughtColumn
                            width: thoughtFlickable.width

                            AiMessageTextBlock {
                                width: parent.width
                                messageData: root.messageData
                                done: root.done
                                segmentContent: root.messageData?.thought ?? ""
                                forceDisableChunkSplitting: true
                            }
                        }
                    }
                }
            }

            AiActivityRow {
                // What it looked up. The queries are the interesting part and
                // they are one click away rather than in the answer.
                id: searchRow
                property bool searchExpanded: false

                readonly property var queries: Array.from(root.messageData?.searchQueries ?? [])

                Layout.fillWidth: true
                shown: searchRow.queries.length > 0
                symbol: "language"
                running: root.streaming
                expandable: true
                expanded: searchRow.searchExpanded
                label: root.streaming ? Translation.tr("Searching the web") : Translation.tr("Searched the web")
                onToggled: searchRow.searchExpanded = !searchRow.searchExpanded

                expandedContent: Component {
                    Flow {
                        spacing: Appearance.rounding.unsharpenmore

                        Repeater {
                            model: ScriptModel {
                                values: searchRow.queries
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
                    values: Array.from(root.messageData?.toolCalls ?? [])
                }

                delegate: AiActivityRow {
                    id: toolRow
                    required property var modelData
                    property bool toolExpanded: false

                    readonly property string toolId: String(toolRow.modelData?.name ?? "")
                    readonly property var definition: Ai.toolbox.definitionFor(toolRow.toolId)
                    readonly property string detail: Ai.toolbox.describeArgs(toolRow.toolId, toolRow.modelData?.args)

                    Layout.fillWidth: true
                    symbol: (toolRow.definition?.icon ?? "").length > 0 ? toolRow.definition.icon : "build"
                    label: Ai.toolbox.titleFor(toolRow.toolId)
                    running: root.streaming || (root.messageData?.functionPending ?? false)
                    expandable: toolRow.detail.length > 0
                    expanded: toolRow.expandable && toolRow.toolExpanded
                    onToggled: toolRow.toolExpanded = !toolRow.toolExpanded

                    expandedContent: Component {
                        StyledText {
                            text: toolRow.detail
                            wrapMode: Text.Wrap
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
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
            color: root.answerSurface

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
                            id: loadingIndicatorLoader
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            shown: root.messageBlocks.length < 1 && root.streaming

                            sourceComponent: RowLayout {
                                spacing: Appearance.rounding.unsharpenmore

                                MaterialLoadingIndicator {
                                    Layout.alignment: Qt.AlignVCenter
                                    loading: true
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: (root.messageData?.thought?.length ?? 0) > 0
                                        ? Translation.tr("Writing the answer")
                                        : Translation.tr("Waiting for the model")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
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
                                    return textBlockComponent;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── When it went wrong, or wants something ────────────────────────

        Loader {
            // Settings the model wants to write, shown against what they
            // would replace. Only ever loaded while an answer is waiting.
            Layout.fillWidth: true
            Layout.maximumWidth: root.answerMaximumWidth
            active: (root.messageData?.pendingChanges?.length ?? 0) > 0 && (root.messageData?.functionPending ?? false)
            visible: active

            sourceComponent: AiConfigDiffCard {
                messageData: root.messageData
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

        // ── What can be done with it ──────────────────────────────────────

        AiMessageActions {
            id: answerActions
            Layout.fillWidth: true
            Layout.maximumWidth: root.answerMaximumWidth
            Layout.topMargin: visible ? root.blockGap / 2 : 0
            visible: root.isAssistant && root.done && root.messageBlocks.length > 0
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
