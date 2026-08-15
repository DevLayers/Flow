pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

/**
 * The row of chips above the composer.
 *
 * Everything the chat can be told to do with a slash command has a chip here,
 * and the chips never go away: the old provider row and model combo were only
 * shown on an empty chat, which is exactly when nobody needs to switch. The
 * commands stay as an accelerator, not as the only way in.
 *
 * Popovers are drawn into `overlayParent` — the transcript above the bar — so
 * they open upward, over the messages, and a click anywhere on the transcript
 * closes them. Nothing here creates a Wayland surface of its own.
 */
Item {
    id: root

    /** Where popovers are drawn. They anchor to its bottom, above this bar. */
    property Item overlayParent: null
    property string commandPrefix: "/"
    property var inputField: null

    signal newChatRequested
    signal sessionsRequested

    /** Whether the chat list is on screen, so its chip can say so. */
    property bool sessionsOpen: false

    /** Below this the chips drop their labels and keep icons and values. */
    readonly property bool compact: root.width < 360

    property string activePopover: ""

    /** Set while the regenerate picker is open, so it knows what to redo. */
    property string regenerateMessageId: ""

    function togglePopover(name: string) {
        root.activePopover = (root.activePopover === name) ? "" : name;
    }

    function closePopover() {
        root.activePopover = "";
    }

    function openKeyManager() {
        root.activePopover = "keys";
    }

    /** Opens the model list for one answer only, without changing the chat's. */
    function openRegenerate(messageId: string) {
        root.regenerateMessageId = messageId;
        root.activePopover = "regenerate";
    }

    readonly property var currentModel: Ai.currentModelEntry
    readonly property bool toolsUsable: root.currentModel?.tools ?? false

    readonly property var thinkingLabels: ({
            "off": Translation.tr("Off"),
            "low": Translation.tr("Low"),
            "medium": Translation.tr("Medium"),
            "high": Translation.tr("High")
        })
    readonly property var thinkingShortLabels: ({
            "off": Translation.tr("Off"),
            "low": Translation.tr("Low"),
            "medium": Translation.tr("Med"),
            "high": Translation.tr("High")
        })

    function promptName(path: string): string {
        const base = String(path ?? "").split("/").pop();
        return base.replace(/\.(md|txt|prompt)$/i, "");
    }

    readonly property string personaChipLabel: {
        if (Ai.promptOverride.length > 0)
            return Translation.tr("This chat");
        if (Ai.currentPersona)
            return Ai.currentPersona.name;
        return Translation.tr("Default");
    }

    readonly property string personaChipTooltip: {
        if (Ai.promptOverride.length > 0)
            return Translation.tr("This chat has its own prompt");
        if (!Ai.currentPersona)
            return Translation.tr("How it should answer\nAlso %1persona NAME").arg(root.commandPrefix);
        if (Ai.personaModified)
            return Translation.tr("Persona: %1 — settings changed since").arg(Ai.currentPersona.name);
        return Translation.tr("Persona: %1").arg(Ai.currentPersona.name);
    }

    /**
     * Every chip, in the order it gives way. The list is read twice — once by
     * the bar, once by the overflow menu — and the order is the priority: what
     * wraps off the first row is what the menu holds.
     */
    readonly property var chipModel: [
        {
            // Saved chats. Doubles as the name of the one on screen, which is
            // otherwise nowhere to be seen.
            "key": "sessions",
            "symbol": "forum",
            "label": Ai.sessionTitle.length > 0 ? Ai.sessionTitle : Translation.tr("Chats"),
            "caret": false,
            "tooltip": Translation.tr("Saved chats\nAlso %1load NAME").arg(root.commandPrefix)
        },
        {
            "key": "newChat",
            "symbol": "add_comment",
            "caret": false,
            "sidePadding": 8,
            "tooltip": Translation.tr("New chat (Ctrl+Shift+O)")
        },
        {
            // The one chip that keeps its label at every width: which model is
            // answering is the thing worth knowing.
            "key": "model",
            "symbol": root.currentModel?.materialIcon ?? "wand_stars",
            "customIcon": root.currentModel?.icon ?? "",
            "label": root.currentModel?.title ?? Translation.tr("No model"),
            "alwaysLabel": true,
            "tooltip": Translation.tr("Model: %1\nAlso %2model MODEL").arg(root.currentModel?.name ?? Translation.tr("none")).arg(root.commandPrefix)
        },
        {
            "key": "thinking",
            "symbol": "neurology",
            "label": root.thinkingShortLabels[Ai.thinkingLevel] ?? Ai.thinkingLevel,
            "available": Ai.currentModelThinks,
            "tooltip": Ai.currentModelThinks ? Translation.tr("How hard to think\nAlso %1think LEVEL").arg(root.commandPrefix) : Translation.tr("%1 does not think out loud").arg(root.currentModel?.title ?? Translation.tr("This model"))
        },
        {
            "key": "tools",
            "symbol": "service_toolbox",
            "label": Ai.toolbox.modeLabels[Ai.currentTool] ?? Ai.currentTool,
            "available": root.toolsUsable,
            "tooltip": root.toolsUsable ? Translation.tr("Tools: %1\nAlso %2tool TOOL").arg(Ai.currentTool).arg(root.commandPrefix) : Translation.tr("%1 has no tool support").arg(root.currentModel?.title ?? Translation.tr("This model"))
        },
        {
            // Persona: prompt, model, thinking and temperature saved together.
            // The old chip named a prompt file, which said nothing about what
            // the file would do.
            "key": "prompt",
            "symbol": Ai.currentPersona?.icon ?? "assignment",
            "label": root.personaChipLabel,
            "dot": Ai.personaModified && Ai.promptOverride.length === 0,
            "tooltip": root.personaChipTooltip
        },
        {
            // Nothing else says whether the model in use can be reached at all
            // until a message fails.
            "key": "keys",
            "symbol": Ai.currentModelHasApiKey ? "key" : "key_off",
            "label": Ai.currentModelHasApiKey ? Translation.tr("Key") : Translation.tr("No key"),
            "caret": false,
            "tooltip": Ai.currentModelHasApiKey ? Translation.tr("API keys\nAlso %1key").arg(root.commandPrefix) : Translation.tr("%1 needs an API key").arg(root.currentModel?.title ?? Translation.tr("This model"))
        },
        {
            "key": "advanced",
            "symbol": "tune",
            "label": Translation.tr("Advanced"),
            "caret": false,
            "tooltip": Translation.tr("Temperature, output length, context")
        },
        {
            // Slash accelerator, kept as a hint that the commands still exist.
            "key": "slash",
            "label": root.commandPrefix,
            "alwaysLabel": true,
            "caret": false,
            "sidePadding": 8,
            "tooltip": Translation.tr("Commands")
        }
    ]

    function chipEntry(key: string): var {
        return root.chipModel.find(entry => entry.key === key) ?? null;
    }

    /** Whether a chip is showing its own popover, or the drawer it opens. */
    function chipOpened(key: string): bool {
        if (key === "sessions")
            return root.sessionsOpen;
        return root.activePopover === key;
    }

    function activateChip(key: string) {
        const entry = root.chipEntry(key);
        if (entry && !(entry.available ?? true))
            return;
        // Only the chips that do something other than open a popover put the
        // open one away first. Clearing it for all of them made every chip
        // reopen on the second press instead of closing.
        if (key === "sessions") {
            root.closePopover();
            root.sessionsRequested();
            return;
        }
        if (key === "newChat") {
            root.closePopover();
            root.newChatRequested();
            return;
        }
        if (key === "slash") {
            root.closePopover();
            if (!root.inputField)
                return;
            root.inputField.text = root.commandPrefix;
            root.inputField.cursorPosition = root.inputField.text.length;
            root.inputField.forceActiveFocus();
            return;
        }
        root.togglePopover(key);
    }

    /**
     * Which chips wrapped off the first row, asked of the chips themselves.
     * Measuring them beats predicting them: a label's width depends on the
     * font, the translation and the model's own name, none of which are known
     * here.
     */
    property var overflowKeys: []

    function refreshOverflow() {
        const keys = [];
        for (let i = 0; i < chipRepeater.count; i++) {
            const chip = chipRepeater.itemAt(i);
            if (!chip)
                continue;
            const past = chip.y > 0.5;
            chip.overflowing = past;
            if (past)
                keys.push(chip.chipKey);
        }
        // Rewriting an identical list would rebuild the menu under the cursor.
        if (keys.join(",") !== root.overflowKeys.join(","))
            root.overflowKeys = keys;
    }

    implicitHeight: chipStrip.implicitHeight

    /**
     * One chip. Everything it shows comes from an entry in `chipModel`, so the
     * bar and the overflow menu draw the same control from the same source
     * rather than declaring it twice and drifting apart.
     */
    component ControlChip: RippleButton {
        id: chip

        property var entry: null
        readonly property string chipKey: chip.entry?.key ?? ""
        readonly property string symbol: chip.entry?.symbol ?? ""
        readonly property string customIconSource: chip.entry?.customIcon ?? ""
        readonly property string label: chip.entry?.label ?? ""
        readonly property bool showCaret: chip.entry?.caret ?? true
        readonly property string tooltipText: chip.entry?.tooltip ?? ""
        readonly property real sidePadding: chip.entry?.sidePadding ?? 10
        readonly property bool opened: root.chipOpened(chip.chipKey)
        /** Set by the overflow menu, where there is room and no icon to guess from. */
        property bool forceLabel: false
        /** Labels go first when there is no room, unless the chip is the model. */
        readonly property bool showLabel: chip.forceLabel || (chip.entry?.alwaysLabel ?? false) || !root.compact
        /**
         * A chip whose setting does not apply to the model in use is dimmed
         * but stays alive: disabling it would take the tooltip away too, and
         * the tooltip is the part that says why.
         */
        readonly property bool available: chip.entry?.available ?? true
        /**
         * Laid out, but past the first row and so out of sight — the overflow
         * menu is where it can be reached. It keeps its place in the flow so
         * the row above it does not reshuffle every time the width changes.
         */
        property bool overflowing: false

        implicitHeight: 30
        leftPadding: chip.sidePadding
        rightPadding: chip.sidePadding
        // The icon's line box is taller than what Button's default vertical
        // padding leaves behind, and a layout cannot shrink under its own
        // minimum: the row was laid out at full height from the top of the
        // content rect and spilled downwards, taking the label with it.
        topPadding: 0
        bottomPadding: 0
        buttonRadius: height / 2
        toggled: chip.opened
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colBackgroundActive: Appearance.colors.colLayer2Active
        colRipple: Appearance.colors.colLayer2Active
        opacity: chip.overflowing ? 0 : (chip.available ? 1 : 0.5)
        enabled: !chip.overflowing
        onClicked: root.activateChip(chip.chipKey)

        contentItem: RowLayout {
            id: chipRowLayout
            spacing: 5

            Loader {
                Layout.alignment: Qt.AlignVCenter
                active: chip.customIconSource.length > 0
                visible: active
                sourceComponent: CustomIcon {
                    source: chip.customIconSource
                    width: Appearance.font.pixelSize.larger
                    height: Appearance.font.pixelSize.larger
                    colorize: true
                    color: chip.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                }
            }

            Loader {
                Layout.alignment: Qt.AlignVCenter
                active: chip.customIconSource.length === 0 && chip.symbol.length > 0
                visible: active
                sourceComponent: MaterialSymbol {
                    text: chip.symbol
                    iconSize: Appearance.font.pixelSize.larger
                    color: chip.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 150
                visible: chip.showLabel && chip.label.length > 0
                text: chip.label
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: chip.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                animateChange: true
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: chip.showCaret
                text: "keyboard_arrow_down"
                iconSize: Appearance.font.pixelSize.normal
                color: chip.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colSubtext
                rotation: chip.opened ? 180 : 0

                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }

        Rectangle {
            // A persona whose model or thinking was changed by hand is no
            // longer quite that persona; the dot says so.
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 5
            visible: chip.entry?.dot ?? false
            implicitWidth: 6
            implicitHeight: 6
            radius: width / 2
            color: Appearance.m3colors.m3tertiary
        }

        StyledToolTip {
            text: chip.tooltipText
        }
    }

    /** One popover's worth of choices: a title, then a row per option. */
    component OptionList: Item {
        id: optionList

        property string title: ""
        property string footnote: ""
        property var options: []
        property real maxListHeight: 300

        signal chosen(key: string)

        implicitHeight: titleText.implicitHeight + 6 + Math.min(optionsColumn.implicitHeight, optionList.maxListHeight) + (footnoteLoader.active ? footnoteLoader.implicitHeight + 6 : 0)

        StyledText {
            id: titleText
            anchors.top: parent.top
            anchors.left: parent.left
            text: optionList.title
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        StyledFlickable {
            anchors {
                top: titleText.bottom
                topMargin: 6
                left: parent.left
                right: parent.right
                bottom: footnoteLoader.active ? footnoteLoader.top : parent.bottom
                bottomMargin: footnoteLoader.active ? 6 : 0
            }
            contentWidth: width
            contentHeight: optionsColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: optionsColumn
                width: parent.width
                spacing: 2

                Repeater {
                    model: optionList.options

                    RippleButton {
                        id: optionButton
                        required property var modelData

                        Layout.fillWidth: true
                        leftPadding: 10
                        rightPadding: 10
                        topPadding: 8
                        bottomPadding: 8
                        buttonRadius: Appearance.rounding.small
                        enabled: modelData.enabled ?? true
                        toggled: modelData.selected ?? false
                        opacity: enabled ? 1 : 0.45
                        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                        onClicked: optionList.chosen(optionButton.modelData.key)

                        contentItem: RowLayout {
                            id: optionRowLayout
                            spacing: 10

                            MaterialSymbol {
                                visible: (optionButton.modelData.symbol ?? "").length > 0
                                text: optionButton.modelData.symbol ?? ""
                                iconSize: Appearance.font.pixelSize.larger
                                color: optionButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer2
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: optionButton.modelData.label ?? ""
                                    elide: Text.ElideRight
                                    color: optionButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer2
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: (optionButton.modelData.description ?? "").length > 0
                                    text: optionButton.modelData.description ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    wrapMode: Text.Wrap
                                }
                            }

                            MaterialSymbol {
                                visible: optionButton.toggled
                                text: "check"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.m3colors.m3onSecondaryContainer
                            }
                        }
                    }
                }
            }
        }

        Loader {
            id: footnoteLoader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            active: optionList.footnote.length > 0
            visible: active
            sourceComponent: StyledText {
                text: optionList.footnote
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
        }
    }

    /**
     * One row, always. Chips that do not fit are laid out below it and hidden
     * there, and the last chip opens them as a menu — the old row scrolled
     * sideways, which hid them behind a gesture nothing announced.
     */
    Item {
        id: chipStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 30
        clip: true

        Flow {
            id: chipFlow
            anchors.left: parent.left
            anchors.top: parent.top
            // The overflow chip's room is reserved whether or not it is in
            // use: a width that changed with it could hand a chip the space
            // that hides the chip that freed it.
            width: Math.max(0, parent.width - moreChip.implicitWidth - spacing)
            spacing: 4
            onWidthChanged: Qt.callLater(root.refreshOverflow)

            Repeater {
                id: chipRepeater
                model: root.chipModel

                delegate: ControlChip {
                    required property var modelData

                    entry: modelData
                    onYChanged: Qt.callLater(root.refreshOverflow)
                    Component.onCompleted: Qt.callLater(root.refreshOverflow)
                }
            }
        }

        ControlChip {
            id: moreChip
            anchors.right: parent.right
            anchors.top: parent.top
            entry: ({
                    "key": "more",
                    "symbol": "more_horiz",
                    "caret": false,
                    "sidePadding": 8,
                    "tooltip": Translation.tr("More controls")
                })
            opacity: root.overflowKeys.length > 0 ? 1 : 0
            enabled: root.overflowKeys.length > 0

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }

    Loader {
        id: popoverLoader
        parent: root.overlayParent ?? root
        anchors.fill: parent
        z: 100
        active: root.activePopover.length > 0

        sourceComponent: Item {
            MouseArea {
                // Scrim. Clicking the transcript puts the popover away, and
                // scrolling it does not leak through to the message list.
                anchors.fill: parent
                onClicked: root.closePopover()
                onWheel: wheel => wheel.accepted = true
            }

            Rectangle {
                id: panel
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 4
                    rightMargin: 4
                    bottomMargin: 4
                }
                height: Math.min(panelContentLoader.implicitHeight + 14 * 2, parent.height - 8)
                radius: Appearance.rounding.normal
                color: Appearance.colors.colSurfaceContainerHigh
                clip: true

                opacity: 0
                transform: Translate {
                    id: panelTransform
                    y: 12
                }

                Component.onCompleted: panelAnim.start()

                ParallelAnimation {
                    id: panelAnim
                    NumberAnimation {
                        target: panel
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: panelTransform
                        property: "y"
                        from: 12
                        to: 0
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    // Swallows clicks so they do not reach the scrim behind.
                    anchors.fill: parent
                }

                Loader {
                    id: panelContentLoader
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 14
                    }
                    height: panel.height - 14 * 2

                    sourceComponent: {
                        if (root.activePopover === "model")
                            return modelPickerComponent;
                        if (root.activePopover === "regenerate")
                            return regenerateComponent;
                        if (root.activePopover === "thinking")
                            return thinkingComponent;
                        if (root.activePopover === "tools")
                            return toolsComponent;
                        if (root.activePopover === "prompt")
                            return promptComponent;
                        if (root.activePopover === "keys")
                            return keysComponent;
                        if (root.activePopover === "more")
                            return moreComponent;
                        return advancedComponent;
                    }
                }
            }
        }
    }

    Component {
        id: modelPickerComponent
        ModelPickerPopover {
            onPicked: modelId => {
                Ai.setModel(modelId, false);
                root.closePopover();
            }
        }
    }

    Component {
        id: thinkingComponent
        OptionList {
            title: Translation.tr("How hard should it think?")
            footnote: Ai.currentModelAlwaysThinks ? Translation.tr("%1 always reasons — the lowest it goes is Low.").arg(Ai.currentModelEntry?.title ?? "") : ""
            options: Ai.thinkingLevels.map(level => ({
                        key: level,
                        label: root.thinkingLabels[level] ?? level,
                        selected: Ai.thinkingLevel === level,
                        enabled: !(level === "off" && Ai.currentModelAlwaysThinks)
                    }))
            onChosen: key => {
                Ai.setThinkingLevel(key);
                root.closePopover();
            }
        }
    }

    Component {
        id: toolsComponent
        ToolsPopover {
            onClosed: root.closePopover()
        }
    }

    Component {
        id: regenerateComponent
        ModelPickerPopover {
            onPicked: modelId => {
                Ai.regenerateWith(root.regenerateMessageId, modelId);
                root.regenerateMessageId = "";
                root.closePopover();
            }
        }
    }

    Component {
        id: promptComponent
        PersonaLibrary {
            onClosed: root.closePopover()
        }
    }

    Component {
        id: keysComponent
        ApiKeyManager {
            onClosed: root.closePopover()
        }
    }

    Component {
        id: advancedComponent
        ChatAdvancedPopover {}
    }

    Component {
        // What did not fit, as the same chips over as many rows as it takes.
        // Picking one here opens the popover it would have opened in the bar.
        id: moreComponent
        Item {
            id: moreList

            implicitHeight: moreTitle.implicitHeight + 8 + moreFlow.implicitHeight

            StyledText {
                id: moreTitle
                anchors.top: parent.top
                anchors.left: parent.left
                text: Translation.tr("More controls")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            Flow {
                id: moreFlow
                anchors.top: moreTitle.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 4

                Repeater {
                    model: root.overflowKeys

                    delegate: ControlChip {
                        required property string modelData

                        entry: root.chipEntry(modelData)
                        forceLabel: true
                    }
                }
            }
        }
    }
}
