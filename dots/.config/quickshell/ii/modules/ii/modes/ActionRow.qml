pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../services/modes/ModeSchema.js" as ModeSchema

/**
 * One action of a mode: what it changes and to what. Simple values
 * (on/off, a choice) are edited right on the row; richer ones unfold a
 * form under it. The whole action object is written back on each change.
 */
Rectangle {
    id: root

    required property var action
    property bool expanded: false
    /// "" for a mode; "while" / "once" when the row belongs to a routine.
    property string routineKind: ""
    /// The owning routine's id, for the loop check on mode/routine actions.
    property string ownerId: ""

    readonly property string type: root.action?.type ?? ""
    readonly property var entry: Modes.actions.get(root.type)
    readonly property string editor: root.entry?.editor ?? "none"
    readonly property bool available: Modes.actions.isAvailable(root.type)
    readonly property var value: root.action?.value
    readonly property var obj: (root.value && typeof root.value === "object" && !Array.isArray(root.value))
        ? root.value : ({})
    readonly property bool inlineEditor: ModeUi.inlineActionEditors.indexOf(root.editor) !== -1
    readonly property bool hasForm: !root.inlineEditor && root.editor !== "none"
    // Only actions the engine can put back offer the "undo at end" choice.
    readonly property bool revertible: root.routineKind === "while" && !!root.entry?.read && !!root.entry?.revert
    readonly property bool undoAtEnd: root.action?.revert !== false
    // Routine ids this action would loop back through, or null.
    readonly property var loop: {
        Modes.routines;
        if (!root.ownerId.length || (root.type !== "mode" && root.type !== "routine"))
            return null;
        return Modes.routineLoop(root.ownerId, [root.action]);
    }

    onExpandedChanged: formLoader.sync()

    signal changed(var action)
    signal removeRequested()

    function setValue(v) {
        root.changed(Object.assign({}, ModeSchema.clone(root.action), { value: v }));
    }

    function patchValue(changes) {
        root.setValue(Object.assign({}, ModeSchema.clone(root.obj), changes));
    }

    function setRevert(on) {
        const next = ModeSchema.clone(root.action);
        if (on)
            delete next.revert;
        else
            next.revert = false;
        root.changed(next);
    }

    // Targets a mode/routine action may point at without closing a loop.
    function loopFree(candidates, makeValue) {
        return candidates.filter(c => Modes.routineLoop(root.ownerId, [{ type: root.type, value: makeValue(c) }]) === null);
    }

    function choiceOptions() {
        let list = [];
        try {
            list = Array.from(root.entry?.choices?.() ?? []);
        } catch (e) {
            list = [];
        }
        return list.map(c => ({ displayName: ModeUi.capitalize(c), value: c }));
    }

    implicitHeight: column.implicitHeight + 16
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    clip: true

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: 8
            leftMargin: 14
            rightMargin: 8
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialSymbol {
                text: root.entry?.icon ?? "bolt"
                iconSize: 22
                color: root.available ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    spacing: 8

                    StyledText {
                        text: root.entry?.label ?? root.type
                        elide: Text.ElideRight
                        color: root.available ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
                    }

                    Rectangle {
                        visible: !root.available
                        implicitWidth: unavailableText.implicitWidth + 14
                        implicitHeight: 20
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colErrorContainer

                        StyledText {
                            id: unavailableText
                            anchors.centerIn: parent
                            text: Translation.tr("Not available here")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnErrorContainer
                        }
                    }

                    // A chain that comes back to this routine: the engine
                    // would cut it after a few hops, but it should not exist.
                    Rectangle {
                        visible: root.loop !== null
                        implicitWidth: loopRow.implicitWidth + 14
                        implicitHeight: 20
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colErrorContainer

                        MouseArea {
                            id: loopArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        StyledToolTip {
                            extraVisibleCondition: loopArea.containsMouse
                            text: {
                                const names = (root.loop ?? []).map(id => Modes.routineById(id)?.name ?? id);
                                const chain = names.length ? names.join(" → ") + " → " : "";
                                return Translation.tr("Runs %1this routine again. Pick another target.").arg(chain);
                            }
                        }

                        RowLayout {
                            id: loopRow
                            anchors.centerIn: parent
                            spacing: 3

                            MaterialSymbol {
                                text: "sync_problem"
                                iconSize: 12
                                color: Appearance.colors.colOnErrorContainer
                            }

                            StyledText {
                                text: Translation.tr("Loops back")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnErrorContainer
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !root.inlineEditor || root.editor === "text"
                    text: {
                        const v = ModeUi.actionValueText(root.action);
                        return v.length ? v : Translation.tr("Not set");
                    }
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            // ---- inline editors
            StyledSwitch {
                visible: root.editor === "switch"
                checked: !!root.value
                onClicked: root.setValue(checked)
            }

            FormChoice {
                visible: root.editor === "segmented"
                Layout.fillWidth: false
                current: root.value ?? ""
                options: root.choiceOptions()
                onPicked: v => root.setValue(v)
            }

            StyledComboBox {
                visible: root.editor === "dropdown"
                Layout.fillWidth: false
                Layout.preferredWidth: 200
                model: root.editor === "dropdown"
                    ? root.choiceOptions().map(o => o.value === "" ? Translation.tr("None") : o.displayName) : []
                currentIndex: {
                    const opts = root.choiceOptions();
                    return Math.max(0, opts.findIndex(o => o.value === (root.value ?? "")));
                }
                onActivated: index => root.setValue(root.choiceOptions()[index]?.value ?? "")
            }

            StyledSpinBox {
                visible: root.editor === "stepper"
                from: 0
                to: Math.max(1, KeyboardBacklight.maxValue)
                value: Number(root.value) || 0
                onValueModified: root.setValue(value)
            }

            // Routines: keep the effect after the routine ends, or put it back.
            RowLayout {
                visible: root.revertible
                spacing: 6

                StyledText {
                    text: Translation.tr("Undo at end")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                StyledSwitch {
                    checked: root.undoAtEnd
                    onClicked: root.setRevert(checked)

                    StyledToolTip {
                        text: Translation.tr("Off: what this sets stays after the routine ends")
                    }
                }
            }

            FormIconButton {
                buttonIcon: root.expanded ? "expand_less" : "expand_more"
                visible: root.hasForm
                onClicked: root.expanded = !root.expanded
            }

            FormIconButton {
                buttonIcon: "close"
                onClicked: root.removeRequested()
            }
        }

        // A URL is short enough to live on the row itself.
        PlainField {
            Layout.fillWidth: true
            Layout.leftMargin: 34
            Layout.rightMargin: 6
            Layout.bottomMargin: 4
            visible: root.editor === "text"
            value: String(root.value ?? "")
            placeholder: Translation.tr("https://…")
            onCommitted: v => root.setValue(v)
        }

        // The parameter form lives in forms/Action<Editor>.qml and gets this
        // row as `row`; it is created on unfold and torn down on fold.
        Loader {
            id: formLoader
            Layout.fillWidth: true
            Layout.leftMargin: 34
            Layout.rightMargin: 6
            Layout.bottomMargin: 4
            visible: status === Loader.Ready && item !== null
            readonly property string formUrl: ModeUi.actionFormUrl(root.editor)
            onFormUrlChanged: formLoader.sync()

            function sync() {
                if (!root.expanded || !formLoader.formUrl.length) {
                    formLoader.source = "";
                    return;
                }
                formLoader.setSource(formLoader.formUrl, { row: root });
            }
        }
    }
}
