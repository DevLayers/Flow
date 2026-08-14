import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentPage {
    id: page

    forceWidth: false

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

    function addDockFolder(path: string): void {
        const cleanPath = page.cleanDockFolderPath(path);
        if (cleanPath)
            TaskbarApps.addPinnedFile(cleanPath);
    }

    function removeDockFolder(index: int): void {
        const folders = Array.from(Config.options.dock.pinnedFiles ?? []);
        if (index >= 0 && index < folders.length)
            TaskbarApps.removePinnedFile(folders[index]);
    }

    function moveDockFolder(index: int, direction: int): void {
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
            buttonIcon: "group_work"
            text: Translation.tr("Smart auto-grouping")
            checked: Config.options.dock.smartGrouping
            onCheckedChanged: {
                Config.options.dock.smartGrouping = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            visible: Config.options.dock.enable
            buttonIcon: "folder_special"
            text: Translation.tr("Enable app groups")
            checked: Config.options.dock.enableAppGroups ?? true
            onCheckedChanged: {
                Config.options.dock.enableAppGroups = checked;
            }
            StyledToolTip {
                text: Translation.tr("Combine up to six apps into dock groups by dragging one app onto another.")
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

        Item {
            visible: Config.options.dock.enable
            Layout.preferredHeight: 8
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            visible: Config.options.dock.enable
            buttonIcon: "preview"
            text: Translation.tr("Enable windows preview")
            checked: Config.options.dock.enablePreview
            onCheckedChanged: {
                Config.options.dock.enablePreview = checked;
                if (checked) {
                    Config.options.dock.enableAppTooltip = false;
                }
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            visible: Config.options.dock.enable
            buttonIcon: "subtitles"
            text: Translation.tr("Enable app name tooltips")
            checked: Config.options.dock.enableAppTooltip
            onCheckedChanged: {
                Config.options.dock.enableAppTooltip = checked;
                if (checked) {
                    Config.options.dock.enablePreview = false;
                }
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

    }

    // ── Content & buttons ─────────────────────────────────────────────────
    ContentSection {
        visible: Config.options.dock.enable
        title: Translation.tr("Content & buttons")
        icon: "widgets"

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "play_circle"
            text: Translation.tr("Enable media widget")
            checked: Config.options.dock.enableMediaWidget
            onCheckedChanged: {
                Config.options.dock.enableMediaWidget = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "cloud"
            text: Translation.tr("Enable weather widget")
            checked: Config.options.dock.enableWeatherWidget
            onCheckedChanged: {
                Config.options.dock.enableWeatherWidget = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "sports_soccer"
            text: Translation.tr("Enable sports widget")
            checked: Config.options.dock.enableSportsWidget ?? true
            onCheckedChanged: {
                Config.options.dock.enableSportsWidget = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "live_tv"
            text: Translation.tr("Enable Live Preview widget")
            checked: Config.options.dock.enableLivePreviewWidget ?? false
            onCheckedChanged: {
                Config.options.dock.enableLivePreviewWidget = checked;
            }
        }

        ContentSubsection {
            visible: Config.options.dock.enable && (Config.options.dock.enableLivePreviewWidget ?? false)
            title: Translation.tr("Live Preview")
            icon: "live_tv"
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: Config.options.dock.livePreviewAppId ?? ""
                onSelected: newValue => {
                    DockLivePreviewService.selectApp(newValue);
                }
                options: {
                    const options = [{
                        displayName: Translation.tr("No application selected"),
                        icon: "block",
                        value: ""
                    }];
                    const selected = Config.options.dock.livePreviewAppId ?? "";
                    if (selected !== "") {
                        options.push({
                            displayName: TaskbarApps.getCachedDesktopEntry(selected)?.name ?? selected,
                            icon: "live_tv",
                            value: selected
                        });
                    }
                    for (const app of (TaskbarApps.apps ?? [])) {
                        const appId = app?.appId ?? "";
                        if (!appId || options.some(option => TaskbarApps.normalizeAppId(option.value) === TaskbarApps.normalizeAppId(appId)))
                            continue;
                        options.push({
                            displayName: TaskbarApps.getCachedDesktopEntry(appId)?.name ?? appId,
                            icon: "apps",
                            value: appId
                        });
                    }
                    return options;
                }
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                icon: "width"
                text: Translation.tr("Preview width (slots)")
                value: Config.options.dock.livePreviewSlots ?? 2
                from: 2
                to: 6
                stepSize: 1
                onValueChanged: Config.options.dock.livePreviewSlots = value
            }

            ConfigSelectionArray {
                currentValue: Config.options.dock.livePreviewCaptureMode ?? "visible"
                onSelected: newValue => Config.options.dock.livePreviewCaptureMode = newValue
                options: [
                    {
                        displayName: Translation.tr("While visible"),
                        icon: "visibility",
                        value: "visible"
                    },
                    {
                        displayName: Translation.tr("While hovered"),
                        icon: "touch_app",
                        value: "hover"
                    }
                ]
            }

            ConfigSwitch {
                buttonIcon: "mouse"
                text: Translation.tr("Show captured cursor")
                checked: Config.options.dock.livePreviewPaintCursor ?? false
                onCheckedChanged: Config.options.dock.livePreviewPaintCursor = checked
            }

            ConfigSwitch {
                buttonIcon: "sync"
                text: Translation.tr("Follow active window")
                checked: Config.options.dock.livePreviewFollowActiveWindow ?? true
                onCheckedChanged: Config.options.dock.livePreviewFollowActiveWindow = checked
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "smartphone"
            text: Translation.tr("Show phone mirror button")
            checked: Config.options.dock.showPhoneButton ?? true
            onCheckedChanged: {
                Config.options.dock.showPhoneButton = checked;
            }
        }

        Item {
            Layout.preferredHeight: 8
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "notifications"
            text: Translation.tr("Show notification badges")
            checked: Config.options.dock.showNotificationBadges
            onCheckedChanged: {
                Config.options.dock.showNotificationBadges = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "vertical_split"
            text: Translation.tr("Show dividers")
            checked: Config.options.dock.showDividers
            onCheckedChanged: {
                Config.options.dock.showDividers = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "grid_view"
            text: Translation.tr("Show overview button")
            checked: Config.options.dock.showOverviewButton
            onCheckedChanged: {
                Config.options.dock.showOverviewButton = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "keep"
            text: Translation.tr("Show pin button")
            checked: Config.options.dock.showPinButton
            onCheckedChanged: {
                Config.options.dock.showPinButton = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.dock.enable
            buttonIcon: "delete"
            text: Translation.tr("Show trash button")
            checked: Config.options.dock.showTrashButton
            onCheckedChanged: {
                Config.options.dock.showTrashButton = checked;
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
            text: Translation.tr("Enable macOS icon magnification")
            checked: Config.options.dock.enableMagnification ?? false
            onCheckedChanged: {
                Config.options.dock.enableMagnification = checked;
            }
        }

        ConfigSlider {
            visible: Config.options.dock.enableMagnification ?? false
            Layout.fillWidth: true
            text: Translation.tr("Magnification intensity")
            value: Math.round((Config.options.dock.magnificationScale ?? 1.5) * 100)
            from: 120
            to: 220
            stepSize: 5
            onValueChanged: {
                Config.options.dock.magnificationScale = value / 100.0;
            }
        }

        ConfigSlider {
            visible: Config.options.dock.enableMagnification ?? false
            Layout.fillWidth: true
            text: Translation.tr("Influence radius (icons)")
            value: Config.options.dock.magnificationInfluenceRadius ?? 2.35
            from: 1.2
            to: 4.0
            stepSize: 0.1
            usePercentTooltip: false
            tooltipContent: Number(value).toFixed(1)
            onValueChanged: {
                Config.options.dock.magnificationInfluenceRadius = value;
            }
        }

        ContentSubsection {
            visible: Config.options.dock.enableMagnification ?? false
            title: Translation.tr("Magnification motion")
            icon: "animation"
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: Config.options.dock.magnificationMotion ?? "balanced"
                onSelected: newValue => {
                    Config.options.dock.magnificationMotion = newValue;
                }
                options: [
                    { displayName: Translation.tr("Fast"), icon: "fast_forward", value: "fast" },
                    { displayName: Translation.tr("Balanced"), icon: "animation", value: "balanced" },
                    { displayName: Translation.tr("Smooth"), icon: "slow_motion_video", value: "smooth" }
                ]
            }
        }

        ConfigSwitch {
            visible: Config.options.dock.enableMagnification ?? false
            buttonIcon: "open_in_full"
            text: Translation.tr("Dynamic icon spacing")
            checked: Config.options.dock.magnificationDynamicSpacing ?? true
            onCheckedChanged: {
                Config.options.dock.magnificationDynamicSpacing = checked;
            }
            StyledToolTip {
                text: Translation.tr("Reserve local layout space as icons magnify so their visual gaps stay stable")
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

    // Keep this optional section out of the page's static type-import graph.
    // The directory import used to make the whole Dock page fail when the
    // preset component (or one of its dependencies) was not registered yet.
    Loader {
        id: dockPresetsLoader
        Layout.fillWidth: true
        asynchronous: true
        visible: Config.options.dock.enable
        source: Qt.resolvedUrl("widgets/DockPresetsManager.qml")
        Layout.preferredHeight: item ? item.implicitHeight : 0
    }

}
