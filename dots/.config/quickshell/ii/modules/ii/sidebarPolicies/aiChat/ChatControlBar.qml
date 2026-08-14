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

    function togglePopover(name: string) {
        root.activePopover = (root.activePopover === name) ? "" : name;
    }

    function closePopover() {
        root.activePopover = "";
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

    implicitHeight: barRowLayout.implicitHeight

    component ControlChip: RippleButton {
        id: chip

        property string symbol: ""
        property string customIconSource: ""
        property string label: ""
        property bool opened: false
        property bool showCaret: true
        property bool showLabel: !root.compact
        property string tooltipText: ""
        property real sidePadding: 10
        /**
         * A chip whose setting does not apply to the model in use is dimmed
         * but stays alive: disabling it would take the tooltip away too, and
         * the tooltip is the part that says why.
         */
        property bool available: true

        implicitHeight: 30
        leftPadding: chip.sidePadding
        rightPadding: chip.sidePadding
        buttonRadius: height / 2
        toggled: chip.opened
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colBackgroundActive: Appearance.colors.colLayer2Active
        colRipple: Appearance.colors.colLayer2Active
        opacity: chip.available ? 1 : 0.5

        contentItem: RowLayout {
            id: chipRowLayout
            spacing: 5

            Loader {
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
                active: chip.customIconSource.length === 0 && chip.symbol.length > 0
                visible: active
                sourceComponent: MaterialSymbol {
                    text: chip.symbol
                    iconSize: Appearance.font.pixelSize.larger
                    color: chip.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                }
            }

            StyledText {
                Layout.maximumWidth: 150
                visible: chip.showLabel && chip.label.length > 0
                text: chip.label
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: chip.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                animateChange: true
            }

            MaterialSymbol {
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

    RowLayout {
        id: barRowLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        StyledFlickable {
            Layout.fillWidth: true
            implicitHeight: chipsRowLayout.implicitHeight
            contentWidth: chipsRowLayout.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            clip: true

            RowLayout {
                id: chipsRowLayout
                height: parent.height
                spacing: 4

                ControlChip {
                    // Saved chats. Doubles as the name of the one on screen,
                    // which is otherwise nowhere to be seen.
                    symbol: "forum"
                    label: Ai.sessionTitle.length > 0 ? Ai.sessionTitle : Translation.tr("New chat")
                    showCaret: false
                    opened: root.sessionsOpen
                    tooltipText: Translation.tr("Saved chats\nAlso %1load NAME").arg(root.commandPrefix)
                    onClicked: root.sessionsRequested()
                }

                ControlChip {
                    // Model. The one chip that keeps its label at every width:
                    // which model is answering is the thing worth knowing.
                    symbol: root.currentModel?.materialIcon ?? "wand_stars"
                    customIconSource: root.currentModel?.icon ?? ""
                    label: root.currentModel?.title ?? Translation.tr("No model")
                    showLabel: true
                    opened: root.activePopover === "model"
                    tooltipText: Translation.tr("Model: %1\nAlso %2model MODEL").arg(root.currentModel?.name ?? Translation.tr("none")).arg(root.commandPrefix)
                    onClicked: root.togglePopover("model")
                }

                ControlChip {
                    // Thinking level.
                    symbol: "neurology"
                    label: root.thinkingShortLabels[Ai.thinkingLevel] ?? Ai.thinkingLevel
                    available: Ai.currentModelThinks
                    opened: root.activePopover === "thinking"
                    tooltipText: Ai.currentModelThinks ? Translation.tr("How hard to think\nAlso %1think LEVEL").arg(root.commandPrefix) : Translation.tr("%1 does not think out loud").arg(root.currentModel?.title ?? Translation.tr("This model"))
                    onClicked: {
                        if (!available)
                            return;
                        root.togglePopover("thinking");
                    }
                }

                ControlChip {
                    // Tools.
                    symbol: "service_toolbox"
                    label: Ai.currentTool.charAt(0).toUpperCase() + Ai.currentTool.slice(1)
                    available: root.toolsUsable
                    opened: root.activePopover === "tools"
                    tooltipText: root.toolsUsable ? Translation.tr("Tools: %1\nAlso %2tool TOOL").arg(Ai.currentTool).arg(root.commandPrefix) : Translation.tr("%1 has no tool support").arg(root.currentModel?.title ?? Translation.tr("This model"))
                    onClicked: {
                        if (!available)
                            return;
                        root.togglePopover("tools");
                    }
                }

                ControlChip {
                    // System prompt. Becomes the persona chip once personas exist.
                    symbol: "assignment"
                    label: Ai.currentPromptFile.length > 0 ? root.promptName(Ai.currentPromptFile) : Translation.tr("Default")
                    available: Ai.promptFiles.length > 0
                    opened: root.activePopover === "prompt"
                    tooltipText: Ai.promptFiles.length > 0 ? Translation.tr("System prompt\nAlso %1prompt PATH").arg(root.commandPrefix) : Translation.tr("No prompt files found in the prompts folder")
                    onClicked: {
                        if (!available)
                            return;
                        root.togglePopover("prompt");
                    }
                }

                ControlChip {
                    // Temperature, output cap and how full the context is.
                    symbol: "tune"
                    label: Translation.tr("Advanced")
                    showCaret: false
                    opened: root.activePopover === "advanced"
                    tooltipText: Translation.tr("Temperature, output length, context")
                    onClicked: root.togglePopover("advanced")
                }
            }
        }

        ControlChip {
            // Slash accelerator, kept as a hint that the commands still exist.
            label: root.commandPrefix
            showLabel: true
            showCaret: false
            sidePadding: 8
            tooltipText: Translation.tr("Commands")
            onClicked: {
                if (!root.inputField)
                    return;
                root.inputField.text = root.commandPrefix;
                root.inputField.cursorPosition = root.inputField.text.length;
                root.inputField.forceActiveFocus();
            }
        }

        ControlChip {
            symbol: "add_comment"
            showCaret: false
            sidePadding: 8
            tooltipText: Translation.tr("New chat (Ctrl+Shift+O)")
            onClicked: root.newChatRequested()
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
                        if (root.activePopover === "thinking")
                            return thinkingComponent;
                        if (root.activePopover === "tools")
                            return toolsComponent;
                        if (root.activePopover === "prompt")
                            return promptComponent;
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
        OptionList {
            title: Translation.tr("What may it reach for?")
            options: Ai.availableTools.map(tool => ({
                        key: tool,
                        label: tool.charAt(0).toUpperCase() + tool.slice(1),
                        description: Ai.toolDescriptions[tool] ?? "",
                        selected: Ai.currentTool === tool
                    }))
            onChosen: key => {
                Ai.setTool(key);
                root.closePopover();
            }
        }
    }

    Component {
        id: promptComponent
        OptionList {
            title: Translation.tr("System prompt")
            footnote: Translation.tr("Loading one replaces the prompt in settings.")
            options: Ai.promptFiles.map(path => ({
                        key: path,
                        label: root.promptName(path),
                        symbol: "description",
                        selected: Ai.currentPromptFile === path
                    }))
            onChosen: key => {
                Ai.loadPrompt(key, false);
                root.closePopover();
            }
        }
    }

    Component {
        id: advancedComponent
        ChatAdvancedPopover {}
    }
}
