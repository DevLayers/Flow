import qs
import qs.services
import qs.services.ai
import qs.services.ai.blocks
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarPolicies.aiChat
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real padding: 4
    property var inputField: messageInputField
    property string commandPrefix: "/"

    property var suggestionQuery: ""
    property var suggestionList: []

    property bool containsDrag: false

    /** Whichever control's view is filling the chat area, "" for the transcript. */
    readonly property bool canvasViewOpen: controlBar.viewOpen

    // Three-surface geometry, kept on the same tokens the Overview
    // AiChatPanel uses so the sidebar and the search panel stay one design
    // rather than two that happen to look alike. Nothing here is a pixel
    // constant: every value is derived from the type scale and the rounding
    // scale, so it follows the user's font size and sharp-mode settings.
    readonly property real toolControlExtent: Math.round(Appearance.font.pixelSize.huge * 2)
    readonly property real toolControlPadding: Appearance.rounding.small
    readonly property real toolsBarHeight: root.toolControlExtent + root.toolControlPadding * 2
    // Floor for the chat area, so a composer that has grown a lot still
    // leaves a readable transcript instead of collapsing it to nothing.
    readonly property real chatAreaMinimumHeight: root.toolsBarHeight * 2
    readonly property real surfaceSpacing: Appearance.rounding.verysmall

    // ── Transcript ──
    /** Space between one turn and the next. */
    readonly property real messageGap: Appearance.rounding.small
    /** What the transcript keeps clear of its own rounded corners. */
    readonly property real messageListInset: Appearance.rounding.small

    // ── Composer ──
    readonly property real composerControlExtent: Math.round(Appearance.font.pixelSize.huge * 2)
    readonly property real composerGap: Appearance.rounding.unsharpenmore
    // A composer's own inset, not a card's: its controls are already round and
    // carry their own optical margin, so the box around them can be tight.
    readonly property real composerInset: Appearance.rounding.verysmall
    /** Whether the plus has slid its ways of attaching out. */
    property bool attachmentsExpanded: false
    onCanvasViewOpenChanged: {
        if (root.canvasViewOpen)
            root.attachmentsExpanded = false;
    }
    readonly property var thinkingShortLabels: ({
        "off": "",
        "low": Translation.tr("Low"),
        "medium": Translation.tr("Med"),
        "high": Translation.tr("High")
    })
    readonly property string thinkingShortLabel: root.thinkingShortLabels[Ai.thinkingLevel] ?? ""

    property int entranceTrigger: -1

    function triggerContentEntrance() {
        root.entranceTrigger++;
    }

    // Handoff state is logical, not a reference to a sidebar delegate. The
    // Search surface can therefore recreate this chat at another width (or
    // after hot reload) without retaining an invalid QML object.
    function captureHandoffState() {
        const anchor = {
            messageId: "",
            offset: 0,
            following: messageListView.following === true
        };
        if (messageListView.count <= 0)
            return anchor;
        const probeY = Math.min(8, Math.max(0, messageListView.height - 1));
        const index = messageListView.indexAt(8, probeY);
        if (index < 0)
            return anchor;
        const modelIds = Ai.messageIDs.filter(id => {
            const message = Ai.messageByID[id];
            return message?.visibleToUser ?? true;
        });
        anchor.messageId = String(modelIds[index] ?? "");
        const delegate = messageListView.itemAtIndex(index);
        if (delegate)
            anchor.offset = Math.max(0, Number(delegate.y) - Number(messageListView.contentY));
        return anchor;
    }

    function restoreHandoffAnchor(anchor) {
        const source = anchor && typeof anchor === "object" ? anchor : ({});
        if (source.following === true) {
            messageListView.pinToEnd();
            return true;
        }
        const modelIds = Ai.messageIDs.filter(id => {
            const message = Ai.messageByID[id];
            return message?.visibleToUser ?? true;
        });
        const index = modelIds.indexOf(String(source.messageId ?? ""));
        if (index < 0)
            return false;
        messageListView.following = false;
        messageListView.positionViewAtIndex(index, ListView.Beginning);
        const offset = Number(source.offset ?? 0);
        if (isFinite(offset) && offset > 0)
            messageListView.contentY = Math.max(0, messageListView.contentY - offset);
        return true;
    }

    function focusMessageTarget(messageId, anchor) {
        const targetId = String(messageId ?? "");
        const modelIds = Ai.messageIDs.filter(id => {
            const message = Ai.messageByID[id];
            return message?.visibleToUser ?? true;
        });
        const index = modelIds.indexOf(targetId);
        if (index < 0)
            return false;
        messageListView.following = false;
        messageListView.positionViewAtIndex(index, ListView.Center);
        const offset = Number(anchor?.offset ?? 0);
        if (isFinite(offset) && offset > 0)
            messageListView.contentY = Math.max(0, messageListView.contentY - offset);
        Qt.callLater(function() {
            const delegate = messageListView.itemAtIndex(index);
            if (delegate && typeof delegate.forceActiveFocus === "function")
                delegate.forceActiveFocus();
            else
                messageListView.forceActiveFocus();
        });
        return true;
    }

    // Returning false leaves a deep-link pending until a streamed target is
    // present in this host. Composer handoffs may be acknowledged immediately
    // once the AI tab is the visible SwipeView page.
    function applySurfaceIntent(intent) {
        if (!intent)
            return false;
        const hasExplicitTarget = String(intent.messageId ?? "").length > 0 || String(intent.blockId ?? "").length > 0;
        if (hasExplicitTarget) {
            const targetId = Ai.surfaceRouter.resolveTargetMessageId(intent);
            return root.focusMessageTarget(targetId, intent.scrollAnchor);
        }
        const anchor = intent.scrollAnchor ?? ({});
        const hasAnchor = String(anchor.messageId ?? "").length > 0 || anchor.following === true;
        if (hasAnchor && !root.restoreHandoffAnchor(anchor))
            return false;
        if (String(intent.focusIntent ?? "composer") === "composer")
            messageInputField.forceActiveFocus();
        return hasAnchor || String(intent.focusIntent ?? "composer") === "composer";
    }

    onFocusChanged: focus => {
        if (focus) {
            root.inputField.forceActiveFocus();
        }
    }

    Keys.onPressed: event => {
        messageInputField.forceActiveFocus();
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                messageListView.contentY = Math.max(0, messageListView.contentY - messageListView.height / 2);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown) {
                messageListView.contentY = Math.min(messageListView.contentHeight - messageListView.height / 2, messageListView.contentY + messageListView.height / 2);
                event.accepted = true;
            }
        }
        if (event.key === Qt.Key_Escape && root.canvasViewOpen) {
            controlBar.closePopover();
            event.accepted = true;
        }
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_J) {
            Ai.surfaceRouter.open({
                surface: "search",
                monitorName: GlobalStates.activeLeftSidebarMonitor,
                sessionId: Ai.sessions.currentId,
                focusIntent: "composer",
                scrollAnchor: root.captureHandoffState()
            });
            event.accepted = true;
            return;
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O) {
            Ai.newChat();
            event.accepted = true;
        }
    }

    property var allCommands: [
        {
            name: "attach",
            description: Translation.tr("Attach a file to the next message. Also: the paperclip, drag and drop, or Ctrl+V."),
            execute: args => {
                const path = args.join(" ").trim();
                if (path.length === 0) {
                    Ai.pickFiles();
                    return;
                }
                Ai.attachFile(path);
            }
        },
        {
            name: "model",
            description: Translation.tr("Choose model"),
            execute: args => {
                Ai.setModel(args.join(" ").trim());
            }
        },
        {
            name: "provider",
            description: Translation.tr("Choose provider"),
            execute: args => {
                Ai.setProvider(args.join(" ").trim());
            }
        },
        {
            name: "tool",
            description: Translation.tr("Set the tool to use for the model."),
            execute: args => {
                // console.log(args)
                if (args.length == 0 || args[0] == "get") {
                    Ai.addMessage(Translation.tr("Usage: %1tool TOOL_NAME").arg(root.commandPrefix), Ai.interfaceRole);
                } else {
                    const tool = args[0];
                    const switched = Ai.setTool(tool);
                    if (switched) {
                        Ai.addMessage(Translation.tr("Tool set to: %1").arg(tool), Ai.interfaceRole);
                    }
                }
            }
        },
        {
            name: "prompt",
            description: Translation.tr("Set the system prompt for the model."),
            execute: args => {
                if (args.length === 0 || args[0] === "get") {
                    Ai.printPrompt();
                    return;
                }
                Ai.loadPrompt(args.join(" ").trim());
            }
        },
        {
            name: "persona",
            description: Translation.tr("Answer as a saved persona: prompt, model, thinking and temperature at once."),
            execute: args => {
                const wanted = args.join(" ").trim();
                if (wanted.length === 0) {
                    controlBar.togglePopover("prompt");
                    return;
                }
                if (wanted === "none" || wanted === "off") {
                    Ai.setPersona("");
                    return;
                }
                const needle = wanted.toLowerCase();
                const persona = Ai.personas.all.find(entry => entry.id === needle || (entry.name ?? "").toLowerCase() === needle);
                if (!persona) {
                    Ai.addMessage(Translation.tr("No persona called %1. Known: %2").arg(wanted).arg(Ai.personas.all.map(entry => entry.id).join(", ")), Ai.interfaceRole);
                    return;
                }
                Ai.setPersona(persona.id);
            }
        },
        {
            name: "key",
            description: Translation.tr("API keys. On its own it opens the key panel."),
            execute: args => {
                // Never `/key get` into the transcript: a chat is screenshot
                // and screen-shared, and a secret written into it stays there.
                if (args.length === 0 || args[0].trim().length === 0) {
                    controlBar.openKeyManager();
                } else if (args[0] == "get") {
                    Ai.printApiKey();
                } else {
                    Ai.setApiKey(args[0]);
                }
            }
        },
        {
            name: "save",
            description: Translation.tr("Name this chat. Chats are kept whether they are named or not."),
            execute: args => {
                const joinedArgs = args.join(" ");
                if (joinedArgs.trim().length == 0) {
                    Ai.addMessage(Translation.tr("Usage: %1save CHAT_NAME").arg(root.commandPrefix), Ai.interfaceRole);
                    return;
                }
                Ai.nameCurrentChat(joinedArgs);
            }
        },
        {
            name: "load",
            description: Translation.tr("Open a saved chat by name"),
            execute: args => {
                const joinedArgs = args.join(" ");
                if (joinedArgs.trim().length == 0) {
                    Ai.addMessage(Translation.tr("Usage: %1load CHAT_NAME").arg(root.commandPrefix), Ai.interfaceRole);
                    return;
                }
                Ai.openChatByName(joinedArgs);
            }
        },
        {
            name: "chats",
            description: Translation.tr("Show the list of saved chats"),
            execute: () => {
                controlBar.activePopover = "sessions";
            }
        },
        {
            name: "clear",
            description: Translation.tr("Put this chat away and start an empty one"),
            execute: () => {
                Ai.newChat();
            }
        },
        {
            name: "temp",
            description: Translation.tr("Set temperature (randomness) of the model. Values range between 0 to 2 for Gemini, 0 to 1 for other models. Default is 0.5."),
            execute: args => {
                // console.log(args)
                if (args.length == 0 || args[0] == "get") {
                    Ai.printTemperature();
                } else {
                    const temp = parseFloat(args[0]);
                    Ai.setTemperature(temp);
                }
            }
        },
        {
            name: "think",
            description: Translation.tr("How hard the model should think: off, low, medium or high. Models that cannot be told to stop reasoning use the smallest budget instead."),
            execute: args => {
                if (args.length == 0 || args[0] == "get") {
                    const model = Ai.currentModelEntry;
                    if (!model?.thinking) {
                        Ai.addMessage(Translation.tr("%1 does not think out loud.").arg(model?.name ?? Translation.tr("This model")), Ai.interfaceRole);
                        return;
                    }
                    Ai.addMessage(Translation.tr("Thinking: %1").arg(Ai.thinkingLevel), Ai.interfaceRole);
                    return;
                }
                if (Ai.setThinkingLevel(args[0]))
                    Ai.addMessage(Translation.tr("Thinking set to %1").arg(Ai.thinkingLevel), Ai.interfaceRole);
            }
        },
        {
            name: "test",
            description: Translation.tr("Markdown test"),
            execute: () => {
                Ai.addMessage(`
<think>
A longer think block to test revealing animation
OwO wem ipsum dowo sit amet, consekituwet awipiscing ewit, sed do eiuwsmod tempow inwididunt ut wabowe et dowo mawa. Ut enim ad minim weniam, quis nostwud exeucitation uwuwamcow bowowis nisi ut awiquip ex ea commowo consequat. Duuis aute iwuwe dowo in wepwependewit in wowuptate velit esse ciwwum dowo eu fugiat nuwa pawiatuw. Excepteuw sint occaecat cupidatat non pwowoident, sunt in cuwpa qui officia desewunt mowit anim id est wabowum. Meouw! >w<
Mowe uwu wem ipsum!
</think>
## ✏️ Markdown test
### Formatting

- *Italic*, \`Monospace\`, **Bold**, [Link](https://example.com)
- Arch lincox icon <img src="${Quickshell.shellPath("assets/icons/arch-symbolic.svg")}" height="${Appearance.font.pixelSize.small}"/>

### Table

Quickshell vs AGS/Astal

|                          | Quickshell       | AGS/Astal         |
|--------------------------|------------------|-------------------|
| UI Toolkit               | Qt               | Gtk3/Gtk4         |
| Language                 | QML              | Js/Ts/Lua         |
| Reactivity               | Implied          | Needs declaration |
| Widget placement         | Mildly difficult | More intuitive    |
| Bluetooth & Wifi support | ❌               | ✅                |
| No-delay keybinds        | ✅               | ❌                |
| Development              | New APIs         | New syntax        |

### Code block

Just a hello world...

\`\`\`cpp
#include <bits/stdc++.h>
// This is intentionally very long to test scrolling
const std::string GREETING = \"UwU\";
int main(int argc, char* argv[]) {
    std::cout << GREETING;
}
\`\`\`

### LaTeX


Inline w/ dollar signs: $\\frac{1}{2} = \\frac{2}{4}$

Inline w/ double dollar signs: $$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$

Inline w/ backslash and square brackets \\[\\int_0^\\infty \\frac{1}{x^2} dx = \\infty\\]

Inline w/ backslash and round brackets \\(e^{i\\pi} + 1 = 0\\)
`, Ai.interfaceRole);
            }
        },
    ]

    function handleInput(inputText) {
        const parsed = AiActionRegistry.parseInput(inputText, root.commandPrefix);
        if (parsed.kind === "command" || parsed.kind === "unknown-command") {
            // Handle special commands
            const commandObj = root.allCommands.find(cmd => cmd.name === `${parsed.id ?? parsed.name}` || cmd.name === `${parsed.name}`);
            if (commandObj) {
                commandObj.execute(parsed.args);
            } else {
                Ai.addMessage(Translation.tr("Unknown command: ") + parsed.name, Ai.interfaceRole);
            }
        } else {
            Ai.sendUserMessage(parsed.text);
        }

        // Sending is the one thing that always brings the view back down,
        // however far up the chat the reader had gone.
        messageListView.pinToEnd();
    }

    Connections {
        // The service says a key is missing; the panel that fixes it lives
        // here. Nothing in the service knows about this bar.
        target: Ai
        function onKeyManagerRequested() {
            controlBar.openKeyManager();
        }
        function onDraftRestored(text) {
            messageInputField.text = text;
            messageInputField.cursorPosition = messageInputField.text.length;
        }
    }

    /**
     * Opens something that will take the focus — a file dialog, the region
     * snip — without the sidebar closing behind it. The counter is lowered
     * again by whoever raised it, so two of these can overlap.
     */
    function holdSidebarOpen() {
        GlobalStates.policiesHoldOpen += 1;
    }

    function releaseSidebar() {
        GlobalStates.policiesHoldOpen = Math.max(0, GlobalStates.policiesHoldOpen - 1);
    }

    Connections {
        // The file dialog belongs to the service, so the sidebar watches it
        // rather than owning it: whichever panel asked, the one on screen is
        // the one that has to stay there until the dialog is answered.
        target: Ai
        function onPickingFilesChanged() {
            if (Ai.pickingFiles) {
                if (!root.filePickerHeld) {
                    root.filePickerHeld = true;
                    root.holdSidebarOpen();
                }
                return;
            }
            if (!root.filePickerHeld)
                return;
            root.filePickerHeld = false;
            root.releaseSidebar();
        }
    }

    property bool filePickerHeld: false

    Connections {
        // The snip is not a process this file can watch, so the hold ends when
        // the selector does, whether it took a shot or was waved away.
        target: GlobalStates
        function onRegionSelectorOpenChanged() {
            if (GlobalStates.regionSelectorOpen) {
                snipHoldTimeout.stop();
                return;
            }
            if (GlobalStates.regionSelectorOpen || !root.snipHeld)
                return;
            root.snipHeld = false;
            root.releaseSidebar();
        }
        function onSidebarLeftOpenChanged() {
            if (GlobalStates.sidebarLeftOpen || !root.snipHeld)
                return;
            root.snipHeld = false;
            root.releaseSidebar();
        }
    }

    property bool snipHeld: false
    Timer {
        id: snipHoldTimeout
        interval: 10000
        repeat: false
        onTriggered: {
            if (!root.snipHeld || GlobalStates.regionSelectorOpen)
                return;
            root.snipHeld = false;
            root.releaseSidebar();
        }
    }

    Process {
        id: decodeImageAndAttachProc
        property string imageDecodePath: Directories.cliphistDecode
        property string imageDecodeFileName: "image"
        property string imageDecodeFilePath: `${imageDecodePath}/${imageDecodeFileName}`
        function handleEntry(entry: string) {
            imageDecodeFileName = parseInt(entry.match(/^(\d+)\t/)[1]);
            decodeImageAndAttachProc.exec(["bash", "-c", `[ -f ${imageDecodeFilePath} ] || echo '${StringUtils.shellSingleQuoteEscape(entry)}' | ${Cliphist.cliphistBinary} decode > '${imageDecodeFilePath}'`]);
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Ai.attachFile(imageDecodeFilePath);
            } else {
                console.error("[AiChat] Failed to decode image in clipboard content");
            }
        }
    }

    /** A small round button on the composer's own row. */
    /** The round control at the head of either composer page. */
    component ComposerCircleButton: RippleButton {
        id: circleButton

        property string symbol: ""

        signal triggered

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: root.composerControlExtent
        implicitHeight: root.composerControlExtent
        buttonRadius: Appearance.rounding.full
        topPadding: 0
        bottomPadding: 0
        leftPadding: 0
        rightPadding: 0
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        onClicked: circleButton.triggered()

        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: circleButton.symbol
            fill: 1
            iconSize: 24
            color: Appearance.colors.colOnLayer2
        }
    }

    /** One way of attaching, as it appears on the composer's second page. */
    component ComposerActionPill: RippleButton {
        id: actionPill

        property string symbol: ""
        property string label: ""

        signal triggered

        implicitHeight: root.composerControlExtent
        implicitWidth: actionPillRow.implicitWidth + root.composerControlExtent * 0.55
        buttonRadius: Appearance.rounding.full
        topPadding: 0
        bottomPadding: 0
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        onClicked: actionPill.triggered()

        contentItem: RowLayout {
            id: actionPillRow
            spacing: Appearance.rounding.unsharpenmore

            MaterialSymbol {
                text: actionPill.symbol
                fill: 1
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer2
            }

            StyledText {
                Layout.fillWidth: true
                text: actionPill.label
                font.pixelSize: Appearance.font.pixelSize.small
                font.bold: true
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer2
            }
        }

        StyledToolTip {
            text: actionPill.label
        }
    }

    component ComposerButton: RippleButton {
        id: composerButton

        property string symbol: ""
        property string tooltipText: ""

        signal triggered

        implicitWidth: 34
        implicitHeight: 34
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        onClicked: composerButton.triggered()
        // Same reason as the control chips: leave the whole button to the
        // glyph, so its line box is centred instead of overflowing the
        // padded content rect downwards. Anchoring the content item fights
        // the geometry a Control assigns it, so it centres itself instead.
        topPadding: 0
        bottomPadding: 0
        leftPadding: 0
        rightPadding: 0

        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: composerButton.symbol
            fill: 1
            iconSize: 20
            color: Appearance.colors.colOnLayer2
        }

        StyledToolTip {
            text: composerButton.tooltipText
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.surfaceSpacing

        // ════════════════════════════════════════════════════════
        // 1. TOP TOOLS BAR RECTANGLE
        // ════════════════════════════════════════════════════════

        Rectangle {
            id: toolsBarSurface
            Layout.fillWidth: true
            Layout.preferredHeight: root.toolsBarHeight
            implicitHeight: root.toolsBarHeight
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.full
            clip: true

            ChatControlBar {
                id: controlBar
                anchors.fill: parent
                anchors.margins: root.toolControlPadding
                overlayParent: chatAreaSurface
                commandPrefix: root.commandPrefix
                inputField: messageInputField
                onNewChatRequested: Ai.newChat()
            }
        }

        // ════════════════════════════════════════════════════════
        // 2. MIDDLE CHAT AREA RECTANGLE
        // ════════════════════════════════════════════════════════

        Rectangle {
            id: chatAreaSurface
            Layout.fillWidth: true
            // Takes every pixel the other two surfaces leave behind, which is
            // what lets the composer grow upward into it.
            Layout.fillHeight: true
            Layout.minimumHeight: root.chatAreaMinimumHeight
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.large
            clip: true

            ColumnLayout {
                id: chatAreaColumn
                anchors.fill: parent
                anchors.margins: root.padding
                spacing: root.padding

                // Leaves to the left as a control's view arrives from the
                // right, so the middle rectangle reads as one surface changing
                // its content rather than something being covered up.
                opacity: root.canvasViewOpen ? 0 : 1
                visible: opacity > 0.001
                transform: Translate {
                    x: root.canvasViewOpen ? -controlBar.canvasSlideDistance : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                Item {
                    id: messagesArea
                    // Messages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: messagesArea.width
                            height: messagesArea.height
                            radius: Appearance.rounding.small
                        }
                    }

                    // Animation properties
                    opacity: 0.0
                    scale: 0.85
                    transform: Translate {
                        id: messagesAreaTransform
                        y: 25
                    }

                    Connections {
                        target: root
                        function onEntranceTriggerChanged() {
                            if (root.entranceTrigger >= 0) {
                                messagesArea.opacity = 0.0;
                                messagesArea.scale = 0.85;
                                messagesAreaTransform.y = 25;
                                Qt.callLater(function() {
                                    messagesAreaAnim.start();
                                });
                            }
                        }
                    }

                    SequentialAnimation {
                        id: messagesAreaAnim
                        PauseAnimation { duration: 100 }
                        ParallelAnimation {
                            NumberAnimation { target: messagesArea; property: "opacity"; from: 0.0; to: 1.0; duration: 300 }
                            NumberAnimation { target: messagesArea; property: "scale"; from: 0.85; to: 1.0; duration: 380; easing.type: Easing.OutBack }
                            NumberAnimation { target: messagesAreaTransform; property: "y"; from: 25; to: 0; duration: 380; easing.type: Easing.OutCubic }
                        }
                    }

                    ScrollEdgeFade {
                        // Both ends of the transcript blur into the surface
                        // instead of stopping at it, and neither end shows
                        // itself while everything already fits.
                        z: 1
                        target: messageListView
                        vertical: true
                        blurEdges: true
                        fadeSize: Math.round(Appearance.font.pixelSize.huge * 1.8)
                        color: Appearance.colors.colLayer1
                    }

                    StyledListView { // Message list
                        id: messageListView
                        z: 0
                        // Inset rather than filled: a bubble that touches the
                        // rounded edge of the surface it sits on reads as
                        // overflowing it.
                        anchors.fill: parent
                        anchors.leftMargin: root.messageListInset
                        anchors.rightMargin: root.messageListInset
                        spacing: root.messageGap
                        popin: false
                        animateAppearance: false
                        topMargin: root.messageListInset
                        bottomMargin: root.messageListInset
                        // A flick that carries on past the last message reads as a
                        // rendering fault, not as elasticity, on a list this tall.
                        boundsBehavior: Flickable.StopAtBounds

                        touchpadScrollFactor: Config.options.interactions.scrolling.touchpadScrollFactor * 1.4
                        mouseScrollFactor: Config.options.interactions.scrolling.mouseScrollFactor * 1.4

                        /** How far the bottom of the list is from the bottom of the view. */
                        readonly property real bottomGap: Math.max(0, messageListView.originY + messageListView.contentHeight - messageListView.height - messageListView.contentY)
                        /**
                         * Whether an answer arriving should drag the view along. Asking
                         * `atYEnd` at the moment the content grows always says no — it
                         * has already grown by then — so what is remembered instead is
                         * where the reader was standing before it did.
                         */
                        property bool following: true
                        /**
                         * Set while the view is moving because it was told to. Its own
                         * scrolling would otherwise read as the reader walking away —
                         * an answer streaming in would stop being followed on its
                         * first token, and offer a button back to where it already was.
                         */
                        property bool pinning: false

                        /**
                         * The very end, margins included. `positionViewAtEnd`
                         * stops at the last row and leaves the bottom margin
                         * below it, which is not the end as far as `atYEnd` is
                         * concerned — so the edge fade stayed on and blurred
                         * the newest message forever.
                         */
                        readonly property real maximumContentY: Math.max(messageListView.originY - messageListView.topMargin,
                            messageListView.originY + messageListView.contentHeight - messageListView.height + messageListView.bottomMargin)

                        function pinToEnd() {
                            messageListView.following = true;
                            messageListView.pinning = true;
                            messageListView.contentY = messageListView.maximumContentY;
                            messageListView.previousContentY = messageListView.contentY;
                            pinReleaseTimer.restart();
                        }

                        Timer {
                            id: pinReleaseTimer
                            interval: Appearance.animation.scroll.duration + 80
                            onTriggered: messageListView.pinning = false
                        }

                        /**
                         * How close to the end still counts as standing at it. Only
                         * used to take the view *back* into following: moving up at
                         * all leaves it, however small the movement, because a band
                         * where an upward scroll is undone reads as the chat fighting
                         * back.
                         */
                        readonly property real followThreshold: Appearance.rounding.large

                        /** Where the view stood before this change, to read direction from. */
                        property real previousContentY: 0

                        // A gesture always has the final say, even mid-answer: it is
                        // the one thing here that is unambiguously the reader's doing.
                        onUserScrolled: (targetY, maxY) => {
                            messageListView.pinning = false;
                            if (targetY < messageListView.previousContentY - 0.5) {
                                messageListView.following = false;
                                return;
                            }
                            messageListView.following = (maxY - targetY) <= messageListView.followThreshold;
                        }
                        onDraggingChanged: {
                            if (messageListView.dragging)
                                messageListView.pinning = false;
                        }
                        onMovementEnded: messageListView.following = messageListView.bottomGap <= messageListView.followThreshold
                        onContentYChanged: {
                            const previous = messageListView.previousContentY;
                            messageListView.previousContentY = messageListView.contentY;
                            if (messageListView.pinning)
                                return;
                            // Upwards is unambiguous: the reader is walking back
                            // through the chat and nothing may pull them down again
                            // until they come back to the end themselves.
                            if (messageListView.contentY < previous - 0.5) {
                                messageListView.following = false;
                                return;
                            }
                            messageListView.following = messageListView.bottomGap <= messageListView.followThreshold;
                        }
                        onContentHeightChanged: {
                            if (!messageListView.following)
                                return;
                            Qt.callLater(function () {
                                messageListView.pinToEnd();
                            });
                        }
                        // An answer arriving does not drag a reader who has
                        // walked back up the chat. Sending does — see
                        // `handleInput`, which pins deliberately.
                        onCountChanged: {
                            if (!messageListView.following)
                                return;
                            Qt.callLater(function () {
                                messageListView.pinToEnd();
                            });
                        }
                        // A chat that arrived while this list had no height —
                        // reopened from disk, or filled before the sidebar was
                        // ever shown — opens where it was left off, at the end.
                        onHeightChanged: {
                            if (messageListView.following)
                                Qt.callLater(function () {
                                    messageListView.pinToEnd();
                                });
                        }

                        add: null // Prevent function calls from being janky

                        model: ScriptModel {
                            values: Ai.messageIDs.filter(id => {
                                const message = Ai.messageByID[id];
                                return message?.visibleToUser ?? true;
                            })
                        }
                        delegate: AiMessage {
                            required property var modelData
                            // The id, not the row: this list hides messages the model
                            // sends itself, so a row number points at the wrong one.
                            messageId: modelData
                            messageData: {
                                Ai.messageByID[modelData];
                            }
                            onRegenerateRequested: id => controlBar.openRegenerate(id)
                            onModelPickerRequested: controlBar.togglePopover("model")
                        }
                    }

                    PagePlaceholder {
                        id: emptyStatePlaceholder
                        z: 2
                        shown: Ai.messageIDs.length === 0
                        icon: Ai.currentPersona?.icon ?? "neurology"
                        title: Ai.currentPersona?.name ?? Translation.tr("Large language models")
                        description: Ai.currentPersona?.description ?? Translation.tr("Ask anything")
                        shape: MaterialShape.Shape.PixelCircle
                        animateIconOnShow: true
                        entranceTrigger: root.entranceTrigger
                    }

                    ScrollToBottomButton {
                        z: 3
                        target: messageListView
                        // Not `atYEnd`: an answer streaming in moves the view itself,
                        // and this would offer a way back to where the reader already
                        // was on every token.
                        shown: !messageListView.following
                        downAction: () => messageListView.pinToEnd()
                    }
                }
                DescriptionBox {
                    id: descriptionBox
                    text: root.suggestionList[suggestions.selectedIndex]?.description ?? ""
                    showArrows: root.suggestionList.length > 1

                    opacity: 0.0
                    scale: 0.85
                    transform: Translate {
                        id: descriptionBoxTransform
                        y: 25
                    }

                    Connections {
                        target: root
                        function onEntranceTriggerChanged() {
                            if (root.entranceTrigger >= 0) {
                                descriptionBox.opacity = 0.0;
                                descriptionBox.scale = 0.85;
                                descriptionBoxTransform.y = 25;
                                Qt.callLater(function() {
                                    descriptionBoxAnim.start();
                                });
                            }
                        }
                    }

                    SequentialAnimation {
                        id: descriptionBoxAnim
                        PauseAnimation { duration: 160 }
                        ParallelAnimation {
                            NumberAnimation { target: descriptionBox; property: "opacity"; from: 0.0; to: 1.0; duration: 300 }
                            NumberAnimation { target: descriptionBox; property: "scale"; from: 0.85; to: 1.0; duration: 380; easing.type: Easing.OutBack }
                            NumberAnimation { target: descriptionBoxTransform; property: "y"; from: 25; to: 0; duration: 380; easing.type: Easing.OutCubic }
                        }
                    }
                }
                FlowButtonGroup { // Suggestions
                    id: suggestions
                    visible: root.suggestionList.length > 0 && messageInputField.text.length > 0
                    property int selectedIndex: 0
                    Layout.fillWidth: true
                    spacing: 5

                    opacity: visible ? 1.0 : 0.0
                    scale: visible ? 1.0 : 0.85
                    transform: Translate {
                        id: suggestionsTransform
                        y: visible ? 0 : 25
                    }

                    Connections {
                        target: root
                        function onEntranceTriggerChanged() {
                            if (root.entranceTrigger >= 0 && suggestions.visible) {
                                suggestions.opacity = 0.0;
                                suggestions.scale = 0.85;
                                suggestionsTransform.y = 25;
                                Qt.callLater(function() {
                                    suggestionsAnim.start();
                                });
                            }
                        }
                    }

                    SequentialAnimation {
                        id: suggestionsAnim
                        PauseAnimation { duration: 280 }
                        ParallelAnimation {
                            NumberAnimation { target: suggestions; property: "opacity"; from: 0.0; to: 1.0; duration: 300 }
                            NumberAnimation { target: suggestions; property: "scale"; from: 0.85; to: 1.0; duration: 380; easing.type: Easing.OutBack }
                            NumberAnimation { target: suggestionsTransform; property: "y"; from: 25; to: 0; duration: 380; easing.type: Easing.OutCubic }
                        }
                    }

                    Repeater {
                        id: suggestionRepeater
                        model: {
                            suggestions.selectedIndex = 0;
                            return root.suggestionList.slice(0, 10);
                        }
                        delegate: ApiCommandButton {
                            id: commandButton
                            required property int index
                            required property var modelData
                            colBackground: suggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                            bounce: false
                    
                            opacity: 0.0
                            transform: Translate {
                                id: cmdBtnTranslate
                                y: 10
                            }

                            Component.onCompleted: {
                                btnEntranceAnim.start();
                            }

                            SequentialAnimation {
                                id: btnEntranceAnim
                                PauseAnimation { duration: index * 40 }
                                ParallelAnimation {
                                    NumberAnimation { target: commandButton; property: "opacity"; from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: cmdBtnTranslate; property: "y"; from: 10; to: 0; duration: 280; easing.type: Easing.OutBack }
                                }
                            }

                            contentItem: StyledText {
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.m3colors.m3onSurface
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.displayName ?? modelData.name
                            }

                            onHoveredChanged: {
                                if (commandButton.hovered) {
                                    suggestions.selectedIndex = index;
                                }
                            }
                            onClicked: {
                                suggestions.acceptSuggestion(modelData.name);
                            }
                        }
                    }

                    function acceptSuggestion(word) {
                        const words = messageInputField.text.trim().split(/\s+/);
                        if (words.length > 0) {
                            words[words.length - 1] = word;
                        } else {
                            words.push(word);
                        }
                        const updatedText = words.join(" ") + " ";
                        messageInputField.text = updatedText;
                        messageInputField.cursorPosition = messageInputField.text.length;
                        messageInputField.forceActiveFocus();
                    }

                    function acceptSelectedWord() {
                        if (suggestions.selectedIndex >= 0 && suggestions.selectedIndex < suggestionRepeater.count) {
                            const word = root.suggestionList[suggestions.selectedIndex].name;
                            suggestions.acceptSuggestion(word);
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════
        // 3. BOTTOM COMPOSER RECTANGLE
        // ════════════════════════════════════════════════════════

        Rectangle {
            id: composerSurface
            Layout.fillWidth: true
            // Deliberately never fillHeight: the composer owns exactly the
            // height its content needs, and the chat area above absorbs the
            // difference, so attachments and extra input lines push this
            // surface upward instead of squashing its own contents.
            implicitHeight: composerColumn.implicitHeight + root.padding * 2
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.large
            clip: true

            ColumnLayout {
                id: composerColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: root.padding
                }
                spacing: root.padding

                Rectangle { // Input area
                    id: inputWrapper
                    property real spacing: 5
                    Layout.fillWidth: true
                    radius: 0
                    color: "transparent"
                    // The room above the row belongs to the attachment tray, so with
                    // nothing attached it is given back: an empty tray still charging
                    // for its spacing left the whole composer sitting low in its own
                    // box, which reads as the buttons being off-centre.
                    // The tray and the column are the whole composer now, so
                    // its height is simply theirs; an empty tray charges nothing.
                    implicitHeight: composerColumnLayout.implicitHeight + root.composerInset * 2
                        + (attachmentTray.implicitHeight > 0
                            ? attachmentTray.implicitHeight + root.composerGap + attachmentTray.anchors.topMargin
                            : 0)
                    clip: true

                    FastBlur {
                        id: inputBlur
                        radius: 0
                    }

                    layer.enabled: inputBlur.radius > 0
                    layer.effect: Component {
                        FastBlur {
                            radius: inputBlur.radius
                        }
                    }

                    opacity: 0.0
                    transform: Translate {
                        id: inputWrapperTransform
                        y: 40
                    }

                    Connections {
                        target: root
                        function onEntranceTriggerChanged() {
                            if (root.entranceTrigger >= 0) {
                                inputWrapper.opacity = 0.0;
                                inputBlur.radius = 20;
                                inputWrapperTransform.y = 40;
                                Qt.callLater(function() {
                                    inputWrapperAnim.start();
                                });
                            }
                        }
                    }

                    SequentialAnimation {
                        id: inputWrapperAnim
                        PauseAnimation { duration: 320 }
                        ParallelAnimation {
                            NumberAnimation { target: inputWrapper; property: "opacity"; from: 0.0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
                            NumberAnimation { target: inputBlur; property: "radius"; from: 20; to: 0; duration: 350; easing.type: Easing.OutCubic }
                            NumberAnimation { target: inputWrapperTransform; property: "y"; from: 40; to: 0; duration: 450; easing.type: Easing.OutExpo }
                        }
                    }

                    Behavior on implicitHeight {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }

                    AiAttachmentTray {
                        id: attachmentTray
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: visible ? 5 : 0
                        }
                        // A drop that will be turned away says so while it is still a
                        // drag, rather than looking like it never registered.
                        dragHint: {
                            if (!root.containsDrag)
                                return "";
                            if (Ai.currentModelTakesFiles)
                                return Translation.tr("Drop to attach");
                            return Translation.tr("%1 cannot read files — text ones will still be pasted in").arg(Ai.currentModelEntry?.title ?? Translation.tr("This model"));
                        }
                    }

                    DropArea {
                        id: dropArea
                        anchors.fill: parent

                        onContainsDragChanged: root.containsDrag = dropArea.containsDrag

                        onDropped: drop => {
                            if (!drop.hasUrls)
                                return;
                            // Gating happens per file, in the service: a text file is
                            // readable by every model, whatever it can otherwise take.
                            for (let i = 0; i < drop.urls.length; i++)
                                Ai.attachFile(drop.urls[i]);
                            drop.accept(Qt.CopyAction);
                        }
                    }

                    ColumnLayout {
                        id: composerColumnLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            margins: root.composerInset
                        }
                        spacing: root.composerGap

                        // ── the message, always on its own line above the controls ──
                        ScrollView {
                            Layout.fillWidth: true
                            // Grows with the message and then scrolls, so a long
                            // draft pushes the composer up instead of running past it.
                            Layout.preferredHeight: Math.min(root.height * 0.4, messageInputField.implicitHeight)
                            id: inputScrollView
                            clip: true
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            StyledTextArea { // The actual TextArea (inside ScrollView to enable scrolling)
                                id: messageInputField
                                anchors.fill: parent
                                wrapMode: TextArea.Wrap
                                padding: 10
                                color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                                placeholderText: Translation.tr('Message the model... "%1" for commands').arg(root.commandPrefix)

                                background: null

                                onTextChanged: {
                                    // Kept per chat, so switching away and back does
                                    // not throw away a half-written message.
                                    Ai.draft = messageInputField.text;

                                    // Handle suggestions
                                    if (messageInputField.text.length === 0) {
                                        root.suggestionQuery = "";
                                        root.suggestionList = [];
                                        return;
                                    } else if (messageInputField.text.startsWith(`${root.commandPrefix}provider`)) {
                                        root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                
                                        const providers = Ai.providerIds

                                        const providerResults = Fuzzy.go(root.suggestionQuery, providers.map(p => ({
                                            name: Fuzzy.prepare(p),
                                            obj: p
                                        })), {
                                            all: true,
                                            key: "name"
                                        });
                                
                                        root.suggestionList = providerResults.map(result => {
                                            const providerName = result.target;
                                            const providerInfo = Ai.providers[providerName];
                                            return {
                                                name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "provider ") : ""}${providerName}`,
                                                displayName: providerInfo?.name ?? providerName,
                                                description: providerInfo?.description ?? ""
                                            };
                                        });
                                    } else if (messageInputField.text.startsWith(`${root.commandPrefix}model`)) {
                                        root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                            
                                        const providerModels = Ai.modelsOfProviders[Ai.currentProvider] ?? [];
                            
                                        const modelList = providerModels.map(model => ({
                                            name: Fuzzy.prepare(model.value),
                                            obj: model
                                        }));

                                        const modelResults = Fuzzy.go(root.suggestionQuery, modelList, {
                                            all: true,
                                            key: "name"
                                        });
                            
                                        root.suggestionList = modelResults.map(result => {
                                            const modelValue = result.target;
                                            const model = providerModels.find(m => m.value === modelValue);
                                    
                                            return {
                                                name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "model ") : ""}${model.value}`,
                                                displayName: model.title,
                                                description: `Provider: ${model.modelProvider || Ai.currentProvider}`
                                            };
                                        });
                                    } else if (messageInputField.text.startsWith(`${root.commandPrefix}prompt`)) {
                                        root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                        const promptFileResults = Fuzzy.go(root.suggestionQuery, Ai.promptFiles.map(file => {
                                            return {
                                                name: Fuzzy.prepare(file),
                                                obj: file
                                            };
                                        }), {
                                            all: true,
                                            key: "name"
                                        });
                                        root.suggestionList = promptFileResults.map(file => {
                                            return {
                                                name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "prompt ") : ""}${file.target}`,
                                                displayName: `${FileUtils.trimFileExt(FileUtils.fileNameForPath(file.target))}`,
                                                description: Translation.tr("Load prompt from %1").arg(file.target)
                                            };
                                        });
                                    } else if (messageInputField.text.startsWith(`${root.commandPrefix}load`)) {
                                        root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                        const chatResults = Fuzzy.go(root.suggestionQuery, Ai.sessions.index.map(entry => {
                                            return {
                                                name: Fuzzy.prepare(entry.title),
                                                obj: entry
                                            };
                                        }), {
                                            all: true,
                                            key: "name"
                                        });
                                        root.suggestionList = chatResults.map(result => {
                                            const chatName = result.obj.title;
                                            return {
                                                name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "load ") : ""}${chatName}`,
                                                displayName: `${chatName}`,
                                                description: result.obj.preview
                                            };
                                        });
                                    } else if (messageInputField.text.startsWith(`${root.commandPrefix}tool`)) {
                                        root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                        const toolResults = Fuzzy.go(root.suggestionQuery, Ai.availableTools.map(tool => {
                                            return {
                                                name: Fuzzy.prepare(tool),
                                                obj: tool
                                            };
                                        }), {
                                            all: true,
                                            key: "name"
                                        });
                                        root.suggestionList = toolResults.map(tool => {
                                            const toolName = tool.target;
                                            return {
                                                name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "tool ") : ""}${tool.target}`,
                                                displayName: toolName,
                                                description: Ai.toolDescriptions[toolName]
                                            };
                                        });
                                    } else if (messageInputField.text.startsWith(root.commandPrefix)) {
                                        root.suggestionQuery = messageInputField.text;
                                        root.suggestionList = root.allCommands.filter(cmd => cmd.name.startsWith(messageInputField.text.substring(1))).map(cmd => {
                                            return {
                                                name: `${root.commandPrefix}${cmd.name}`,
                                                description: `${cmd.description}`
                                            };
                                        });
                                    }
                                }

                                function accept() {
                                    root.handleInput(text);
                                    text = "";
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Tab) {
                                        suggestions.acceptSelectedWord();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Up && suggestions.visible) {
                                        suggestions.selectedIndex = Math.max(0, suggestions.selectedIndex - 1);
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Down && suggestions.visible) {
                                        suggestions.selectedIndex = Math.min(root.suggestionList.length - 1, suggestions.selectedIndex + 1);
                                        event.accepted = true;
                                    } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                                        if (event.modifiers & Qt.ShiftModifier) {
                                            // Insert newline
                                            messageInputField.insert(messageInputField.cursorPosition, "\n");
                                            event.accepted = true;
                                        } else {
                                            // Accept text
                                            const inputText = messageInputField.text;
                                            messageInputField.clear();
                                            root.handleInput(inputText);
                                            event.accepted = true;
                                        }
                                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                                        // Intercept Ctrl+V to handle image/file pasting
                                        if (event.modifiers & Qt.ShiftModifier) {
                                            // Let Shift+Ctrl+V = plain paste
                                            messageInputField.text += Quickshell.clipboardText;
                                            event.accepted = true;
                                            return;
                                        }
                                        // Try image paste first
                                        const currentClipboardEntry = Cliphist.entries[0];
                                        const cleanCliphistEntry = StringUtils.cleanCliphistEntry(currentClipboardEntry);
                                        if (/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(currentClipboardEntry)) {
                                            // First entry = currently copied entry = image?
                                            decodeImageAndAttachProc.handleEntry(currentClipboardEntry);
                                            event.accepted = true;
                                            return;
                                        } else if (cleanCliphistEntry.startsWith("file://")) {
                                            // First entry = currently copied entry = image?
                                            const fileName = decodeURIComponent(cleanCliphistEntry);
                                            Ai.attachFile(fileName);
                                            event.accepted = true;
                                            return;
                                        }
                                        event.accepted = false; // No image, let text pasting proceed
                                    } else if (event.key === Qt.Key_Escape) {
                                        // Esc takes the attachments back off, one row
                                        // at a time, before it closes anything.
                                        if (Ai.attachments.length > 0) {
                                            Ai.clearAttachments();
                                            event.accepted = true;
                                        } else {
                                            event.accepted = false;
                                        }
                                    }
                                }
                            }
                        }

                        // ── the controls ──
                        // ── the controls ──
                        //
                        // Two pages that slide, the way the Bluetooth dialog
                        // shows a device and then what can be done with it.
                        // The ways of attaching take the place of the model and
                        // the send button instead of shoving them sideways.
                        Flickable {
                            id: composerControlsRow
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.composerControlExtent
                            contentWidth: composerControlsRow.width * 2 + root.composerGap
                            contentHeight: composerControlsRow.height
                            interactive: false
                            clip: true

                            contentX: root.attachmentsExpanded
                                ? (composerControlsRow.width + root.composerGap)
                                : 0

                            Behavior on contentX {
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutExpo
                                }
                            }

                            Row {
                                height: composerControlsRow.height
                                spacing: root.composerGap

                                // PAGE 1 — write and send
                                RowLayout {
                                    width: composerControlsRow.width
                                    height: composerControlsRow.height
                                    spacing: root.composerGap

                                    ComposerCircleButton {
                                        symbol: "add"
                                        onTriggered: root.attachmentsExpanded = true

                                        StyledToolTip {
                                            extraVisibleCondition: false
                                            alternativeVisibleCondition: parent.hovered
                                            text: Translation.tr("Attach something")
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                    }

                                    // Which model is answering, and a way to
                                    // change it without leaving the composer.
                                    RippleButton {
                                        id: composerModelPill
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.maximumWidth: composerControlsRow.width * 0.62
                                        implicitHeight: root.composerControlExtent
                                        // Measured off the label rather than off the row
                                        // it sits in: a filling child inside a Control's
                                        // content item feeds the Control's own width back
                                        // into itself, and Layouts abort the pass.
                                        implicitWidth: Math.min(composerModelPill.Layout.maximumWidth,
                                            composerModelLabel.implicitWidth + composerModelIcon.implicitWidth
                                            + composerModelRow.spacing + root.composerControlExtent * 0.6)
                                        buttonRadius: Appearance.rounding.full
                                        topPadding: 0
                                        bottomPadding: 0
                                        colBackground: Appearance.colors.colPrimary
                                        colBackgroundHover: Appearance.colors.colPrimaryHover
                                        colRipple: Appearance.colors.colPrimaryActive
                                        onClicked: controlBar.togglePopover("model")

                                        contentItem: RowLayout {
                                            id: composerModelRow
                                            spacing: Appearance.rounding.unsharpenmore

                                            MaterialSymbol {
                                                id: composerModelIcon
                                                text: Ai.currentModelEntry?.materialIcon || "auto_awesome"
                                                fill: 1
                                                iconSize: Appearance.font.pixelSize.larger
                                                color: Appearance.colors.colOnPrimary
                                            }

                                            StyledText {
                                                id: composerModelLabel
                                                Layout.maximumWidth: Math.max(0, composerModelPill.Layout.maximumWidth
                                                    - composerModelIcon.implicitWidth - composerModelRow.spacing
                                                    - root.composerControlExtent * 0.6)
                                                text: Ai.currentModelEntry?.title ?? Translation.tr("No model")
                                                font.pixelSize: Appearance.font.pixelSize.normal
                                                font.bold: true
                                                elide: Text.ElideRight
                                                color: Appearance.colors.colOnPrimary
                                            }

                                        }

                                        StyledToolTip {
                                            // The reasoning level lives here
                                            // rather than in the pill: the name
                                            // is what has to be readable at a
                                            // glance, and the level is a detail
                                            // worth a hover.
                                            text: {
                                                const name = Ai.currentModelEntry?.name ?? Translation.tr("none");
                                                if (!Ai.currentModelThinks || root.thinkingShortLabel.length === 0)
                                                    return Translation.tr("Model: %1").arg(name);
                                                return Translation.tr("Model: %1\nThinking: %2").arg(name).arg(root.thinkingShortLabel);
                                            }
                                        }
                                    }

                                    RippleButton { // Send button, or Stop while a reply is coming in
                                        id: sendButton
                                        readonly property bool stopping: Ai.isGenerating

                                        implicitWidth: root.composerControlExtent
                                        implicitHeight: root.composerControlExtent
                                        buttonRadius: Appearance.rounding.full
                                        enabled: sendButton.stopping || messageInputField.text.length > 0
                                        toggled: enabled
                                        topPadding: 0
                                        bottomPadding: 0
                                        leftPadding: 0
                                        rightPadding: 0

                                        Behavior on enabled {
                                            SequentialAnimation {
                                                PauseAnimation { duration: 50 }
                                                NumberAnimation {
                                                    target: sendButton
                                                    property: "opacity"
                                                    to: sendButton.enabled ? 1.0 : 0.5
                                                    duration: 200
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                if (sendButton.stopping) {
                                                    Ai.stopGeneration();
                                                    return;
                                                }
                                                const inputText = messageInputField.text;
                                                root.handleInput(inputText);
                                                messageInputField.clear();
                                            }
                                        }

                                        contentItem: MaterialSymbol {
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            iconSize: 22
                                            color: sendButton.enabled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2Disabled
                                            text: sendButton.stopping ? "stop" : "arrow_upward"
                                            fill: 1
                                        }

                                        StyledToolTip {
                                            text: AiActionRegistry.tooltip(sendButton.stopping ? "stop" : "send", {
                                                surface: "sidebar",
                                                busy: sendButton.stopping,
                                                text: messageInputField.text
                                            })
                                        }
                                    }
                                }

                                // PAGE 2 — what can be attached
                                RowLayout {
                                    width: composerControlsRow.width
                                    height: composerControlsRow.height
                                    spacing: root.composerGap

                                    ComposerCircleButton {
                                        symbol: "arrow_forward"
                                        onTriggered: root.attachmentsExpanded = false

                                        StyledToolTip {
                                            extraVisibleCondition: false
                                            alternativeVisibleCondition: parent.hovered
                                            text: Translation.tr("Back")
                                        }
                                    }

                                    // The options scroll on their own: the
                                    // composer is as wide as the sidebar and
                                    // this list is not, and it only grows as
                                    // more ways of attaching are added.
                                    Flickable {
                                        id: composerActionsFlick
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        contentWidth: composerActionsRow.implicitWidth
                                        contentHeight: composerActionsFlick.height
                                        flickableDirection: Flickable.HorizontalFlick
                                        boundsBehavior: Flickable.StopAtBounds
                                        interactive: composerActionsFlick.contentWidth > composerActionsFlick.width
                                        clip: true

                                        MouseArea {
                                            // Most mice only send a vertical
                                            // wheel, so it is turned sideways
                                            // here — and left alone when
                                            // everything already fits.
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            enabled: composerActionsFlick.interactive
                                            onWheel: wheel => {
                                                const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                                                const limit = composerActionsFlick.contentWidth - composerActionsFlick.width;
                                                composerActionsFlick.contentX = Math.max(0, Math.min(limit, composerActionsFlick.contentX - delta));
                                                wheel.accepted = true;
                                            }
                                        }

                                        Row {
                                            id: composerActionsRow
                                            height: composerActionsFlick.height
                                            spacing: root.composerGap

                                            ComposerActionPill {
                                                symbol: "attach_file"
                                                label: Translation.tr("Attach files")
                                                onTriggered: {
                                                    Ai.pickFiles();
                                                    root.attachmentsExpanded = false;
                                                }
                                            }

                                            ComposerActionPill {
                                                symbol: "screenshot_region"
                                                label: Translation.tr("Send part of the screen")
                                                onTriggered: {
                                                    if (!root.snipHeld) {
                                                        root.snipHeld = true;
                                                        root.holdSidebarOpen();
                                                        snipHoldTimeout.restart();
                                                    }
                                                    GlobalStates.snipForAiRequested();
                                                    root.attachmentsExpanded = false;
                                                }
                                            }
                                        }
                                    }

                                    ScrollEdgeFade {
                                        // Says there is more to the right, and
                                        // fades out once the end is reached.
                                        parent: composerActionsFlick
                                        target: composerActionsFlick
                                        vertical: false
                                        color: Appearance.colors.colLayer1
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
