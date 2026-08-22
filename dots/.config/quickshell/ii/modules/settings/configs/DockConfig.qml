import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: dockConfigRoot
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

        function cleanDockFolderPath(path: string): string {
            let cleanPath = String(path ?? "").trim().replace(/^file:\/\//, "");
            try {
                cleanPath = decodeURIComponent(cleanPath);
            } catch (error) {
                // Keep the original path if a file manager returns malformed URI data.
            }
            if (cleanPath.length > 1)
                cleanPath = cleanPath.replace(/\/+$/, "");
            return cleanPath;
        }

        function addDockFolder(path: string) {
            const cleanPath = page.cleanDockFolderPath(path);
            if (cleanPath)
                TaskbarApps.addPinnedFile(cleanPath);
        }

        function removeDockFolder(index: int) {
            const folders = Array.from(Config.options.dock.pinnedFiles ?? []);
            if (index >= 0 && index < folders.length)
                TaskbarApps.removePinnedFile(folders[index]);
        }

        function moveDockFolder(index: int, direction: int) {
            const folders = Config.options.dock.pinnedFiles ?? [];
            const targetIndex = index + direction;
            if (targetIndex < 0 || targetIndex >= folders.length)
                return;
            TaskbarApps.reorderPinnedFileByIndex(index, targetIndex);
        }

        FolderDialog {
            id: dockFolderDialog
            title: Translation.tr("Choose a folder for the dock")
            currentFolder: "file://" + Quickshell.env("HOME")
            onAccepted: page.addDockFolder(selectedFolder.toString())
        }

        // ── Behavior ──────────────────────────────────────────────────────────
        ContentSection {
            title: Translation.tr("Behavior")
            icon: "dock"

            ConfigSwitch {
                buttonIcon: "toggle_on"
                text: Translation.tr("Enable")
                checked: Config.options.dock.enable
                onCheckedChanged: {
                    Config.options.dock.enable = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.dock.enable
                visible: Config.options.dock.enable
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Show only on focused monitor")
                checked: Config.options.dock.showOnlyOnFocusedMonitor
                onCheckedChanged: {
                    Config.options.dock.showOnlyOnFocusedMonitor = checked;
                }
                StyledToolTip {
                    text: Translation.tr("When workspace is empty, show the dock only on the focused monitor instead of all monitors")
                }
            }

            ConfigSwitch {
                enabled: Config.options.dock.enable
                visible: Config.options.dock.enable
                buttonIcon: "monitor"
                text: Translation.tr("Isolate monitors")
                checked: Config.options.dock.isolateMonitors
                onCheckedChanged: {
                    Config.options.dock.isolateMonitors = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.dock.enable
                visible: Config.options.dock.enable
                buttonIcon: "mouse"
                text: Translation.tr("Hover to reveal")
                checked: Config.options.dock.hoverToReveal
                onCheckedChanged: {
                    Config.options.dock.hoverToReveal = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.dock.enable
                visible: Config.options.dock.enable
                buttonIcon: "push_pin"
                text: Translation.tr("Pinned on startup")
                checked: Config.options.dock.pinnedOnStartup
                onCheckedChanged: {
                    Config.options.dock.pinnedOnStartup = checked;
                }
            }

            ContentSubsection {
                enabled: Config.options.dock.enable
                visible: Config.options.dock.enable
                title: Translation.tr("Hover content")
                icon: "touch_app"
                Layout.fillWidth: true
                tooltip: Translation.tr("Choose what to display when hovering pinned or running apps in the dock.")

                ConfigSelectionArray {
                    currentValue: Config.options.dock.enablePreview ? "preview" : (Config.options.dock.enableAppTooltip ? "tooltip" : "none")
                    onSelected: newValue => {
                        Config.options.dock.enablePreview = (newValue === "preview");
                        Config.options.dock.enableAppTooltip = (newValue === "tooltip");
                    }
                    options: [
                        { displayName: Translation.tr("None"), icon: "block", value: "none" },
                        { displayName: Translation.tr("App Name"), icon: "subtitles", value: "tooltip" },
                        { displayName: Translation.tr("Window Preview"), icon: "preview", value: "preview" }
                    ]
                }
            }

            ConfigSwitch {
                enabled: Config.options.dock.enable
                visible: Config.options.dock.enable
                buttonIcon: "folder_special"
                text: Translation.tr("App groups & smart grouping")
                checked: Config.options.dock.enableAppGroups ?? true
                configPage: Qt.resolvedUrl("widgets/DockAppGroupsConfig.qml")
                onCheckedChanged: {
                    Config.options.dock.enableAppGroups = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Combine up to six apps into dock groups. Click button text to configure smart auto-grouping.")
                }
            }
        }

        // ── Content & buttons ─────────────────────────────────────────────────
        ContentSection {
            visible: Config.options.dock.enable
            title: Translation.tr("Content & buttons")
            icon: "widgets"

            NoticeBox {
                Layout.fillWidth: true
                isFirst: true
                text: Translation.tr("Toggle the widgets and utility buttons visible on the dock.")
            }

            GridLayout {
                id: dockButtonsGrid
                Layout.fillWidth: true
                columns: width >= Appearance.font.pixelSize.hugeass * 24 ? 3 : (width >= Appearance.font.pixelSize.hugeass * 16 ? 2 : 1)
                columnSpacing: 8
                rowSpacing: 8

                // Media Widget
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.dock.enableMediaWidget
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.dock.enableMediaWidget = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "play_circle"
                            iconSize: 20
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Media Widget")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: parent.parent.active
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }

                // Weather Widget
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.dock.enableWeatherWidget
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.dock.enableWeatherWidget = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "cloud"
                            iconSize: 20
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Weather Widget")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: parent.parent.active
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }

                // Sports Widget
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.dock.enableSportsWidget ?? true
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.dock.enableSportsWidget = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "sports_soccer"
                            iconSize: 20
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Sports Widget")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: parent.parent.active
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }

                // Live Preview Tile (com botão de navegação)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: Appearance.rounding.normal
                    color: (Config.options.dock.enableLivePreviewWidget ?? false) ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        RippleButton {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            buttonRadius: Appearance.rounding.normal
                            colBackground: "transparent"
                            colBackgroundHover: "transparent"
                            colRipple: "transparent"
                            onClicked: Config.options.dock.enableLivePreviewWidget = !(Config.options.dock.enableLivePreviewWidget ?? false)

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                MaterialSymbol {
                                    text: "live_tv"
                                    iconSize: 20
                                    fill: (Config.options.dock.enableLivePreviewWidget ?? false) ? 1 : 0
                                    color: (Config.options.dock.enableLivePreviewWidget ?? false) ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Live Preview")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.bold: (Config.options.dock.enableLivePreviewWidget ?? false)
                                    color: (Config.options.dock.enableLivePreviewWidget ?? false) ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                                }
                            }
                        }

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.full
                            colBackground: (Config.options.dock.enableLivePreviewWidget ?? false) ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                            colBackgroundHover: Appearance.colors.colLayer3Hover
                            colRipple: Appearance.colors.colLayer3Active
                            onClicked: dockConfigRoot.activeSubPage = Qt.resolvedUrl("widgets/DockLivePreviewConfig.qml")

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "settings"
                                iconSize: 16
                                color: (Config.options.dock.enableLivePreviewWidget ?? false) ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                            }

                            StyledToolTip {
                                text: Translation.tr("Configure Live Preview settings")
                            }
                        }
                    }
                }

                // Phone Mirror
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.dock.showPhoneButton ?? true
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.dock.showPhoneButton = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "smartphone"
                            iconSize: 20
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Phone Mirror")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: parent.parent.active
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }

                // Notification Badges
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.dock.showNotificationBadges
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.dock.showNotificationBadges = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "notifications"
                            iconSize: 20
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Notification Badges")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: parent.parent.active
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }

                // Dividers
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.dock.showDividers
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.dock.showDividers = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "vertical_split"
                            iconSize: 20
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Dividers")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: parent.parent.active
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }

                // Overview Button
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.dock.showOverviewButton
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.dock.showOverviewButton = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "grid_view"
                            iconSize: 20
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Overview Button")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: parent.parent.active
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }

                // Pin Button
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.dock.showPinButton
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.dock.showPinButton = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "keep"
                            iconSize: 20
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Pin Button")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: parent.parent.active
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }

                // Trash Button
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.dock.showTrashButton
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.dock.showTrashButton = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "delete"
                            iconSize: 20
                            fill: parent.parent.active ? 1 : 0
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Trash Button")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: parent.parent.active
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        // ── Appearance ────────────────────────────────────────────────────────
        ContentSection {
            visible: Config.options.dock.enable
            title: Translation.tr("Appearance")
            icon: "palette"

            ConfigSwitch {
                enabled: Config.options.dock.enable
                buttonIcon: "palette"
                text: Translation.tr("Tint dock icons")
                checked: Config.options.dock.monochromeIcons
                onCheckedChanged: {
                    Config.options.dock.monochromeIcons = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Applies monochrome tint to dock icons")
                }
            }

            ConfigSwitch {
                enabled: Config.options.dock.enable && !Config.options.dock.monochromeIcons
                buttonIcon: "tonality"
                text: Translation.tr("Dim inactive dock icons")
                checked: Config.options.dock.dimInactiveIcons
                onCheckedChanged: {
                    Config.options.dock.dimInactiveIcons = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Greyscale icons for pinned apps that are not running.\nDisabled when 'Tint dock icons' is active.")
                }
            }

            ConfigSlider {
                Layout.fillWidth: true
                text: Translation.tr("Icon spacing")
                value: Config.options.dock.iconSpacing
                from: -4
                to: 16
                stepSize: 1
                onValueChanged: {
                    Config.options.dock.iconSpacing = value;
                }
            }

            ConfigSwitch {
                buttonIcon: "view_quilt"
                text: Translation.tr("Islands style")
                checked: Config.options.dock.islandsStyle ?? false
                onCheckedChanged: {
                    Config.options.dock.islandsStyle = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Separate apps, widgets and utilities into independent dock surfaces. Drag an island by its outer edge to reorder it.")
                }
            }

            ConfigSlider {
                visible: Config.options.dock.islandsStyle ?? false
                Layout.fillWidth: true
                text: Translation.tr("Island spacing")
                value: Config.options.dock.islandSpacing ?? 8
                from: 4
                to: 32
                stepSize: 1
                usePercentTooltip: false
                onValueChanged: {
                    Config.options.dock.islandSpacing = value;
                }
            }

            ConfigSlider {
                Layout.fillWidth: true
                text: Translation.tr("Dock corner radius") + (Config.options.dock.dockRadius < 0 ? " (" + Translation.tr("Auto") + ")" : "")
                value: Config.options.dock.dockRadius < 0 ? 0 : Config.options.dock.dockRadius
                from: 0
                to: 60
                stepSize: 1
                onValueChanged: {
                    Config.options.dock.dockRadius = value === 0 ? -1 : value;
                }
            }

            ConfigSlider {
                Layout.fillWidth: true
                text: Translation.tr("Widget corner radius") + (Config.options.dock.widgetRadius < 0 ? " (" + Translation.tr("Auto") + ")" : "")
                value: Config.options.dock.widgetRadius < 0 ? 0 : Config.options.dock.widgetRadius
                from: 0
                to: 40
                stepSize: 1
                onValueChanged: {
                    Config.options.dock.widgetRadius = value === 0 ? -1 : value;
                }
            }

            ConfigSwitch {
                buttonIcon: "zoom_in"
                text: Translation.tr("macOS icon magnification")
                checked: Config.options.dock.enableMagnification ?? false
                configPage: Qt.resolvedUrl("widgets/DockMagnificationConfig.qml")
                onCheckedChanged: {
                    Config.options.dock.enableMagnification = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Magnifies icons on hover. Click button text to configure intensity, influence radius, and motion styles.")
                }
            }
        }

        ContentSection {
            visible: Config.options.dock.enable
            title: Translation.tr("Dock Shape Mask")
            icon: "category"

            ConfigSwitch {
                buttonIcon: "interests"
                text: Translation.tr("Adaptive icons")
                checked: Config.options.dock.enableShapeMask
                onCheckedChanged: {
                    Config.options.dock.enableShapeMask = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Crops the icons using the selected material shape")
                }

                extraComponent: Component {
                    RippleButtonWithShape {
                        enabled: Config.options.dock.enableShapeMask
                        shapeString: Config.options.dock.shapeMask
                        implicitWidth: 60
                        extraIcon: "edit"
                        onClicked: {
                            dockShapeMaskLoader.active = !dockShapeMaskLoader.active;
                        }

                        StyledToolTip {
                            text: Translation.tr("Edit the material shape")
                        }
                    }
                }
            }

            Loader {
                id: dockShapeMaskLoader
                active: false
                visible: active && Config.options.dock.enable
                Layout.fillWidth: true

                sourceComponent: ContentSubsection {
                    title: Translation.tr("Mask shape")
                    icon: "shape_line"

                    ConfigSelectionArray {
                        currentValue: Config.options.dock.shapeMask
                        onSelected: (newValue) => {
                            Config.options.dock.shapeMask = newValue;
                        }
                        options: (["Circle", "Square", "Slanted", "Arch", "Arrow", "SemiCircle", "Oval", "Pill", "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny", "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided", "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Flower", "Puffy", "PuffyDiamond", "PixelCircle", "Bun", "Heart"]).map((icon) => {
                            return {
                                "displayName": "",
                                "shape": icon,
                                "value": icon
                            };
                        })
                    }
                }
            }
        }

        // ── Dock folders ─────────────────────────────────────────────────────
        ContentSection {
            visible: Config.options.dock.enable
            title: Translation.tr("Dock folders")
            icon: "folder_special"

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Add folders to the dock and choose their position.")
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }

                RippleButtonWithIcon {
                    mainText: Translation.tr("Add folder")
                    materialIcon: "create_new_folder"
                    colText: Appearance.colors.colOnPrimaryContainer
                    colBackground: Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    onClicked: dockFolderDialog.open()
                }
            }

            Item {
                Layout.fillWidth: true
                visible: (Config.options.dock.pinnedFiles ?? []).length === 0
                implicitHeight: visible ? 110 : 0

                PagePlaceholder {
                    anchors.fill: parent
                    shown: parent.visible
                    icon: "folder_off"
                    title: Translation.tr("No folders in the dock")
                    description: Translation.tr("Use Add folder to place a directory in the dock.")
                    shape: MaterialShape.Shape.Cookie7Sided
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: Config.options.dock.pinnedFiles ?? []

                    delegate: Rectangle {
                        id: dockFolderRow
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 60
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer2

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 10

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                text: "folder"
                                iconSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colPrimary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        const parts = dockFolderRow.modelData.split("/").filter(part => part.length > 0);
                                        return parts[parts.length - 1] ?? dockFolderRow.modelData;
                                    }
                                    color: Appearance.colors.colOnLayer2
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: dockFolderRow.modelData
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideMiddle
                                }
                            }

                            RippleButtonWithIcon {
                                mainText: ""
                                materialIcon: "arrow_upward"
                                enabled: dockFolderRow.index > 0
                                opacity: enabled ? 1 : 0.4
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                buttonRadius: Appearance.rounding.full
                                colText: Appearance.colors.colOnLayer2
                                colBackground: Appearance.colors.colLayer3
                                colBackgroundHover: Appearance.colors.colLayer3Hover
                                colRipple: Appearance.colors.colLayer3Active
                                onClicked: page.moveDockFolder(dockFolderRow.index, -1)

                                StyledToolTip {
                                    text: Translation.tr("Move folder up")
                                }
                            }

                            RippleButtonWithIcon {
                                mainText: ""
                                materialIcon: "arrow_downward"
                                enabled: dockFolderRow.index < (Config.options.dock.pinnedFiles ?? []).length - 1
                                opacity: enabled ? 1 : 0.4
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                buttonRadius: Appearance.rounding.full
                                colText: Appearance.colors.colOnLayer2
                                colBackground: Appearance.colors.colLayer3
                                colBackgroundHover: Appearance.colors.colLayer3Hover
                                colRipple: Appearance.colors.colLayer3Active
                                onClicked: page.moveDockFolder(dockFolderRow.index, 1)

                                StyledToolTip {
                                    text: Translation.tr("Move folder down")
                                }
                            }

                            RippleButtonWithIcon {
                                mainText: ""
                                materialIcon: "close"
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                buttonRadius: Appearance.rounding.full
                                colText: Appearance.colors.colOnErrorContainer
                                colBackground: Appearance.colors.colErrorContainer
                                colBackgroundHover: Appearance.colors.colErrorContainerHover
                                colRipple: Appearance.colors.colErrorContainerActive
                                onClicked: page.removeDockFolder(dockFolderRow.index)

                                StyledToolTip {
                                    text: Translation.tr("Remove folder from dock")
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Position & size ───────────────────────────────────────────────────
        ContentSection {
            visible: Config.options.dock.enable
            title: Translation.tr("Position & size")
            icon: "open_in_full"

            ConfigSpinBox {
                enabled: Config.options.dock.enable
                icon: "height"
                text: Translation.tr("Dock height")
                value: Config.options.dock.height
                from: 20
                to: 200
                stepSize: 1
                onValueChanged: {
                    Config.options.dock.height = value;
                }
            }

            ContentSubsection {
                visible: Config.options.dock.enable
                title: Translation.tr("Dock position")
                icon: "border_all"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.dock.position
                    onSelected: (newValue) => {
                        Config.options.dock.position = newValue;
                    }
                    options: [{
                        "displayName": Translation.tr("Auto"),
                        "icon": "auto_awesome",
                        "value": "auto"
                    }, {
                        "displayName": Translation.tr("Bottom"),
                        "icon": "border_bottom",
                        "value": "bottom"
                    }, {
                        "displayName": Translation.tr("Top"),
                        "icon": "border_top",
                        "value": "top"
                    }, {
                        "displayName": Translation.tr("Left"),
                        "icon": "border_left",
                        "value": "left"
                    }, {
                        "displayName": Translation.tr("Right"),
                        "icon": "border_right",
                        "value": "right"
                    }]
                }
            }
        }

        Loader {
            id: dockPresetsLoader
            Layout.fillWidth: true
            asynchronous: true
            visible: Config.options.dock.enable
            source: Qt.resolvedUrl("widgets/DockPresetsManager.qml")
            Layout.preferredHeight: item ? item.implicitHeight : 0
        }
    }

    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }
}
