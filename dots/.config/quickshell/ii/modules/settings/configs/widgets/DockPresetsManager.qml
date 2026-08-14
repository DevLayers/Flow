import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

ContentSection {
    id: root
    title: Translation.tr("Dock Presets")
    icon: "bookmarks"
    Layout.fillWidth: true

    readonly property string presetsFilePath: Directories.config + "/illogical-impulse/dock-presets.json"

    property var presetsList: []

    FileView {
        id: presetsFile
        path: root.presetsFilePath
        // A missing file is the normal first-run state until the user saves
        // the first preset; do not turn that state into a QML warning.
        printErrors: false
        onLoaded: root.loadPresetsFromJson()
        onLoadFailed: root.presetsList = []
        onAdapterUpdated: root.loadPresetsFromJson()
    }

    function loadPresetsFromJson() {
        try {
            if (!presetsFile.text || presetsFile.text.trim() === "") {
                presetsList = [];
                return;
            }
            let data = JSON.parse(presetsFile.text);
            if (Array.isArray(data)) {
                presetsList = data;
            } else {
                presetsList = [];
            }
        } catch (e) {
            console.log("[DockPresets] Error parsing dock-presets.json:", e);
            presetsList = [];
        }
    }

    function savePresetsToFile(list) {
        try {
            presetsList = list;
            presetsFile.text = JSON.stringify(list, null, 2);
        } catch (e) {
            console.log("[DockPresets] Error saving dock-presets.json:", e);
        }
    }

    function applyPreset(preset) {
        if (!preset) return;
        if (preset.pinnedApps) Config.options.dock.pinnedApps = preset.pinnedApps;
        if (preset.pinnedFiles) Config.options.dock.pinnedFiles = preset.pinnedFiles;
        if (preset.order) Config.options.dock.order = preset.order;
        if (preset.enableMediaWidget !== undefined) Config.options.dock.enableMediaWidget = preset.enableMediaWidget;
        if (preset.enableWeatherWidget !== undefined) Config.options.dock.enableWeatherWidget = preset.enableWeatherWidget;
        if (preset.enableSportsWidget !== undefined) Config.options.dock.enableSportsWidget = preset.enableSportsWidget;
        if (preset.enableLivePreviewWidget !== undefined) Config.options.dock.enableLivePreviewWidget = preset.enableLivePreviewWidget;
        if (preset.livePreviewAppId !== undefined) Config.options.dock.livePreviewAppId = preset.livePreviewAppId;
        if (preset.livePreviewSlots !== undefined) Config.options.dock.livePreviewSlots = preset.livePreviewSlots;
        if (preset.showPinButton !== undefined) Config.options.dock.showPinButton = preset.showPinButton;
        if (preset.showOverviewButton !== undefined) Config.options.dock.showOverviewButton = preset.showOverviewButton;
        if (preset.showTrashButton !== undefined) Config.options.dock.showTrashButton = preset.showTrashButton;
    }

    function saveCurrentAsPreset(name) {
        if (!name || name.trim() === "") return;
        let newPreset = {
            name: name.trim(),
            pinnedApps: Array.from(Config.options.dock.pinnedApps ?? []),
            pinnedFiles: Array.from(Config.options.dock.pinnedFiles ?? []),
            order: Array.from(Config.options.dock.order ?? []),
            enableMediaWidget: Config.options.dock.enableMediaWidget,
            enableWeatherWidget: Config.options.dock.enableWeatherWidget,
            enableSportsWidget: Config.options.dock.enableSportsWidget,
            enableLivePreviewWidget: Config.options.dock.enableLivePreviewWidget,
            livePreviewAppId: Config.options.dock.livePreviewAppId,
            livePreviewSlots: Config.options.dock.livePreviewSlots,
            showPinButton: Config.options.dock.showPinButton,
            showOverviewButton: Config.options.dock.showOverviewButton,
            showTrashButton: Config.options.dock.showTrashButton
        };

        let current = Array.from(presetsList);
        let existingIdx = current.findIndex(p => p.name === newPreset.name);
        if (existingIdx >= 0) {
            current[existingIdx] = newPreset;
        } else {
            current.push(newPreset);
        }
        savePresetsToFile(current);
    }

    function deletePreset(index) {
        let current = Array.from(presetsList);
        if (index >= 0 && index < current.length) {
            current.splice(index, 1);
            savePresetsToFile(current);
        }
    }

    // ── Input & Action Header ───────────────────────────────────────────────
    ConfigRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 48

        ToolbarTextField {
            id: presetNameInput
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: Translation.tr("Preset name...")
            font.pixelSize: Appearance.font.pixelSize.normal
        }

        RippleButtonWithIcon {
            materialIcon: "save"
            mainText: Translation.tr("Save")
            topLeftRadius: Appearance.rounding.full
            topRightRadius: Appearance.rounding.small
            bottomLeftRadius: Appearance.rounding.full
            bottomRightRadius: Appearance.rounding.small
            Layout.fillHeight: true
            enabled: presetNameInput.text.trim().length > 0
            onClicked: {
                if (presetNameInput.text.trim() !== "") {
                    root.saveCurrentAsPreset(presetNameInput.text);
                    presetNameInput.text = "";
                }
            }
        }
    }

    // ── Empty State ────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 150
        visible: root.presetsList.length === 0
        radius: Appearance.rounding.normal
        color: Appearance.colors.colSurfaceContainerLow
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "bookmark_border"
                iconSize: 42
                color: Appearance.colors.colOutline
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("No Dock Presets Saved")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Type a preset name above and click Save to store your current dock layout.")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOutline
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── Grid Flow Layout for Presets Cards ───────────────────────────────
    Item {
        id: flowContainer
        Layout.fillWidth: true
        Layout.topMargin: 10
        implicitHeight: flowLayout.implicitHeight
        visible: root.presetsList.length > 0

        Flow {
            id: flowLayout
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 15

            readonly property int minWidth: 260
            readonly property int spacingWidth: 15
            readonly property int columns: Math.max(1, Math.floor((width + spacingWidth) / (minWidth + spacingWidth)))
            readonly property real itemWidth: Math.floor((width - (columns - 1) * spacingWidth) / columns)

            add: Transition {
                NumberAnimation {
                    properties: "scale,opacity"
                    from: 0
                    to: 1
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }
            move: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            Repeater {
                model: root.presetsList

                delegate: Rectangle {
                    id: presetCard
                    required property var modelData
                    required property int index

                    width: flowLayout.itemWidth
                    implicitHeight: 145
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow
                    border.color: cardButton.down ? Appearance.colors.colPrimaryActive : (cardButton.hovered ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant)
                    border.width: cardButton.hovered ? 2 : 1

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    scale: cardButton.down ? 0.97 : 1.0

                    RippleButton {
                        id: cardButton
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.normal
                        colBackground: "transparent"
                        colBackgroundHover: "transparent"
                        colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                        onClicked: root.applyPreset(modelData)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                implicitWidth: 38
                                implicitHeight: 38
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colPrimaryContainer

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "dock"
                                    iconSize: 22
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name ?? Translation.tr("Unnamed Preset")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        let apps = modelData.pinnedApps ? modelData.pinnedApps.length : 0;
                                        let files = modelData.pinnedFiles ? modelData.pinnedFiles.length : 0;
                                        return `${apps} ${Translation.tr("apps")} • ${files} ${Translation.tr("files")}`;
                                    }
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOutline
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                visible: modelData.enableMediaWidget ?? false
                                implicitHeight: 22
                                implicitWidth: mediaTag.implicitWidth + 12
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colSecondaryContainer

                                StyledText {
                                    id: mediaTag
                                    anchors.centerIn: parent
                                    text: "🎵 " + Translation.tr("Media")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                            }

                            Rectangle {
                                visible: modelData.enableWeatherWidget ?? false
                                implicitHeight: 22
                                implicitWidth: weatherTag.implicitWidth + 12
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colSecondaryContainer

                                StyledText {
                                    id: weatherTag
                                    anchors.centerIn: parent
                                    text: "🌤 " + Translation.tr("Weather")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                            }

                            Rectangle {
                                visible: modelData.enableSportsWidget ?? false
                                implicitHeight: 22
                                implicitWidth: sportsTag.implicitWidth + 12
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colSecondaryContainer

                                StyledText {
                                    id: sportsTag
                                    anchors.centerIn: parent
                                    text: "⚽ " + Translation.tr("Sports")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                            }

                            Rectangle {
                                visible: modelData.enableLivePreviewWidget ?? false
                                implicitHeight: 22
                                implicitWidth: livePreviewTag.implicitWidth + 12
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colTertiaryContainer

                                StyledText {
                                    id: livePreviewTag
                                    anchors.centerIn: parent
                                    text: "▣ " + Translation.tr("Live Preview")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnTertiaryContainer
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RippleButtonWithIcon {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                materialIcon: "play_arrow"
                                mainText: Translation.tr("Load")
                                buttonRadius: Appearance.rounding.small
                                colBackground: Appearance.colors.colPrimary
                                colBackgroundHover: Appearance.colors.colPrimaryHover
                                colText: Appearance.colors.colOnPrimary
                                onClicked: root.applyPreset(modelData)
                            }

                            RippleButton {
                                implicitHeight: 32
                                implicitWidth: 32
                                buttonRadius: Appearance.rounding.small
                                colBackground: Appearance.colors.colErrorContainer
                                colBackgroundHover: Appearance.colors.colErrorContainerHover
                                onClicked: root.deletePreset(index)

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    iconSize: 16
                                    color: Appearance.colors.colOnErrorContainer
                                }

                                StyledToolTip {
                                    text: Translation.tr("Delete preset")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
