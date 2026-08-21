pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../services/modes/ModeSchema.js" as ModeSchema

/**
 * One condition of a mode: its summary, whether it holds right now, and —
 * unfolded — the form for its parameters. Each change is written back as
 * a whole trigger object; the engine normalizes it.
 */
Rectangle {
    id: root

    required property var trigger
    property var watcher: null
    property int triggerIndex: 0
    property bool expanded: false

    readonly property string type: root.trigger?.type ?? ""
    readonly property var condition: root.watcher?.conditionAt(root.triggerIndex) ?? null
    readonly property bool supported: root.condition?.supported ?? true
    readonly property bool negated: root.trigger?.not === true
    readonly property bool holds: (root.condition?.item?.satisfied ?? false) !== root.negated
    readonly property string liveReason: root.condition?.item?.reason ?? ""

    signal changed(var trigger)
    signal removeRequested()

    function set(changes) {
        root.changed(Object.assign({}, ModeSchema.clone(root.trigger), changes));
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
                text: ModeUi.triggerTypeIcon(root.type)
                iconSize: 22
                color: Appearance.colors.colOnLayer2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: ModeUi.triggerText(root.trigger)
                    elide: Text.ElideRight
                    color: Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    text: ModeUi.triggerTypeLabel(root.type)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            // Live verdict, so a mode that "should have started" is
            // diagnosable from its own row.
            Rectangle {
                visible: root.watcher !== null
                implicitWidth: verdictRow.implicitWidth + 16
                implicitHeight: 24
                radius: Appearance.rounding.full
                color: !root.supported ? Appearance.colors.colErrorContainer
                    : (root.holds ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3)

                MouseArea {
                    id: verdictArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                StyledToolTip {
                    extraVisibleCondition: verdictArea.containsMouse && root.liveReason.length > 0
                    text: root.liveReason
                }

                RowLayout {
                    id: verdictRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        text: !root.supported ? "error" : (root.holds ? "check" : "remove")
                        iconSize: 14
                        color: !root.supported ? Appearance.colors.colOnErrorContainer
                            : (root.holds ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext)
                    }

                    StyledText {
                        text: !root.supported ? Translation.tr("Unsupported")
                            : (root.holds ? Translation.tr("Holds now") : Translation.tr("Not now"))
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: !root.supported ? Appearance.colors.colOnErrorContainer
                            : (root.holds ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext)
                    }
                }
            }

            IconButton {
                buttonIcon: root.expanded ? "expand_less" : "expand_more"
                onClicked: root.expanded = !root.expanded
            }

            IconButton {
                buttonIcon: "close"
                onClicked: root.removeRequested()
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.leftMargin: 34
            Layout.rightMargin: 6
            active: root.expanded
            visible: active && status === Loader.Ready && item !== null
            sourceComponent: {
                switch (root.type) {
                case "schedule":
                    return scheduleForm;
                case "app":
                    return appForm;
                case "game":
                    return gameForm;
                case "battery":
                    return batteryForm;
                case "wifi":
                    return wifiForm;
                case "bluetooth":
                    return bluetoothForm;
                case "monitors":
                    return monitorsForm;
                case "locked":
                    return lockedForm;
                case "modeActive":
                    return modeActiveForm;
                case "audioDevice":
                    return audioDeviceForm;
                }
                return null;
            }
        }

        // Every condition can be read the other way round: "Zoom is not
        // running" is how "when Zoom closes" is said.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 34
            Layout.rightMargin: 6
            Layout.bottomMargin: 4
            visible: root.expanded
            spacing: 10

            StyledSwitch {
                checked: root.negated
                onClicked: root.set({ not: checked })
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                FormLabel {
                    text: Translation.tr("Invert")
                }

                FormHint {
                    text: root.negated ? Translation.tr("Holds while the above is not the case")
                        : Translation.tr("Hold when the above is not the case instead")
                }
            }
        }
    }

    // ------------------------------------------------------ forms

    Component {
        id: scheduleForm

        ColumnLayout {
            spacing: 10

            RowLayout {
                spacing: 10

                FormLabel {
                    text: Translation.tr("From")
                }

                TimeField {
                    value: root.trigger.from
                    onCommitted: v => root.set({ from: v })
                }

                FormLabel {
                    text: Translation.tr("to")
                }

                TimeField {
                    value: root.trigger.to
                    onCommitted: v => root.set({ to: v })
                }

                StyledText {
                    visible: ModeSchema.timeToMinutes(root.trigger.from) >= ModeSchema.timeToMinutes(root.trigger.to)
                    text: Translation.tr("overnight")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            RowLayout {
                spacing: 4

                Repeater {
                    model: 7

                    delegate: RippleButton {
                        id: dayButton
                        required property int index
                        readonly property int day: dayButton.index + 1
                        readonly property bool on: ModeSchema.toArray(root.trigger.days).indexOf(dayButton.day) !== -1

                        implicitWidth: 44
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        colBackground: on ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                        colBackgroundHover: on ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer3Hover
                        colRipple: on ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer3Active
                        onClicked: {
                            const days = ModeSchema.toArray(root.trigger.days).map(Number);
                            const idx = days.indexOf(dayButton.day);
                            if (idx === -1)
                                days.push(dayButton.day);
                            else if (days.length > 1)
                                days.splice(idx, 1);
                            root.set({ days: days.sort((a, b) => a - b) });
                        }

                        contentItem: StyledText {
                            text: ModeUi.dayShort[dayButton.index]
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: dayButton.on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                        }
                    }
                }
            }
        }
    }

    Component {
        id: appForm

        ColumnLayout {
            spacing: 10

            Choice {
                current: root.trigger.when
                onPicked: v => root.set({ when: v })
                options: [
                    { displayName: Translation.tr("Is running"), value: "running" },
                    { displayName: Translation.tr("Is focused"), value: "focused" }
                ]
            }

            ChipInput {
                Layout.fillWidth: true
                values: root.trigger.classes
                placeholder: Translation.tr("Window class, e.g. zen or steam_app_.*")
                suggestions: root.windowSuggestions()
                onChanged: list => root.set({ classes: list })
            }

            FormHint {
                text: Translation.tr("A plain name matches the class exactly (case-insensitive); "
                    + "anything with regex characters is a regular expression.")
            }
        }
    }

    Component {
        id: gameForm

        ColumnLayout {
            spacing: 10

            Choice {
                current: root.trigger.when
                onPicked: v => root.set({ when: v })
                options: [
                    { displayName: Translation.tr("Is running"), value: "running" },
                    { displayName: Translation.tr("Is focused"), value: "focused" }
                ]
            }

            FormHint {
                text: GameDetector.gameRunning
                    ? Translation.tr("Detected now: %1").arg(GameDetector.reason)
                    : Translation.tr("Detects Steam, Heroic, Lutris, Bottles, Prism, desktop entries in the Game "
                        + "category, fullscreen Windows executables and fullscreen windows that keep the GPU busy.")
            }

            ChipInput {
                Layout.fillWidth: true
                values: Config.options.modes.game.extraClasses
                placeholder: Translation.tr("Also treat this window class as a game")
                suggestions: root.windowSuggestions()
                onChanged: list => Config.options.modes.game.extraClasses = list
            }
        }
    }

    Component {
        id: batteryForm

        ColumnLayout {
            spacing: 10

            RowLayout {
                spacing: 10

                FormLabel {
                    text: Translation.tr("Below")
                }

                PercentField {
                    value: root.trigger.below
                    onCommitted: v => root.set({ below: v })
                }

                FormLabel {
                    text: Translation.tr("Above")
                }

                PercentField {
                    value: root.trigger.above
                    onCommitted: v => root.set({ above: v })
                }

                FormHint {
                    text: Translation.tr("Leave empty to ignore")
                }
            }

            Choice {
                current: root.trigger.pluggedIn === true ? "yes" : (root.trigger.pluggedIn === false ? "no" : "any")
                onPicked: v => root.set({ pluggedIn: v === "any" ? null : v === "yes" })
                options: [
                    { displayName: Translation.tr("Any power"), value: "any" },
                    { displayName: Translation.tr("Plugged in"), value: "yes" },
                    { displayName: Translation.tr("On battery"), value: "no" }
                ]
            }
        }
    }

    Component {
        id: wifiForm

        ColumnLayout {
            spacing: 10

            Choice {
                current: root.trigger.connected === false ? "off" : "on"
                onPicked: v => root.set({ connected: v === "on" })
                options: [
                    { displayName: Translation.tr("Connected"), value: "on" },
                    { displayName: Translation.tr("Disconnected"), value: "off" }
                ]
            }

            ChipInput {
                Layout.fillWidth: true
                visible: root.trigger.connected !== false
                values: root.trigger.ssids
                placeholder: Translation.tr("Network name — empty means any")
                suggestions: Array.from(Network.friendlyWifiNetworks ?? [])
                    .map(n => n?.ssid).filter(s => s && s.length)
                    .filter((s, i, arr) => arr.indexOf(s) === i)
                    .map(s => ({ label: s, value: s }))
                onChanged: list => root.set({ ssids: list })
            }

            Choice {
                current: root.trigger.ethernet === true ? "yes" : (root.trigger.ethernet === false ? "no" : "any")
                onPicked: v => root.set({ ethernet: v === "any" ? null : v === "yes" })
                options: [
                    { displayName: Translation.tr("Ethernet: any"), value: "any" },
                    { displayName: Translation.tr("Ethernet up"), value: "yes" },
                    { displayName: Translation.tr("Ethernet down"), value: "no" }
                ]
            }
        }
    }

    Component {
        id: bluetoothForm

        ColumnLayout {
            spacing: 10

            Choice {
                current: root.trigger.connected === false ? "off" : "on"
                onPicked: v => root.set({ connected: v === "on" })
                options: [
                    { displayName: Translation.tr("Connected"), value: "on" },
                    { displayName: Translation.tr("Disconnected"), value: "off" }
                ]
            }

            ChipInput {
                Layout.fillWidth: true
                values: root.trigger.devices
                placeholder: Translation.tr("Device address — empty means any device")
                display: v => ModeUi.bluetoothName(v)
                suggestions: Array.from(BluetoothStatus.connectedDevices ?? [])
                    .concat(Array.from(BluetoothStatus.pairedButNotConnectedDevices ?? []))
                    .map(d => ({ label: d.name, value: String(d.address).toUpperCase() }))
                onChanged: list => root.set({ devices: list })
            }
        }
    }

    Component {
        id: monitorsForm

        ColumnLayout {
            spacing: 10

            RowLayout {
                spacing: 10

                FormLabel {
                    text: Translation.tr("At least")
                }

                StyledSpinBox {
                    from: 1
                    to: 16
                    value: root.trigger.count
                    onValueModified: root.set({ count: value })
                }

                FormLabel {
                    text: Translation.tr("monitors connected")
                }
            }

            ChipInput {
                Layout.fillWidth: true
                values: root.trigger.names
                placeholder: Translation.tr("Or a specific monitor name")
                suggestions: Array.from(Hyprland.monitors.values).map(m => ({ label: m.name, value: m.name }))
                onChanged: list => root.set({ names: list })
            }

            FormHint {
                visible: root.trigger.names.length > 0
                text: Translation.tr("With names set, the count is ignored.")
            }
        }
    }

    Component {
        id: lockedForm

        Choice {
            current: root.trigger.is === false ? "no" : "yes"
            onPicked: v => root.set({ is: v === "yes" })
            options: [
                { displayName: Translation.tr("Locked"), value: "yes" },
                { displayName: Translation.tr("Unlocked"), value: "no" }
            ]
        }
    }

    Component {
        id: modeActiveForm

        RowLayout {
            spacing: 10

            FormLabel {
                text: Translation.tr("Mode")
            }

            StyledComboBox {
                Layout.preferredWidth: 220
                model: [Translation.tr("Any mode")].concat(Modes.modes.map(m => m.name))
                currentIndex: Math.max(0, Modes.modeIndex(root.trigger.id) + 1)
                onActivated: index => root.set({ id: index === 0 ? "" : (Modes.modes[index - 1]?.id ?? "") })
            }
        }
    }

    Component {
        id: audioDeviceForm

        ColumnLayout {
            spacing: 10

            Choice {
                current: root.trigger.kind
                onPicked: v => root.set({ kind: v })
                options: [
                    { displayName: Translation.tr("Output"), value: "sink" },
                    { displayName: Translation.tr("Input"), value: "source" }
                ]
            }

            PlainField {
                Layout.fillWidth: true
                value: root.trigger.match
                placeholder: Translation.tr("Part of the device name, e.g. WH-1000XM")
                onCommitted: v => root.set({ match: v })
            }
        }
    }

    // ------------------------------------------------------ helpers

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

    // HH:MM, committed only when valid.
    component TimeField: Rectangle {
        id: timeField
        property string value: "00:00"
        signal committed(string value)
        readonly property bool valid: ModeSchema.validTime(timeInput.text)

        implicitWidth: 72
        implicitHeight: 36
        radius: Appearance.rounding.full
        color: Appearance.colors.colLayer3
        border.width: timeInput.activeFocus ? 2 : (timeField.valid ? 0 : 1)
        border.color: timeField.valid ? Appearance.colors.colPrimary : Appearance.colors.colError

        StyledTextInput {
            id: timeInput
            anchors.fill: parent
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            text: timeField.value
            color: Appearance.colors.colOnLayer3
            inputMask: "99:99"
            font.family: Appearance.font.family.numbers
            onEditingFinished: {
                if (timeField.valid && timeInput.text !== timeField.value)
                    timeField.committed(timeInput.text);
                else if (!timeField.valid)
                    timeInput.text = timeField.value;
            }
        }
    }

    // 0–100 or empty for "not set".
    component PercentField: Rectangle {
        id: percentField
        property var value: null
        signal committed(var value)

        implicitWidth: 72
        implicitHeight: 36
        radius: Appearance.rounding.full
        color: Appearance.colors.colLayer3
        border.width: percentInput.activeFocus ? 2 : 0
        border.color: Appearance.colors.colPrimary

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }
            spacing: 2

            StyledTextInput {
                id: percentInput
                Layout.fillWidth: true
                horizontalAlignment: TextInput.AlignRight
                verticalAlignment: TextInput.AlignVCenter
                text: percentField.value === null || percentField.value === undefined ? "" : String(percentField.value)
                color: Appearance.colors.colOnLayer3
                font.family: Appearance.font.family.numbers
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                onEditingFinished: {
                    const next = percentInput.text.trim().length ? Number(percentInput.text) : null;
                    if (next !== percentField.value)
                        percentField.committed(next);
                }
            }

            StyledText {
                text: "%"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }
    }
}
