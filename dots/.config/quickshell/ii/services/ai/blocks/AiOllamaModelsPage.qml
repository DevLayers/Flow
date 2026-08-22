pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.services.ai
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * A local-first model catalogue for the sidebar picker.
 *
 * Suggestions are available without querying a remote catalogue. Pulling is
 * always explicit and happens through the user's loopback Ollama daemon.
 */
Item {
    id: root

    signal backRequested

    property bool active: false
    property bool showHeader: true
    property bool fillAvailableHeight: false
    property string query: ""
    property list<string> pulledModels: []

    readonly property real rowGap: Appearance.rounding.unsharpenmore
    readonly property real maxListHeight: 520
    readonly property real actionExtent: Math.round(Appearance.font.pixelSize.huge * 2)

    implicitHeight: pageColumn.implicitHeight
    height: root.fillAvailableHeight && parent ? parent.height : implicitHeight

    function modelMatches(model, needle: string): bool {
        if (needle.length === 0)
            return true;
        return model.title.toLowerCase().includes(needle)
            || model.name.toLowerCase().includes(needle)
            || model.description.toLowerCase().includes(needle)
            || model.category.toLowerCase().includes(needle);
    }

    readonly property var visibleModels: {
        const needle = root.query.trim().toLowerCase();
        return OllamaCatalog.models.filter(model => root.modelMatches(model, needle));
    }

    function isInstalled(modelName: string): bool {
        return root.pulledModels.indexOf(modelName) >= 0
            || !!Ai.catalog.models["ollama:" + modelName];
    }

    function pull(modelName: string) {
        if (OllamaCatalog.pull(modelName))
            customModelInput.text = "";
    }

    Connections {
        target: OllamaCatalog

        function onPullSucceeded(modelName) {
            if (root.pulledModels.indexOf(modelName) < 0)
                root.pulledModels = [...root.pulledModels, modelName];
            Ai.refreshOllamaModels();
        }
    }

    onActiveChanged: {
        if (root.active)
            Qt.callLater(customModelInput.forceActiveFocus);
    }

    ColumnLayout {
        id: pageColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.fillAvailableHeight ? root.height : implicitHeight
        spacing: root.rowGap

        RowLayout {
            Layout.fillWidth: true
            visible: root.showHeader
            spacing: root.rowGap

            RippleButton {
                implicitWidth: root.actionExtent
                implicitHeight: root.actionExtent
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.backRequested()

                Accessible.name: Translation.tr("Back to model providers")
                contentItem: MaterialSymbol {
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Ollama models")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.bold: true
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Pull a model to your local machine")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        NoticeBox {
            Layout.fillWidth: true
            materialIcon: "download"
            text: Translation.tr("Pulling downloads the chosen model from the Ollama library through your local daemon. Nothing is downloaded until you press Pull.")
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: root.actionExtent
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer2

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.IBeamCursor
                onClicked: customModelInput.forceActiveFocus()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.rounding.large
                anchors.rightMargin: Appearance.rounding.verysmall
                spacing: root.rowGap

                MaterialSymbol {
                    text: "search"
                    fill: 1
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colSubtext
                }

                StyledTextInput {
                    id: customModelInput
                    Layout.fillWidth: true
                    enabled: !OllamaCatalog.pulling
                    font.pixelSize: Appearance.font.pixelSize.normal
                    onTextChanged: root.query = text
                    Keys.onReturnPressed: root.pull(text)

                    Accessible.name: Translation.tr("Find or enter an Ollama model name")

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        cursorShape: Qt.IBeamCursor
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: customModelInput.text.length === 0
                        text: Translation.tr("Find a model or enter a library tag")
                        color: Appearance.colors.colSubtext
                        font: customModelInput.font
                    }
                }

                RippleButton {
                    id: customPullButton
                    readonly property string candidate: OllamaCatalog.normalizeModelName(customModelInput.text)

                    implicitWidth: root.actionExtent
                    implicitHeight: root.actionExtent
                    buttonRadius: Appearance.rounding.full
                    enabled: !OllamaCatalog.pulling && candidate.length > 0 && !root.isInstalled(candidate)
                    colBackground: enabled ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                    colBackgroundHover: enabled ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer3
                    colRipple: enabled ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer3Active
                    onClicked: root.pull(candidate)

                    Accessible.name: Translation.tr("Pull this Ollama model")
                    contentItem: MaterialSymbol {
                        text: "download"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.normal
                        color: customPullButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: OllamaCatalog.pullState !== "idle"
            spacing: root.rowGap / 2

            RowLayout {
                Layout.fillWidth: true
                spacing: root.rowGap

                MaterialSymbol {
                    text: OllamaCatalog.pulling
                        ? "progress_activity"
                        : OllamaCatalog.pullState === "succeeded" ? "check_circle"
                        : OllamaCatalog.pullState === "cancelled" ? "stop_circle" : "error"
                    fill: 1
                    iconSize: Appearance.font.pixelSize.normal
                    color: OllamaCatalog.pulling || OllamaCatalog.pullState === "succeeded"
                        ? Appearance.colors.colPrimary
                        : OllamaCatalog.pullState === "cancelled"
                            ? Appearance.colors.colSubtext
                        : Appearance.colors.colError
                }

                StyledText {
                    Layout.fillWidth: true
                    text: OllamaCatalog.pulling
                        ? OllamaCatalog.pullingModel + " · " + OllamaCatalog.pullStatus
                        : OllamaCatalog.pullState === "failed"
                            ? OllamaCatalog.pullError
                            : OllamaCatalog.pullStatus
                    wrapMode: Text.Wrap
                    color: OllamaCatalog.pullState === "failed"
                        ? Appearance.colors.colError
                        : Appearance.colors.colSubtext
                }

                RippleButton {
                    visible: OllamaCatalog.pulling
                    implicitWidth: root.actionExtent
                    implicitHeight: root.actionExtent
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: OllamaCatalog.cancelPull()

                    Accessible.name: Translation.tr("Stop model download")
                    contentItem: MaterialSymbol {
                        text: "stop"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }

            StyledProgressBar {
                Layout.fillWidth: true
                visible: OllamaCatalog.pulling && OllamaCatalog.pullProgress >= 0
                from: 0
                to: 1
                value: OllamaCatalog.pullProgress >= 0 ? OllamaCatalog.pullProgress : 0
                valueBarHeight: Appearance.rounding.unsharpenmore / 2
                valueBarGap: Appearance.rounding.unsharpenmore / 2
                highlightColor: Appearance.colors.colPrimary
                trackColor: Appearance.colors.colLayer3
            }
        }

        StyledListView {
            id: modelList
            Layout.fillWidth: true
            Layout.fillHeight: root.fillAvailableHeight
            Layout.minimumHeight: root.fillAvailableHeight ? 0 : 96
            Layout.preferredHeight: root.fillAvailableHeight
                ? 0
                : Math.min(root.maxListHeight, Math.max(96, contentHeight))
            clip: true
            spacing: root.rowGap
            animatePopulate: false
            model: root.visibleModels

            delegate: RowLayout {
                id: modelRow
                required property var modelData

                width: modelList.width
                readonly property bool installed: root.isInstalled(modelData.name)
                readonly property bool pullingThis: OllamaCatalog.pullingModel === modelData.name

                spacing: root.rowGap

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: details.implicitHeight + root.rowGap * 2
                    radius: Appearance.rounding.large
                    color: Appearance.colors.colLayer2

                    ColumnLayout {
                        id: details
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Appearance.rounding.large
                        anchors.rightMargin: Appearance.rounding.large
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.rowGap

                            StyledText {
                                Layout.fillWidth: true
                                text: modelRow.modelData.title
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.bold: true
                                elide: Text.ElideRight
                                color: Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                text: modelRow.modelData.category
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelRow.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelRow.modelData.description
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.Wrap
                        }
                    }
                }

                RippleButton {
                    id: modelPullButton
                    implicitWidth: root.actionExtent
                    implicitHeight: root.actionExtent
                    buttonRadius: Appearance.rounding.full
                    enabled: !modelRow.installed && !OllamaCatalog.pulling
                    colBackground: enabled ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                    colBackgroundHover: enabled ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer3
                    colRipple: enabled ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer3Active
                    onClicked: root.pull(modelRow.modelData.name)

                    Accessible.name: modelRow.installed
                        ? Translation.tr("Model already pulled")
                        : Translation.tr("Pull %1").arg(modelRow.modelData.title)
                    contentItem: MaterialSymbol {
                        text: modelRow.installed ? "check" : modelRow.pullingThis ? "progress_activity" : "download"
                        fill: 1
                        iconSize: Appearance.font.pixelSize.normal
                        color: modelPullButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            visible: root.visibleModels.length === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            text: Translation.tr("No suggested Ollama model matches this search. Enter a library tag above to pull it.")
            color: Appearance.colors.colSubtext
        }
    }
}
