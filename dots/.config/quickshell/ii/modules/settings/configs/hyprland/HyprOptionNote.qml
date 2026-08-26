pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * The footer row of a Hyprland section: where its values actually come from, and the only
 * place anything is undone.
 *
 * One per ContentSection rather than one per control - a chip under every row would be noise,
 * and most rows have nothing to report. Declared as the section's last child so it joins the
 * same rounded group, and it hides itself when there is nothing to say (an invisible sibling
 * does not break the grouping, so an untouched section looks exactly as it did before).
 */
Rectangle {
    id: root

    /// Every key the section owns. The note reports on whichever of them has something to say.
    property var keys: []
    /// Extra lines the section wants in the same footer, as `{ icon, text }`. For the things a
    /// key's own state cannot say - an option that moved to another syntax, a setting that only
    /// applies on some hardware - so a section still has one place where the caveats live.
    property var notes: []

    /// Everything below that feeds a Repeater goes through ObjectUtils.keep: the states are
    /// rebuilt whenever any layer moves, and a model that kept its identity keeps its rows.
    property var _memo: ({})

    // Defensive: a caller whose own `keys` binding throws hands this undefined, and one bad
    // reference there would otherwise take out all six properties below it as well.
    readonly property var optionStates: Array.from(root.keys ?? [])
        .filter(key => String(key ?? "") !== "").map(key => HyprlandGui.resolve(key))
    readonly property var managed: ObjectUtils.keep(root._memo, "managed",
        root.optionStates.filter(state => state.isManaged).map(state => ({ "key": state.key })))
    readonly property var inherited: root.optionStates.filter(state => state.inherited !== null)
    readonly property var shadowed: root.optionStates.filter(state => state.shadowedBy !== null)
    readonly property var shellOwned: root.optionStates.filter(state => state.shellOwnedBy !== "")

    function shortName(key: string): string {
        return String(key).split(":").slice(1).join(":") || key;
    }

    readonly property var lines: {
        const out = [];
        for (const state of root.shellOwned)
            out.push({
                "icon": "lock",
                "text": Translation.tr("%1 is pushed back by the shell after every reload, so it cannot be set from here.")
                    .arg(root.shortName(state.key))
            });
        for (const state of root.shadowed)
            out.push({
                "icon": "layers",
                "text": Translation.tr("%1 is overridden after load by Modes, Game Mode or the screen shader, which currently set it to %2.")
                    .arg(root.shortName(state.key)).arg(String(state.shadowedBy.value))
            });
        for (const state of root.inherited) {
            const where = Translation.tr("%1 line %2").arg(state.inherited.file).arg(state.inherited.line);
            out.push({
                "icon": "edit_note",
                "text": state.isManaged
                    ? Translation.tr("%1 is also set by hand at %2. The value above wins.")
                        .arg(root.shortName(state.key)).arg(where)
                    : Translation.tr("%1 is set by hand at %2.").arg(root.shortName(state.key)).arg(where)
            });
        }
        for (const note of Array.from(root.notes))
            out.push(note);
        return ObjectUtils.keep(root._memo, "lines", out);
    }

    /// Removing a hand-written line is only offered once this page sets the key too, because
    /// then taking it out changes nothing. Otherwise it would silently reset the setting.
    readonly property var removable: ObjectUtils.keep(root._memo, "removable",
        root.inherited.filter(state => state.isManaged && state.inherited.removable)
            .map(state => ({ "key": state.key })))

    visible: root.lines.length > 0 || root.managed.length > 0
    Layout.fillWidth: true
    implicitHeight: visible ? layout.implicitHeight + 20 : 0
    color: root.shellOwned.length > 0 || root.shadowed.length > 0
        ? Appearance.colors.colSurfaceContainerHigh : Appearance.colors.colLayer2

    // Only the bottom corners need thinking about: the note is the last row of its group, and
    // never the first, because a section always has controls above it.
    readonly property bool isLast: {
        const owner = root.parent;
        if (!owner) return true;
        const siblings = owner.children;
        let seen = false;
        for (let i = 0; i < siblings.length; i++) {
            if (siblings[i] === root) {
                seen = true;
                continue;
            }
            if (!seen || !siblings[i].visible) continue;
            return typeof siblings[i].topLeftRadius === "undefined";
        }
        return true;
    }

    topLeftRadius: Appearance.rounding.verysmall
    topRightRadius: Appearance.rounding.verysmall
    bottomLeftRadius: root.isLast ? Appearance.rounding.large : Appearance.rounding.verysmall
    bottomRightRadius: root.isLast ? Appearance.rounding.large : Appearance.rounding.verysmall

    /// The confirmation lives on the hub, which is the only thing here that can host a dialog.
    function askToRemove(key: string) {
        let node = root.parent;
        while (node) {
            if (node.requestDropInherited !== undefined) {
                node.requestDropInherited(key);
                return;
            }
            node = node.parent;
        }
    }

    ColumnLayout {
        id: layout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 16
            rightMargin: 16
            topMargin: 10
        }
        spacing: 6

        Repeater {
            model: root.lines

            delegate: RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignTop
                    text: modelData.icon
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    text: modelData.text
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: root.managed.length > 0 || root.removable.length > 0 || root.shadowed.length > 0

            Repeater {
                model: root.managed

                delegate: NoteButton {
                    required property var modelData

                    label: Translation.tr("Reset %1").arg(root.shortName(modelData.key))
                    buttonIcon: "undo"
                    onClicked: HyprlandGui.resetKey(modelData.key)
                }
            }

            Repeater {
                model: root.removable

                delegate: NoteButton {
                    required property var modelData

                    label: Translation.tr("Remove the old %1 line").arg(root.shortName(modelData.key))
                    buttonIcon: "delete_sweep"
                    onClicked: root.askToRemove(modelData.key)
                }
            }

            RelatedChip {
                visible: root.shadowed.length > 0
                pageId: "modes"
                label: Translation.tr("Modes & Routines")
            }
        }
    }

    component NoteButton: RippleButton {
        id: noteButton

        property string label: ""
        property string buttonIcon: ""

        implicitHeight: 28
        implicitWidth: noteButtonRow.implicitWidth + 20
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colSecondaryContainerActive

        contentItem: RowLayout {
            id: noteButtonRow
            spacing: 4

            MaterialSymbol {
                Layout.leftMargin: 10
                text: noteButton.buttonIcon
                iconSize: 14
                color: Appearance.colors.colOnSecondaryContainer
            }

            StyledText {
                Layout.rightMargin: 10
                text: noteButton.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSecondaryContainer
            }
        }
    }
}
