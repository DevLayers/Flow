pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/**
 * Personas, prompt files, and this chat's own prompt.
 *
 * A persona is a way of answering saved whole — prompt, model, thinking,
 * temperature — so picking one sets all of it at once. What used to be here
 * was a list of prompt file paths, which said nothing about what any of them
 * would do.
 *
 * The prompt view shows the prompt as the model will receive it, with
 * {DISTRO}, {DE}, {DATETIME} and {WINDOWCLASS} already filled in: the
 * substitutions were invisible until the answer came back strange.
 */
Item {
    id: root

    signal closed

    /** "list" or "prompt". */
    property string view: "list"

    readonly property var personas: Ai.personas.all
    readonly property string activeId: Ai.personas.currentId

    implicitHeight: root.view === "prompt" ? promptLoader.implicitHeight : listColumnLayout.implicitHeight

    component SectionHeading: StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 4
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }

    component EntryRow: RippleButton {
        id: entryRow

        property string symbol: ""
        property string label: ""
        property string sublabel: ""
        property bool selected: false
        property bool deletable: false

        signal deleteRequested

        Layout.fillWidth: true
        leftPadding: 10
        rightPadding: 6
        topPadding: 8
        bottomPadding: 8
        buttonRadius: Appearance.rounding.small
        toggled: entryRow.selected
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover

        contentItem: RowLayout {
            spacing: 10

            MaterialSymbol {
                visible: entryRow.symbol.length > 0
                text: entryRow.symbol
                iconSize: Appearance.font.pixelSize.larger
                color: entryRow.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: entryRow.label
                    elide: Text.ElideRight
                    color: entryRow.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: entryRow.sublabel.length > 0
                    text: entryRow.sublabel
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            RippleButton {
                visible: entryRow.deletable
                implicitWidth: 26
                implicitHeight: 26
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: entryRow.deleteRequested()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "delete"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer2
                }

                StyledToolTip {
                    text: Translation.tr("Delete this persona")
                }
            }

            MaterialSymbol {
                visible: entryRow.selected
                text: "check"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.m3colors.m3onSecondaryContainer
            }
        }
    }

    ColumnLayout {
        id: listColumnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.view === "list"
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("How should it answer?")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            RippleButton {
                leftPadding: 10
                rightPadding: 10
                topPadding: 5
                bottomPadding: 5
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.view = "prompt"

                contentItem: RowLayout {
                    spacing: 5

                    MaterialSymbol {
                        text: "edit_note"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        text: Translation.tr("This chat's prompt")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
        }

        StyledFlickable {
            Layout.fillWidth: true
            implicitHeight: Math.min(entriesColumnLayout.implicitHeight, 320)
            contentWidth: width
            contentHeight: entriesColumnLayout.implicitHeight
            clip: true

            ColumnLayout {
                id: entriesColumnLayout
                width: parent.width
                spacing: 2

                EntryRow {
                    symbol: "chat"
                    label: Translation.tr("No persona")
                    sublabel: Translation.tr("The prompt from the settings")
                    selected: root.activeId.length === 0
                    onClicked: {
                        Ai.setPersona("", false);
                        root.closed();
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: root.personas
                    }

                    delegate: EntryRow {
                        id: personaRow
                        required property var modelData

                        symbol: personaRow.modelData.icon ?? "person"
                        label: personaRow.modelData.name ?? personaRow.modelData.id
                        sublabel: {
                            const description = personaRow.modelData.description ?? "";
                            if (!personaRow.selected || !Ai.personaModified)
                                return description;
                            return Translation.tr("%1 — changed since").arg(description);
                        }
                        selected: root.activeId === personaRow.modelData.id
                        deletable: Ai.personas.isCustom(personaRow.modelData.id)
                        onDeleteRequested: Ai.personas.remove(personaRow.modelData.id)
                        onClicked: {
                            Ai.setPersona(personaRow.modelData.id, false);
                            root.closed();
                        }
                    }
                }

                SectionHeading {
                    visible: Ai.promptFiles.length > 0
                    text: Translation.tr("Prompt files")
                }

                Repeater {
                    model: ScriptModel {
                        values: Ai.promptFiles
                    }

                    delegate: EntryRow {
                        id: promptRow
                        required property var modelData

                        symbol: "description"
                        label: String(promptRow.modelData).split("/").pop().replace(/\.(md|txt|prompt)$/i, "")
                        sublabel: Translation.tr("Give this chat the prompt in this file")
                        selected: Ai.currentPromptFile === promptRow.modelData
                        onClicked: {
                            Ai.loadPrompt(promptRow.modelData, false);
                            root.closed();
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: promptLoader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        active: root.view === "prompt"
        visible: active

        sourceComponent: ColumnLayout {
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: root.view = "list"

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "arrow_back"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer2
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("What this chat tells the model")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 150
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                StyledFlickable {
                    id: promptFlickable
                    anchors.fill: parent
                    anchors.margins: 10
                    contentWidth: width
                    contentHeight: promptInput.implicitHeight
                    clip: true

                    StyledTextArea {
                        id: promptInput
                        width: promptFlickable.width
                        wrapMode: TextArea.Wrap
                        padding: 0
                        background: null
                        color: Appearance.colors.colOnLayer2
                        placeholderText: Translation.tr("Leave empty to use the persona's own prompt")
                        text: Ai.promptOverride.length > 0 ? Ai.promptOverride : Ai.basePrompt
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Sent as: %1").arg(Ai.substituted(promptInput.text).split("\n").filter(line => line.trim().length > 0).slice(0, 2).join(" · "))
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                RippleButton {
                    visible: Ai.promptOverride.length > 0
                    leftPadding: 12
                    rightPadding: 12
                    topPadding: 6
                    bottomPadding: 6
                    buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: {
                        Ai.setPromptOverride("", false);
                        root.closed();
                    }

                    contentItem: StyledText {
                        text: Translation.tr("Back to the usual one")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                RippleButton {
                    leftPadding: 14
                    rightPadding: 14
                    topPadding: 6
                    bottomPadding: 6
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    onClicked: {
                        Ai.setPromptOverride(promptInput.text, false);
                        root.closed();
                    }

                    contentItem: StyledText {
                        text: Translation.tr("Use for this chat")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onPrimary
                    }
                }
            }
        }
    }
}
