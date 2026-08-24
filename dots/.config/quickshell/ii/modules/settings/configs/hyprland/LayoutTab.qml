pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings -> Hyprland -> Layout.
 *
 * The tiling engine and everything that follows from it, plus the focus and workspace rules that
 * decide where attention goes once the windows are placed.
 *
 * Only the engine that is actually running gets a section, because the four of them share almost
 * no options and showing all four at once would be four times the page for no gain. The diagram
 * at the top is the point of the tab: it runs the same arithmetic the layout does and draws where
 * the next window lands, so the options stop being folklore.
 */
ContentPage {
    id: tab

    forceWidth: false

    readonly property string engine:
        String(HyprlandGui.displayValue("general:layout", "dwindle") ?? "dwindle")
    readonly property bool knownEngine:
        ["dwindle", "master", "scrolling", "monocle"].includes(tab.engine)

    ContentSection {
        title: Translation.tr("Tiling engine")
        icon: "view_quilt"

        HyprSelect {
            optionKey: "general:layout"
            defaultValue: "dwindle"
            title: Translation.tr("How windows are arranged")
            icon: "grid_view"
            options: [
                { "displayName": Translation.tr("Dwindle"), "icon": "splitscreen", "value": "dwindle" },
                { "displayName": Translation.tr("Master"), "icon": "view_sidebar", "value": "master" },
                { "displayName": Translation.tr("Scrolling"), "icon": "view_carousel", "value": "scrolling" },
                { "displayName": Translation.tr("Monocle"), "icon": "crop_square", "value": "monocle" }
            ]
        }

        ContentSubsection {
            title: Translation.tr("Where the next window lands")
            icon: "preview"
            Layout.fillWidth: true

            HyprLayoutPreview {
                engine: tab.engine
            }
        }

        HyprOptionNote {
            keys: ["general:layout"]
            notes: tab.knownEngine ? [] : [{
                "icon": "help",
                "text": Translation.tr("The layout in use is \"%1\", which is neither built in nor drawn here. A Lua layout is written as lua:<name>.").arg(tab.engine)
            }]
        }
    }

    Loader {
        active: tab.engine === "dwindle"
        visible: active
        Layout.fillWidth: true

        sourceComponent: ContentSection {
            title: Translation.tr("Dwindle")
            icon: "splitscreen"

            HyprSelect {
                optionKey: "dwindle:force_split"
                defaultValue: 0
                title: Translation.tr("Which half a new window takes")
                icon: "flip"
                options: [
                    { "displayName": Translation.tr("Where the pointer is"), "value": 0 },
                    { "displayName": Translation.tr("Left or top"), "value": 1 },
                    { "displayName": Translation.tr("Right or bottom"), "value": 2 }
                ]
            }

            HyprSlider {
                id: splitRatioSlider

                optionKey: "dwindle:default_split_ratio"
                defaultValue: 1
                buttonIcon: "straighten"
                text: Translation.tr("How evenly a window splits")
                // Hyprland spells this as a 0.1-1.9 number where 1 is even; what it means to
                // anyone looking at it is the share the first side takes.
                readonly property int firstShare:
                    Math.round(Math.max(0.08, Math.min(0.92, value / 2)) * 100)
                tooltipContent: `${splitRatioSlider.firstShare}% / ${100 - splitRatioSlider.firstShare}%`
                from: 0.1
                to: 1.9
                stepSize: 0.05
            }

            HyprSelect {
                optionKey: "dwindle:split_bias"
                defaultValue: 0
                title: Translation.tr("Which window keeps that share")
                icon: "balance"
                options: [
                    { "displayName": Translation.tr("The left or top one"), "value": 0 },
                    { "displayName": Translation.tr("The one already open"), "value": 1 }
                ]
            }

            HyprSlider {
                optionKey: "dwindle:split_width_multiplier"
                defaultValue: 1
                buttonIcon: "aspect_ratio"
                text: Translation.tr("How wide before a window splits sideways")
                tooltipContent: `${value.toFixed(2)}×`
                from: 0.1
                to: 3
                stepSize: 0.05

                StyledToolTip {
                    text: Translation.tr("A window splits side by side while it is wider than its height times this. Above 1 it takes an unusually wide window to split sideways; below 1, almost any window does.")
                }
            }

            HyprSwitch {
                optionKey: "dwindle:preserve_split"
                buttonIcon: "lock"
                text: Translation.tr("Keep the split direction when a window closes")
            }

            HyprSwitch {
                optionKey: "dwindle:smart_split"
                buttonIcon: "grid_4x4"
                text: Translation.tr("Split into quarters, following the pointer")

                StyledToolTip {
                    text: Translation.tr("The quarter of the window the pointer sits in decides which of the four sides the new window takes. Overrides the choice above.")
                }
            }

            HyprSwitch {
                optionKey: "dwindle:use_active_for_splits"
                defaultValue: true
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Split the focused window, not the one under the pointer")
            }

            HyprSwitch {
                optionKey: "dwindle:smart_resizing"
                defaultValue: true
                buttonIcon: "open_with"
                text: Translation.tr("Resize towards the edge the pointer is nearest")
            }

            HyprSwitch {
                optionKey: "dwindle:permanent_direction_override"
                buttonIcon: "push_pin"
                text: Translation.tr("A preselected direction stays selected")

                StyledToolTip {
                    text: Translation.tr("Normally a layoutmsg preselect applies to the next window only. This makes it hold until it is changed.")
                }
            }

            HyprSwitch {
                optionKey: "dwindle:precise_mouse_move"
                buttonIcon: "drag_pan"
                text: Translation.tr("Drop a dragged window exactly where the pointer is")
            }

            HyprSlider {
                optionKey: "dwindle:special_scale_factor"
                defaultValue: 1
                buttonIcon: "photo_size_select_small"
                text: Translation.tr("Size of scratchpad windows")
                tooltipContent: `${Math.round(value * 100)}%`
                from: 0.3
                to: 1
                stepSize: 0.01
            }

            HyprOptionNote {
                keys: ["dwindle:force_split", "dwindle:default_split_ratio", "dwindle:split_bias",
                    "dwindle:split_width_multiplier", "dwindle:preserve_split", "dwindle:smart_split",
                    "dwindle:use_active_for_splits", "dwindle:smart_resizing",
                    "dwindle:permanent_direction_override", "dwindle:precise_mouse_move",
                    "dwindle:special_scale_factor"]
            }
        }
    }

    Loader {
        active: tab.engine === "master"
        visible: active
        Layout.fillWidth: true

        sourceComponent: ContentSection {
            title: Translation.tr("Master")
            icon: "view_sidebar"

            HyprSlider {
                optionKey: "master:mfact"
                defaultValue: 0.55
                buttonIcon: "width_normal"
                text: Translation.tr("Size of the master area")
                tooltipContent: `${Math.round(value * 100)}%`
                from: 0.1
                to: 0.9
                stepSize: 0.01
            }

            HyprSelect {
                optionKey: "master:orientation"
                defaultValue: "left"
                title: Translation.tr("Where the master area sits")
                icon: "align_horizontal_left"
                options: [
                    { "displayName": Translation.tr("Left"), "value": "left" },
                    { "displayName": Translation.tr("Right"), "value": "right" },
                    { "displayName": Translation.tr("Top"), "value": "top" },
                    { "displayName": Translation.tr("Bottom"), "value": "bottom" },
                    { "displayName": Translation.tr("Centre"), "value": "center" }
                ]
            }

            HyprSelect {
                optionKey: "master:new_status"
                defaultValue: "slave"
                title: Translation.tr("A new window becomes")
                icon: "add_box"
                options: [
                    { "displayName": Translation.tr("The master"), "value": "master" },
                    { "displayName": Translation.tr("Part of the stack"), "value": "slave" },
                    { "displayName": Translation.tr("Whatever the focused one is"), "value": "inherit" }
                ]
            }

            HyprSwitch {
                optionKey: "master:new_on_top"
                buttonIcon: "vertical_align_top"
                text: Translation.tr("New windows join the top of the stack")
            }

            HyprSelect {
                optionKey: "master:new_on_active"
                defaultValue: "none"
                title: Translation.tr("Place new windows relative to the focused one")
                icon: "swap_vert"
                options: [
                    { "displayName": Translation.tr("Before it"), "value": "before" },
                    { "displayName": Translation.tr("After it"), "value": "after" },
                    { "displayName": Translation.tr("Not at all"), "value": "none" }
                ]
            }

            HyprSpinBox {
                optionKey: "master:slave_count_for_center_master"
                defaultValue: 2
                icon: "filter_2"
                text: Translation.tr("Windows in the stack before the master centres")
                from: 0
                to: 10
                stepSize: 1
            }

            HyprSelect {
                optionKey: "master:center_master_fallback"
                defaultValue: "left"
                title: Translation.tr("Until then, a centred master sits")
                icon: "west"
                options: [
                    { "displayName": Translation.tr("Left"), "value": "left" },
                    { "displayName": Translation.tr("Right"), "value": "right" },
                    { "displayName": Translation.tr("Top"), "value": "top" },
                    { "displayName": Translation.tr("Bottom"), "value": "bottom" }
                ]
            }

            HyprSwitch {
                optionKey: "master:center_ignores_reserved"
                buttonIcon: "crop_free"
                text: Translation.tr("A centred master ignores the bar and centres on the screen")
            }

            HyprSwitch {
                optionKey: "master:allow_small_split"
                buttonIcon: "splitscreen_vertical_add"
                text: Translation.tr("Allow more than one master window")
            }

            HyprSwitch {
                optionKey: "master:always_keep_position"
                buttonIcon: "push_pin"
                text: Translation.tr("Keep the master in place when it is the only window")
            }

            HyprSwitch {
                optionKey: "master:focus_master_on_close"
                defaultValue: false
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Closing a window focuses the master")
            }

            HyprSwitch {
                optionKey: "master:smart_resizing"
                defaultValue: true
                buttonIcon: "open_with"
                text: Translation.tr("Resize towards the edge the pointer is nearest")
            }

            HyprSwitch {
                optionKey: "master:drop_at_cursor"
                defaultValue: true
                buttonIcon: "drag_pan"
                text: Translation.tr("Drop a dragged window where the pointer is")
            }

            HyprSlider {
                optionKey: "master:special_scale_factor"
                defaultValue: 1
                buttonIcon: "photo_size_select_small"
                text: Translation.tr("Size of scratchpad windows")
                tooltipContent: `${Math.round(value * 100)}%`
                from: 0.3
                to: 1
                stepSize: 0.01
            }

            HyprOptionNote {
                keys: ["master:mfact", "master:orientation", "master:new_status", "master:new_on_top",
                    "master:new_on_active", "master:slave_count_for_center_master",
                    "master:center_master_fallback", "master:center_ignores_reserved",
                    "master:allow_small_split", "master:always_keep_position",
                    "master:focus_master_on_close", "master:smart_resizing", "master:drop_at_cursor",
                    "master:special_scale_factor"]
            }
        }
    }

    Loader {
        active: tab.engine === "scrolling"
        visible: active
        Layout.fillWidth: true

        sourceComponent: ContentSection {
            title: Translation.tr("Scrolling")
            icon: "view_carousel"

            HyprSlider {
                optionKey: "scrolling:column_width"
                defaultValue: 0.5
                buttonIcon: "width_normal"
                text: Translation.tr("Width of a new column")
                tooltipContent: `${Math.round(value * 100)}%`
                from: 0.1
                to: 1
                stepSize: 0.01
            }

            HyprSelect {
                optionKey: "scrolling:direction"
                defaultValue: "right"
                title: Translation.tr("New columns appear on the")
                icon: "swap_horiz"
                options: [
                    { "displayName": Translation.tr("Right"), "value": "right" },
                    { "displayName": Translation.tr("Left"), "value": "left" }
                ]
            }

            HyprSwitch {
                optionKey: "scrolling:fullscreen_on_one_column"
                defaultValue: true
                buttonIcon: "fullscreen"
                text: Translation.tr("A single column fills the screen")
            }

            HyprSwitch {
                optionKey: "scrolling:follow_focus"
                defaultValue: true
                buttonIcon: "center_focus_weak"
                text: Translation.tr("Scroll to the focused window automatically")
            }

            HyprSlider {
                optionKey: "scrolling:follow_min_visible"
                defaultValue: 0.4
                buttonIcon: "visibility"
                text: Translation.tr("How much of a window must show before it counts as visible")
                tooltipContent: `${Math.round(value * 100)}%`
                from: 0
                to: 1
                stepSize: 0.05
            }

            HyprSelect {
                optionKey: "scrolling:focus_fit_method"
                defaultValue: 1
                title: Translation.tr("Bring a focused column into view by")
                icon: "fit_screen"
                options: [
                    { "displayName": Translation.tr("Centring it"), "value": 0 },
                    { "displayName": Translation.tr("Scrolling the least it can"), "value": 1 }
                ]
            }

            HyprSwitch {
                optionKey: "scrolling:wrap_focus"
                defaultValue: true
                buttonIcon: "loop"
                text: Translation.tr("Focus wraps around the ends of the row")
            }

            HyprSwitch {
                optionKey: "scrolling:wrap_swapcol"
                defaultValue: true
                buttonIcon: "swap_horizontal_circle"
                text: Translation.tr("Moving a column wraps around too")
            }

            HyprTextField {
                optionKey: "scrolling:explicit_column_widths"
                defaultValue: "0.333, 0.5, 0.667, 1.0"
                icon: "format_list_numbered"
                text: Translation.tr("Preset column widths")
                placeholderText: "0.333, 0.5, 0.667, 1.0"
                tooltip: Translation.tr("The widths the layoutmsg colresize +conf and -conf messages cycle through, as fractions of the screen.")
            }

            HyprOptionNote {
                keys: ["scrolling:column_width", "scrolling:direction",
                    "scrolling:fullscreen_on_one_column", "scrolling:follow_focus",
                    "scrolling:follow_min_visible", "scrolling:focus_fit_method",
                    "scrolling:wrap_focus", "scrolling:wrap_swapcol",
                    "scrolling:explicit_column_widths"]
            }
        }
    }

    ContentSection {
        title: Translation.tr("Focus")
        icon: "center_focus_strong"

        HyprSelect {
            optionKey: "binds:focus_preferred_method"
            defaultValue: 0
            title: Translation.tr("Moving focus in a direction picks")
            icon: "open_in_full"
            options: [
                { "displayName": Translation.tr("The nearest window"), "value": 0 },
                { "displayName": Translation.tr("The one sharing the longest edge"), "value": 1 }
            ]
        }

        HyprSwitch {
            optionKey: "binds:window_direction_monitor_fallback"
            defaultValue: true
            buttonIcon: "monitor"
            text: Translation.tr("Moving past the edge of a screen crosses to the next")
        }

        HyprSwitch {
            optionKey: "binds:movefocus_cycles_fullscreen"
            buttonIcon: "fullscreen"
            text: Translation.tr("Move focus while fullscreen instead of leaving it")
        }

        HyprSwitch {
            optionKey: "binds:movefocus_cycles_groupfirst"
            buttonIcon: "tab_group"
            text: Translation.tr("Move through a group before leaving it")
        }

        HyprSwitch {
            optionKey: "binds:ignore_group_lock"
            buttonIcon: "lock_open"
            text: Translation.tr("Group shortcuts ignore a locked group")
        }

        HyprSwitch {
            optionKey: "misc:focus_on_activate"
            buttonIcon: "notifications_active"
            text: Translation.tr("An app asking for attention gets focus")

            StyledToolTip {
                text: Translation.tr("Off, a window that asks to be raised only gets marked urgent. On, it takes focus from whatever you were doing.")
            }
        }

        HyprOptionNote {
            keys: ["binds:focus_preferred_method", "binds:window_direction_monitor_fallback",
                "binds:movefocus_cycles_fullscreen", "binds:movefocus_cycles_groupfirst",
                "binds:ignore_group_lock", "misc:focus_on_activate"]
        }
    }

    ContentSection {
        title: Translation.tr("Workspaces")
        icon: "dashboard"

        HyprSwitch {
            optionKey: "binds:workspace_back_and_forth"
            buttonIcon: "swap_horiz"
            text: Translation.tr("Switching to the current workspace goes back to the previous one")
        }

        HyprSwitch {
            optionKey: "binds:allow_workspace_cycles"
            buttonIcon: "history"
            text: Translation.tr("Workspaces remember where you came from")
        }

        HyprSelect {
            optionKey: "binds:workspace_center_on"
            defaultValue: 1
            title: Translation.tr("After switching, the pointer goes to")
            icon: "my_location"
            options: [
                { "displayName": Translation.tr("The middle of the screen"), "value": 0 },
                { "displayName": Translation.tr("The last window used there"), "value": 1 }
            ]
        }

        HyprSwitch {
            optionKey: "binds:hide_special_on_workspace_change"
            buttonIcon: "visibility_off"
            text: Translation.tr("Leaving a workspace hides the scratchpad")
        }

        HyprSwitch {
            optionKey: "binds:allow_pin_fullscreen"
            buttonIcon: "push_pin"
            text: Translation.tr("A pinned window can go fullscreen and stay pinned")
        }

        HyprSlider {
            optionKey: "binds:scroll_event_delay"
            defaultValue: 300
            integer: true
            buttonIcon: "mouse"
            text: Translation.tr("Wait between scroll shortcuts")
            tooltipContent: `${Math.round(value)} ms`
            from: 0
            to: 800
            stepSize: 10

            StyledToolTip {
                text: Translation.tr("How long a scroll-wheel shortcut ignores further scrolling. Lower it for a faster wheel, raise it if one flick skips several workspaces.")
            }
        }

        HyprSlider {
            optionKey: "binds:drag_threshold"
            defaultValue: 0
            integer: true
            buttonIcon: "drag_indicator"
            text: Translation.tr("Movement before a click becomes a drag")
            tooltipContent: value < 1 ? Translation.tr("Off") : `${Math.round(value)} px`
            from: 0
            to: 64
            stepSize: 1
        }

        HyprOptionNote {
            keys: ["binds:workspace_back_and_forth", "binds:allow_workspace_cycles",
                "binds:workspace_center_on", "binds:hide_special_on_workspace_change",
                "binds:allow_pin_fullscreen", "binds:scroll_event_delay", "binds:drag_threshold"]
        }
    }

    ContentSection {
        title: Translation.tr("Workspace swipe")
        icon: "swipe"

        HyprSlider {
            optionKey: "gestures:workspace_swipe_distance"
            defaultValue: 300
            integer: true
            buttonIcon: "straighten"
            text: Translation.tr("Finger travel for a full workspace")
            tooltipContent: `${Math.round(value)} px`
            from: 50
            to: 2000
            stepSize: 10
        }

        HyprSlider {
            optionKey: "gestures:workspace_swipe_cancel_ratio"
            defaultValue: 0.5
            buttonIcon: "undo"
            text: Translation.tr("How far to swipe before it commits")
            tooltipContent: `${Math.round(value * 100)}%`
            from: 0
            to: 1
            stepSize: 0.05
        }

        HyprSlider {
            optionKey: "gestures:workspace_swipe_min_speed_to_force"
            defaultValue: 30
            integer: true
            buttonIcon: "bolt"
            text: Translation.tr("Speed that commits a swipe regardless")
            tooltipContent: value < 1 ? Translation.tr("Off") : `${Math.round(value)} px`
            from: 0
            to: 200
            stepSize: 1
        }

        HyprSwitch {
            optionKey: "gestures:workspace_swipe_invert"
            defaultValue: true
            buttonIcon: "swap_horiz"
            text: Translation.tr("Invert the touchpad direction")
        }

        HyprSwitch {
            optionKey: "gestures:workspace_swipe_create_new"
            defaultValue: true
            buttonIcon: "add"
            text: Translation.tr("Swiping past the last workspace makes a new one")
        }

        HyprSwitch {
            optionKey: "gestures:workspace_swipe_forever"
            buttonIcon: "all_inclusive"
            text: Translation.tr("Keep going past the next workspace in one swipe")
        }

        HyprSwitch {
            optionKey: "gestures:workspace_swipe_use_r"
            buttonIcon: "tag"
            text: Translation.tr("Swipe within the monitor's own workspaces")

            StyledToolTip {
                text: Translation.tr("Uses the r workspace prefix instead of m, so a swipe stays inside the workspaces that belong to this monitor.")
            }
        }

        ContentSubsection {
            title: Translation.tr("Direction lock")
            icon: "lock"
            Layout.fillWidth: true

            HyprSwitch {
                optionKey: "gestures:workspace_swipe_direction_lock"
                defaultValue: true
                buttonIcon: "swipe_right"
                text: Translation.tr("Lock to the direction the swipe started in")
            }

            HyprSlider {
                optionKey: "gestures:workspace_swipe_direction_lock_threshold"
                defaultValue: 10
                integer: true
                buttonIcon: "straighten"
                text: Translation.tr("Travel before the lock takes hold")
                tooltipContent: `${Math.round(value)} px`
                from: 0
                to: 200
                stepSize: 1
            }
        }

        ContentSubsection {
            title: Translation.tr("Touchscreen")
            icon: "touch_app"
            Layout.fillWidth: true

            HyprSwitch {
                optionKey: "gestures:workspace_swipe_touch"
                buttonIcon: "swipe"
                text: Translation.tr("Swipe workspaces from the edge of a touchscreen")
            }

            HyprSwitch {
                optionKey: "gestures:workspace_swipe_touch_invert"
                buttonIcon: "swap_horiz"
                text: Translation.tr("Invert the touchscreen direction")
            }
        }

        HyprOptionNote {
            keys: ["gestures:workspace_swipe_distance", "gestures:workspace_swipe_cancel_ratio",
                "gestures:workspace_swipe_min_speed_to_force", "gestures:workspace_swipe_invert",
                "gestures:workspace_swipe_create_new", "gestures:workspace_swipe_forever",
                "gestures:workspace_swipe_use_r", "gestures:workspace_swipe_direction_lock",
                "gestures:workspace_swipe_direction_lock_threshold",
                "gestures:workspace_swipe_touch", "gestures:workspace_swipe_touch_invert"]
            notes: [{
                "icon": "info",
                "text": Translation.tr("Turning the swipe on and choosing how many fingers it takes is no longer a setting: since Hyprland 0.55 that is a gesture line, and the ones this config ships live in hyprland/general.lua. Everything here tunes a swipe that is already set up.")
            }]
        }
    }

    ContentSection {
        title: Translation.tr("Related settings")

        Flow {
            Layout.fillWidth: true
            spacing: 8

            RelatedChip {
                pageId: "windows"
                label: Translation.tr("Windows")
            }

            RelatedChip {
                pageId: "tiling"
                label: Translation.tr("Window tiling")
            }

            RelatedChip {
                pageId: "workspaces"
                label: Translation.tr("Workspaces")
            }

            RelatedChip {
                pageId: "touchGestures"
                label: Translation.tr("Touch & gestures")
            }
        }
    }
}
