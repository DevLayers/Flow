pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: -1

    readonly property string normalizedQuery: root.searchQuery.trim().toLocaleLowerCase()
    readonly property var bindings: root.collectBindings()
    readonly property var filteredBindings: root.bindings.filter(binding => {
        const terms = root.normalizedQuery.split(/\s+/).filter(term => term.length > 0);
        const haystack = [binding.section, binding.name, binding.keys.join(" "), binding.dispatcher, binding.params]
            .join(" ").toLocaleLowerCase();
        return terms.length === 0 || terms.every(term => haystack.includes(term));
    })
    readonly property var rows: root.sectionRows(root.filteredBindings)
    readonly property string statusText: Translation.tr("%1 shortcuts").arg(String(root.filteredBindings.length))

    implicitWidth: 720
    implicitHeight: scaffold.implicitHeight

    function collectBindings() {
        const output = [];

        function walk(nodes, source, parentSection) {
            for (const node of Array.from(nodes ?? [])) {
                const section = String(node?.name ?? parentSection ?? "").trim() || Translation.tr("Keybinds");
                for (const binding of Array.from(node?.keybinds ?? [])) {
                    const keys = Array.from(binding?.mods ?? []).map(part => String(part))
                        .concat([String(binding?.key ?? "")]).filter(part => part.length > 0);
                    const name = String(binding?.comment ?? "").trim()
                        || `${String(binding?.dispatcher ?? "").trim()} ${String(binding?.params ?? "").trim()}`.trim();
                    if (keys.length === 0 || name.length === 0)
                        continue;
                    output.push({
                        section,
                        source,
                        keys,
                        name,
                        dispatcher: String(binding?.dispatcher ?? "").trim(),
                        params: String(binding?.params ?? "").trim()
                    });
                }
                walk(node?.children, source, section);
            }
        }

        if (Config.options.search.modules.keybinds.includeDefaultBinds)
            walk(HyprlandKeybinds.defaultKeybinds?.children, "default", "");
        if (Config.options.search.modules.keybinds.includeUserBinds)
            walk(HyprlandKeybinds.userKeybinds?.children, "user", "");
        return output;
    }

    function sectionRows(bindings) {
        const output = [];
        let previousSection = "";
        for (const binding of bindings) {
            if (binding.section !== previousSection) {
                output.push({ kind: "section", name: binding.section });
                previousSection = binding.section;
            }
            output.push({ kind: "binding", binding });
        }
        return output;
    }

    function isBindingIndex(index) {
        return index >= 0 && index < root.rows.length && root.rows[index].kind === "binding";
    }

    function clampSelection() {
        if (root.filteredBindings.length === 0) {
            root.selectedIndex = -1;
            return;
        }
        if (!root.isBindingIndex(root.selectedIndex))
            root.selectedIndex = root.rows.findIndex(row => row.kind === "binding");
    }

    function moveSelection(direction) {
        if (root.filteredBindings.length === 0)
            return false;
        let index = root.selectedIndex;
        do {
            index += direction;
        } while (index >= 0 && index < root.rows.length && !root.isBindingIndex(index));
        if (!root.isBindingIndex(index))
            return false;
        root.selectedIndex = index;
        keybindList.positionViewAtIndex(index, ListView.Contain);
        return true;
    }

    function selectedBinding() {
        return root.isBindingIndex(root.selectedIndex) ? root.rows[root.selectedIndex].binding : null;
    }

    function focusInput(): bool {
        return false;
    }

    function navigateUp(): bool {
        return root.moveSelection(-1);
    }

    function navigateDown(): bool {
        return root.moveSelection(1);
    }

    function activateSelected(): bool {
        const binding = root.selectedBinding();
        return binding ? HyprlandKeybinds.dispatchBinding(binding) : false;
    }

    function copySelected(): bool {
        const binding = root.selectedBinding();
        if (!binding)
            return false;
        Quickshell.clipboardText = binding.keys.join("+");
        return true;
    }

    function openSelectedInCheatsheet(): bool {
        if (!root.selectedBinding())
            return false;
        GlobalStates.openCheatsheet("keybinds");
        return true;
    }

    onRowsChanged: root.clampSelection()
    Component.onCompleted: root.clampSelection()

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Keybinds")
        icon: "keyboard"
        accent: true
        statusText: root.statusText
        showStatus: true
        primaryHint: ({ label: Translation.tr("Run"), actionId: "activate", keys: ["↵"] })
        hints: [
            { label: Translation.tr("Copy"), actionId: "copy", keys: ["Ctrl", "C"] },
            { label: Translation.tr("Cheat sheet"), actionId: "secondary", keys: ["Ctrl", "↵"] }
        ]

        ColumnLayout {
            width: parent.width
            height: parent.height
            spacing: Appearance.sizes.elevationMargin

            ListView {
                id: keybindList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: emptyState.implicitHeight
                clip: true
                spacing: Appearance.sizes.elevationMargin / 2
                model: root.rows
                visible: root.rows.length > 0

                delegate: Loader {
                    id: rowLoader
                    required property int index
                    required property var modelData
                    width: keybindList.width
                    sourceComponent: rowLoader.modelData.kind === "section" ? sectionRow : bindingRow

                    Component {
                        id: sectionRow

                        StyledText {
                            width: rowLoader.width
                            text: rowLoader.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colSubtext
                            topPadding: Appearance.sizes.elevationMargin / 2
                        }
                    }

                    Component {
                        id: bindingRow

                        RippleButton {
                            readonly property var binding: rowLoader.modelData.binding
                            implicitWidth: rowLoader.width
                            implicitHeight: bindingContent.implicitHeight + Appearance.sizes.elevationMargin * 2
                            buttonRadius: Appearance.rounding.normal
                            colBackground: root.selectedIndex === rowLoader.index
                                ? Appearance.colors.colPrimaryContainer
                                : Appearance.colors.colSurfaceContainerHigh
                            colBackgroundHover: root.selectedIndex === rowLoader.index
                                ? Appearance.colors.colPrimaryContainerHover
                                : Appearance.colors.colSurfaceContainerHighestHover
                            colRipple: root.selectedIndex === rowLoader.index
                                ? Appearance.colors.colPrimaryContainerActive
                                : Appearance.colors.colSurfaceContainerHighestActive
                            onClicked: {
                                root.selectedIndex = rowLoader.index;
                                activate();
                            }

                            function activate(): bool {
                                return root.activateSelected();
                            }

                            RowLayout {
                                id: bindingContent
                                anchors.fill: parent
                                anchors.margins: Appearance.sizes.elevationMargin
                                spacing: Appearance.sizes.elevationMargin

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: binding.name
                                        elide: Text.ElideRight
                                        color: root.selectedIndex === rowLoader.index
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colOnSurface
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: binding.source === "user" ? Translation.tr("Custom") : binding.section
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: root.selectedIndex === rowLoader.index
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colSubtext
                                    }
                                }

                                KeyHint {
                                    keys: binding.keys
                                    surface: root.selectedIndex === rowLoader.index
                                        ? Appearance.colors.colPrimaryContainer
                                        : Appearance.colors.colSurfaceContainerHigh
                                    onSurface: root.selectedIndex === rowLoader.index
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : Appearance.colors.colOnSurface
                                }

                                ConfiguredKeyHint {
                                    visible: root.selectedIndex === rowLoader.index && Config.options.search.appearance.showKeyHints
                                    actionId: "activate"
                                    fallbackKeys: ["↵"]
                                    surface: Appearance.colors.colPrimaryContainer
                                    onSurface: Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                id: emptyState
                Layout.fillWidth: true
                visible: root.rows.length === 0
                text: Translation.tr("No shortcuts match \"%1\"").arg(root.normalizedQuery)
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
