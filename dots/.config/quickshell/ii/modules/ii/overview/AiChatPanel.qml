pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.services.ai
import qs.services.ai.blocks
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

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
AiSearchSurface {
    id: root

    signal requestBackToSearch()
    signal requestFocusComposer()
    signal requestSendMessage()
    signal requestContinueInSidebar()

    implicitWidth: parent ? parent.width : 720
    implicitHeight: chatColumn.implicitHeight

    function focusComposer() {
        composer.focusInput();
    }

    readonly property var visibleMessageIds: Ai.messageIDs.filter(id => {
        const m = Ai.messageByID[id];
        return m && m.role !== Ai.interfaceRole && (m.visibleToUser ?? true);
    })

    Connections {
        target: Ai
        function onKeyManagerRequested() {
            root.navigateTo("keys");
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
        id: chatColumn
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
                        { icon: "auto_awesome", page: "models", active: root.navigator.currentPage === "models", tooltip: Translation.tr("Models") },
                        { icon: "add_comment", page: "", active: false, tooltip: Translation.tr("New chat (/new)") },
                        { icon: "history", page: "history", active: root.navigator.currentPage === "history", tooltip: Translation.tr("History (/sessions)") },
                        { icon: "construction", page: "tools", active: root.navigator.currentPage === "tools", tooltip: Translation.tr("Tools (/tool)") },
                        { icon: Ai.currentModelHasApiKey ? "key" : "key_alert", page: "keys", active: root.navigator.currentPage === "keys", tooltip: Translation.tr("Keys (/key)") }
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
                        if (modelData.page === "") {
                            Ai.newChat();
                            root.requestFocusComposer();
                        } else {
                            root.navigateTo(modelData.page);
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

        AiAttachmentTray {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            visible: Ai.attachments.length > 0 || Ai.attachmentNotice.length > 0
        }

        // ── Transcript / Empty state ──────────────────────────

        Item {
            id: transcriptSurface
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: root.visibleMessageIds.length > 0
                ? Math.min(420, Math.max(120, messageList.contentHeight))
                : 0
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
                        following = AiTranscriptRegistry.shouldFollow(contentY, height, contentHeight);
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

        AiSearchComposer {
            id: composer
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            onRequestSend: root.requestSendMessage()
            onRequestEscape: root.requestBackToSearch()
            onRequestModels: root.navigateTo("models")
            onRequestHistory: root.navigateTo("history")
            onRequestTools: root.navigateTo("tools")
            onRequestNewChat: root.requestFocusComposer()
        }

    }
}
