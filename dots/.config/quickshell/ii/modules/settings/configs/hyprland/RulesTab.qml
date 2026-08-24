pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Settings -> Hyprland -> Rules.
 *
 * Four lists over one file. Apps come first because that is what a rule is nearly always for -
 * this window should float, that one should never be blurred - and the raw window, layer and
 * workspace lists underneath are the same machinery without the friendly names.
 *
 * Everything here is written into the block at the end of ~/.config/hypr/custom/rules.lua, which
 * loads after the shell's own rules and after anything hand-written above it, so a rule made here
 * wins. The two exceptions are stated where they apply: layer rules on quickshell's own surfaces,
 * which Appearance.qml re-pushes after every reload, and the screen assigned to workspaces 1 to
 * 100, which hyprland/lib/init.lua also writes.
 */
ContentPage {
    id: tab

    forceWidth: false

    readonly property url editorPage: Qt.resolvedUrl("HyprRuleEditorPage.qml")
    readonly property url pickerPage: Qt.resolvedUrl("HyprAppPickerPage.qml")

    /// The host that owns the slide-in overlay is the hub, several files up; this page cannot
    /// see it by name.
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

    function edit(kind: string, id: string) {
        HyprlandRules.beginEdit(kind, id);
        tab.openSubPage(tab.editorPage);
    }

    function addRule(kind: string, prefix: string, spec: var) {
        const id = HyprlandRules.freeId(kind, prefix);
        HyprlandRules.save(kind, id, spec);
        tab.edit(kind, id);
    }

    /// One row per rule: what it selects, what it does, and a way in.
    component RuleRow: HyprNavRow {
        required property string ruleKind
        required property var rule

        buttonIcon: ruleKind === "layerrule" ? "layers"
            : (ruleKind === "workspacerule" ? "space_dashboard" : "filter_alt")
        text: HyprlandRules.matchSummary(ruleKind, rule.spec)
        value: HyprlandRules.effectSummary(ruleKind, rule.spec)
        onOpenSubPage: tab.edit(ruleKind, rule.id)
    }

    // ── Apps ──────────────────────────────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Apps")
        icon: "apps"

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Rules for one application's windows. Each card is a single line in your config, and the list under it shows which of your open windows it currently catches.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: HyprlandRules.apps

            delegate: HyprAppRuleCard {
                required property var modelData

                rule: modelData
                onEditRequested: tab.edit("windowrule", modelData.id)
                onRemoveRequested: HyprlandRules.remove("windowrule", modelData.id)
            }
        }

        HyprNavRow {
            buttonIcon: "add"
            text: Translation.tr("Add an app")
            value: HyprlandRules.apps.length === 0 ? Translation.tr("None yet") : ""
            onOpenSubPage: tab.openSubPage(tab.pickerPage)
        }
    }

    // ── Raw window rules ──────────────────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Window rules")
        icon: "filter_alt"

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("For everything the app cards do not cover: matching on a title, a tag or a state instead of a class, and the settings that are too rare to put on a card.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: HyprlandRules.rawWindowRules

            delegate: RuleRow {
                required property var modelData

                ruleKind: "windowrule"
                rule: modelData
            }
        }

        HyprNavRow {
            buttonIcon: "add"
            text: Translation.tr("Add a window rule")
            value: HyprlandRules.rawWindowRules.length === 0 ? Translation.tr("None yet") : ""
            onOpenSubPage: tab.addRule("windowrule", "win:", { "match": {} })
        }

        HyprOptionNote {
            notes: {
                const hand = HyprlandRules.inheritedRules.filter(rule => rule.kind === "windowrule");
                if (hand.length === 0) return [];
                return [{ "icon": "edit_note", "text": Translation.tr("%1 window rules are written by hand higher up in custom/rules.lua. They are left exactly as they are; anything set here loads afterwards and wins.").arg(hand.length) }];
            }
        }
    }

    // ── Layer rules ───────────────────────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Layer rules")
        icon: "layers"

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Layers are the surfaces that are not windows: this shell's own panels, a launcher, a notification. A layer rule decides how one of them is blurred, ordered or animated.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: HyprlandRules.layerRules

            delegate: RuleRow {
                required property var modelData

                ruleKind: "layerrule"
                rule: modelData
            }
        }

        HyprNavRow {
            buttonIcon: "add"
            text: Translation.tr("Add a layer rule")
            value: HyprlandRules.layerRules.length === 0 ? Translation.tr("None yet") : ""
            onOpenSubPage: tab.addRule("layerrule", "layer:", { "match": {} })
        }

        HyprOptionNote {
            notes: {
                const out = [{ "icon": "lock", "text": Translation.tr("Namespaces starting with quickshell: belong to this shell. It re-applies its own blur, order and animation for them after every reload, so a rule written here for one of them is overwritten within the second.") }];
                const hand = HyprlandRules.inheritedRules.filter(rule => rule.kind === "layerrule");
                if (hand.length > 0)
                    out.push({ "icon": "edit_note", "text": Translation.tr("%1 layer rules are written by hand higher up in custom/rules.lua, and are left alone.").arg(hand.length) });
                if (HyprlandRules.liveNamespaces.length > 0)
                    out.push({ "icon": "search", "text": Translation.tr("On screen right now: %1")
                        .arg(HyprlandRules.liveNamespaces.join(", ")) });
                return out;
            }
        }
    }

    // ── Workspace rules ───────────────────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Workspace rules")
        icon: "space_dashboard"

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Settings that belong to one workspace rather than to one window: which screen it lives on, whether it stays when empty, its own gaps or its own tiling engine.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: HyprlandRules.workspaceRules

            delegate: RuleRow {
                required property var modelData

                ruleKind: "workspacerule"
                rule: modelData
            }
        }

        HyprNavRow {
            buttonIcon: "add"
            text: Translation.tr("Add a workspace rule")
            value: HyprlandRules.workspaceRules.length === 0 ? Translation.tr("None yet") : ""
            onOpenSubPage: tab.addRule("workspacerule", "ws:", {})
        }

        HyprOptionNote {
            notes: [{ "icon": "info", "text": Translation.tr("Workspaces 1 to 100 are already given a screen on every start by hyprland/lib/init.lua, from the workspace map. Rules written here load afterwards and win, but both are setting it.") }]
        }
    }

    // ── Related ───────────────────────────────────────────────────────────────
    ContentSection {
        title: Translation.tr("Related settings")
        icon: "link"

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Opacity, blur, gaps and borders for every window at once live on the shell's own pages, not here. This page is for the exceptions.")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

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
                pageId: "overlays"
                label: Translation.tr("Overlays")
            }
        }
    }
}
