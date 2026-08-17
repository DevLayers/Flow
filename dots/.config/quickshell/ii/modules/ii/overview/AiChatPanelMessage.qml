pragma ComponentBehavior: Bound

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

/**
 * One message, minimal: user turns are pills docked right, assistant turns
 * are plain content blocks anchored left — no bubble, no background — so long
 * answers read like a document instead of a wall of cards.
 */
ColumnLayout {
    id: root

    required property string messageId
    required property var messageData

    readonly property bool isUser: root.messageData?.role === "user"
    readonly property var messageBlocks: AiTranscriptRegistry.blocksFor(root.messageData)
    readonly property var sentFiles: Array.from(root.messageData?.attachments ?? [])
    readonly property bool actionFocused: copyButton.activeFocus || regenerateButton.activeFocus

    focus: false
    activeFocusOnTab: true
    Accessible.name: root.isUser
        ? Translation.tr("Your message: %1").arg(String(root.messageData?.content ?? ""))
        : Translation.tr("Assistant response")

    spacing: 4
    Layout.fillWidth: true

    // ---- User turn ---------------------------------------------------------

    RowLayout {
        visible: root.isUser
        Layout.fillWidth: true
        spacing: 6

        Item {
            Layout.fillWidth: true
        }

        ColumnLayout {
            visible: root.sentFiles.length > 0
            spacing: 3
            Layout.alignment: Qt.AlignRight

            Repeater {
                model: ScriptModel {
                    values: root.sentFiles
                }

                Rectangle {
                    required property var modelData
                    implicitWidth: attachmentRow.implicitWidth + 16
                    implicitHeight: attachmentRow.implicitHeight + 8
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: attachmentRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: modelData.kind === "image" ? "image"
                                : modelData.kind === "video" ? "movie"
                                : modelData.kind === "text" ? "description"
                                : "file_present"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.maximumWidth: 200
                            text: modelData.name ?? ""
                            elide: Text.ElideMiddle
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    StyledToolTip {
                        text: `${modelData.path ?? ""}\n${Ai.humanSize(modelData.bytes ?? 0)}`
                    }
                }
            }
        }

        Rectangle {
            id: userBubble
            visible: root.isUser
            Layout.maximumWidth: Math.min(parent?.width * 0.78 ?? 400, userText.implicitWidth + 28)
            implicitWidth: Math.min(parent?.width * 0.78 ?? 400, Math.max(120, userText.implicitWidth + 28))
            implicitHeight: userText.implicitHeight + 20
            radius: Appearance.rounding.large
            color: Appearance.colors.colPrimaryContainer

            StyledText {
                id: userText
                anchors.fill: parent
                anchors.margins: 10
                text: root.messageData?.content ?? ""
                wrapMode: Text.Wrap
                textFormat: Text.MarkdownText
                color: Appearance.colors.colOnPrimaryContainer
            }
        }
    }

    // ---- Assistant turn ----------------------------------------------------

    ColumnLayout {
        visible: !root.isUser
        Layout.fillWidth: true
        spacing: root.contentSpacing

        property real contentSpacing: 3

        Loader {
            Layout.fillWidth: true
            active: (root.messageData?.thought?.length ?? 0) > 0
            sourceComponent: AiMessageThinkBlock {
                messageData: root.messageData
                done: root.messageData?.done ?? false
                thoughtText: root.messageData?.thought ?? ""
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

            FadeLoader {
                id: loadingIndicatorLoader
                anchors.centerIn: parent
                shown: (root.messageBlocks.length < 1) && ((root.messageData?.thought?.length ?? 0) === 0) && !(root.messageData?.done ?? false)
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
                role: "type"

                DelegateChoice {
                    roleValue: "code"
                    AiMessageCodeBlock {
                        segmentContent: modelData.content
                        segmentLang: modelData.lang
                        messageData: root.messageData
                    }
                }
                DelegateChoice {
                    roleValue: "think"
                    AiMessageThinkBlock {
                        segmentContent: modelData.content
                        messageData: root.messageData
                        done: root.messageData?.done ?? false
                        completed: modelData.completed ?? false
                    }
                }
                DelegateChoice {
                    roleValue: "text"
                    AiMessageTextBlock {
                        segmentContent: modelData.content
                        messageData: root.messageData
                        done: root.messageData?.done ?? false
                        forceDisableChunkSplitting: root.messageData?.content.includes("```") ?? true
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: (root.messageData?.pendingChanges?.length ?? 0) > 0 && (root.messageData?.functionPending ?? false)
            visible: active
            sourceComponent: AiConfigDiffCard {
                messageData: root.messageData
            }
        }

        Loader {
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RippleButton {
                            visible: (root.messageData?.errorKind ?? "") === "auth"
                            leftPadding: 12
                            rightPadding: 12
                            topPadding: 5
                            bottomPadding: 5
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer2
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            colRipple: Appearance.colors.colLayer2Active
                            onClicked: Ai.keyManagerRequested()

                            contentItem: StyledText {
                                text: Translation.tr("Keys")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer2
                            }
                        }

                        Item {
                            Layout.fillWidth: true
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
            Layout.fillWidth: true
            active: (root.messageData?.notice ?? "") === "apiKey"
            visible: active

            sourceComponent: RippleButton {
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

        Flow {
            visible: root.messageData?.annotationSources?.length > 0
            spacing: 5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft

            Repeater {
                model: ScriptModel {
                    values: root.messageData?.annotationSources || []
                }
                delegate: AiAnnotationSourceButton {
                    required property var modelData
                    displayText: modelData.text
                    url: modelData.url
                }
            }
        }

        Flow {
            visible: root.messageData?.searchQueries?.length > 0
            spacing: 5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft

            Repeater {
                model: ScriptModel {
                    values: root.messageData?.searchQueries || []
                }
                delegate: AiSearchQueryButton {
                    required property var modelData
                    query: modelData
                }
            }
        }
    }

    // ---- Quiet actions under the turn --------------------------------------

    RowLayout {
        Layout.fillWidth: true
        spacing: 2
        opacity: messageHover.hovered || root.actionFocused ? 1.0 : 0.0
        visible: opacity > 0 || root.actionFocused

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        HoverHandler {
            id: messageHover
            blocking: false
        }

        Item {
            Layout.fillWidth: !root.isUser
            visible: !root.isUser
        }

        RippleButton {
            id: copyButton
            buttonRadius: Appearance.rounding.full
            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active

            contentItem: MaterialSymbol {
                text: "content_copy"
                iconSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
            }
            onClicked: {
                AiOutputController.copyText(root.messageData?.content ?? "");
            }

            Accessible.name: Translation.tr("Copy message")
        }

        RippleButton {
            id: regenerateButton
            visible: !root.isUser && (root.messageData?.done ?? false)
            buttonRadius: Appearance.rounding.full
            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active
            onClicked: Ai.regenerate(root.messageId)

            Accessible.name: Translation.tr("Regenerate response")

            contentItem: MaterialSymbol {
                text: "refresh"
                iconSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
            }
        }

        Item {
            Layout.fillWidth: root.isUser
            visible: root.isUser
        }
    }
}
