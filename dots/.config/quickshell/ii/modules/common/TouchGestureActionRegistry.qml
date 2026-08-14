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

    function trigger(actionId, screenName) {
        switch (actionId) {
        case "overview":
            if (!GlobalStates.overviewOpen)
                GlobalStates.openSearch(screenName);
            break;

        case "sidebarLeft":
            if (!GlobalStates.sidebarLeftOpen)
                GlobalStates.openLeftSidebar(screenName);
            break;

        case "sidebarRight":
            if (!GlobalStates.sidebarRightOpen)
                GlobalStates.openRightSidebar(screenName);
            break;

        case "cheatsheet":
            if (!GlobalStates.cheatsheetOpen)
                GlobalStates.openCheatsheet();
            break;

        case "osk":
            GlobalStates.oskOpen = true;
            break;

        case "settings":
            if (!GlobalStates.settingsOpen)
                GlobalStates.openSettings();
            break;

        case "none":
        default:
            break;
        }
    }
}
