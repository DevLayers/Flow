import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.configs.ai
import qs.modules.ii.usage

/**
 * The AI settings page.
 *
 * A dashboard, not a manual: what a user touches day to day (model list,
 * answer animation, system prompt) stays here, while everything that is set
 * once and left alone lives behind two entry buttons — custom models get a
 * form-driven sub-page instead of the raw JSON array, and tools, requests
 * and attachments share the advanced sub-page. Keys are deliberately still
 * absent: they belong in the chat's key panel, next to the model that needs
 * one.
 */
Item {
    id: aiRoot
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

        ContentSection {
            icon: "monitoring"
            title: Translation.tr("Usage overview")
            customBackgroundColor: Appearance.colors.colLayer0

            AiUsageDashboard {
                Layout.fillWidth: true
            }
        }

        ContentSection {
            icon: "neurology"
            title: Translation.tr("AI Assistant")

            HelperLinkBox {
                Layout.fillWidth: true
                title: Translation.tr("Google AI Studio")
                text: Translation.tr("Get your Gemini API Key here for free. Keys are entered from the key panel in the chat, and kept in the system keyring.")
                isFirst: true

                RippleButtonWithIcon {
                    mainText: Translation.tr("Open Website")
                    materialIcon: "open_in_new"
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    colBackground: Appearance.colors.colLayer0
                    colBackgroundHover: Appearance.colors.colLayer0Hover
                    colRipple: Appearance.colors.colLayer0Active
                    downAction: () => {
                        Qt.openUrlExternally("https://aistudio.google.com/app/apikey");
                    }
                }
            }

            ConfigSwitch {
                buttonIcon: "smart_toy"
                text: Translation.tr("List available models at startup")
                checked: Config.options.ai.indexAtStartup
                onCheckedChanged: {
                    Config.options.ai.indexAtStartup = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "text_fields"
                text: Translation.tr("Fade answers in as they arrive")
                checked: Config.options.sidebar.ai.textFadeIn
                onCheckedChanged: {
                    Config.options.sidebar.ai.textFadeIn = checked;
                }
            }
        }

        ContentSection {
            icon: "extension"
            title: Translation.tr("Models & advanced")

            SubPageEntryButton {
                entryIcon: "dataset"
                entryTitle: Translation.tr("Custom models")
                entryDescription: Translation.tr("Add models from any provider or your own endpoint to the picker")
                entryAccent: Appearance.colors.colPrimary
                entryOnAccent: Appearance.colors.colOnPrimary
                entryContainer: Appearance.colors.colPrimaryContainer
                entryContainerHover: Appearance.colors.colPrimaryContainerHover
                entryContainerActive: Appearance.colors.colPrimaryContainerActive
                entryOnContainer: Appearance.colors.colOnPrimaryContainer
                onClicked: aiRoot.activeSubPage = Qt.resolvedUrl("ai/CustomModelsConfig.qml")
            }

            SubPageEntryButton {
                entryIcon: "tune"
                entryTitle: Translation.tr("Advanced settings")
                entryDescription: Translation.tr("Tool permissions, request limits and attachments")
                entryAccent: Appearance.colors.colTertiary
                entryOnAccent: Appearance.colors.colOnTertiary
                entryContainer: Appearance.colors.colTertiaryContainer
                entryContainerHover: Appearance.colors.colTertiaryContainerHover
                entryContainerActive: Appearance.colors.colTertiaryContainerActive
                entryOnContainer: Appearance.colors.colOnTertiaryContainer
                onClicked: aiRoot.activeSubPage = Qt.resolvedUrl("ai/AdvancedAiConfig.qml")
            }
        }

        ContentSection {
            icon: "description"
            title: Translation.tr("System Prompt")

            TipBox {
                Layout.fillWidth: true
                text: Translation.tr("A persona replaces this while it is picked. This is what the assistant falls back to.")
            }

            // Height-capped so a long prompt cannot stretch the page: past the
            // cap the text scrolls inside the field instead of growing it.
            ScrollView {
                id: promptScroll
                Layout.fillWidth: true
                implicitHeight: Math.min(systemPromptArea.implicitHeight, 240)
                clip: true

                ScrollBar.vertical: ScrollBar {
                    id: promptScrollBar
                    policy: ScrollBar.AsNeeded
                    opacity: size < 1 ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2Active
                    }
                }

                MaterialTextArea {
                    id: systemPromptArea
                    width: promptScroll.width
                    placeholderText: Translation.tr("System prompt")
                    text: Config.options.ai.systemPrompt
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Qt.callLater(() => {
                            Config.options.ai.systemPrompt = text;
                        });
                    }
                }
            }
        }

        ContentSection {
            icon: "privacy_tip"
            title: Translation.tr("Privacy & context")

            TipBox {
                Layout.fillWidth: true
                text: Translation.tr("Clipboard text, a launcher result, and active-app metadata are sent only when you attach them in the composer. Each attachment shows its source, size, destination, and a remove action before sending.")
            }

            TipBox {
                Layout.fillWidth: true
                text: String(Config.options.ai.systemPrompt ?? "").includes("{WINDOWCLASS}")
                    ? Translation.tr("Your system prompt currently includes {WINDOWCLASS}; it is replaced with the active application's class on every request.")
                    : Translation.tr("Your system prompt does not include active-window metadata.")
            }

            RippleButton {
                Layout.fillWidth: true
                visible: String(Config.options.ai.systemPrompt ?? "").includes("{WINDOWCLASS}")
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: Config.options.ai.systemPrompt = String(Config.options.ai.systemPrompt ?? "").replace("{WINDOWCLASS}", "")

                contentItem: RowLayout {
                    spacing: 8

                    MaterialSymbol {
                        text: "visibility_off"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnSecondaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Remove active-window metadata from the prompt")
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }
    }

    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }

    component SubPageEntryButton: RippleButton {
        id: entryButton

        property string entryIcon: ""
        property string entryTitle: ""
        property string entryDescription: ""
        property color entryAccent: Appearance.colors.colPrimary
        property color entryOnAccent: Appearance.colors.colOnPrimary
        property color entryContainer: Appearance.colors.colPrimaryContainer
        property color entryContainerHover: Appearance.colors.colPrimaryContainerHover
        property color entryContainerActive: Appearance.colors.colPrimaryContainerActive
        property color entryOnContainer: Appearance.colors.colOnPrimaryContainer

        Layout.fillWidth: true
        implicitHeight: entryRow.implicitHeight + 32
        buttonRadius: Appearance.rounding.full
        colBackground: entryButton.entryContainer
        colBackgroundHover: entryButton.entryContainerHover
        colBackgroundActive: entryButton.entryContainerActive
        colRipple: entryButton.entryContainerActive

        contentItem: RowLayout {
            id: entryRow
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: entryButton.entryIcon
                shape: MaterialShape.Shape.Circle
                iconSize: Appearance.font.pixelSize.large
                padding: 8
                color: entryButton.entryAccent
                colSymbol: entryButton.entryOnAccent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: entryButton.entryTitle
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: entryButton.entryOnContainer
                }

                StyledText {
                    Layout.fillWidth: true
                    text: entryButton.entryDescription
                    wrapMode: Text.WordWrap
                    color: entryButton.entryOnContainer
                    opacity: 0.82
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "arrow_forward"
                iconSize: Appearance.font.pixelSize.large
                color: entryButton.entryOnContainer
            }
        }
    }
}
