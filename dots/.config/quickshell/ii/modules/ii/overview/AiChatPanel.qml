pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../sidebarPolicies"
import "../sidebarPolicies/aiChat"

/**
 * Unified AI chat panel for the overview search.
 *
 * Layout: header (back + title + actions) → transcript → bottom bar (model chip + attach + send).
 * The search bar above this panel acts as the text input — this panel is purely the
 * conversation surface, consistent with how bluetooth/clipboard/translator panels
 * sit below the search bar.
 *
 * Everything reads the shared Ai singleton, so it stays in sync with the sidebar chat.
 */
Item {
    id: root

    signal requestBackToSearch()
    signal requestFocusComposer()
    signal requestSendMessage()
    signal requestContinueInSidebar()

    implicitWidth: parent ? parent.width : 720
    implicitHeight: 520

    /** Which floating popover is up: "", "model", "tools", "keys", "sessions". */
    property string activePopover: ""

    function openPopover(name: string) {
        root.activePopover = (root.activePopover === name) ? "" : name;
    }

    function closePopovers() {
        root.activePopover = "";
    }

    readonly property var visibleMessageIds: Ai.messageIDs.filter(id => {
        const m = Ai.messageByID[id];
        return m && m.role !== Ai.interfaceRole && (m.visibleToUser ?? true);
    })

    Connections {
        target: Ai
        function onKeyManagerRequested() {
            root.activePopover = "keys";
        }
    }

    // File picker for attachments
    Process {
        id: attachPicker
        command: ["bash", "-c",
            "if command -v kdialog >/dev/null; then " +
            "  FILES=$(kdialog --getopenfilename \"$HOME\" \"\" --multiple 2>/dev/null); " +
            "  if [ -n \"$FILES\" ]; then echo -n \"$FILES\" | tr '\\n' '|'; fi; " +
            "elif command -v zenity >/dev/null; then " +
            "  zenity --file-selection --multiple --separator=\"|\" 2>/dev/null; " +
            "fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const paths = this.text.split("|").filter(p => p.length > 0);
                for (let i = 0; i < paths.length; i++)
                    Ai.attachFile(paths[i]);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            spacing: 4

            RippleButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.requestBackToSearch()

                contentItem: MaterialSymbol {
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }

                StyledToolTip {
                    text: Translation.tr("Back to search (Esc)")
                }
            }

            RippleButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.requestContinueInSidebar()

                contentItem: MaterialSymbol {
                    text: "open_in_new"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }

                StyledToolTip {
                    text: Translation.tr("Continue in sidebar (Ctrl+J)")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const title = Ai.sessions?.titleFor?.(Ai.sessions?.currentId ?? "") ?? "";
                        return title.length > 0 ? title : Translation.tr("New chat");
                    }
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !Ai.currentModelHasApiKey && Ai.currentModelEntry?.requires_key
                    text: Translation.tr("No API key set")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    color: Appearance.m3colors.m3error
                }
            }

            Repeater {
                model: ScriptModel {
                    values: [
                        { icon: "auto_awesome", popover: "model", active: root.activePopover === "model", tooltip: Translation.tr("Model (/model)") },
                        { icon: "add_comment", popover: "", active: false, tooltip: Translation.tr("New chat (/new)") },
                        { icon: "history", popover: "sessions", active: root.activePopover === "sessions", tooltip: Translation.tr("History (/sessions)") },
                        { icon: "construction", popover: "tools", active: root.activePopover === "tools", tooltip: Translation.tr("Tools (/tool)") },
                        { icon: Ai.currentModelHasApiKey ? "key" : "key_alert", popover: "keys", active: root.activePopover === "keys", tooltip: Translation.tr("Keys (/key)") }
                    ]
                }

                RippleButton {
                    required property var modelData
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    colBackground: modelData.active ? Appearance.colors.colLayer2 : ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: {
                        if (modelData.popover === "") {
                            Ai.newChat();
                            root.closePopovers();
                            root.requestFocusComposer();
                        } else {
                            root.openPopover(modelData.popover);
                        }
                    }

                    contentItem: MaterialSymbol {
                        text: modelData.icon
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledToolTip {
                        text: modelData.tooltip
                    }
                }
            }
        }

        // ── Attachment tray ──────────────────────────────────

        AttachmentTray {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            visible: Ai.attachments.length > 0 || Ai.attachmentNotice.length > 0
        }

        // ── Transcript / Empty state ──────────────────────────

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                anchors.margins: 20
                width: Math.min(parent.width - 40, 480)
                spacing: 14
                visible: root.visibleMessageIds.length === 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "auto_awesome"
                    iconSize: Math.round(Appearance.font.pixelSize.huge * 1.6)
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("How can I help you?")
                    font.pixelSize: Math.round(Appearance.font.pixelSize.huge * 1.1)
                    color: Appearance.colors.colOnLayer1
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Repeater {
                        model: ScriptModel {
                            values: (Ai.starters ?? []).slice(0, 4)
                        }

                        RippleButton {
                            id: starterChip
                            required property var modelData
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer2
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            colRipple: Appearance.colors.colLayer2Active
                            onClicked: {
                                Ai.sendUserMessage(starterChip.modelData);
                                root.requestFocusComposer();
                            }

                            contentItem: StyledText {
                                text: starterChip.modelData
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }
            }

            // Message list
            ListView {
                id: messageList
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                spacing: 10
                visible: root.visibleMessageIds.length > 0
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                model: ScriptModel {
                    values: root.visibleMessageIds
                }

                delegate: AiChatPanelMessage {
                    messageId: modelData
                    messageData: Ai.messageByID[modelData]
                }

                property bool following: true
                onCountChanged: {
                    if (following)
                        Qt.callLater(() => messageList.positionViewAtEnd());
                }
                onContentHeightChanged: {
                    if (following)
                        positionViewAtEnd();
                }
                onMovingChanged: {
                    if (!moving)
                        following = atYEnd;
                }
                onHeightChanged: {
                    if (following)
                        positionViewAtEnd();
                }
            }

            ScrollToBottomButton {
                target: messageList
                shown: messageList.visible && !messageList.atYEnd && messageList.contentHeight > messageList.height
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // ── Bottom composer bar ──────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            spacing: 6

            // Model chip
            RippleButton {
                Layout.alignment: Qt.AlignVCenter
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.openPopover("model")

                contentItem: RowLayout {
                    spacing: 4

                    MaterialSymbol {
                        text: "auto_awesome"
                        iconSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.maximumWidth: 120
                        text: Ai.currentModelEntry?.title ?? Ai.currentModelId
                        elide: Text.ElideMiddle
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: "expand_more"
                        iconSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colSubtext
                    }
                }

                StyledToolTip {
                    text: Translation.tr("Model (/model)")
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Attach button
            RippleButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: attachPicker.running = true

                contentItem: MaterialSymbol {
                    text: "attach_file"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer2
                }

                StyledToolTip {
                    text: Translation.tr("Attach files")
                }
            }

            // Send / Stop button
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 40
                implicitHeight: 40
                radius: Appearance.rounding.full
                color: Ai.isGenerating ? Appearance.colors.colLayer2 : Appearance.colors.colPrimary

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: Ai.isGenerating ? "stop" : "arrow_upward"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Ai.isGenerating ? Appearance.colors.colOnLayer2 : Appearance.m3colors.m3onPrimary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Ai.isGenerating) {
                            Ai.stopGeneration();
                        } else {
                            root.requestSendMessage();
                        }
                    }
                }

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }

        // ── Popovers ──────────────────────────────────────────

        Rectangle {
            anchors.fill: parent
            visible: root.activePopover !== ""
            color: "transparent"
            z: 10

            MouseArea {
                anchors.fill: parent
                onClicked: root.closePopovers()
            }
        }

        Rectangle {
            id: popoverSurface
            visible: root.activePopover !== ""
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 48
            anchors.rightMargin: 8
            width: Math.min(parent.width - 16, 380)
            height: Math.min(parent.height - 60, popoverContent.implicitHeight + 20)
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerHigh
            z: 11

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            ColumnLayout {
                id: popoverContent
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Model picker
                ScrollView {
                    visible: root.activePopover === "model"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: popoverSurface.width - 20
                        spacing: 8

                        MaterialTextField {
                            id: modelSearch
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Search models...")
                        }

                        ModelPickerPopover {
                            Layout.fillWidth: true
                            query: modelSearch.text
                            maxListHeight: popoverSurface.height - 120
                            onPicked: modelId => {
                                Ai.setModel(modelId, false);
                                root.closePopovers();
                                root.requestFocusComposer();
                            }
                        }
                    }
                }

                ToolsPopover {
                    visible: root.activePopover === "tools"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onClosed: {
                        if (root.activePopover === "tools")
                            root.activePopover = "";
                    }
                }

                ApiKeyManager {
                    visible: root.activePopover === "keys"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onClosed: {
                        if (root.activePopover === "keys")
                            root.activePopover = "";
                    }
                }

                // Session history
                ScrollView {
                    visible: root.activePopover === "sessions"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: sessionList
                        width: popoverSurface.width - 20
                        implicitHeight: contentHeight
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds

                        model: ScriptModel {
                            values: {
                                const entries = Array.from(Ai.sessions?.index ?? []);
                                entries.sort((a, b) => {
                                    if ((b.pinned ?? false) !== (a.pinned ?? false))
                                        return (b.pinned ?? false) ? 1 : -1;
                                    return String(b.updatedAt ?? "").localeCompare(String(a.updatedAt ?? ""));
                                });
                                return entries;
                            }
                        }

                        delegate: RippleButton {
                            id: sessionEntry
                            required property var modelData
                            width: sessionList.width
                            implicitHeight: sessionColumn.implicitHeight + 12
                            buttonRadius: Appearance.rounding.small
                            colBackground: Ai.sessions?.currentId === modelData.id ? Appearance.colors.colSecondaryContainer : ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            colRipple: Appearance.colors.colLayer2Active
                            onClicked: {
                                Ai.openSession(modelData.id);
                                root.closePopovers();
                                root.requestFocusComposer();
                            }

                            contentItem: ColumnLayout {
                                id: sessionColumn
                                spacing: 2

                                RowLayout {
                                    spacing: 6

                                    MaterialSymbol {
                                        visible: sessionEntry.modelData.pinned ?? false
                                        text: "push_pin"
                                        iconSize: Appearance.font.pixelSize.smallie
                                        color: Appearance.colors.colSubtext
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: sessionEntry.modelData.title ?? Translation.tr("Untitled")
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnLayer2
                                    }

                                    StyledText {
                                        text: String(sessionEntry.modelData.messageCount ?? 0)
                                        font.pixelSize: Appearance.font.pixelSize.smallie
                                        color: Appearance.colors.colSubtext
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: (sessionEntry.modelData.preview ?? "").length > 0
                                    text: sessionEntry.modelData.preview ?? ""
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
