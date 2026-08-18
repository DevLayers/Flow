pragma ComponentBehavior: Bound

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
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
    signal requestFocusNext
    signal requestFocusPrev

    readonly property int maximumLines: 6
    readonly property int maximumCharacters: 12000
    readonly property real lineHeight: Math.round(draftInput.font.pixelSize * 1.5)
    readonly property real maximumEditorHeight: root.lineHeight * root.maximumLines + root.controlPadding * 2
    readonly property real controlExtent: Math.round(Appearance.font.pixelSize.huge * 2)
    readonly property real controlPadding: Appearance.rounding.small
    readonly property real controlGap: Appearance.rounding.verysmall
    readonly property real horizontalInset: Appearance.rounding.normal
    readonly property real chipPadding: Appearance.rounding.small
    readonly property real iconTextGap: Appearance.rounding.verysmall
    readonly property real railSlideDistance: Math.max(root.controlExtent, Appearance.rounding.large)
    readonly property bool hasDraft: draftInput.text.trim().length > 0
    readonly property real maximumCompactModelWidth: Math.max(root.controlExtent * 2, composerSurface.width * 0.45)
    readonly property real compactDraftWidth: Math.max(0, composerStage.width - root.controlExtent * 2 - root.controlGap * 2 - modelButton.implicitWidth)
    // The probe is always measured at the compact-row width. Unlike the live
    // editor, its width never changes when this condition turns true, which
    // prevents multiline expansion from feeding back into itself.
    readonly property bool longDraft: compactDraftProbe.lineCount > 1
    readonly property real expandedEditorHeight: Math.max(root.controlExtent, Math.min(root.maximumEditorHeight, draftInput.contentHeight + root.controlPadding * 2))
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

    function focusFirstButton() {
        if (root.activeRail !== "composer") {
            railSendButton.forceActiveFocus();
            return;
        }
        if (compactChevron.visible)
            compactChevron.forceActiveFocus();
        else
            modelButton.forceActiveFocus();
    }

    function focusLastButton() {
        if (root.activeRail !== "composer") {
            railSendButton.forceActiveFocus();
            return;
        }
        sendButton.forceActiveFocus();
    }

    function cycleWebMode() {
        const modes = ["off", "auto", "on"];
        const index = modes.indexOf(Ai.webMode);
        Ai.setWebMode(modes[(index + 1 + modes.length) % modes.length], false);
    }

    function webModeLabel(mode) {
        switch (mode) {
        case "on": return Translation.tr("Web on");
        case "auto": return Translation.tr("Web auto");
        default: return Translation.tr("Web off");
        }
    }

    function toolModeLabel(mode) {
        switch (mode) {
        case "safe": return Translation.tr("Tools safe");
        case "none": return Translation.tr("Tools off");
        default: return Translation.tr("Tools all");
        }
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
                { id: "web", kind: "text", icon: "travel_explore", label: root.webModeLabel(Ai.webMode), tooltip: Translation.tr("Web search: %1").arg(Ai.webMode) },
                { id: "tools", kind: "text", icon: "service_toolbox", label: root.toolModeLabel(Ai.functionExposure), tooltip: Translation.tr("Tools: %1").arg(Ai.functionExposure) },
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
        radius: root.longDraft ? Appearance.rounding.large : Appearance.rounding.full
        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: composerSurface.width
                height: composerSurface.height
                radius: composerSurface.radius
            }
        }

        Behavior on radius {
            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(composerSurface)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.focusInput()
        }

        Item {
            id: composerStage
            anchors {
                fill: parent
                margins: root.controlPadding
            }
            implicitHeight: root.activeRail === "composer" ? composerRail.implicitHeight : root.controlExtent

            TextEdit {
                id: compactDraftProbe
                visible: false
                width: root.compactDraftWidth
                text: draftInput.text
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                font.variableAxes: Appearance.font.variableAxes.main
            }

            // ── Compact composer ──────────────────────────────

            Item {
                id: composerRail
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.longDraft ? root.expandedEditorHeight + root.controlGap + root.controlExtent : root.controlExtent
                implicitHeight: height
                opacity: root.activeRail === "composer" ? 1 : 0
                visible: opacity > 0.001

                Behavior on height {
                    animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(composerRail)
                }

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(composerRail)
                }

                transform: Translate {
                    id: composerRailSlide
                    x: root.activeRail === "composer" ? 0 : -root.railSlideDistance

                    Behavior on x {
                        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(composerRailSlide)
                    }
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
                    height: root.longDraft ? root.expandedEditorHeight : root.controlExtent
                    color: Appearance.colors.colOnLayer1
                    placeholderText: Translation.tr("Ask something")
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    verticalAlignment: root.longDraft ? TextEdit.AlignTop : TextEdit.AlignVCenter
                    topPadding: root.longDraft ? root.controlPadding : 0
                    bottomPadding: root.longDraft ? root.controlPadding : 0
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    selectByMouse: true
                    persistentSelection: true
                    background: Item {}
                    Accessible.name: Translation.tr("AI message")
                    Accessible.description: Translation.tr("Multiline draft. Enter sends; Shift+Enter inserts a line break.")

                    Behavior on height {
                        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(draftInput)
                    }
                    Behavior on anchors.leftMargin {
                        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(draftInput)
                    }
                    Behavior on anchors.rightMargin {
                        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(draftInput)
                    }

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
                        } else if (event.key === Qt.Key_Tab) {
                            if (event.modifiers & Qt.ShiftModifier) {
                                root.requestFocusPrev();
                            } else {
                                root.focusFirstButton();
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Backtab) {
                            root.requestFocusPrev();
                            event.accepted = true;
                        }
                    }
                }

                RowLayout {
                    id: composerActions
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    y: root.longDraft ? root.expandedEditorHeight + root.controlGap : 0
                    height: root.controlExtent
                    spacing: root.controlGap

                    Behavior on y {
                        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(composerActions)
                    }

                    RailIconButton {
                        id: compactChevron
                        symbol: "chevron_right"
                        tooltip: Translation.tr("Show chat controls")
                        active: false
                        onClicked: root.showRail("actions")

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Space || event.key === Qt.Key_Enter) {
                                root.showRail("actions");
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.focusInput();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    root.focusInput();
                                else
                                    modelButton.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Backtab) {
                                root.focusInput();
                                event.accepted = true;
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }

                    RailTextButton {
                        id: modelButton
                        symbol: root.modelSymbol
                        customIcon: root.modelIcon
                        label: root.modelTitle
                        maximumWidth: root.maximumCompactModelWidth
                        active: true
                        tooltip: Translation.tr("Choose model: %1").arg(root.modelTitle)
                        onClicked: root.showRail("models")

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Space || event.key === Qt.Key_Enter) {
                                root.showRail("models");
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.focusInput();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    compactChevron.forceActiveFocus();
                                else
                                    sendButton.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Backtab) {
                                compactChevron.forceActiveFocus();
                                event.accepted = true;
                            }
                        }
                    }

                    SendButton {
                        id: sendButton
                        Layout.alignment: Qt.AlignVCenter

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Space || event.key === Qt.Key_Enter) {
                                if (Ai.isGenerating)
                                    Ai.stopGeneration();
                                else
                                    root.requestSend();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.focusInput();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    modelButton.forceActiveFocus();
                                else
                                    root.requestFocusNext();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Backtab) {
                                modelButton.forceActiveFocus();
                                event.accepted = true;
                            }
                        }
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
            width: root.controlExtent * 2 + root.horizontalInset
            visible: root.activeRail === "models" || root.activeRail === "response"
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: ColorUtils.transparentize(Appearance.colors.colLayer1)
                }
                GradientStop {
                    position: 0.28
                    color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.65)
                }
                GradientStop {
                    position: 0.62
                    color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.1)
                }
                GradientStop {
                    position: 1
                    color: Appearance.colors.colLayer1
                }
            }
            z: 3
        }

        Item {
            id: modelEdgeBlur
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            width: sendFade.width
            visible: root.activeRail === "models"
            z: 2
            layer.enabled: visible
            layer.effect: OpacityMask {
                maskSource: modelEdgeBlurMask
            }

            ShaderEffectSource {
                id: modelRailCapture
                anchors.fill: parent
                sourceItem: modelsRail
                sourceRect: {
                    const edgeOrigin = modelEdgeBlur.mapToItem(modelsRail, 0, 0);
                    return Qt.rect(edgeOrigin.x, edgeOrigin.y, width, height);
                }
                live: modelEdgeBlur.visible
                hideSource: false
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: modelRailCapture
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: root.controlExtent
                blur: 0.6
            }
        }

        Item {
            id: modelEdgeBlurMask
            x: modelEdgeBlur.x
            y: modelEdgeBlur.y
            width: modelEdgeBlur.width
            height: modelEdgeBlur.height
            visible: false

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: ColorUtils.transparentize(Appearance.colors.colLayer1)
                    }
                    GradientStop {
                        position: 0.3
                        color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.8)
                    }
                    GradientStop {
                        position: 0.72
                        color: Appearance.colors.colLayer1
                    }
                    GradientStop {
                        position: 1
                        color: Appearance.colors.colLayer1
                    }
                }
            }
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
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(page)
        }

        transform: Translate {
            id: pageSlide
            x: root.activeRail === page.railName ? 0 : -root.railSlideDistance

            Behavior on x {
                animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(pageSlide)
            }
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
                    delegate: RailControl {
                        required property var modelData
                        railName: page.railName
                        railItem: modelData
                    }
                }
            }
        }
    }

    component RailControl: Item {
        id: railControl

        required property string railName
        required property var railItem
        readonly property bool isTextControl: railItem?.kind === "text"

        implicitWidth: isTextControl ? textControl.implicitWidth : iconControl.implicitWidth
        implicitHeight: root.controlExtent

        RailIconButton {
            id: iconControl
            anchors.fill: parent
            visible: !railControl.isTextControl
            symbol: String(railControl.railItem?.icon ?? "")
            tooltip: String(railControl.railItem?.tooltip ?? "")
            active: root.railItemActive(railControl.railName, railControl.railItem)
            onClicked: root.activateRailItem(railControl.railName, railControl.railItem)
        }

        RailTextButton {
            id: textControl
            anchors.fill: parent
            visible: railControl.isTextControl
            symbol: String(railControl.railItem?.icon ?? "")
            customIcon: String(railControl.railItem?.customIcon ?? "")
            label: String(railControl.railItem?.label ?? "")
            tooltip: String(railControl.railItem?.tooltip ?? "")
            active: root.railItemActive(railControl.railName, railControl.railItem)
            onClicked: root.activateRailItem(railControl.railName, railControl.railItem)
        }
    }

    component RailIconButton: RippleButton {
        id: iconButton

        property string symbol: ""
        property string tooltip: ""
        property bool active: false

        implicitWidth: root.controlExtent
        implicitHeight: root.controlExtent
        buttonRadius: Appearance.rounding.full
        focusPolicy: Qt.StrongFocus
        toggled: iconButton.active
        colBackground: iconButton.activeFocus
            ? (iconButton.active ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer2Active)
            : (iconButton.active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2)
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colBackgroundActive: Appearance.colors.colLayer2Active
        colRipple: Appearance.colors.colLayer2Active
        colBackgroundToggled: Appearance.colors.colPrimary
        colBackgroundToggledHover: Appearance.colors.colPrimaryHover
        colBackgroundToggledActive: Appearance.colors.colPrimaryActive
        colRippleToggled: Appearance.colors.colPrimaryActive
        Accessible.name: iconButton.tooltip

        contentItem: MaterialSymbol {
            text: iconButton.symbol
            iconSize: Appearance.font.pixelSize.larger
            fill: 1
            color: (iconButton.active || iconButton.activeFocus) ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
        }

        StyledToolTip {
            text: iconButton.tooltip
        }
    }

    component RailTextButton: RippleButton {
        id: textButton

        property string symbol: ""
        property string label: ""
        property string tooltip: ""
        property string customIcon: ""
        property bool active: false
        property real maximumWidth: Number.POSITIVE_INFINITY

        implicitWidth: Math.min(contentRow.implicitWidth + root.chipPadding * 2, maximumWidth)
        implicitHeight: root.controlExtent
        buttonRadius: Appearance.rounding.full
        focusPolicy: Qt.StrongFocus
        toggled: textButton.active
        colBackground: textButton.activeFocus
            ? (textButton.active ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer2Active)
            : (textButton.active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2)
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
            spacing: root.iconTextGap

            Loader {
                Layout.alignment: Qt.AlignVCenter
                active: textButton.customIcon.length > 0
                visible: active
                sourceComponent: CustomIcon {
                    source: textButton.customIcon
                    width: Appearance.font.pixelSize.larger
                    height: Appearance.font.pixelSize.larger
                    colorize: true
                    color: (textButton.active || textButton.activeFocus) ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: textButton.customIcon.length === 0
                text: textButton.symbol
                iconSize: Appearance.font.pixelSize.larger
                fill: 1
                color: (textButton.active || textButton.activeFocus) ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Math.max(Appearance.font.pixelSize.huge * 8, root.controlExtent * 2)
                text: textButton.label
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                color: (textButton.active || textButton.activeFocus) ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
            }
        }

        StyledToolTip {
            text: textButton.tooltip
        }
    }

    component SendButton: RailIconButton {
        symbol: Ai.isGenerating ? "stop" : "send"
        tooltip: Ai.isGenerating ? Translation.tr("Stop response") : Translation.tr("Send message (Enter)")
        // Disabled send remains fully opaque; it changes to the neutral layer
        // instead of inheriting RippleButton's generic disabled fade.
        active: enabled && !Ai.isGenerating
        enabled: Ai.isGenerating || root.hasDraft
        opacity: 1
        onClicked: {
            if (Ai.isGenerating)
                Ai.stopGeneration();
            else
                root.requestSend();
        }
    }
}
