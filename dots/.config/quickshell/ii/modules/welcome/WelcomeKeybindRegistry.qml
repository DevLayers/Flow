pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

/**
 * Welcome-facing keybind metadata. Descriptions come from the parsed Hyprland
 * keybind source; this registry never stores a guessed key combination.
 */
QtObject {
    id: root

    readonly property var everydayActions: [{
        "id": "launcher",
        "labelKey": "Search",
        "icon": "search",
        "matcher": "Shell: Open search only"
    }, {
        "id": "dashboard",
        "labelKey": "Control dashboard",
        "icon": "side_navigation",
        "matcher": "Shell: Toggle right sidebar"
    }, {
        "id": "settings",
        "labelKey": "Settings",
        "icon": "settings",
        "matcher": "App: Settings app"
    }, {
        "id": "cheatsheet",
        "labelKey": "Cheatsheet",
        "icon": "help",
        "matcher": "Shell: Toggle cheatsheet"
    }]

    readonly property var exploreActions: [{
        "id": "overview",
        "labelKey": "Overview",
        "icon": "grid_view",
        "matcher": "Shell: Toggle overview"
    }, {
        "id": "ai",
        "labelKey": "AI sidebar",
        "icon": "neurology",
        "matcher": "Shell: Toggle left sidebar"
    }, {
        "id": "wallpaper",
        "labelKey": "Wallpaper picker",
        "icon": "wallpaper",
        "matcher": "Shell: Toggle wallpaper selector"
    }, {
        "id": "keyboardLayout",
        "labelKey": "Switch keyboard layout",
        "icon": "keyboard",
        "matcher": "Switch keyboard layout"
    }]

    readonly property var actions: [...everydayActions, ...exploreActions]

    function flatten(nodes, output): void {
        for (const node of nodes ?? []) {
            output.push(...(node.keybinds ?? []));
            root.flatten(node.children, output);
        }
    }

    function parseUnbinds(nodes, output): void {
        for (const node of nodes ?? []) {
            output.push(...(node.unbinds ?? []));
            root.parseUnbinds(node.children, output);
        }
    }

    function sameBinding(a, b): bool {
        if (!a || !b || a.key !== b.key)
            return false;
        const aMods = a.mods ?? [];
        const bMods = b.mods ?? [];
        if (aMods.length !== bMods.length)
            return false;
        for (let i = 0; i < aMods.length; i++) {
            if (aMods[i] !== bMods[i])
                return false;
        }
        return true;
    }

    function rawKeybindFor(action): var {
        const bindings = [];
        root.flatten(HyprlandKeybinds.defaultKeybinds.children, bindings);
        root.flatten(HyprlandKeybinds.userKeybinds.children, bindings);

        const unbinds = [];
        if (Config.options.cheatsheet.filterUnbinds) {
            root.parseUnbinds(HyprlandKeybinds.userKeybinds.children, unbinds);
            unbinds.push(...(HyprlandKeybinds.userKeybinds.unbinds ?? []));
        }

        let result = null;
        for (const binding of bindings) {
            if (binding.comment !== action.matcher)
                continue;
            if (unbinds.some(unbind => root.sameBinding(unbind, binding)))
                continue;
            result = binding;
        }
        return result;
    }

    function displayKey(key: string): string {
        const map = {
            "SUPER": Config.options.cheatsheet.superKey || "Super",
            "Super": Config.options.cheatsheet.superKey || "Super",
            "CTRL": "Ctrl",
            "ALT": "Alt",
            "SHIFT": "Shift",
            "Slash": "/",
            "Hash": "#",
            "Return": "Enter",
            "Space": "Space",
            "Tab": "Tab",
            "Period": "."
        };
        return map[key] ?? key;
    }

    function keysFor(actionId: string): list<string> {
        const action = root.actions.find(item => item.id === actionId);
        const binding = action ? root.rawKeybindFor(action) : null;
        if (!binding)
            return [];
        const result = [];
        for (const modifier of binding.mods ?? [])
            result.push(root.displayKey(modifier));
        if (binding.key && binding.key !== "Super_L")
            result.push(root.displayKey(binding.key));
        return result;
    }
}
