pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings -> Hyprland -> Shortcuts.
 *
 * Every keyboard shortcut, grouped the way the cheatsheet groups them, each showing which file
 * it came from. A shortcut can be changed wherever it was written: the compositor's own files
 * are never edited, so replacing a stock shortcut writes a release of that key followed by a new
 * bind into the block at the end of custom/keybinds.lua, which loads afterwards.
 *
 * Underneath is the other half of a shortcut: the app it opens. Those are a list of candidates
 * tried in order rather than a single command, so they get their own editor.
 */
ContentPage {
    id: tab

    forceWidth: false

    property string rawQuery: ""
    property bool showEverything: false

    readonly property string query: tab.rawQuery.trim().toLowerCase()

    /// Whether one row is on screen right now. The list itself is grouped once from every row
    /// and rows hide instead of being torn down: rebuilding a hundred delegates per keystroke
    /// was most of what typing in the search box used to cost.
    function shows(row: var): bool {
        if (!tab.showEverything && !HyprlandBinds.isListed(row)) return false;
        return HyprlandBinds.matches(row, tab.query);
    }

    readonly property var allRows: HyprlandBinds.listed.concat(HyprlandBinds.unnamed)
    readonly property int shownCount: tab.allRows.filter(row => tab.shows(row)).length

    readonly property var groups: HyprlandBinds.grouped(tab.allRows)

    /// The shell's own launch commands. Not keybinds, but the same question - which program
    /// opens - so they belong on the same page rather than in a corner of their own.
    readonly property var shellApps: [
        { "key": "terminal", "icon": "terminal", "label": Translation.tr("Terminal for shell actions") },
        { "key": "network", "icon": "wifi", "label": Translation.tr("Network settings") },
        { "key": "networkEthernet", "icon": "settings_ethernet", "label": Translation.tr("Wired network settings") },
        { "key": "bluetooth", "icon": "bluetooth", "label": Translation.tr("Bluetooth settings") },
        { "key": "volumeMixer", "icon": "volume_up", "label": Translation.tr("Volume mixer") },
        { "key": "taskManager", "icon": "monitoring", "label": Translation.tr("Task manager") },
        { "key": "manageUser", "icon": "person", "label": Translation.tr("User accounts") },
        { "key": "changePassword", "icon": "password", "label": Translation.tr("Change password") },
        { "key": "update", "icon": "system_update", "label": Translation.tr("System update") }
    ]

    function openSubPage(page: url) {
        let node = tab.parent;
        while (node) {
            if (typeof node.activeSubPage !== "undefined") {
                node.activeSubPage = page;
                return;
            }
            node = node.parent;
        }
    }

    function edit(row: var) {
        HyprlandBinds.beginEdit(row);
        tab.openSubPage(Qt.resolvedUrl("HyprBindEditorPage.qml"));
    }

    function addShortcut() {
        HyprlandBinds.beginNew();
        tab.openSubPage(Qt.resolvedUrl("HyprBindEditorPage.qml"));
    }

    /// Something elsewhere in the shell asked for a shortcut - a routine's trigger, so far. The
    /// draft is already filled in; all this has to do is show it.
    function takePendingEditor() {
        if (!HyprlandBinds.takePendingEditor())
            return;
        tab.openSubPage(Qt.resolvedUrl("HyprBindEditorPage.qml"));
    }

    // Deferred: openSubPage walks up the parent chain, and on the first frame of a tab that has
    // only just been loaded there is not yet a chain to walk.
    Component.onCompleted: Qt.callLater(tab.takePendingEditor)

    // A second request arrives while this tab is already built, so it never reaches the line above.
    Connections {
        target: HyprlandBinds
        function onPendingEditorChanged() {
            tab.takePendingEditor();
        }
    }

    function editApp(name: string) {
        HyprlandBinds.beginEditApp(name);
        tab.openSubPage(Qt.resolvedUrl("HyprAppChainPage.qml"));
    }

    // ── Finding one ───────────────────────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Shortcuts")
        icon: "keyboard_command_key"

        StyledText {
            Layout.fillWidth: true
            text: HyprlandBinds.ready
                ? Translation.tr("%1 shortcuts have a name, out of %2 keys bound in total.")
                    .arg(HyprlandBinds.listed.length).arg(HyprlandBinds.effective.length)
                : Translation.tr("Reading the config files…")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        MaterialTextField {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Search by name, key or command")
            onTextChanged: tab.rawQuery = text
        }

        HyprToggle {
            buttonIcon: "visibility"
            text: Translation.tr("Show the ones with no name")
            switchOn: tab.showEverything
            onRequested: wanted => tab.showEverything = wanted
        }

        HyprOptionNote {
            notes: {
                const out = [];
                for (const missing of HyprlandBinds.missingEssentials)
                    out.push({
                        "icon": "warning",
                        "text": Translation.tr("Nothing on this keyboard can %1. Add a shortcut for it before you need one.")
                            .arg(String(missing.label).toLowerCase())
                    });
                if (HyprlandBinds.unnamed.length > 0 && !tab.showEverything)
                    out.push({ "icon": "visibility_off", "text": Translation.tr("%1 more keys are bound without a name. They are the duplicates and fallbacks the config uses, and they still work.")
                        .arg(HyprlandBinds.unnamed.length) });
                if (HyprlandBinds.unreadable.length > 0)
                    out.push({ "icon": "code", "text": Translation.tr("%1 lines build their key in a loop, so this page cannot tell which keys they are. They are left alone.")
                        .arg(HyprlandBinds.unreadable.length) });
                if (HyprlandBinds.unexplainedLive > 0)
                    out.push({ "icon": "help", "text": Translation.tr("Hyprland reports %1 more keys bound than the files here account for — those are the ones from the loops above, and anything a plugin added.")
                        .arg(HyprlandBinds.unexplainedLive) });
                return out;
            }
        }
    }

    // ── The list ──────────────────────────────────────────────────────────────
    Repeater {
        model: tab.groups

        delegate: ContentSection {
            id: group

            required property var modelData

            visible: group.modelData.rows.some(row => tab.shows(row))
            title: group.modelData.name
            icon: {
                const known = { "Shell": "widgets", "Window": "web_asset", "Workspace": "space_dashboard",
                    "Workspaces": "space_dashboard", "Utilities": "build", "Apps": "apps",
                    "App": "apps", "Media": "music_note", "Session": "power_settings_new",
                    "Screen": "monitor", "Misc": "more_horiz", "User": "person" };
                return known[group.modelData.name] ?? "keyboard";
            }

            Repeater {
                model: group.modelData.rows

                delegate: HyprShortcutRow {
                    required property var modelData

                    visible: tab.shows(modelData)
                    row: modelData
                    onOpenSubPage: tab.edit(modelData)
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Add")
        icon: "add"

        HyprNavRow {
            buttonIcon: "add"
            text: Translation.tr("Make a shortcut")
            value: Translation.tr("Goes in custom/keybinds.lua")
            onOpenSubPage: tab.addShortcut()
        }

        StyledText {
            Layout.fillWidth: true
            visible: tab.query !== "" && tab.shownCount === 0
            text: Translation.tr("Nothing matches \"%1\".").arg(tab.rawQuery.trim())
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }
    }

    // ── Default apps ──────────────────────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Apps these shortcuts open")
        icon: "apps"

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Each of these is a list of programs tried in order, so the config works on a machine that has none of your usual ones. The first one installed is the one that opens.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: HyprlandBinds.appVariables

            delegate: HyprNavRow {
                required property var modelData

                readonly property var chain: HyprlandBinds.readChain(HyprlandBinds.appValue(modelData.name))
                readonly property string winner: HyprlandBinds.winningCandidate(chain.candidates)

                buttonIcon: modelData.icon
                text: modelData.label
                value: {
                    if (!chain.chain) return chain.plain;
                    if (winner !== "") return winner;
                    return chain.candidates.length === 0 ? Translation.tr("Empty")
                        : Translation.tr("None installed");
                }
                onOpenSubPage: tab.editApp(modelData.name)
            }
        }

        HyprOptionNote {
            notes: {
                const out = [];
                const changed = HyprlandBinds.appVariables
                    .filter(variable => HyprlandBinds.appSource(variable.name) === "managed");
                if (changed.length > 0)
                    out.push({ "icon": "edit", "text": Translation.tr("%1 of these are set by this page.").arg(changed.length) });
                const empty = HyprlandBinds.appVariables.filter(variable => {
                    const chain = HyprlandBinds.readChain(HyprlandBinds.appValue(variable.name));
                    return chain.chain && HyprlandBinds.winningCandidate(chain.candidates) === "";
                });
                if (empty.length > 0)
                    out.push({ "icon": "warning", "text": Translation.tr("%1 of them have nothing installed, so their shortcut does nothing when pressed.").arg(empty.length) });
                return out;
            }
        }
    }

    // ── What the shell itself opens ───────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Apps the shell opens")
        icon: "widgets"

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("These are not shortcuts. They are what opens when you press a button in the shell — the settings link on the Wi-Fi popup, the mixer on the volume slider — and they are kept here because it is the same question about the other half of the desktop.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: tab.shellApps

            delegate: ConfigTextField {
                id: shellAppField

                required property var modelData

                Layout.fillWidth: true
                // MaterialTextField wraps, so a value wider than the field makes its own implicit
                // width depend on its width and the layout never settles. Commands are long.
                textField.wrapMode: TextInput.NoWrap
                icon: modelData.icon
                text: modelData.label
                inputText: String(Config.options.apps[modelData.key] ?? "")
                textField.onEditingFinished: Config.options.apps[shellAppField.modelData.key] =
                    shellAppField.textField.text
            }
        }

        HyprOptionNote {
            notes: [{ "icon": "info", "text": Translation.tr("These live in the shell's own settings file, not in the Hyprland config, so they take effect at once and no reload happens.") }]
        }
    }

    // ── Where it all lives ────────────────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Where shortcuts live")
        icon: "folder"

        Repeater {
            model: HyprlandBinds.parsedFiles

            delegate: HyprNavRow {
                required property var modelData

                enabled: false
                buttonIcon: modelData.file.startsWith("custom/") ? "edit_note" : "inventory"
                text: modelData.file
                value: modelData.readable
                    ? Translation.tr("%1 lines").arg(modelData.binds.length)
                    : Translation.tr("Not readable")
            }
        }

        HyprOptionNote {
            notes: [
                { "icon": "lock", "text": Translation.tr("hyprland/keybinds.lua is replaced on every update, so it is never edited from here. Changes go into the block at the end of custom/keybinds.lua, which loads last and wins.") },
                { "icon": "swap_horiz", "text": Translation.tr("Binding a key that is already bound registers both, and both fire. Every shortcut written here therefore releases its key first.") }
            ]
        }
    }

    // ── Related ───────────────────────────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Related settings")
        icon: "link"

        Flow {
            Layout.fillWidth: true
            spacing: 6

            RelatedChip {
                pageId: "cheatSheet"
                label: Translation.tr("Cheatsheet")
            }

            RelatedChip {
                pageId: "modes"
                label: Translation.tr("Modes & Routines")
            }

            RelatedChip {
                pageId: "tiling"
                label: Translation.tr("Window tiling")
            }
        }
    }
}
