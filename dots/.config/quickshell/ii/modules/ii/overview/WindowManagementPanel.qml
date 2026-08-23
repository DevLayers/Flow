pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: 0
    property int categoryIndex: 0
    // GlobalStates captures this before the layer-shell receives focus.
    readonly property string targetAddress: GlobalStates.searchTargetWindowAddress
    readonly property var targetWindow: HyprlandData.windowByAddress[targetAddress] ?? null
    readonly property var categories: ["all", "tiling", "window", "workspace", "monitor"]
    readonly property string selectedCategory: root.categories[root.categoryIndex]
    readonly property var rows: root.filteredActions()
    readonly property var selectedAction: root.selectedIndex >= 0 && root.selectedIndex < root.rows.length
        ? root.rows[root.selectedIndex]
        : null
    readonly property string targetLabel: root.targetWindow
        ? String(root.targetWindow.title ?? root.targetWindow.class ?? root.targetAddress)
        : Translation.tr("No target window")
    readonly property string statusText: root.selectedAction
        ? `${root.targetLabel} · ${root.selectedAction.name}`
        : root.targetLabel

    implicitWidth: 720
    implicitHeight: scaffold.implicitHeight

    function visibleByConfig(action) {
        if (action.category === "tiling")
            return Config.options.search.modules.windowManagement.showTilingPresets;
        if (action.category === "workspace")
            return Config.options.search.modules.windowManagement.showWorkspaceMoves;
        if (action.category === "monitor")
            return Config.options.search.modules.windowManagement.showMonitorMoves;
        return true;
    }

    function filteredActions() {
        const terms = root.searchQuery.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
        return WindowActionRegistry.actions.filter(action => {
            if (!root.visibleByConfig(action))
                return false;
            if (root.selectedCategory !== "all" && action.category !== root.selectedCategory)
                return false;
            const text = [action.name, action.category, ...(action.keywords ?? [])].join(" ").toLocaleLowerCase();
            return terms.every(term => text.includes(term));
        });
    }

    function clampSelection() {
        if (root.rows.length === 0) {
            root.selectedIndex = -1;
            return;
        }
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.rows.length - 1));
    }

    function navigateUp(): bool {
        if (root.selectedIndex <= 0)
            return false;
        root.selectedIndex--;
        actionList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateDown(): bool {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.rows.length - 1)
            return false;
        root.selectedIndex++;
        actionList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateLeft(): bool {
        if (root.categoryIndex <= 0)
            return false;
        root.categoryIndex--;
        root.selectedIndex = 0;
        return true;
    }

    function navigateRight(): bool {
        if (root.categoryIndex >= root.categories.length - 1)
            return false;
        root.categoryIndex++;
        root.selectedIndex = 0;
        return true;
    }

    function runSelected(keepOpen) {
        if (!WindowActionRegistry.execute(root.selectedAction, root.targetAddress))
            return false;
        if (!keepOpen)
            GlobalStates.overviewOpen = false;
        return true;
    }

    function activateSelected(): bool {
        return root.runSelected(false);
    }

    function secondaryActivateSelected(): bool {
        return root.runSelected(true);
    }

    function copyDispatchSelected(): bool {
        if (!root.selectedAction || !WindowActionRegistry.validTarget(root.targetAddress))
            return false;
        Quickshell.clipboardText = root.selectedAction.expression(root.targetAddress);
        return true;
    }

    function focusInput(): bool {
        return false;
    }

    onRowsChanged: root.clampSelection()
    onCategoryIndexChanged: root.clampSelection()

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Window Management")
        icon: "splitscreen"
        accent: true
        statusText: root.statusText
        primaryHint: ({ label: Translation.tr("Run"), keys: ["↵"] })
        hints: [
            { label: Translation.tr("Keep open"), keys: ["Ctrl", "↵"] },
            { label: Translation.tr("Category"), keys: ["←", "→"] },
            { label: Translation.tr("Copy dispatch"), keys: ["Ctrl", "Shift", "K"] }
        ]

        ColumnLayout {
            width: parent.width
            spacing: Appearance.sizes.elevationMargin

            RowLayout {
                Layout.fillWidth: true

                MaterialSymbol {
                    text: "select_window"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.targetLabel
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.targetAddress.length > 0
                        ? Appearance.colors.colOnSurface
                        : Appearance.colors.colError
                }

                StyledText {
                    text: root.selectedCategory === "all"
                        ? Translation.tr("All actions")
                        : root.selectedCategory
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }

            ListView {
                id: actionList
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.sizes.elevationMargin * 34
                clip: true
                spacing: Appearance.sizes.elevationMargin / 2
                model: root.rows

                delegate: RippleButton {
                    required property int index
                    required property var modelData
                    width: actionList.width
                    implicitHeight: actionContent.implicitHeight + Appearance.sizes.elevationMargin * 2
                    buttonRadius: Appearance.rounding.normal
                    colBackground: root.selectedIndex === index
                        ? Appearance.colors.colPrimaryContainer
                        : Appearance.colors.colSurfaceContainerHigh
                    colBackgroundHover: root.selectedIndex === index
                        ? Appearance.colors.colPrimaryContainerHover
                        : Appearance.colors.colSurfaceContainerHighHover
                    colRipple: root.selectedIndex === index
                        ? Appearance.colors.colPrimaryContainerActive
                        : Appearance.colors.colSurfaceContainerHighActive
                    onClicked: {
                        root.selectedIndex = index;
                        root.activateSelected();
                    }

                    RowLayout {
                        id: actionContent
                        anchors.fill: parent
                        anchors.margins: Appearance.sizes.elevationMargin
                        spacing: Appearance.sizes.elevationMargin

                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                elide: Text.ElideRight
                                color: root.selectedIndex === index
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colOnSurface
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.category
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.selectedIndex === index
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colSubtext
                            }
                        }

                        KeyHint {
                            visible: modelData.keyHint.length > 0
                            keys: modelData.keyHint
                            surface: root.selectedIndex === index
                                ? Appearance.colors.colPrimaryContainer
                                : Appearance.colors.colSurfaceContainerHigh
                            onSurface: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.rows.length === 0
                    text: root.targetAddress.length === 0
                        ? Translation.tr("Open Search while a window is focused")
                        : Translation.tr("No window actions match")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
