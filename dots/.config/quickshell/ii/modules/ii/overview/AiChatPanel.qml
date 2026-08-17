pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.services.ai
import qs.services.ai.blocks
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarPolicies
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

/**
 * Floating Bubbles 3-rectangle AI Chat panel for Overview Search (Figma Prototype Design).
 *
 * 1. Top Header Rectangle:
 *    - Left: Brain shape icon ("network_intelligence", fill: 1) that switches to "arrow_back" on hover (returns to search)
 *    - Middle: AI Task Title (with clean fallback)
 *    - Right: History toggle & New Chat buttons (with fill: 1)
 *
 * 2. Middle Canvas Rectangle:
 *    - Hosts the message transcript and the inlined history view with fade + slide animation
 *
 * 3. Bottom Composer Rectangle:
 *    - Multi-line keyboard-first prompt input, model selector pill, and send button
 */
Item {
    id: root

    signal requestBackToSearch()
    signal requestFocusComposer()
    signal requestSendMessage()
    signal requestContinueInSidebar()

    property bool historyOpen: false
    property string pendingTrashId: ""

    readonly property real headerControlExtent: Math.round(Appearance.font.pixelSize.huge * 2)
    readonly property real headerControlPadding: Appearance.rounding.small
    readonly property real headerHeight: headerControlExtent + headerControlPadding * 2
    readonly property real canvasHeight: 380
    readonly property real composerHeight: headerControlExtent + headerControlPadding * 2
    readonly property real columnSpacing: Appearance.rounding.small

    implicitWidth: 720
    implicitHeight: headerHeight + canvasHeight + composerHeight + columnSpacing * 2
    width: parent ? parent.width : implicitWidth
    height: implicitHeight

    function focusComposer() {
        composer.focusInput();
    }

    function navigateUp() {
        if (root.historyOpen) {
            sessionList.contentY = Math.max(0, sessionList.contentY - 64);
            return;
        }
        if (messageList.contentHeight > messageList.height)
            messageList.contentY = Math.max(0, messageList.contentY - 64);
    }

    function navigateDown() {
        if (root.historyOpen) {
            sessionList.contentY = Math.min(
                Math.max(0, sessionList.contentHeight - sessionList.height),
                sessionList.contentY + 64);
            return;
        }
        if (messageList.contentHeight > messageList.height)
            messageList.contentY = Math.min(messageList.contentHeight - messageList.height, messageList.contentY + 64);
    }

    function captureHandoffState() {
        const anchor = {
            messageId: "",
            offset: 0,
            following: messageList.following === true
        };
        if (messageList.count <= 0)
            return anchor;
        const probeY = Math.min(8, Math.max(0, messageList.height - 1));
        const index = messageList.indexAt(8, probeY);
        if (index < 0 || index >= root.visibleMessageIds.length)
            return anchor;
        anchor.messageId = String(root.visibleMessageIds[index] ?? "");
        const delegate = messageList.itemAtIndex(index);
        if (delegate)
            anchor.offset = Math.max(0, Number(delegate.y) - Number(messageList.contentY));
        return anchor;
    }

    function restoreHandoffAnchor(anchor) {
        const source = anchor && typeof anchor === "object" ? anchor : ({});
        if (source.following === true) {
            messageList.following = true;
            messageList.positionViewAtEnd();
            return true;
        }
        const anchorId = String(source.messageId ?? "");
        const index = root.visibleMessageIds.indexOf(anchorId);
        if (index < 0)
            return false;
        messageList.following = false;
        messageList.positionViewAtIndex(index, ListView.Beginning);
        const offset = Number(source.offset ?? 0);
        if (isFinite(offset) && offset > 0)
            messageList.contentY = Math.max(0, messageList.contentY - offset);
        return true;
    }

    function focusMessageTarget(messageId, anchor) {
        const targetId = String(messageId ?? "");
        const index = root.visibleMessageIds.indexOf(targetId);
        if (index < 0)
            return false;
        messageList.following = false;
        messageList.positionViewAtIndex(index, ListView.Center);
        const offset = Number(anchor?.offset ?? 0);
        if (isFinite(offset) && offset > 0)
            messageList.contentY = Math.max(0, messageList.contentY - offset);
        Qt.callLater(function() {
            const delegate = messageList.itemAtIndex(index);
            if (delegate && typeof delegate.forceActiveFocus === "function")
                delegate.forceActiveFocus();
            else
                messageList.forceActiveFocus();
        });
        return true;
    }

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
            root.focusComposer();
        return hasAnchor || String(intent.focusIntent ?? "composer") === "composer";
    }

    function handleEscape() {
        if (root.historyOpen) {
            root.historyOpen = false;
            return true;
        }
        return false;
    }

    function handleComposerEscape() {
        if (!root.handleEscape())
            root.requestBackToSearch();
    }

    readonly property var visibleMessageIds: Ai.messageIDs.filter(id => {
        const m = Ai.messageByID[id];
        return m && m.role !== Ai.interfaceRole && (m.visibleToUser ?? true);
    })

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (!root.handleEscape())
                root.requestBackToSearch();
            event.accepted = true;
        } else if (event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            Ai.newChat();
            root.historyOpen = false;
            event.accepted = true;
        }
    }

    ColumnLayout {
        id: chatColumn
        anchors.fill: parent
        spacing: root.columnSpacing

        // ════════════════════════════════════════════════════════
        // 1. TOP HEADER RECTANGLE
        // ════════════════════════════════════════════════════════

        Rectangle {
            id: headerSurface
            Layout.fillWidth: true
            implicitHeight: root.headerHeight
            Layout.preferredHeight: root.headerHeight
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.full
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: root.headerControlPadding
                spacing: Appearance.rounding.verysmall

                // Brain shape button (switches to back arrow on hover)
                RippleButton {
                    id: brainBackButton
                    implicitWidth: root.headerControlExtent
                    implicitHeight: root.headerControlExtent
                    buttonRadius: Appearance.rounding.full
                    colBackground: brainBackButton.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: root.requestBackToSearch()

                    Accessible.name: Translation.tr("Back to search")

                    contentItem: MaterialSymbol {
                        text: brainBackButton.hovered ? "arrow_back" : "network_intelligence"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.larger
                        color: brainBackButton.hovered ? Appearance.m3colors.m3primary : Appearance.colors.colOnLayer1
                    }

                    StyledToolTip {
                        text: Translation.tr("Back to search (Esc)")
                    }
                }

                // AI Task Title
                StyledText {
                    id: taskTitleText
                    Layout.fillWidth: true
                    Layout.leftMargin: Appearance.rounding.verysmall
                    Layout.rightMargin: Appearance.rounding.verysmall
                    text: {
                        const title = Ai.sessions?.currentTitle?.trim()
                            || Ai.sessions?.titleFor?.(Ai.sessions?.currentId ?? "")?.trim()
                            || "";
                        return title.length > 0 ? title : Translation.tr("New conversation");
                    }
                    elide: Text.ElideRight
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    font.variableAxes: Appearance.font.variableAxes.main
                    color: Appearance.colors.colOnLayer1
                }

                // Right action toggles: History & New Chat
                RowLayout {
                    spacing: Appearance.rounding.verysmall

                    RippleButton {
                        id: historyToggleBtn
                        implicitWidth: root.headerControlExtent
                        implicitHeight: root.headerControlExtent
                        buttonRadius: Appearance.rounding.full
                        toggled: root.historyOpen
                        colBackground: root.historyOpen ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                        colBackgroundHover: root.historyOpen ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: root.historyOpen = !root.historyOpen

                        Accessible.name: Translation.tr("History")

                        contentItem: MaterialSymbol {
                            text: "history"
                            fill: 1
                            iconSize: Appearance.font.pixelSize.larger
                            color: root.historyOpen ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                        }

                        StyledToolTip {
                            text: Translation.tr("History (/sessions)")
                        }
                    }

                    RippleButton {
                        id: newChatBtn
                        implicitWidth: root.headerControlExtent
                        implicitHeight: root.headerControlExtent
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: {
                            Ai.newChat();
                            root.historyOpen = false;
                            root.requestFocusComposer();
                        }

                        Accessible.name: Translation.tr("New chat")

                        contentItem: MaterialSymbol {
                            text: "add_comment"
                            fill: 1
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnLayer2
                        }

                        StyledToolTip {
                            text: Translation.tr("New chat (/new)")
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════
        // 2. MIDDLE CANVAS RECTANGLE (Messages & History)
        // ════════════════════════════════════════════════════════

        Rectangle {
            id: canvasSurface
            Layout.fillWidth: true
            Layout.preferredHeight: root.canvasHeight
            implicitHeight: root.canvasHeight
            Layout.minimumHeight: 180
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.large
            clip: true

            // Messages view (Transcript & Starters)
            Item {
                id: messagesView
                anchors.fill: parent
                opacity: root.historyOpen ? 0.0 : 1.0
                visible: opacity > 0.001
                transform: Translate {
                    x: root.historyOpen ? -36 : 0
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }
                Behavior on transform {
                    NumberAnimation {
                        property: "x"
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                // Empty state starter chips
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 16
                    visible: root.visibleMessageIds.length === 0

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "auto_awesome"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.m3colors.m3primary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("How can I help you?")
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Repeater {
                            model: [
                                Translation.tr("Explain what this command does"),
                                Translation.tr("Summarise this in three points"),
                                Translation.tr("What is wrong with this code?"),
                                Translation.tr("Help me word this")
                            ]
                            delegate: RippleButton {
                                id: starterBtn
                                required property string modelData
                                implicitHeight: 32
                                implicitWidth: starterLabel.implicitWidth + 24
                                buttonRadius: Appearance.rounding.full
                                colBackground: Appearance.colors.colLayer2
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                onClicked: {
                                    Ai.draft = starterBtn.modelData;
                                    root.requestFocusComposer();
                                }

                                contentItem: StyledText {
                                    id: starterLabel
                                    anchors.centerIn: parent
                                    text: starterBtn.modelData
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer2
                                }
                            }
                        }
                    }
                }

                // Messages list
                ListView {
                    id: messageList
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true
                    spacing: 12
                    visible: root.visibleMessageIds.length > 0
                    model: root.visibleMessageIds

                    property bool following: true

                    onContentYChanged: {
                        if (moving) {
                            following = atYEnd;
                        }
                    }

                    onCountChanged: {
                        if (following) {
                            Qt.callLater(positionViewAtEnd);
                        }
                    }

                    delegate: AiChatPanelMessage {
                        id: messageDelegate
                        required property string modelData
                        required property int index
                        width: messageList.width
                        messageId: modelData
                    }
                }
            }

            // Inlined Session History view
            Item {
                id: historyView
                anchors.fill: parent
                anchors.margins: 16
                opacity: root.historyOpen ? 1.0 : 0.0
                visible: opacity > 0.001
                transform: Translate {
                    x: root.historyOpen ? 0 : 36
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }
                Behavior on transform {
                    NumberAnimation {
                        property: "x"
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: Translation.tr("Conversations")
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: Translation.tr("%1 sessions").arg(Ai.sessions.entries.length)
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            color: Appearance.colors.colSubtext
                        }
                    }

                    ListView {
                        id: sessionList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: Ai.sessions.entries

                        delegate: RowLayout {
                            id: sessionRow
                            required property var modelData
                            width: sessionList.width
                            spacing: 8

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 48
                                buttonRadius: Appearance.rounding.normal
                                toggled: Ai.sessions.currentId === sessionRow.modelData.id
                                colBackground: toggled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                                colBackgroundHover: toggled ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                onClicked: {
                                    Ai.openSession(sessionRow.modelData.id);
                                    root.historyOpen = false;
                                    root.requestFocusComposer();
                                }

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    MaterialSymbol {
                                        text: sessionRow.modelData.pinned ? "push_pin" : "chat_bubble"
                                        fill: 1
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: Appearance.colors.colOnLayer2
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: sessionRow.modelData.title || Translation.tr("Untitled chat")
                                            elide: Text.ElideRight
                                            color: Appearance.colors.colOnLayer2
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: sessionRow.modelData.preview || Translation.tr("No messages yet")
                                            elide: Text.ElideRight
                                            font.pixelSize: Appearance.font.pixelSize.smallie
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }
                            }

                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.full
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                onClicked: Ai.sessions.setPinned(sessionRow.modelData.id, !sessionRow.modelData.pinned)

                                contentItem: MaterialSymbol {
                                    text: "push_pin"
                                    fill: 1
                                    iconSize: Appearance.font.pixelSize.smallie
                                    color: sessionRow.modelData.pinned ? Appearance.m3colors.m3primary : Appearance.colors.colSubtext
                                }

                                StyledToolTip { text: Translation.tr("Pin or unpin") }
                            }

                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.full
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                onClicked: root.pendingTrashId = root.pendingTrashId === sessionRow.modelData.id ? "" : sessionRow.modelData.id

                                Accessible.name: Translation.tr("Move chat to trash")

                                contentItem: MaterialSymbol {
                                    text: "delete"
                                    fill: 1
                                    iconSize: Appearance.font.pixelSize.smallie
                                    color: Appearance.m3colors.m3error
                                }

                                StyledToolTip { text: Translation.tr("Move to trash") }
                            }

                            RippleButton {
                                visible: root.pendingTrashId === sessionRow.modelData.id
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.full
                                colBackground: Appearance.m3colors.m3error
                                colBackgroundHover: Appearance.m3colors.m3error
                                colRipple: Appearance.colors.colLayer2Active
                                onClicked: {
                                    Ai.sessions.trash(sessionRow.modelData.id);
                                    root.pendingTrashId = "";
                                }

                                Accessible.name: Translation.tr("Confirm moving chat to trash")

                                contentItem: MaterialSymbol {
                                    text: "check"
                                    fill: 1
                                    iconSize: Appearance.font.pixelSize.smallie
                                    color: Appearance.m3colors.m3onError
                                }

                                StyledToolTip { text: Translation.tr("Confirm trash") }
                            }
                        }
                    }

                    RowLayout {
                        visible: !!Ai.sessions.deletedEntry
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("%1 moved to trash").arg(Ai.sessions.deletedEntry?.title ?? Translation.tr("Chat"))
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            color: Appearance.colors.colSubtext
                        }

                        RippleButton {
                            implicitWidth: 76
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colSecondaryContainer
                            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                            colRipple: Appearance.colors.colSecondaryContainerActive
                            onClicked: Ai.sessions.undoDelete()

                            contentItem: StyledText {
                                text: Translation.tr("Undo")
                                horizontalAlignment: Text.AlignHCenter
                                color: Appearance.m3colors.m3onSecondaryContainer
                            }
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════
        // 3. BOTTOM COMPOSER RECTANGLE
        // ════════════════════════════════════════════════════════

        AiSearchComposer {
            id: composer
            Layout.fillWidth: true
            onRequestSend: root.requestSendMessage()
            onRequestEscape: root.handleComposerEscape()
            onRequestOpenHistory: root.historyOpen = !root.historyOpen
        }
    }
}
