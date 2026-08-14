pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common

Singleton {
    id: root

    readonly property var actions: [
        {
            id: "none",
            name: "None",
            icon: "block"
        },
        {
            id: "overview",
            name: "Overview",
            icon: "grid_view"
        },
        {
            id: "sidebarLeft",
            name: "Left Sidebar",
            icon: "left_panel_open"
        },
        {
            id: "sidebarRight",
            name: "Right Sidebar",
            icon: "right_panel_open"
        },
        {
            id: "cheatsheet",
            name: "Cheat Sheet",
            icon: "keyboard"
        },
        {
            id: "osk",
            name: "On-screen Keyboard",
            icon: "keyboard_alt"
        },
        {
            id: "settings",
            name: "Settings",
            icon: "settings"
        }
    ]

    function actionById(actionId) {
        return actions.find(action => action.id === actionId)
            ?? actions[0];
    }

    // Repeating a gesture on a target that is already open closes it again. Targets
    // that live on one monitor at a time are moved to the swiped screen instead of
    // closing when they are open somewhere else, so the gesture is never a no-op on
    // the screen it was made on.
    function shouldCloseOnScreen(isOpen, activeMonitor, screenName) {
        if (!isOpen)
            return false;
        if (!screenName || !activeMonitor)
            return true;
        return activeMonitor === screenName;
    }

    function trigger(actionId, screenName) {
        switch (actionId) {
        case "overview":
            if (shouldCloseOnScreen(GlobalStates.overviewOpen, GlobalStates.activeSearchMonitor, screenName))
                GlobalStates.overviewOpen = false;
            else
                GlobalStates.openSearch(screenName);
            break;

        case "sidebarLeft":
            if (shouldCloseOnScreen(GlobalStates.sidebarLeftOpen, GlobalStates.activeLeftSidebarMonitor, screenName))
                GlobalStates.sidebarLeftOpen = false;
            else
                GlobalStates.openLeftSidebar(screenName);
            break;

        case "sidebarRight":
            if (shouldCloseOnScreen(GlobalStates.sidebarRightOpen, GlobalStates.activeRightSidebarMonitor, screenName))
                GlobalStates.sidebarRightOpen = false;
            else
                GlobalStates.openRightSidebar(screenName);
            break;

        case "cheatsheet":
            GlobalStates.toggleCheatsheet();
            break;

        case "osk":
            GlobalStates.oskOpen = !GlobalStates.oskOpen;
            break;

        case "settings":
            GlobalStates.toggleSettings();
            break;

        case "none":
        default:
            break;
        }
    }
}
