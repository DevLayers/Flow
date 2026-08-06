import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/tiling.js" as Tiling

ContentPage {
    id: page
    forceWidth: false

    property string selectedMonitor: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

    readonly property var monitorList: Array.from(Config.options.tiling.monitors ?? [])
    readonly property var currentEntry: page.entryFor(page.selectedMonitor)
    readonly property string currentPreset: page.currentEntry?.preset ?? Config.options.tiling.defaultPreset
    readonly property var currentZones: Tiling.zonesForMonitor(Config.options.tiling.monitors, page.selectedMonitor, Config.options.tiling.defaultPreset)
    readonly property var currentGapsOverride: page.currentEntry?.gapsOverride ?? null

    readonly property real monitorAspect: {
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i];
            if (screen.name !== page.selectedMonitor || screen.height <= 0) continue;
            return screen.width / screen.height;
        }
        return 16 / 9;
    }

    readonly property var presetOptions: {
        const list = [];
        const icons = {
            "kde": "dashboard",
            "halves": "vertical_split",
            "thirds": "view_column",
            "sidebars": "view_week",
            "quarters": "grid_view",
            "sixths": "view_module"
        };
        for (const id of Tiling.PRESET_IDS) {
            list.push({
                "displayName": Translation.tr(Tiling.PRESET_NAMES[id]),
                "icon": icons[id] ?? "grid_view",
                "value": id
            });
        }
        list.push({
            "displayName": Translation.tr("Custom"),
            "icon": "draw",
            "value": "custom"
        });
        return list;
    }

    function entryFor(name) {
        for (const entry of page.monitorList) {
            if (entry?.name === name) return entry;
        }
        return null;
    }

    // The monitor list is stored rather than derived, so every edit rewrites the
    // whole array: changing one entry in place leaves the JsonAdapter with no
    // idea anything happened.
    function updateEntry(patch) {
        if (!page.selectedMonitor) return;
        const list = page.monitorList.map(entry => Object.assign({}, entry));
        let index = list.findIndex(entry => entry?.name === page.selectedMonitor);
        if (index < 0) {
            list.push({
                "name": page.selectedMonitor
            });
            index = list.length - 1;
        }
        Config.options.tiling.monitors = list.map((entry, i) => i === index ? Object.assign({}, entry, patch) : entry);
    }

    function setZones(zones) {
        page.updateEntry({
            "preset": "custom",
            "zones": zones
        });
    }

    // The shortcuts below are bound in the Hyprland config, which the shell's
    // own update never touches - so they can be missing on an otherwise current
    // install, and nothing else detects a drag, so the feature is simply inert.
    WarningBox {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        visible: TilingAssistant.keybindsMissing
        materialIcon: "keyboard_off"
        text: Translation.tr("Hyprland has no binding for the tiling assistant, so Super + drag and Super + Alt + arrows do nothing and no zones are ever shown. Re-run the setup script with --hypr to install the Hyprland config.")
        isFirst: true
        isLast: true
    }

    KeyboardShortcutBox {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        visible: Config.options.tiling.enable && Config.options.tiling.keyboardQuickTile
        text: Translation.tr("Quick-tile in a direction, or untile at the edge")
        keys: ["Super", "Alt", "←↑→↓"]
    }

    ContentSection {
        title: Translation.tr("Tiling assistant")
        icon: "grid_view"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "toggle_on"
                text: Translation.tr("Enable")
                checked: Config.options.tiling.enable
                onCheckedChanged: {
                    Config.options.tiling.enable = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.tiling.enable
                buttonIcon: "drag_pan"
                text: Translation.tr("Show zones when a window drag starts")
                checked: Config.options.tiling.showOnDragStart
                onCheckedChanged: {
                    Config.options.tiling.showOnDragStart = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.tiling.enable
                buttonIcon: "keyboard"
                text: Translation.tr("Quick-tile with Super + Alt + arrows")
                checked: Config.options.tiling.keyboardQuickTile
                onCheckedChanged: {
                    Config.options.tiling.keyboardQuickTile = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.tiling.enable && Config.options.tiling.mode !== "preview"
                buttonIcon: "settings_backup_restore"
                text: Translation.tr("Restore the original size when a window leaves its zone")
                checked: Config.options.tiling.restoreOnUntile
                onCheckedChanged: {
                    Config.options.tiling.restoreOnUntile = checked;
                }
            }

            ContentSubsection {
                title: Translation.tr("What happens on drop")
                icon: "ads_click"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.tiling.mode
                    onSelected: newValue => {
                        Config.options.tiling.mode = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Quick-tile"),
                            icon: "grid_view",
                            value: "quickTile"
                        },
                        {
                            displayName: Translation.tr("Preview only"),
                            icon: "visibility",
                            value: "preview"
                        },
                        {
                            displayName: Translation.tr("Hybrid"),
                            icon: "call_split",
                            value: "hybrid"
                        }
                    ]
                }
            }
        }

        TipBox {
            Layout.fillWidth: true
            materialIcon: "info"
            text: Translation.tr("Quick-tile floats the window and gives it the zone's exact geometry. Preview only draws the overlay and leaves Hyprland's own layout alone. Hybrid quick-tiles windows that are already floating and previews the ones Hyprland is tiling.")
        }
    }

    ContentSection {
        title: Translation.tr("Zones")
        icon: "dashboard_customize"
        visible: Config.options.tiling.enable

        ContentSubsection {
            title: Translation.tr("Monitor")
            icon: "monitor"
            Layout.fillWidth: true

            MonitorPicker {
                currentValue: page.selectedMonitor
                onSelected: newValue => {
                    page.selectedMonitor = newValue;
                    editor.selectedIndex = -1;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Layout")
            icon: "view_quilt"
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: page.currentPreset
                onSelected: newValue => {
                    editor.selectedIndex = -1;
                    // Custom starts from whatever is on screen: an empty monitor
                    // would throw away the layout the user was looking at.
                    if (newValue === "custom") page.setZones(page.currentZones);
                    else page.updateEntry({
                        "preset": newValue
                    });
                }
                options: page.presetOptions
            }
        }

        TilingZoneEditor {
            id: editor

            Layout.fillWidth: true
            Layout.topMargin: 8
            // Shown for every layout: on a preset it is a preview of what was
            // just picked, and only "Custom" makes it editable.
            readOnly: page.currentPreset !== "custom"
            zones: page.currentZones
            aspect: page.monitorAspect
            onZonesEdited: updated => page.setZones(updated)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: page.currentPreset === "custom"
            spacing: 4

            RippleButtonWithIcon {
                buttonRadius: Appearance.rounding.small
                materialIcon: "add_box"
                mainText: Translation.tr("Add zone")
                onClicked: {
                    const list = Array.from(page.currentZones);
                    list.push({
                        "x": 1 / 3,
                        "y": 1 / 3,
                        "w": 1 / 3,
                        "h": 1 / 3
                    });
                    page.setZones(list);
                    editor.selectedIndex = list.length - 1;
                }
            }

            RippleButtonWithIcon {
                buttonRadius: Appearance.rounding.small
                enabled: editor.selectedIndex >= 0
                materialIcon: "delete"
                mainText: Translation.tr("Delete")
                onClicked: {
                    const list = Array.from(page.currentZones);
                    list.splice(editor.selectedIndex, 1);
                    editor.selectedIndex = -1;
                    page.setZones(list);
                }
            }

            RippleButtonWithIcon {
                buttonRadius: Appearance.rounding.small
                materialIcon: "restart_alt"
                mainText: Translation.tr("Start over")
                onClicked: {
                    editor.selectedIndex = -1;
                    page.setZones([]);
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        TipBox {
            Layout.fillWidth: true
            Layout.topMargin: 8
            materialIcon: "info"
            text: Translation.tr("Zones cover the screen minus the bar and the gaps. With a layout that leaves no empty space, dragging a window out of tiling means dropping it on the bar or on another monitor — leave a strip free if you would rather have somewhere to drop.")
        }
    }

    ContentSection {
        title: Translation.tr("Gaps")
        icon: "padding"
        visible: Config.options.tiling.enable

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "sync"
                text: Translation.tr("Follow Hyprland's gaps")
                checked: Config.options.tiling.gaps.followHyprland
                onCheckedChanged: {
                    Config.options.tiling.gaps.followHyprland = checked;
                }
            }

            ConfigSpinBox {
                enabled: !Config.options.tiling.gaps.followHyprland
                icon: "border_outer"
                text: Translation.tr("Screen edge gap (px)")
                value: Config.options.tiling.gaps.outer
                from: 0
                to: 64
                stepSize: 1
                onValueChanged: {
                    Config.options.tiling.gaps.outer = value;
                }
            }

            ConfigSpinBox {
                enabled: !Config.options.tiling.gaps.followHyprland
                icon: "border_inner"
                text: Translation.tr("Gap between zones (px)")
                value: Config.options.tiling.gaps.inner
                from: 0
                to: 64
                stepSize: 1
                onValueChanged: {
                    Config.options.tiling.gaps.inner = value;
                }
            }

            ConfigSwitch {
                buttonIcon: "monitor"
                text: Translation.tr("Different gaps on %1").arg(page.selectedMonitor)
                checked: page.currentGapsOverride !== null
                onCheckedChanged: {
                    if (checked === (page.currentGapsOverride !== null)) return;
                    page.updateEntry({
                        "gapsOverride": checked ? {
                            "outer": Config.options.tiling.gaps.outer,
                            "inner": Config.options.tiling.gaps.inner
                        } : null
                    });
                }
            }

            ConfigSpinBox {
                visible: page.currentGapsOverride !== null
                icon: "border_outer"
                text: Translation.tr("Screen edge gap on %1 (px)").arg(page.selectedMonitor)
                value: page.currentGapsOverride?.outer ?? 0
                from: 0
                to: 64
                stepSize: 1
                onValueChanged: {
                    if (page.currentGapsOverride === null || value === page.currentGapsOverride.outer) return;
                    page.updateEntry({
                        "gapsOverride": {
                            "outer": value,
                            "inner": page.currentGapsOverride.inner
                        }
                    });
                }
            }

            ConfigSpinBox {
                visible: page.currentGapsOverride !== null
                icon: "border_inner"
                text: Translation.tr("Gap between zones on %1 (px)").arg(page.selectedMonitor)
                value: page.currentGapsOverride?.inner ?? 0
                from: 0
                to: 64
                stepSize: 1
                onValueChanged: {
                    if (page.currentGapsOverride === null || value === page.currentGapsOverride.inner) return;
                    page.updateEntry({
                        "gapsOverride": {
                            "outer": page.currentGapsOverride.outer,
                            "inner": value
                        }
                    });
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Overlay")
        icon: "opacity"
        visible: Config.options.tiling.enable

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "label"
                text: Translation.tr("Name each zone")
                checked: Config.options.tiling.overlay.showLabels
                onCheckedChanged: {
                    Config.options.tiling.overlay.showLabels = checked;
                }
            }

            ConfigSpinBox {
                icon: "opacity"
                text: Translation.tr("Zone opacity (%)")
                value: Math.round(Config.options.tiling.overlay.zoneOpacity * 100)
                from: 5
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.tiling.overlay.zoneOpacity = value / 100;
                }
            }

            ConfigSpinBox {
                icon: "highlight"
                text: Translation.tr("Hovered zone opacity (%)")
                value: Math.round(Config.options.tiling.overlay.hoveredOpacity * 100)
                from: 5
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.tiling.overlay.hoveredOpacity = value / 100;
                }
            }

            ConfigSpinBox {
                icon: "rounded_corner"
                text: Translation.tr("Corner radius (px)")
                value: Config.options.tiling.overlay.cornerRadius
                from: 0
                to: 48
                stepSize: 1
                onValueChanged: {
                    Config.options.tiling.overlay.cornerRadius = value;
                }
            }

            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Fade duration (ms)")
                value: Config.options.tiling.overlay.fadeDuration
                from: 0
                to: 600
                stepSize: 10
                onValueChanged: {
                    Config.options.tiling.overlay.fadeDuration = value;
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Resizing")
        icon: "open_in_full"
        visible: Config.options.tiling.enable && Config.options.tiling.mode !== "preview"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "width"
                text: Translation.tr("Resizing a tiled window moves its neighbours")
                checked: Config.options.tiling.coResize.enable
                onCheckedChanged: {
                    Config.options.tiling.coResize.enable = checked;
                }
            }

            ConfigSpinBox {
                enabled: Config.options.tiling.coResize.enable
                icon: "straighten"
                text: Translation.tr("Shared edge tolerance (px)")
                value: Config.options.tiling.coResize.edgeTolerancePx
                from: 1
                to: 64
                stepSize: 1
                onValueChanged: {
                    Config.options.tiling.coResize.edgeTolerancePx = value;
                }
            }
        }

        TipBox {
            Layout.fillWidth: true
            materialIcon: "info"
            text: Translation.tr("Dragged edges last until the shell restarts, and are dropped when the layout above changes. Only windows the assistant placed take part.")
        }
    }

    ContentSection {
        title: Translation.tr("Drag detection")
        icon: "my_location"
        visible: Config.options.tiling.enable

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            ConfigSwitch {
                buttonIcon: "keyboard_command_key"
                text: Translation.tr("Listen to Hyprland's move and resize binds")
                checked: Config.options.tiling.detection.useKeybinds
                onCheckedChanged: {
                    Config.options.tiling.detection.useKeybinds = checked;
                }
            }

            ConfigSpinBox {
                enabled: Config.options.tiling.detection.useKeybinds
                icon: "straighten"
                text: Translation.tr("Window tracking tolerance (px)")
                value: Config.options.tiling.detection.trackingTolerancePx
                from: 0
                to: 32
                stepSize: 1
                onValueChanged: {
                    Config.options.tiling.detection.trackingTolerancePx = value;
                }
            }

            ConfigSpinBox {
                enabled: Config.options.tiling.detection.useKeybinds
                icon: "hourglass_empty"
                text: Translation.tr("Window sampling rate between drags (Hz)")
                value: Config.options.tiling.detection.idleHz
                from: 1
                to: 30
                stepSize: 1
                onValueChanged: {
                    Config.options.tiling.detection.idleHz = value;
                }
            }

            ConfigSpinBox {
                enabled: Config.options.tiling.detection.useKeybinds
                icon: "bolt"
                text: Translation.tr("Polling rate during a drag (Hz)")
                value: Config.options.tiling.detection.activeHz
                from: 30
                to: 240
                stepSize: 10
                onValueChanged: {
                    Config.options.tiling.detection.activeHz = value;
                }
            }
        }

        TipBox {
            Layout.fillWidth: true
            materialIcon: "info"
            text: Translation.tr("Only Super + drag is detected. Dragging a window by its own titlebar fires no Hyprland bind, and inferring one from the window's motion was dropped: nothing reports the button coming back up, so the guess either broke the layout or never showed the zones at all.")
        }
    }

    ContentSection {
        icon: "link"
        title: Translation.tr("Related settings")

        Flow {
            Layout.fillWidth: true
            spacing: 8

            RelatedChip {
                pageId: "windows"
                label: Translation.tr("Windows")
            }

            RelatedChip {
                pageId: "displays"
                label: Translation.tr("Displays")
            }
        }
    }
}
