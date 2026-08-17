pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Keyboard-first composer for the overview AI surface.
 *
 * The overview search field is intentionally not reused here: a launcher
 * query is single-line and ephemeral, while a chat draft is multiline and
 * belongs to the current persisted AI session. The composer therefore writes
 * only to Ai.draft and lets the submit pipeline clear it after its durable
 * checkpoint is acknowledged.
 */
ColumnLayout {
    id: root

    signal requestSend
    signal requestEscape
    signal requestModels
    signal requestHistory
    signal requestTools
    signal requestNewChat

    readonly property int maximumLines: 6
    readonly property int maximumCharacters: 12000
    readonly property real lineHeight: Math.max(22, draftInput.font.pixelSize * 1.45)
    readonly property real maximumEditorHeight: root.lineHeight * root.maximumLines + 18
    readonly property bool hasDraft: draftInput.text.trim().length > 0
    property bool syncingDraft: false

    Layout.fillWidth: true
    implicitHeight: composerSurface.implicitHeight

    function setDraft(value) {
        root.syncingDraft = true;
        draftInput.text = String(value ?? "");
        root.syncingDraft = false;
    }

    function focusInput() {
        draftInput.forceActiveFocus();
        draftInput.cursorPosition = draftInput.length;
    }

    function cycleResponseMode() {
        const modes = ["fast", "balanced", "deep"];
        const index = modes.indexOf(Ai.responseMode);
        Ai.setResponseMode(modes[(index + 1 + modes.length) % modes.length], false);
    }

    function cycleWebMode() {
        const modes = ["off", "auto", "on"];
        const index = modes.indexOf(Ai.webMode);
        Ai.setWebMode(modes[(index + 1 + modes.length) % modes.length], false);
    }

    function cycleFunctionExposure() {
        const modes = ["none", "safe", "all"];
        const index = modes.indexOf(Ai.functionExposure);
        Ai.setFunctionExposure(modes[(index + 1 + modes.length) % modes.length], false);
    }

    function pasteClipboard() {
        const value = String(Quickshell.clipboardText ?? "");
        if (value.length === 0)
            return;
        const next = (draftInput.text.slice(0, draftInput.cursorPosition) + value + draftInput.text.slice(draftInput.cursorPosition)).slice(0, root.maximumCharacters);
        root.setDraft(next);
        Ai.draft = next;
        root.focusInput();
    }

    Connections {
        target: Ai
        function onDraftChanged() {
            if (draftInput.text !== Ai.draft)
                root.setDraft(Ai.draft);
        }
    }

    Component.onCompleted: root.setDraft(Ai.draft)

    MaterialShape {
        id: composerSurface
        Layout.fillWidth: true
        implicitHeight: composerColumn.implicitHeight + 24
        color: Appearance.colors.colLayer1
        shape: MaterialShape.Shape.SoftBoom

        ColumnLayout {
            id: composerColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: ScriptModel {
                        values: [
                            { id: "model", icon: "auto_awesome", label: Ai.currentModelEntry?.title ?? Ai.currentModelId },
                            { id: "response", icon: "speed", label: Translation.tr("%1 response").arg(Ai.responseMode) },
                            { id: "web", icon: "travel_explore", label: Translation.tr("Web %1").arg(Ai.webMode) },
                            { id: "tools", icon: "construction", label: Translation.tr("Tools %1").arg(Ai.functionExposure) }
                        ]
                    }

                    RippleButton {
                        id: profileButton
                        required property var modelData
                        buttonRadius: Appearance.rounding.full
                        colBackground: profileButton.modelData.id === "web" && Ai.webMode === "on"
                            ? Appearance.colors.colPrimaryContainer
                            : Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: {
                            switch (profileButton.modelData.id) {
                            case "model": root.requestModels(); break;
                            case "response": root.cycleResponseMode(); break;
                            case "web": root.cycleWebMode(); break;
                            case "tools": root.cycleFunctionExposure(); break;
                            }
                        }

                        Accessible.name: profileButton.modelData.label
                        Accessible.description: profileButton.modelData.id === "model"
                            ? Translation.tr("Open model selection")
                            : Translation.tr("Change %1").arg(profileButton.modelData.label)

                        contentItem: RowLayout {
                            spacing: 5

                            MaterialSymbol {
                                text: profileButton.modelData.icon
                                iconSize: Appearance.font.pixelSize.smallie
                                color: profileButton.modelData.id === "web" && Ai.webMode === "on"
                                    ? Appearance.m3colors.m3onPrimaryContainer
                                    : Appearance.colors.colOnLayer2
                            }

                            StyledText {
                                text: profileButton.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: profileButton.modelData.id === "web" && Ai.webMode === "on"
                                    ? Appearance.m3colors.m3onPrimaryContainer
                                    : Appearance.colors.colOnLayer2
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                            }
                        }

                        StyledToolTip {
                            text: profileButton.modelData.id === "response"
                                ? Translation.tr("Cycle response mode")
                                : profileButton.modelData.id === "web"
                                    ? Translation.tr("Cycle web mode")
                                    : profileButton.modelData.id === "tools"
                                        ? Translation.tr("Cycle tool exposure")
                                        : Translation.tr("Open model page")
                        }
                    }
                }

                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 32
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: root.requestHistory()

                    Accessible.name: Translation.tr("Chat history")

                    contentItem: MaterialSymbol {
                        text: "history"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledToolTip { text: Translation.tr("History") }
                }

                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 32
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: {
                        Ai.newChat();
                        root.requestNewChat();
                    }

                    Accessible.name: Translation.tr("New chat")

                    contentItem: MaterialSymbol {
                        text: "add_comment"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledToolTip { text: Translation.tr("New chat") }
                }
            }

            StyledTextArea {
                id: draftInput
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(44, Math.min(root.maximumEditorHeight, contentHeight + 18))
                implicitHeight: Layout.preferredHeight
                color: Appearance.colors.colOnLayer1
                placeholderText: Translation.tr("Ask AI anything…")
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                selectByMouse: true
                persistentSelection: true
                maximumLength: root.maximumCharacters
                background: Item {}
                Accessible.name: Translation.tr("AI message")
                Accessible.description: Translation.tr("Multiline draft. Enter sends; Shift+Enter inserts a line break.")

                onTextChanged: {
                    if (!root.syncingDraft)
                        Ai.draft = text;
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.requestEscape();
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                        root.requestSend();
                        event.accepted = true;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 34
                    buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: root.pasteClipboard()

                    Accessible.name: Translation.tr("Paste clipboard")

                    contentItem: MaterialSymbol {
                        text: "content_paste"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledToolTip { text: Translation.tr("Paste clipboard") }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: draftInput.length > 0 ? Translation.tr("%1 characters").arg(String(draftInput.length)) : Translation.tr("Shift+Enter for a new line")
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }

                RippleButton {
                    implicitWidth: 42
                    implicitHeight: 42
                    buttonRadius: Appearance.rounding.full
                    colBackground: Ai.isGenerating ? Appearance.colors.colLayer2 : Appearance.colors.colPrimary
                    colBackgroundHover: Ai.isGenerating ? Appearance.colors.colLayer2Hover : Appearance.colors.colPrimaryHover
                    colRipple: Ai.isGenerating ? Appearance.colors.colLayer2Active : Appearance.colors.colPrimaryActive
                    enabled: Ai.isGenerating || root.hasDraft
                    onClicked: {
                        if (Ai.isGenerating)
                            Ai.stopGeneration();
                        else
                            root.requestSend();
                    }

                    Accessible.name: Ai.isGenerating ? Translation.tr("Stop response") : Translation.tr("Send message")
                    Accessible.description: Ai.isGenerating ? Translation.tr("Stop the active response") : Translation.tr("Send the current draft")

                    contentItem: MaterialSymbol {
                        text: Ai.isGenerating ? "stop" : "arrow_upward"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Ai.isGenerating ? Appearance.colors.colOnLayer2 : Appearance.m3colors.m3onPrimary
                    }

                    StyledToolTip {
                        text: Ai.isGenerating ? Translation.tr("Stop response") : Translation.tr("Send message (Enter)")
                    }

                    Behavior on colBackground {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }
            }
        }
    }
}
