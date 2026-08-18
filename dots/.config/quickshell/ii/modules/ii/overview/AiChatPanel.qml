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
    signal requestSendMessage(string text)
    signal requestContinueInSidebar()

    property bool historyOpen: false
    property bool modelsOpen: false

    onModelsOpenChanged: {
        if (root.modelsOpen)
            root.historyOpen = false;
    }
    onHistoryOpenChanged: {
        if (root.historyOpen) {
            root.modelsOpen = false;
            Ai.sessions.ensureLoaded();
        }
    }

    readonly property var orderedModels: {
        const models = Ai.catalog.modelIds.map(modelId => Ai.catalog.models[modelId]).filter(model => !!model);
        models.sort((first, second) => {
            const firstLocal = Ai.catalog.isModelLocal(first) ? 0 : 1;
            const secondLocal = Ai.catalog.isModelLocal(second) ? 0 : 1;
            if (firstLocal !== secondLocal)
                return firstLocal - secondLocal;
            return String(first.title ?? first.value ?? "").localeCompare(String(second.title ?? second.value ?? ""));
        });
        return models;
    }

    Component.onCompleted: Ai.sessions.ensureLoaded()
    property string pendingTrashId: ""

    readonly property real headerControlExtent: Math.round(Appearance.font.pixelSize.huge * 2)
    readonly property real headerControlPadding: Appearance.rounding.small
    readonly property real headerHeight: headerControlExtent + headerControlPadding * 2
    readonly property real canvasHeight: 380
    readonly property real composerHeight: headerControlExtent + headerControlPadding * 2
    readonly property real columnSpacing: Appearance.rounding.verysmall

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
        if (root.modelsOpen) {
            modelList.contentY = Math.max(0, modelList.contentY - 64);
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
        if (root.modelsOpen) {
            modelList.contentY = Math.min(
                Math.max(0, modelList.contentHeight - modelList.height),
                modelList.contentY + 64);
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
        if (root.modelsOpen) {
            root.modelsOpen = false;
            return true;
        }
        return false;
    }

    function handleComposerEscape() {
        if (!root.handleEscape())
            root.requestBackToSearch();
    }

    function focusNext() {
        if (brainBackButton.activeFocus)
            historyToggleBtn.forceActiveFocus();
        else if (historyToggleBtn.activeFocus)
            newChatBtn.forceActiveFocus();
        else if (newChatBtn.activeFocus)
            composer.focusInput();
        else
            composer.focusFirstButton();
    }

    function focusPrev() {
        if (brainBackButton.activeFocus)
            composer.focusLastButton();
        else if (newChatBtn.activeFocus)
            historyToggleBtn.forceActiveFocus();
        else if (historyToggleBtn.activeFocus)
            brainBackButton.forceActiveFocus();
        else
            brainBackButton.forceActiveFocus();
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
        } else if (event.key === Qt.Key_Tab) {
            if (event.modifiers & Qt.ShiftModifier)
                root.focusPrev();
            else
                root.focusNext();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backtab) {
            root.focusPrev();
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

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

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
                    focusPolicy: Qt.StrongFocus
                    colBackground: brainBackButton.activeFocus
                        ? Appearance.colors.colLayer2Active
                        : (brainBackButton.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: root.requestBackToSearch()

                    Accessible.name: Translation.tr("Back to search")

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Space || event.key === Qt.Key_Enter) {
                            root.requestBackToSearch();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.focusComposer();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            if (event.modifiers & Qt.ShiftModifier)
                                newChatBtn.forceActiveFocus();
                            else
                                root.focusComposer();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Backtab) {
                            newChatBtn.forceActiveFocus();
                            event.accepted = true;
                        }
                    }

                    contentItem: MaterialSymbol {
                        text: (brainBackButton.hovered || brainBackButton.activeFocus) ? "arrow_back" : "network_intelligence"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.larger
                        color: (brainBackButton.hovered || brainBackButton.activeFocus) ? Appearance.m3colors.m3primary : Appearance.colors.colOnLayer1
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
                        focusPolicy: Qt.StrongFocus
                        toggled: root.historyOpen
                        colBackground: historyToggleBtn.activeFocus
                            ? (root.historyOpen ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer2Active)
                            : (root.historyOpen ? Appearance.colors.colPrimary : Appearance.colors.colLayer2)
                        colBackgroundHover: root.historyOpen ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: root.historyOpen = !root.historyOpen

                        Accessible.name: Translation.tr("History")

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Space || event.key === Qt.Key_Enter) {
                                root.historyOpen = !root.historyOpen;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.focusComposer();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    composer.focusLastButton();
                                else
                                    newChatBtn.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Backtab) {
                                composer.focusLastButton();
                                event.accepted = true;
                            }
                        }

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
                        focusPolicy: Qt.StrongFocus
                        colBackground: newChatBtn.activeFocus
                            ? Appearance.colors.colLayer2Active
                            : (newChatBtn.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: {
                            Ai.newChat();
                            root.historyOpen = false;
                            root.requestFocusComposer();
                        }

                        Accessible.name: Translation.tr("New chat")

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Space || event.key === Qt.Key_Enter) {
                                Ai.newChat();
                                root.historyOpen = false;
                                root.focusComposer();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.focusComposer();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    historyToggleBtn.forceActiveFocus();
                                else
                                    brainBackButton.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Backtab) {
                                historyToggleBtn.forceActiveFocus();
                                event.accepted = true;
                            }
                        }

                        contentItem: MaterialSymbol {
                            text: "add_comment"
                            fill: 1
                            iconSize: Appearance.font.pixelSize.larger
                            color: newChatBtn.activeFocus ? Appearance.m3colors.m3primary : Appearance.colors.colOnLayer2
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

            MouseArea {
                anchors.fill: parent
                onClicked: root.focusComposer()
            }

            // Messages view (Transcript & Starters)
            Item {
                id: messagesView
                anchors.fill: parent
                opacity: (!root.historyOpen && !root.modelsOpen) ? 1.0 : 0.0
                visible: opacity > 0.001
                transform: Translate {
                    x: (root.historyOpen || root.modelsOpen) ? -36 : 0
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

                // Empty state matching sidebarPolicies/AiChat
                PagePlaceholder {
                    id: emptyStatePlaceholder
                    z: 2
                    shown: root.visibleMessageIds.length === 0
                    icon: Ai.currentPersona?.icon ?? "neurology"
                    title: Ai.currentPersona?.name ?? Translation.tr("Large language models")
                    description: Ai.currentPersona?.description ?? Translation.tr("Ask anything, or start with one of these")
                    shape: MaterialShape.Shape.PixelCircle
                    animateIconOnShow: true
                }

                // Messages list
                ListView {
                    id: messageList
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true
                    spacing: 12
                    visible: root.visibleMessageIds.length > 0
                    model: ScriptModel {
                        values: root.visibleMessageIds
                    }

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
                        messageData: Ai.messageByID[modelData]
                    }
                }
            }

            // Inlined Session History view
            Item {
                id: historyView
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 0
                anchors.bottomMargin: 0
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

                // Empty history placeholder
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: (Ai.sessions.index ?? []).length === 0

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "history"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No conversation history")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                }

                ListView {
                    id: sessionList
                    anchors.fill: parent
                    clip: false
                    spacing: 8
                    topMargin: 16
                    bottomMargin: 16
                    visible: (Ai.sessions.index ?? []).length > 0
                    model: Ai.sessions.index ?? []

                    header: Item {
                        width: sessionList.width
                        implicitHeight: headerRow.implicitHeight + 12
                        height: implicitHeight

                        RowLayout {
                            id: headerRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 0
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4

                            StyledText {
                                text: Translation.tr("Conversations")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: Translation.tr("%1 sessions").arg((Ai.sessions.index ?? []).length)
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    delegate: Item {
                        id: sessionRow
                        required property var modelData
                        width: sessionList.width
                        implicitHeight: 48
                        height: implicitHeight

                        readonly property bool isActive: sessionRow.modelData?.id === Ai.sessions.currentId

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            // Main Conversation Info Card
                            RippleButton {
                                id: sessionCard
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                buttonRadius: Appearance.rounding.full
                                toggled: sessionRow.isActive
                                colBackground: sessionRow.isActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                                colBackgroundHover: sessionRow.isActive ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                colBackgroundToggled: Appearance.colors.colPrimary
                                colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                                colBackgroundToggledActive: Appearance.colors.colPrimaryActive

                                onClicked: {
                                    Ai.openSession(sessionRow.modelData.id);
                                    root.historyOpen = false;
                                    root.requestFocusComposer();
                                }

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    MaterialSymbol {
                                        text: "chat_bubble"
                                        fill: 1
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: sessionRow.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: sessionRow.modelData.title || Translation.tr("Untitled chat")
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.DemiBold
                                        color: sessionRow.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // Right Circle Arrow Button
                            RippleButton {
                                id: openSessionBtn
                                implicitWidth: 48
                                implicitHeight: 48
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                buttonRadius: Appearance.rounding.full
                                toggled: sessionRow.isActive
                                colBackground: sessionRow.isActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                                colBackgroundHover: sessionRow.isActive ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                colBackgroundToggled: Appearance.colors.colPrimary
                                colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                                colBackgroundToggledActive: Appearance.colors.colPrimaryActive

                                onClicked: {
                                    Ai.openSession(sessionRow.modelData.id);
                                    root.historyOpen = false;
                                    root.requestFocusComposer();
                                }

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "arrow_forward"
                                    fill: 1
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: sessionRow.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                }

                                StyledToolTip {
                                    text: Translation.tr("Open chat")
                                }
                            }
                        }
                    }
                }
            }

            // Inlined Models view (Identical design to historyView)
            Item {
                id: modelsView
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 0
                anchors.bottomMargin: 0
                opacity: root.modelsOpen ? 1.0 : 0.0
                visible: opacity > 0.001
                transform: Translate {
                    x: root.modelsOpen ? 0 : 36
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

                // Empty models placeholder
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.orderedModels.length === 0

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "smart_toy"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No models available")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                }

                ListView {
                    id: modelList
                    anchors.fill: parent
                    clip: false
                    spacing: 8
                    topMargin: 16
                    bottomMargin: 16
                    visible: root.orderedModels.length > 0
                    model: root.orderedModels

                    header: Item {
                        width: modelList.width
                        implicitHeight: modelHeaderRow.implicitHeight + 12
                        height: implicitHeight

                        RowLayout {
                            id: modelHeaderRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 0
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4

                            StyledText {
                                text: Translation.tr("Models")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: Translation.tr("%1 models").arg(root.orderedModels.length)
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    delegate: Item {
                        id: modelRow
                        required property var modelData
                        width: modelList.width
                        implicitHeight: 48
                        height: implicitHeight

                        readonly property bool isActive: modelRow.modelData?.id === Ai.currentModelId

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            // Main Model Info Card
                            RippleButton {
                                id: modelCard
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                buttonRadius: Appearance.rounding.full
                                toggled: modelRow.isActive
                                colBackground: modelRow.isActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                                colBackgroundHover: modelRow.isActive ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                colBackgroundToggled: Appearance.colors.colPrimary
                                colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                                colBackgroundToggledActive: Appearance.colors.colPrimaryActive

                                onClicked: {
                                    Ai.setModel(modelRow.modelData.id, false);
                                    root.modelsOpen = false;
                                    root.requestFocusComposer();
                                }

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Loader {
                                        Layout.alignment: Qt.AlignVCenter
                                        active: (modelRow.modelData.icon ?? "").length > 0
                                        visible: active
                                        sourceComponent: CustomIcon {
                                            source: modelRow.modelData.icon ?? ""
                                            width: Appearance.font.pixelSize.larger
                                            height: Appearance.font.pixelSize.larger
                                            colorize: true
                                            color: modelRow.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                        }
                                    }

                                    MaterialSymbol {
                                        visible: !(modelRow.modelData.icon ?? "").length
                                        text: modelRow.modelData.materialIcon ?? "auto_awesome"
                                        fill: 1
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: modelRow.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelRow.modelData.title || modelRow.modelData.name || modelRow.modelData.value || Translation.tr("Unknown model")
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.DemiBold
                                        color: modelRow.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        visible: Ai.catalog.isModelLocal(modelRow.modelData)
                                        text: Translation.tr("Local")
                                        font.pixelSize: Appearance.font.pixelSize.smallie
                                        color: modelRow.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colSubtext
                                    }
                                }
                            }

                            // Right Circle Check/Select Button
                            RippleButton {
                                id: selectModelBtn
                                implicitWidth: 48
                                implicitHeight: 48
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                buttonRadius: Appearance.rounding.full
                                toggled: modelRow.isActive
                                colBackground: modelRow.isActive ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                                colBackgroundHover: modelRow.isActive ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                colBackgroundToggled: Appearance.colors.colPrimary
                                colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                                colBackgroundToggledActive: Appearance.colors.colPrimaryActive

                                onClicked: {
                                    Ai.setModel(modelRow.modelData.id, false);
                                    root.modelsOpen = false;
                                    root.requestFocusComposer();
                                }

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: modelRow.isActive ? "check" : "arrow_forward"
                                    fill: 1
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: modelRow.isActive ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                }

                                StyledToolTip {
                                    text: modelRow.isActive ? Translation.tr("Active model") : Translation.tr("Select model")
                                }
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
            modelsOpen: root.modelsOpen
            onRequestSend: text => root.requestSendMessage(text)
            onRequestEscape: root.handleComposerEscape()
            onRequestOpenHistory: root.historyOpen = !root.historyOpen
            onRequestOpenModels: root.modelsOpen = !root.modelsOpen
            onRequestFocusNext: historyToggleBtn.forceActiveFocus()
            onRequestFocusPrev: brainBackButton.forceActiveFocus()
        }
    }
}
