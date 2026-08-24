pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Which program a shortcut opens, and what it falls back to.
 *
 * These are not one command but a list tried in order: the first one that is installed runs.
 * That is what makes a config portable, and also what makes it surprising - installing a second
 * terminal can quietly take Super+Return away from the first, which is exactly what happened
 * here once. So the list is shown in order, each entry says whether it is installed, and the one
 * that would actually run is named at the top.
 */
Item {
    id: subPageRoot
    anchors.fill: parent

    signal goBack
    property bool showBackButton: false

    readonly property string name: HyprlandBinds.editApp
    readonly property var entry: HyprlandBinds.appEntry(subPageRoot.name)
    readonly property string value: HyprlandBinds.appValue(subPageRoot.name)
    readonly property var chain: HyprlandBinds.readChain(subPageRoot.value)
    readonly property string source: HyprlandBinds.appSource(subPageRoot.name)
    readonly property string winner: HyprlandBinds.winningCandidate(subPageRoot.chain.candidates)

    function commit(candidates: var) {
        HyprlandBinds.saveApp(subPageRoot.name,
            HyprlandBinds.writeChain(subPageRoot.chain.prefix, candidates));
    }

    function move(index: int, delta: int) {
        const list = Array.from(subPageRoot.chain.candidates);
        const target = index + delta;
        if (target < 0 || target >= list.length) return;
        const moved = list[index];
        list[index] = list[target];
        list[target] = moved;
        subPageRoot.commit(list);
    }

    function drop(index: int) {
        const list = Array.from(subPageRoot.chain.candidates);
        list.splice(index, 1);
        subPageRoot.commit(list);
    }

    function add(candidate: string) {
        const text = String(candidate ?? "").trim();
        if (text === "") return;
        subPageRoot.commit(Array.from(subPageRoot.chain.candidates).concat([text]));
    }

    component RowButton: RippleButton {
        id: rowButton

        property string buttonIcon: ""

        implicitWidth: 34
        implicitHeight: 34
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active

        MaterialSymbol {
            anchors.centerIn: parent
            text: rowButton.buttonIcon
            iconSize: 18
            color: Appearance.colors.colSubtext
            opacity: rowButton.enabled ? 1 : 0.3
        }
    }

    component CandidateRow: RippleButton {
        id: candidateRow

        required property string candidate
        required property int index

        readonly property var installed: HyprlandBinds.candidateAvailable(candidateRow.candidate)
        readonly property bool winning: candidateRow.candidate === subPageRoot.winner

        Layout.fillWidth: true
        implicitHeight: 52
        useDynamicRadius: true
        colBackground: candidateRow.winning ? Appearance.colors.colPrimaryContainer
            : Appearance.colors.colLayer2
        colBackgroundHover: candidateRow.winning ? Appearance.colors.colPrimaryContainerHover
            : Appearance.colors.colLayer2Hover
        colRipple: candidateRow.winning ? Appearance.colors.colPrimaryContainerActive
            : Appearance.colors.colLayer2Active

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 8
            spacing: 10

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: candidateRow.installed === true ? "check_circle"
                    : (candidateRow.installed === false ? "cancel" : "help")
                iconSize: Appearance.font.pixelSize.large
                color: candidateRow.installed === true
                    ? (candidateRow.winning ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colPrimary)
                    : Appearance.colors.colSubtext
            }

            StyledText {
                Layout.fillWidth: true
                text: candidateRow.candidate
                elide: Text.ElideRight
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: candidateRow.winning ? Appearance.colors.colOnPrimaryContainer
                    : (candidateRow.installed === false ? Appearance.colors.colSubtext
                        : Appearance.colors.colOnLayer2)
            }

            RowButton {
                buttonIcon: "keyboard_arrow_up"
                enabled: candidateRow.index > 0
                onClicked: subPageRoot.move(candidateRow.index, -1)
            }

            RowButton {
                buttonIcon: "keyboard_arrow_down"
                enabled: candidateRow.index < subPageRoot.chain.candidates.length - 1
                onClicked: subPageRoot.move(candidateRow.index, 1)
            }

            RowButton {
                buttonIcon: "close"
                onClicked: subPageRoot.drop(candidateRow.index)
            }
        }
    }

    ContentPage {
        anchors.fill: parent
        forceWidth: false

        RowLayout {
            visible: subPageRoot.showBackButton
            Layout.fillWidth: true
            spacing: 12

            RippleButton {
                implicitWidth: implicitHeight
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: subPageRoot.goBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: subPageRoot.entry.label
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    Layout.fillWidth: true
                    text: subPageRoot.winner === "" ? Translation.tr("Nothing in this list is installed.")
                        : Translation.tr("Opens %1").arg(subPageRoot.winner)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: subPageRoot.winner === "" ? Appearance.colors.colError
                        : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }

        // ── The list ──────────────────────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Tried in this order")
            icon: "list"
            visible: subPageRoot.chain.chain

            Repeater {
                model: subPageRoot.chain.candidates

                delegate: CandidateRow {
                    required property var modelData

                    candidate: String(modelData)
                }
            }

            ConfigTextField {
                id: addField
                Layout.fillWidth: true

                icon: "add"
                text: Translation.tr("Add one")
                placeholderText: Translation.tr("ghostty")

                Connections {
                    target: addField.textField

                    function onAccepted() {
                        subPageRoot.add(addField.inputText);
                        addField.inputText = "";
                    }
                }
            }

            HyprOptionNote {
                notes: {
                    const out = [{ "icon": "info", "text": Translation.tr("The first installed one wins, so the order is the choice. A tick means the command exists on this machine right now.") }];
                    if (subPageRoot.winner !== "" && subPageRoot.chain.candidates.length > 0
                        && subPageRoot.winner !== subPageRoot.chain.candidates[0])
                        out.push({ "icon": "swap_vert", "text": Translation.tr("%1 is above %2 in the list but is not installed, so it is skipped.")
                            .arg(subPageRoot.chain.candidates[0]).arg(subPageRoot.winner) });
                    return out;
                }
            }
        }

        // ── Not a list ────────────────────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Command")
            icon: "terminal"
            visible: !subPageRoot.chain.chain

            ConfigTextField {
                id: plainField
                Layout.fillWidth: true

                readonly property string currentValue: subPageRoot.value

                icon: subPageRoot.entry.icon
                text: subPageRoot.entry.label
                textField.wrapMode: TextInput.NoWrap

                onCurrentValueChanged: {
                    if (plainField.textField.activeFocus) return;
                    plainField.inputText = plainField.currentValue;
                }
                Component.onCompleted: plainField.inputText = plainField.currentValue

                Connections {
                    target: plainField.textField

                    function onEditingFinished() {
                        if (plainField.inputText === plainField.currentValue) return;
                        HyprlandBinds.saveApp(subPageRoot.name, plainField.inputText);
                    }
                }
            }

            HyprOptionNote {
                notes: [{ "icon": "info", "text": Translation.tr("This one is a single command rather than a list of fallbacks, so it is edited as text.") }]
            }
        }

        // ── Where it comes from ───────────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Where this comes from")
            icon: "history"

            HyprNavRow {
                visible: subPageRoot.source === "managed"
                buttonIcon: "undo"
                text: Translation.tr("Undo what this page set")
                value: Translation.tr("Back to the config file")
                onOpenSubPage: HyprlandBinds.resetApp(subPageRoot.name)
            }

            HyprOptionNote {
                notes: {
                    if (subPageRoot.source === "managed")
                        return [{ "icon": "edit", "text": Translation.tr("Set by this page, in the block at the end of custom/variables.lua.") },
                            { "icon": "restart_alt", "text": Translation.tr("The shortcut picks this up on the next config reload, which happens as soon as the file is written.") }];
                    if (subPageRoot.source === "custom")
                        return [{ "icon": "edit_note", "text": Translation.tr("Written by hand in custom/variables.lua. Changing it here leaves that line alone and adds one below it, which runs afterwards and wins.") }];
                    return [{ "icon": "inventory", "text": Translation.tr("This is the shipped default, from hyprland/variables.lua. That file is replaced on every update, so changes go into custom/variables.lua instead.") }];
                }
            }
        }
    }
}
