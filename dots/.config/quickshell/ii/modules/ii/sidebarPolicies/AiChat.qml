import qs
import qs.services
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

    /** Whether the list of saved chats is on screen, in either of its hosts. */
    property bool sessionsOpen: false
    readonly property bool wideEnoughForPane: root.width >= 640
    /**
     * Between the chat pane and the conversation. Wider than the padding used
     * everywhere else on purpose: the pane's other three sides also carry the
     * sidebar's own inset, and a gap of one padding here read as a seam.
     */
    readonly property real sessionPaneGap: 20

    property int entranceTrigger: -1

    function triggerContentEntrance() {
        root.entranceTrigger++;
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
        if (event.key === Qt.Key_Escape && root.sessionsOpen) {
            root.sessionsOpen = false;
            event.accepted = true;
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O) {
            Ai.newChat();
        }
    }

    property var allCommands: [
        {
            name: "attach",
            description: Translation.tr("Attach a file to the next message. Also: the paperclip, drag and drop, or Ctrl+V."),
            execute: args => {
                const path = args.join(" ").trim();
                if (path.length === 0) {
                    filePickerProc.running = true;
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
                root.sessionsOpen = true;
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
        if (inputText.startsWith(root.commandPrefix)) {
            // Handle special commands
            const command = inputText.split(" ")[0].substring(1);
            const args = inputText.split(" ").slice(1);
            const commandObj = root.allCommands.find(cmd => cmd.name === `${command}`);
            if (commandObj) {
                commandObj.execute(args);
            } else {
                Ai.addMessage(Translation.tr("Unknown command: ") + command, Ai.interfaceRole);
            }
        } else {
            Ai.sendUserMessage(inputText);
        }

        // Always scroll to bottom when user sends a message
        messageListView.positionViewAtEnd();
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
        // The snip is not a process this file can watch, so the hold ends when
        // the selector does, whether it took a shot or was waved away.
        target: GlobalStates
        function onRegionSelectorOpenChanged() {
            if (GlobalStates.regionSelectorOpen || !root.snipHeld)
                return;
            root.snipHeld = false;
            root.releaseSidebar();
        }
    }

    property bool snipHeld: false

    Process {
        // The paperclip. Several files at once, because a message can carry
        // several.
        id: filePickerProc
        running: false
        onRunningChanged: {
            if (filePickerProc.running)
                root.holdSidebarOpen();
            else
                root.releaseSidebar();
        }
        command: ["bash", "-c", "if command -v kdialog >/dev/null; then " + "  FILES=$(kdialog --getopenfilename \"$HOME\" \"\" --multiple 2>/dev/null); " + "  if [ -n \"$FILES\" ]; then echo -n \"$FILES\" | tr '\\n' '|'; fi; " + "elif command -v zenity >/dev/null; then " + "  zenity --file-selection --multiple --separator=\"|\" 2>/dev/null; " + "fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const picked = this.text.trim();
                if (picked.length === 0)
                    return;
                picked.split("|").map(path => path.trim()).filter(path => path.length > 0).forEach(path => Ai.attachFile(path));
            }
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
            iconSize: 20
            color: Appearance.colors.colOnLayer2
        }

        StyledToolTip {
            text: composerButton.tooltipText
        }
    }

    component StatusItem: MouseArea {
        id: statusItem
        property string icon
        property string statusText
        property string description
        property int animIndex: 0
        property var rootRef: null
        property color tint: Appearance.colors.colSubtext
        /** Set when clicking it does something, so the cursor says so. */
        property bool actionable: false

        signal activated

        hoverEnabled: true
        cursorShape: statusItem.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: statusItem.activated()
        implicitHeight: statusItemRowLayout.implicitHeight
        implicitWidth: statusItemRowLayout.implicitWidth

        opacity: 0.0
        transform: [
            Translate {
                id: statusItemTransform
                x: 0
                y: 0
            },
            Rotation {
                id: statusItemRotation
                origin.x: statusItem.width / 2
                origin.y: statusItem.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: 0
            }
        ]

        Connections {
            target: statusItem.rootRef
            function onEntranceTriggerChanged() {
                if (statusItem.rootRef && statusItem.rootRef.entranceTrigger >= 0) {
                    statusItem.opacity = 0.0;
                    statusItem.scale = statusItem.animIndex === 2 ? 0.2 : 1.0;
                    statusItemTransform.x = statusItem.animIndex === 1 ? -20 : 0;
                    statusItemTransform.y = statusItem.animIndex === 0 ? 15 : 0;
                    statusItemRotation.angle = statusItem.animIndex === 0 ? 90 : 0;
                    Qt.callLater(function() {
                        statusItemAnim.start();
                    });
                }
            }
        }

        SequentialAnimation {
            id: statusItemAnim
            PauseAnimation { duration: 140 + statusItem.animIndex * 80 }
            ParallelAnimation {
                NumberAnimation { target: statusItem; property: "opacity"; from: 0.0; to: 1.0; duration: 280 }
                NumberAnimation { target: statusItem; property: "scale"; to: 1.0; duration: 350; easing.type: Easing.OutBack }
                NumberAnimation { target: statusItemTransform; property: "x"; to: 0; duration: 350; easing.type: Easing.OutBack }
                NumberAnimation { target: statusItemTransform; property: "y"; to: 0; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: statusItemRotation; property: "angle"; to: 0; duration: 350; easing.type: Easing.OutBack }
            }
        }

        RowLayout {
            id: statusItemRowLayout
            spacing: 0
            MaterialSymbol {
                text: statusItem.icon
                iconSize: Appearance.font.pixelSize.huge
                color: statusItem.tint
            }
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                text: statusItem.statusText
                color: statusItem.tint
                animateChange: true
            }
        }

        StyledToolTip {
            text: statusItem.description
            extraVisibleCondition: false
            alternativeVisibleCondition: statusItem.containsMouse
        }
    }

    component StatusSeparator: Rectangle {
        implicitWidth: 4
        implicitHeight: 4
        radius: implicitWidth / 2
        color: Appearance.colors.colOutlineVariant
    }

    Loader {
        // The chat list as a pane, once there is room for it beside the
        // conversation. Below that width the drawer at the bottom of this file
        // shows the same list over it instead.
        id: sessionPaneLoader
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: root.padding
        }
        width: 260
        active: root.sessionsOpen && root.wideEnoughForPane
        visible: active

        // The list draws no ground of its own — it is the drawer's content
        // too — so the pane gives it the same surface the drawer does. Without
        // one the rows sat directly on the transcript and read as part of it.
        sourceComponent: Rectangle {
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerHigh

            SessionList {
                anchors.fill: parent
                anchors.margins: 10
                onCloseRequested: root.sessionsOpen = false
            }
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
            leftMargin: root.padding + (sessionPaneLoader.active ? sessionPaneLoader.width + root.sessionPaneGap : 0)
        }
        spacing: root.padding

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

            StyledRectangularShadow {
                z: 1
                target: statusBg
                opacity: messageListView.atYBeginning ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
            Rectangle {
                id: statusBg
                z: 2
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: 4
                }
                implicitWidth: statusRowLayout.implicitWidth + 10 * 2
                implicitHeight: Math.max(statusRowLayout.implicitHeight, 38)
                radius: Appearance.rounding.normal - root.padding
                color: messageListView.atYBeginning ? Appearance.colors.colLayer2 : Appearance.colors.colLayer2Base
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                RowLayout {
                    id: statusRowLayout
                    anchors.centerIn: parent
                    spacing: 10

                    StatusItem {
                        rootRef: root
                        animIndex: 0
                        icon: Ai.currentModelHasApiKey ? "key" : "key_off"
                        statusText: ""
                        actionable: true
                        tint: Ai.currentModelHasApiKey ? Appearance.colors.colSubtext : Appearance.m3colors.m3error
                        description: Ai.currentModelHasApiKey ? Translation.tr("API key is set\nClick to open the key panel") : Translation.tr("No API key\nClick to add one")
                        onActivated: controlBar.openKeyManager()
                    }
                    StatusSeparator {}
                    StatusItem {
                        rootRef: root
                        animIndex: 1
                        icon: "device_thermostat"
                        statusText: Ai.temperature.toFixed(1)
                        description: Translation.tr("Temperature\nChange with /temp VALUE")
                    }
                    StatusSeparator {
                        visible: Ai.tokenCount.total > 0
                    }
                    StatusItem {
                        rootRef: root
                        animIndex: 2
                        visible: Ai.tokenCount.total > 0
                        icon: "token"
                        statusText: Ai.tokenCount.total
                        description: Translation.tr("Total token count\nInput: %1\nOutput: %2").arg(Ai.tokenCount.input).arg(Ai.tokenCount.output)
                    }
                    StatusSeparator {
                        visible: contextMeter.visible
                    }
                    StatusItem {
                        // How full the window is. A token count on its own
                        // says nothing until the chat is dropping its own
                        // beginning; a share of the window says it early.
                        id: contextMeter
                        readonly property int window: Ai.currentModelEntry?.contextWindow ?? 0
                        readonly property real fraction: contextMeter.window > 0 ? Math.min(1, Ai.tokenCount.total / contextMeter.window) : 0

                        rootRef: root
                        animIndex: 2
                        visible: contextMeter.window > 0 && Ai.tokenCount.total > 0
                        icon: contextMeter.fraction >= 0.75 ? "data_alert" : "data_usage"
                        statusText: `${Math.round(contextMeter.fraction * 100)}%`
                        tint: contextMeter.fraction >= 0.75 ? Appearance.m3colors.m3tertiary : Appearance.colors.colSubtext
                        description: Translation.tr("%1 of %2 tokens used in this chat").arg(Ai.tokenCount.total).arg(contextMeter.window)
                    }
                }
            }

            ScrollEdgeFade {
                z: 1
                target: messageListView
                vertical: true
            }

            StyledListView { // Message list
                id: messageListView
                z: 0
                anchors.fill: parent
                spacing: 10
                popin: false
                animateAppearance: false
                topMargin: statusBg.implicitHeight + statusBg.anchors.topMargin * 2
                bottomMargin: 8
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

                function pinToEnd() {
                    messageListView.following = true;
                    messageListView.pinning = true;
                    messageListView.positionViewAtEnd();
                    pinReleaseTimer.restart();
                }

                Timer {
                    id: pinReleaseTimer
                    interval: Appearance.animation.scroll.duration + 80
                    onTriggered: messageListView.pinning = false
                }

                // A gesture always has the final say, even mid-answer: it is
                // the one thing here that is unambiguously the reader's doing.
                onUserScrolled: (targetY, maxY) => {
                    messageListView.pinning = false;
                    messageListView.following = (maxY - targetY) < 48;
                }
                onDraggingChanged: {
                    if (messageListView.dragging)
                        messageListView.pinning = false;
                }
                onMovementEnded: messageListView.following = messageListView.bottomGap < 48
                onContentYChanged: {
                    if (messageListView.pinning)
                        return;
                    messageListView.following = messageListView.bottomGap < 48;
                }
                onContentHeightChanged: {
                    if (!messageListView.following)
                        return;
                    Qt.callLater(function () {
                        messageListView.pinToEnd();
                    });
                }
                onCountChanged: Qt.callLater(function () {
                    messageListView.pinToEnd();
                })

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
                    messageInputField: root.inputField
                    onRegenerateRequested: id => controlBar.openRegenerate(id)
                }
            }

            PagePlaceholder {
                id: emptyStatePlaceholder
                z: 2
                shown: Ai.messageIDs.length === 0
                icon: Ai.currentPersona?.icon ?? "neurology"
                title: Ai.currentPersona?.name ?? Translation.tr("Large language models")
                description: Ai.currentPersona?.description ?? Translation.tr("Ask anything, or start with one of these")
                shape: MaterialShape.Shape.PixelCircle
                animateIconOnShow: true
                entranceTrigger: root.entranceTrigger
            }

            Loader {
                // The empty chat used to list keyboard shortcuts. What it is
                // for is a way in: four things worth asking, or the one thing
                // standing between this chat and an answer.
                id: emptyStateActionsLoader
                z: 3
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 12
                }
                width: Math.min(parent.width - 24, 460)
                active: Ai.messageIDs.length === 0
                visible: active

                sourceComponent: ColumnLayout {
                    spacing: 6

                    Loader {
                        Layout.fillWidth: true
                        active: !Ai.currentModelHasApiKey
                        visible: active

                        sourceComponent: Rectangle {
                            implicitHeight: missingKeyRowLayout.implicitHeight + 10 * 2
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colSecondaryContainer

                            RowLayout {
                                id: missingKeyRowLayout
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8

                                MaterialSymbol {
                                    text: "key_off"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.m3colors.m3onSecondaryContainer
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("%1 needs an API key").arg(Ai.currentModelEntry?.title ?? Translation.tr("This model"))
                                    wrapMode: Text.Wrap
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.m3colors.m3onSecondaryContainer
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
                                    onClicked: controlBar.openKeyManager()

                                    contentItem: StyledText {
                                        text: Translation.tr("Add a key")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.m3colors.m3onPrimary
                                    }
                                }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width >= 420 ? 2 : 1
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            model: ScriptModel {
                                values: Ai.starters
                            }

                            delegate: RippleButton {
                                id: starterButton
                                required property var modelData

                                Layout.fillWidth: true
                                leftPadding: 12
                                rightPadding: 12
                                topPadding: 8
                                bottomPadding: 8
                                buttonRadius: Appearance.rounding.small
                                colBackground: Appearance.colors.colLayer2
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                // Put in the composer rather than sent: an
                                // opening line is a start, not the message.
                                onClicked: {
                                    messageInputField.text = starterButton.modelData;
                                    messageInputField.cursorPosition = messageInputField.text.length;
                                    messageInputField.forceActiveFocus();
                                }

                                contentItem: StyledText {
                                    text: starterButton.modelData
                                    wrapMode: Text.Wrap
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer2
                                }
                            }
                        }
                    }
                }
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

        ChatControlBar {
            id: controlBar
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            overlayParent: messagesArea
            commandPrefix: root.commandPrefix
            inputField: messageInputField
            sessionsOpen: root.sessionsOpen
            onNewChatRequested: Ai.newChat()
            onSessionsRequested: root.sessionsOpen = !root.sessionsOpen
        }

        Rectangle { // Input area
            id: inputWrapper
            property real spacing: 5
            Layout.fillWidth: true
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.colors.colLayer2
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.bottomMargin + spacing, 45) + (attachmentTray.implicitHeight + spacing + attachmentTray.anchors.topMargin)
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

            AttachmentTray {
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

            RowLayout { // Input field and send button
                id: inputFieldRowLayout
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    bottomMargin: 5
                }
                spacing: 0

                FontMetrics {
                    // The buttons beside the field line up with the middle of
                    // its last line of text, not with its bottom edge: the
                    // field's own padding sits below that line, so a button
                    // flush with the bottom reads as sitting too low.
                    id: composerTextMetrics
                    font: messageInputField.font
                }

                ComposerButton {
                    // Attaching used to be a slash command with a path typed
                    // by hand, or a drag. Both are still there.
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: Math.max(0, messageInputField.bottomPadding + composerTextMetrics.height / 2 - implicitHeight / 2)
                    Layout.leftMargin: 5
                    symbol: "attach_file"
                    tooltipText: Translation.tr("Attach files")
                    onTriggered: filePickerProc.running = true
                }

                ComposerButton {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: Math.max(0, messageInputField.bottomPadding + composerTextMetrics.height / 2 - implicitHeight / 2)
                    symbol: "screenshot_region"
                    tooltipText: Translation.tr("Send a part of the screen")
                    onTriggered: {
                        if (!root.snipHeld) {
                            root.snipHeld = true;
                            root.holdSidebarOpen();
                        }
                        GlobalStates.snipForAiRequested();
                    }
                }

                ScrollView {
                    id: inputScrollView
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.height * 3/5, messageInputField.height)
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
                    
                
                RippleButton { // Send button, or Stop while a reply is coming in
                    id: sendButton
                    readonly property bool stopping: Ai.isGenerating

                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: Math.max(0, messageInputField.bottomPadding + composerTextMetrics.height / 2 - implicitHeight / 2)
                    Layout.rightMargin: 5
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.small
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
                    }

                    StyledToolTip {
                        text: sendButton.stopping ? Translation.tr("Stop") : Translation.tr("Send")
                    }
                }
            }
        }
    }

    SessionDrawer {
        anchors.fill: parent
        anchors.margins: root.padding
        shown: root.sessionsOpen && !root.wideEnoughForPane
        onClosed: root.sessionsOpen = false
    }
}