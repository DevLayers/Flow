pragma ComponentBehavior: Bound

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Keyboard-first composer for the overview AI surface.
 *
 * The compact rail keeps the prompt, model and send action on one line. Its
 * chevron changes the rail in place instead of opening a popup: tools, models
 * and response effort slide inside the same clipped, full-radius surface.
 */
ColumnLayout {
    id: root

    signal requestSend
    signal requestEscape
    signal requestOpenHistory

    readonly property int maximumLines: 6
    readonly property int maximumCharacters: 12000
    readonly property real lineHeight: Math.round(draftInput.font.pixelSize * 1.5)
    readonly property real maximumEditorHeight: root.lineHeight * root.maximumLines + root.controlPadding * 2
    readonly property real controlExtent: Math.round(Appearance.font.pixelSize.huge * 2)
    readonly property real controlPadding: Appearance.rounding.small
    readonly property real controlGap: Appearance.rounding.small
    readonly property real horizontalInset: Appearance.rounding.normal
    readonly property real modelInset: Appearance.rounding.small
    readonly property real railSlideDistance: Math.max(root.controlExtent, Appearance.rounding.large)
    readonly property bool hasDraft: draftInput.text.trim().length > 0
    readonly property bool longDraft: draftInput.contentHeight > root.lineHeight + root.controlPadding
    readonly property string modelTitle: Ai.currentModelEntry?.title ?? Translation.tr("No model")
    readonly property string modelSymbol: Ai.currentModelEntry?.materialIcon ?? "auto_awesome"
    readonly property string modelIcon: Ai.currentModelEntry?.icon ?? ""
    readonly property bool webActive: Ai.webMode !== "off"

    // Only one rail is visible at a time. This preserves the prompt while a
    // keyboard user changes a setting and mirrors the one-surface navigation
    // used by the Wi-Fi and Bluetooth dialogs.
    property string activeRail: "composer"
    property bool syncingDraft: false

    readonly property var orderedModels: {
        const models = Ai.catalog.modelIds.map(modelId => Ai.catalog.models[modelId]).filter(model => !!model);
        models.sort((first, second) => {
            const firstLocal = Ai.catalog.isModelLocal(first) ? 0 : 1;
            const secondLocal = Ai.catalog.isModelLocal(second) ? 0 : 1;
            if (firstLocal !== secondLocal)
                return firstLocal - secondLocal;
            return String(first.title ?? first.value ?? "").localeCompare(String(second.title ?? second.value ?? ""));
        });
        return models;
    }

    Layout.fillWidth: true
    implicitHeight: composerSurface.implicitHeight

    function setDraft(value) {
        root.syncingDraft = true;
        draftInput.text = String(value ?? "");
        root.syncingDraft = false;
    }

    function focusInput() {
        root.activeRail = "composer";
        draftInput.forceActiveFocus();
        draftInput.cursorPosition = draftInput.length;
    }

    function showRail(rail) {
        root.activeRail = root.activeRail === rail ? "composer" : rail;
        if (root.activeRail === "composer")
            root.focusInput();
    }

    function closeRail() {
        if (root.activeRail === "composer")
            return false;
        root.focusInput();
        return true;
    }

    function cycleWebMode() {
        const modes = ["off", "auto", "on"];
        const index = modes.indexOf(Ai.webMode);
        Ai.setWebMode(modes[(index + 1 + modes.length) % modes.length], false);
    }

    function cycleFunctionExposure() {
        const values = ["all", "safe", "none"];
        const index = values.indexOf(Ai.functionExposure);
        Ai.setFunctionExposure(values[(index + 1 + values.length) % values.length], false);
    }

    function pasteClipboard() {
        const value = String(Quickshell.clipboardText ?? "");
        if (value.length === 0)
            return;
        const next = (draftInput.text.slice(0, draftInput.cursorPosition) + value + draftInput.text.slice(draftInput.cursorPosition)).slice(0, root.maximumCharacters);
        root.setDraft(next);
        Ai.draft = next;
        root.focusInput();
    }

    function selectModel(modelId) {
        if (Ai.setModel(modelId, false))
            root.focusInput();
    }

    function selectResponseMode(mode) {
        Ai.setResponseMode(mode, false);
        root.focusInput();
    }

    function railItems(railName) {
        if (railName === "actions") {
            return [
                { id: "back", kind: "icon", icon: "chevron_left", tooltip: Translation.tr("Return to message") },
                { id: "web", kind: "text", icon: "travel_explore", label: Translation.tr("Web search"), tooltip: Translation.tr("Web search: %1").arg(Ai.webMode) },
                { id: "tools", kind: "text", icon: "service_toolbox", label: Translation.tr("Tools"), tooltip: Translation.tr("Tools: %1").arg(Ai.functionExposure) },
                { id: "paste", kind: "icon", icon: "content_paste", tooltip: Translation.tr("Paste clipboard") },
                { id: "history", kind: "icon", icon: "history", tooltip: Translation.tr("Chat history") },
                { id: "response", kind: "icon", icon: "speed", tooltip: Translation.tr("Response effort: %1").arg(Ai.responseMode) }
            ];
        }
        if (railName === "models") {
            const start = [{ id: "back", kind: "icon", icon: "chevron_left", tooltip: Translation.tr("Return to message") }];
            return start.concat(root.orderedModels.map(model => ({
                id: String(model.id ?? ""),
                kind: "text",
                icon: model.materialIcon ?? "auto_awesome",
                customIcon: model.icon ?? "",
                label: model.title ?? model.value ?? "",
                tooltip: model.name ?? model.title ?? ""
            })));
        }
        return [
            { id: "back", kind: "icon", icon: "chevron_left", tooltip: Translation.tr("Return to message") },
            { id: "fast", kind: "text", icon: "speed", label: Translation.tr("Slow"), tooltip: Translation.tr("Response effort: Slow") },
            { id: "balanced", kind: "text", icon: "speed", label: Translation.tr("Medium"), tooltip: Translation.tr("Response effort: Medium") },
            { id: "deep", kind: "text", icon: "speed", label: Translation.tr("High"), tooltip: Translation.tr("Response effort: High") }
        ];
    }

    function railItemActive(railName, item) {
        if (railName === "actions") {
            if (item.id === "web")
                return root.webActive;
            return item.id === "response" && Ai.responseMode !== "balanced";
        }
        if (railName === "models")
            return item.id === Ai.currentModelId;
        return item.id === Ai.responseMode;
    }

    function activateRailItem(railName, item) {
        if (item.id === "back") {
            root.focusInput();
            return;
        }
        if (railName === "models") {
            root.selectModel(item.id);
            return;
        }
        if (railName === "response") {
            root.selectResponseMode(item.id);
            return;
        }
        switch (item.id) {
        case "web": root.cycleWebMode(); break;
        case "tools": root.cycleFunctionExposure(); break;
        case "paste": root.pasteClipboard(); break;
        case "history": root.requestOpenHistory(); break;
        case "response": root.showRail("response"); break;
        }
    }

    Connections {
        target: Ai
        function onDraftChanged() {
            if (draftInput.text !== Ai.draft)
                root.setDraft(Ai.draft);
        }
    }

    Component.onCompleted: root.setDraft(Ai.draft)

    Rectangle {
        id: composerSurface

        Layout.fillWidth: true
        implicitHeight: composerStage.implicitHeight + root.controlPadding * 2
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.full
        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: composerSurface.width
                height: composerSurface.height
                radius: composerSurface.radius
            }
        }

        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(composerSurface)
        }

        Item {
            id: composerStage
            anchors {
                fill: parent
                margins: root.controlPadding
            }
            implicitHeight: root.activeRail === "composer" ? composerRail.implicitHeight : root.controlExtent

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(composerStage)
            }

            // ── Compact composer ──────────────────────────────

            Item {
                id: composerRail
                anchors.left: parent.left
                anchors.right: parent.right
                height: implicitHeight
                implicitHeight: root.longDraft ? draftInput.height + root.controlGap + root.controlExtent : root.controlExtent
                opacity: root.activeRail === "composer" ? 1 : 0
                visible: opacity > 0.001
                x: root.activeRail === "composer" ? 0 : -root.railSlideDistance

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(composerRail)
                }
                Behavior on x {
                    animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(composerRail)
                }

                StyledTextArea {
                    id: draftInput
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: root.longDraft ? root.horizontalInset : root.controlExtent + root.controlGap
                        rightMargin: root.longDraft ? root.horizontalInset : modelButton.implicitWidth + sendButton.implicitWidth + root.controlGap * 2
                    }
                    height: root.longDraft
                        ? Math.max(root.controlExtent, Math.min(root.maximumEditorHeight, contentHeight + root.controlPadding * 2))
                        : root.controlExtent
                    color: Appearance.colors.colOnLayer1
                    placeholderText: Translation.tr("Ask something")
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    persistentSelection: true
                    background: Item {}
                    Accessible.name: Translation.tr("AI message")
                    Accessible.description: Translation.tr("Multiline draft. Enter sends; Shift+Enter inserts a line break.")

                    onTextChanged: {
                        const nextText = String(text ?? "");
                        if (nextText.length > root.maximumCharacters) {
                            const boundedText = nextText.slice(0, root.maximumCharacters);
                            if (boundedText !== nextText) {
                                root.syncingDraft = true;
                                text = boundedText;
                                root.syncingDraft = false;
                                if (!root.syncingDraft)
                                    Ai.draft = boundedText;
                                return;
                            }
                        }
                        if (!root.syncingDraft)
                            Ai.draft = text;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (!root.closeRail())
                                root.requestEscape();
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            root.requestSend();
                            event.accepted = true;
                        }
                    }
                }

                RowLayout {
                    id: composerActions
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: root.longDraft ? draftInput.bottom : parent.top
                        topMargin: root.longDraft ? root.controlGap : 0
                    }
                    height: root.controlExtent
                    spacing: root.controlGap

                    RailIconButton {
                        id: compactChevron
                        icon: "chevron_right"
                        tooltip: Translation.tr("Show chat controls")
                        active: false
                        onClicked: root.showRail("actions")
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }

                    RailTextButton {
                        id: modelButton
                        icon: root.modelSymbol
                        customIcon: root.modelIcon
                        label: root.modelTitle
                        maximumWidth: Math.max(root.controlExtent * 2, composerActions.width * 0.45)
                        active: true
                        tooltip: Translation.tr("Choose model: %1").arg(root.modelTitle)
                        onClicked: root.showRail("models")
                    }

                    SendButton {
                        id: sendButton
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // ── Collapsed controls rail ───────────────────────

            RailPage {
                id: actionsRail
                railName: "actions"
            }

            // ── Model carousel ─────────────────────────────────

            RailPage {
                id: modelsRail
                railName: "models"
                scrollable: true
            }

            // ── Response effort carousel ───────────────────────

            RailPage {
                id: responseRail
                railName: "response"
                scrollable: true
            }
        }

        // The send action remains visually fixed above every horizontal rail.
        // Its surface-colored fade makes scrolling content disappear naturally
        // below it instead of meeting a separate invisible viewport wall.
        Rectangle {
            id: sendFade
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            width: root.controlExtent + root.horizontalInset
            visible: root.activeRail === "models" || root.activeRail === "response"
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: ColorUtils.transparentize(Appearance.colors.colLayer1)
                }
                GradientStop {
                    position: 1
                    color: Appearance.colors.colLayer1
                }
            }
            z: 3
        }

        SendButton {
            id: railSendButton
            anchors {
                right: parent.right
                rightMargin: root.controlPadding
                verticalCenter: parent.verticalCenter
            }
            visible: root.activeRail !== "composer"
            z: 4
        }
    }

    component RailPage: Item {
        id: page

        required property string railName
        property bool scrollable: false

        anchors.fill: parent
        opacity: root.activeRail === page.railName ? 1 : 0
        visible: opacity > 0.001
        x: root.activeRail === page.railName ? 0 : -root.railSlideDistance

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(page)
        }
        Behavior on x {
            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(page)
        }

        Flickable {
            id: railFlickable
            anchors.fill: parent
            contentWidth: railRow.implicitWidth
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            interactive: page.scrollable && contentWidth > width
            clip: false

            RowLayout {
                id: railRow
                height: parent.height
                spacing: root.controlGap

                Repeater {
                    model: root.railItems(page.railName)
                    delegate: Loader {
                        required property var modelData
                        sourceComponent: modelData.kind === "text" ? textControl : iconControl
                        Layout.preferredWidth: item?.implicitWidth ?? 0
                        Layout.preferredHeight: item?.implicitHeight ?? 0
                    }
                }

                Component {
                    id: iconControl

                    RailIconButton {
                        icon: modelData.icon
                        tooltip: modelData.tooltip
                        active: root.railItemActive(page.railName, modelData)
                        onClicked: root.activateRailItem(page.railName, modelData)
                    }
                }

                Component {
                    id: textControl

                    RailTextButton {
                        icon: modelData.icon
                        customIcon: modelData.customIcon ?? ""
                        label: modelData.label
                        tooltip: modelData.tooltip
                        active: root.railItemActive(page.railName, modelData)
                        onClicked: root.activateRailItem(page.railName, modelData)
                    }
                }
            }
        }
    }

    component RailIconButton: RippleButton {
        id: iconButton

        property string icon: ""
        property string tooltip: ""
        property bool active: false

        implicitWidth: root.controlExtent
        implicitHeight: root.controlExtent
        buttonRadius: Appearance.rounding.full
        toggled: iconButton.active
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colBackgroundActive: Appearance.colors.colLayer2Active
        colRipple: Appearance.colors.colLayer2Active
        colBackgroundToggled: Appearance.colors.colPrimary
        colBackgroundToggledHover: Appearance.colors.colPrimaryHover
        colBackgroundToggledActive: Appearance.colors.colPrimaryActive
        colRippleToggled: Appearance.colors.colPrimaryActive
        Accessible.name: iconButton.tooltip

        contentItem: MaterialSymbol {
            text: iconButton.icon
            iconSize: Appearance.font.pixelSize.normal
            color: iconButton.active ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
        }

        StyledToolTip {
            text: iconButton.tooltip
        }
    }

    component RailTextButton: RippleButton {
        id: textButton

        property string icon: ""
        property string label: ""
        property string tooltip: ""
        property string customIcon: ""
        property bool active: false
        property real maximumWidth: Number.POSITIVE_INFINITY

        implicitWidth: Math.min(contentRow.implicitWidth + root.modelInset * 2, maximumWidth)
        implicitHeight: root.controlExtent
        buttonRadius: Appearance.rounding.full
        toggled: textButton.active
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colBackgroundActive: Appearance.colors.colLayer2Active
        colRipple: Appearance.colors.colLayer2Active
        colBackgroundToggled: Appearance.colors.colPrimary
        colBackgroundToggledHover: Appearance.colors.colPrimaryHover
        colBackgroundToggledActive: Appearance.colors.colPrimaryActive
        colRippleToggled: Appearance.colors.colPrimaryActive
        Accessible.name: textButton.tooltip

        contentItem: RowLayout {
            id: contentRow
            spacing: root.modelInset

            Loader {
                Layout.alignment: Qt.AlignVCenter
                active: textButton.customIcon.length > 0
                visible: active
                sourceComponent: CustomIcon {
                    source: textButton.customIcon
                    width: Appearance.font.pixelSize.normal
                    height: Appearance.font.pixelSize.normal
                    colorize: true
                    color: textButton.active ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: textButton.customIcon.length === 0
                text: textButton.icon
                iconSize: Appearance.font.pixelSize.normal
                color: textButton.active ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Math.max(Appearance.font.pixelSize.huge * 8, root.controlExtent * 2)
                text: textButton.label
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: Appearance.font.pixelSize.small
                color: textButton.active ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
            }
        }

        StyledToolTip {
            text: textButton.tooltip
        }
    }

    component SendButton: RailIconButton {
        icon: Ai.isGenerating ? "stop" : "arrow_upward"
        tooltip: Ai.isGenerating ? Translation.tr("Stop response") : Translation.tr("Send message (Enter)")
        active: !Ai.isGenerating
        enabled: Ai.isGenerating || root.hasDraft
        onClicked: {
            if (Ai.isGenerating)
                Ai.stopGeneration();
            else
                root.requestSend();
        }
    }
}
