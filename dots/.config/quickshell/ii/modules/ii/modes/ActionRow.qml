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
    readonly property bool inlineEditor: ["switch", "segmented", "dropdown", "stepper", "text"].indexOf(root.editor) !== -1
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

            Choice {
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

            IconButton {
                buttonIcon: root.expanded ? "expand_less" : "expand_more"
                visible: root.hasForm
                onClicked: root.expanded = !root.expanded
            }

            IconButton {
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

        Loader {
            Layout.fillWidth: true
            Layout.leftMargin: 34
            Layout.rightMargin: 6
            Layout.bottomMargin: 4
            active: root.expanded && root.hasForm
            visible: active
            sourceComponent: {
                switch (root.editor) {
                case "brightness":
                    return brightnessForm;
                case "volume":
                    return volumeForm;
                case "file":
                    return fileForm;
                case "classes":
                    return classesForm;
                case "hyprland":
                    return hyprlandForm;
                case "barDock":
                    return barDockForm;
                case "launch":
                    return launchForm;
                case "shell":
                    return shellForm;
                case "notify":
                    return notifyForm;
                case "mode":
                    return modeForm;
                case "routine":
                    return routineForm;
                }
                return null;
            }
        }
    }

    // ------------------------------------------------------ forms

    Component {
        id: brightnessForm

        ColumnLayout {
            id: brightnessCol
            spacing: 10

            readonly property int level: Number(typeof root.value === "object" ? root.obj.level : root.value) || 0

            RowLayout {
                spacing: 12

                StyledSlider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    from: 1
                    to: 100
                    stepSize: 1
                    value: brightnessCol.level
                    onPressedChanged: {
                        if (!pressed)
                            root.patchValue({ level: Math.round(value), scope: root.obj.scope ?? "all" });
                    }
                }

                StyledText {
                    text: `${Math.round(brightnessSlider.value)} %`
                    font.family: Appearance.font.family.numbers
                    color: Appearance.colors.colOnLayer2
                }
            }

            Choice {
                current: root.obj.scope ?? "all"
                onPicked: v => root.patchValue({ level: brightnessCol.level, scope: v })
                options: [
                    { displayName: Translation.tr("All monitors"), value: "all" },
                    { displayName: Translation.tr("Focused monitor"), value: "focused" }
                ]
            }
        }
    }

    Component {
        id: volumeForm

        ColumnLayout {
            id: volumeCol
            spacing: 10

            readonly property bool setsLevel: root.obj.level !== null && root.obj.level !== undefined

            RowLayout {
                spacing: 12

                StyledSwitch {
                    checked: volumeCol.setsLevel
                    onClicked: root.patchValue({ level: checked ? 40 : null })
                }

                StyledText {
                    text: Translation.tr("Set level")
                    color: Appearance.colors.colOnLayer2
                }

                StyledSlider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    enabled: volumeCol.setsLevel
                    opacity: enabled ? 1 : 0.4
                    from: 0
                    to: 100
                    stepSize: 1
                    value: Number(root.obj.level) || 0
                    onPressedChanged: {
                        if (!pressed)
                            root.patchValue({ level: Math.round(value) });
                    }
                }

                StyledText {
                    visible: volumeCol.setsLevel
                    text: `${Math.round(volumeSlider.value)} %`
                    font.family: Appearance.font.family.numbers
                    color: Appearance.colors.colOnLayer2
                }
            }

            Choice {
                current: root.obj.muted === true ? "mute" : (root.obj.muted === false ? "unmute" : "keep")
                onPicked: v => root.patchValue({ muted: v === "keep" ? null : v === "mute" })
                options: [
                    { displayName: Translation.tr("Leave mute as is"), value: "keep" },
                    { displayName: Translation.tr("Mute"), value: "mute" },
                    { displayName: Translation.tr("Unmute"), value: "unmute" }
                ]
            }
        }
    }

    Component {
        id: fileForm

        RowLayout {
            spacing: 8

            PlainField {
                Layout.fillWidth: true
                value: String(root.value ?? "")
                placeholder: Translation.tr("Absolute path to an image")
                onCommitted: v => root.setValue(v)
            }

            SmallButton {
                buttonText: Translation.tr("Use current")
                onClicked: root.setValue(Config.options.background.wallpaperPath)
            }
        }
    }

    Component {
        id: classesForm

        ColumnLayout {
            spacing: 8

            ChipInput {
                Layout.fillWidth: true
                values: Array.isArray(root.value) || ModeSchema.isArrayLike(root.value)
                    ? ModeSchema.stringList(root.value) : ModeSchema.stringList(root.obj.classes)
                placeholder: Translation.tr("Window class to close gracefully")
                suggestions: root.windowSuggestions()
                onChanged: list => root.setValue(list)
            }

            FormHint {
                text: Translation.tr("Windows are asked to close, never killed.")
            }
        }
    }

    Component {
        id: hyprlandForm

        ColumnLayout {
            id: hyprlandCol
            spacing: 10

            readonly property var presets: ModeSchema.stringList(root.obj.presets)
            readonly property var options: root.obj.options ?? ({})
            readonly property var optionKeys: Object.keys(root.obj.options ?? {})

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Object.keys(ModeSchema.HYPRLAND_PRESETS)

                    delegate: RippleButton {
                        id: presetChip
                        required property string modelData
                        readonly property bool on: hyprlandCol.presets.indexOf(presetChip.modelData) !== -1

                        implicitHeight: 32
                        implicitWidth: presetRow.implicitWidth + 22
                        buttonRadius: Appearance.rounding.full
                        colBackground: on ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                        colBackgroundHover: on ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer3Hover
                        colRipple: on ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer3Active
                        onClicked: {
                            const list = ModeSchema.stringList(root.obj.presets);
                            const idx = list.indexOf(presetChip.modelData);
                            if (idx === -1)
                                list.push(presetChip.modelData);
                            else
                                list.splice(idx, 1);
                            root.patchValue({ presets: list, options: root.obj.options ?? {} });
                        }

                        contentItem: RowLayout {
                            id: presetRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                visible: presetChip.on
                                text: "check"
                                iconSize: 16
                                color: Appearance.colors.colOnPrimary
                            }

                            StyledText {
                                text: root.presetLabel(presetChip.modelData)
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: presetChip.on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                            }
                        }
                    }
                }
            }

            FormHint {
                text: Translation.tr("Presets turn the named effect off for the duration of the mode "
                    + "(tearing: on). Add raw options below for anything else.")
            }

            Repeater {
                model: hyprlandCol.optionKeys

                delegate: RowLayout {
                    id: optionRow
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: 6

                    PlainField {
                        Layout.preferredWidth: 240
                        monospace: true
                        value: optionRow.modelData
                        placeholder: "general:gaps_out"
                        onCommitted: v => {
                            const opts = ModeSchema.clone(root.obj.options ?? {});
                            const val = opts[optionRow.modelData];
                            delete opts[optionRow.modelData];
                            if (v.trim().length)
                                opts[v.trim()] = val;
                            root.patchValue({ options: opts });
                        }
                    }

                    StyledText {
                        text: "="
                        color: Appearance.colors.colSubtext
                    }

                    PlainField {
                        Layout.fillWidth: true
                        monospace: true
                        value: String((root.obj.options ?? {})[optionRow.modelData] ?? "")
                        placeholder: "0"
                        onCommitted: v => {
                            const opts = ModeSchema.clone(root.obj.options ?? {});
                            opts[optionRow.modelData] = v;
                            root.patchValue({ options: opts });
                        }
                    }

                    IconButton {
                        buttonIcon: "close"
                        onClicked: {
                            const opts = ModeSchema.clone(root.obj.options ?? {});
                            delete opts[optionRow.modelData];
                            root.patchValue({ options: opts });
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                PlainField {
                    id: newKey
                    Layout.preferredWidth: 240
                    monospace: true
                    placeholder: Translation.tr("option, e.g. general:gaps_out")
                }

                StyledText {
                    text: "="
                    color: Appearance.colors.colSubtext
                }

                PlainField {
                    id: newValue
                    Layout.fillWidth: true
                    monospace: true
                    placeholder: Translation.tr("value")
                }

                SmallButton {
                    buttonText: Translation.tr("Add")
                    onClicked: {
                        const key = newKey.value.trim();
                        if (!key.length)
                            return;
                        const opts = ModeSchema.clone(root.obj.options ?? {});
                        opts[key] = newValue.value;
                        root.patchValue({ options: opts });
                        newKey.value = "";
                        newValue.value = "";
                    }
                }
            }
        }
    }

    Component {
        id: barDockForm

        ColumnLayout {
            spacing: 10

            RowLayout {
                spacing: 10

                FormLabel {
                    text: Translation.tr("Bar")
                }

                Choice {
                    current: root.obj.bar ?? "keep"
                    onPicked: v => root.patchValue({ bar: v })
                    options: [
                        { displayName: Translation.tr("Keep"), value: "keep" },
                        { displayName: Translation.tr("Auto-hide"), value: "autoHide" },
                        { displayName: Translation.tr("Always shown"), value: "fixed" }
                    ]
                }
            }

            RowLayout {
                spacing: 10

                FormLabel {
                    text: Translation.tr("Dock")
                }

                Choice {
                    current: root.obj.dock ?? "keep"
                    onPicked: v => root.patchValue({ dock: v })
                    options: [
                        { displayName: Translation.tr("Keep"), value: "keep" },
                        { displayName: Translation.tr("Hidden"), value: "hide" },
                        { displayName: Translation.tr("Shown"), value: "show" }
                    ]
                }
            }
        }
    }

    Component {
        id: launchForm

        ColumnLayout {
            id: launchCol
            spacing: 10

            property string appQuery: ""
            readonly property var appResults: {
                const q = appQuery.trim();
                if (!q.length)
                    return [];
                return Array.from(AppSearch.fuzzyQuery(q)).slice(0, 6);
            }
            readonly property bool useCommand: (root.obj.command ?? "").length > 0 && !(root.obj.app ?? "").length

            Choice {
                current: launchCol.useCommand ? "command" : "app"
                onPicked: v => root.patchValue(v === "command" ? { app: "", command: root.obj.command || "" }
                                                                : { command: "", app: root.obj.app || "" })
                options: [
                    { displayName: Translation.tr("An app"), value: "app" },
                    { displayName: Translation.tr("A command"), value: "command" }
                ]
            }

            // App: the chosen entry, or a search to choose one.
            ColumnLayout {
                id: appPicker
                Layout.fillWidth: true
                visible: !launchCol.useCommand
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        visible: (root.obj.app ?? "").length > 0
                        implicitWidth: chosenRow.implicitWidth + 20
                        implicitHeight: 32
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSecondaryContainer

                        RowLayout {
                            id: chosenRow
                            anchors.centerIn: parent
                            spacing: 6

                            StyledText {
                                text: DesktopEntries.byId(root.obj.app ?? "")?.name ?? (root.obj.app ?? "")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            MouseArea {
                                implicitWidth: 18
                                implicitHeight: 18
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.patchValue({ app: "" })

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 16
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colLayer3
                        border.width: appSearch.activeFocus ? 2 : 0
                        border.color: Appearance.colors.colPrimary

                        StyledTextInput {
                            id: appSearch
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Appearance.colors.colOnLayer3
                            clip: true
                            onTextChanged: launchCol.appQuery = text

                            StyledText {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: !appSearch.text.length
                                text: (root.obj.app ?? "").length ? Translation.tr("Search to replace")
                                                                  : Translation.tr("Search apps")
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                Repeater {
                    model: launchCol.appResults

                    delegate: RippleButton {
                        id: appResult
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.small
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer3Hover
                        colRipple: Appearance.colors.colLayer3Active
                        onClicked: {
                            root.patchValue({ app: appResult.modelData.id, command: "" });
                            appSearch.text = "";
                        }

                        contentItem: RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 10
                            }
                            spacing: 8

                            StyledText {
                                Layout.fillWidth: true
                                text: appResult.modelData.name
                                elide: Text.ElideRight
                                color: Appearance.colors.colOnLayer2
                            }

                            StyledText {
                                text: appResult.modelData.id
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }

            PlainField {
                Layout.fillWidth: true
                visible: launchCol.useCommand
                monospace: true
                value: String(root.obj.command ?? "")
                placeholder: Translation.tr("Command line, run with sh -c")
                onCommitted: v => root.patchValue({ command: v, app: "" })
            }

            RowLayout {
                spacing: 10

                FormLabel {
                    text: Translation.tr("When it ends")
                }

                Choice {
                    current: root.obj.onEnd ?? "keep"
                    onPicked: v => root.patchValue({ onEnd: v })
                    options: [
                        { displayName: Translation.tr("Leave it open"), value: "keep" },
                        { displayName: Translation.tr("Close it"), value: "close" }
                    ]
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: (root.obj.onEnd ?? "keep") === "close"
                spacing: 10

                FormLabel {
                    text: Translation.tr("Window class")
                }

                PlainField {
                    Layout.fillWidth: true
                    value: String(root.obj["class"] ?? "")
                    placeholder: Translation.tr("Only if it differs from the app's own")
                    onCommitted: v => root.patchValue({ "class": v })
                }
            }
        }
    }

    Component {
        id: shellForm

        ColumnLayout {
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FormLabel {
                    Layout.preferredWidth: 60
                    text: Translation.tr("On start")
                }

                PlainField {
                    Layout.fillWidth: true
                    monospace: true
                    value: String(typeof root.value === "object" ? (root.obj.start ?? "") : (root.value ?? ""))
                    placeholder: Translation.tr("Command, run with sh -c")
                    onCommitted: v => root.patchValue({ start: v, end: root.obj.end ?? "" })
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FormLabel {
                    Layout.preferredWidth: 60
                    text: Translation.tr("On end")
                }

                PlainField {
                    Layout.fillWidth: true
                    monospace: true
                    value: String(root.obj.end ?? "")
                    placeholder: Translation.tr("Optional")
                    onCommitted: v => root.patchValue({ start: root.obj.start ?? "", end: v })
                }
            }
        }
    }

    Component {
        id: notifyForm

        ColumnLayout {
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FormLabel {
                    Layout.preferredWidth: 60
                    text: Translation.tr("Title")
                }

                PlainField {
                    Layout.fillWidth: true
                    value: String(root.obj.title ?? "")
                    placeholder: Translation.tr("Routine ran")
                    onCommitted: v => root.patchValue({ title: v })
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FormLabel {
                    Layout.preferredWidth: 60
                    text: Translation.tr("Body")
                }

                PlainField {
                    Layout.fillWidth: true
                    value: String(root.obj.body ?? "")
                    placeholder: Translation.tr("Optional")
                    onCommitted: v => root.patchValue({ body: v })
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FormLabel {
                    Layout.preferredWidth: 60
                    text: Translation.tr("Icon")
                }

                PlainField {
                    Layout.fillWidth: true
                    monospace: true
                    value: String(root.obj.icon ?? "")
                    placeholder: Translation.tr("Icon name or file, optional")
                    onCommitted: v => root.patchValue({ icon: v })
                }
            }

            FormHint {
                text: Translation.tr("Sent as a desktop notification, so it shows in the notification list too.")
            }
        }
    }

    Component {
        id: modeForm

        ColumnLayout {
            id: modeCol
            spacing: 8

            readonly property bool stopping: (root.obj.action ?? "start") === "stop"
            // Starting a mode another routine waits for can loop back here.
            readonly property var allowed: modeCol.stopping ? Modes.modes
                : root.loopFree(Modes.modes, m => ({ action: "start", id: m.id }))
            readonly property int hiddenCount: Modes.modes.length - modeCol.allowed.length

            RowLayout {
                spacing: 10

                Choice {
                    current: root.obj.action ?? "start"
                    onPicked: v => root.patchValue({ action: v, id: v === "stop" ? "" : root.obj.id ?? "" })
                    options: [
                        { displayName: Translation.tr("Start"), value: "start" },
                        { displayName: Translation.tr("Stop"), value: "stop" }
                    ]
                }

                StyledComboBox {
                    Layout.preferredWidth: 220
                    model: (modeCol.stopping ? [Translation.tr("Whatever is on")] : [])
                        .concat(modeCol.allowed.map(m => m.name))
                    currentIndex: {
                        const idx = modeCol.allowed.findIndex(m => m.id === (root.obj.id ?? ""));
                        return Math.max(0, idx + (modeCol.stopping ? 1 : 0));
                    }
                    onActivated: index => {
                        const i = modeCol.stopping ? index - 1 : index;
                        root.patchValue({ id: i < 0 ? "" : (modeCol.allowed[i]?.id ?? "") });
                    }
                }
            }

            FormHint {
                visible: modeCol.hiddenCount > 0
                text: modeCol.hiddenCount === 1
                    ? Translation.tr("1 mode hidden: a routine waiting for it would run this one again")
                    : Translation.tr("%1 modes hidden: a routine waiting for them would run this one again").arg(modeCol.hiddenCount)
            }

            FormHint {
                visible: !modeCol.stopping && !Modes.modes.length
                text: Translation.tr("There is no mode to start yet.")
            }
        }
    }

    Component {
        id: routineForm

        ColumnLayout {
            id: routineCol
            spacing: 8

            readonly property bool stopping: (root.obj.action ?? "run") === "stop"
            readonly property var others: Modes.routines.filter(r => r.id !== root.ownerId)
            readonly property var allowed: routineCol.stopping ? routineCol.others
                : root.loopFree(routineCol.others, r => ({ action: "run", id: r.id }))
            readonly property int hiddenCount: routineCol.others.length - routineCol.allowed.length

            RowLayout {
                spacing: 10

                Choice {
                    current: root.obj.action ?? "run"
                    onPicked: v => root.patchValue({ action: v })
                    options: [
                        { displayName: Translation.tr("Run"), value: "run" },
                        { displayName: Translation.tr("Stop"), value: "stop" }
                    ]
                }

                StyledComboBox {
                    Layout.preferredWidth: 220
                    model: [Translation.tr("Choose…")].concat(routineCol.allowed.map(r => r.name))
                    currentIndex: Math.max(0, routineCol.allowed.findIndex(r => r.id === (root.obj.id ?? "")) + 1)
                    onActivated: index => root.patchValue({ id: index === 0 ? "" : (routineCol.allowed[index - 1]?.id ?? "") })
                }
            }

            FormHint {
                visible: routineCol.hiddenCount > 0
                text: routineCol.hiddenCount === 1
                    ? Translation.tr("1 routine hidden: it would run this one again")
                    : Translation.tr("%1 routines hidden: they would run this one again").arg(routineCol.hiddenCount)
            }

            FormHint {
                visible: !routineCol.others.length
                text: Translation.tr("There is no other routine yet.")
            }
        }
    }

    // ------------------------------------------------------ helpers

    function presetLabel(key) {
        switch (key) {
        case "animations":
            return Translation.tr("Animations");
        case "blur":
            return Translation.tr("Blur");
        case "shadows":
            return Translation.tr("Shadows");
        case "gaps":
            return Translation.tr("Gaps");
        case "rounding":
            return Translation.tr("Rounding");
        case "tearing":
            return Translation.tr("Tearing");
        }
        return key;
    }

    function windowSuggestions() {
        const seen = {};
        const out = [];
        for (const w of ModeSchema.toArray(HyprlandData.windowList)) {
            const cls = String(w.initialClass || w["class"] || "");
            if (!cls.length || seen[cls])
                continue;
            seen[cls] = true;
            out.push({ label: String(w.title || cls).slice(0, 40), value: cls });
        }
        return out;
    }

    component IconButton: RippleButton {
        id: iconButton
        property string buttonIcon

        implicitWidth: 32
        implicitHeight: 32
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: iconButton.buttonIcon
            iconSize: 20
            color: Appearance.colors.colOnLayer2
        }
    }

    component SmallButton: RippleButton {
        id: smallButton

        implicitHeight: 36
        implicitWidth: smallText.implicitWidth + 28
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colSecondaryContainerActive

        contentItem: StyledText {
            id: smallText
            text: smallButton.buttonText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.colors.colOnSecondaryContainer
        }
    }

    component FormLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colOnLayer2
    }

    component FormHint: StyledText {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }

    component Choice: ConfigSelectionArray {
        id: choice
        property var current
        signal picked(var value)
        currentValue: choice.current
        onSelected: value => choice.picked(value)
    }
}
