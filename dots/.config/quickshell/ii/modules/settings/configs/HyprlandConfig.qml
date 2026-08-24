pragma ComponentBehavior: Bound

import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.configs.hyprland

/**
 * Settings -> Hyprland.
 *
 * One page over six tabs, because the compositor's settings do not split cleanly into six
 * sidebar entries and nothing else in Settings is this deep. The tabs are peers; anything
 * that needs a whole screen of its own - a rule editor, one keybind, the full option list -
 * opens as a sub-page instead, so drilling down stays a push and switching stays a tab.
 *
 * Everything written from here lands in a fenced block at the end of the matching file in
 * ~/.config/hypr/custom/. The strip at the top is the only place that says so, so it stays
 * visible on every tab.
 */
Item {
    id: hubRoot
    anchors.fill: parent

    property alias activeSubPage: subPageOverlay.activeSubPage
    /// The settings window pushes a restored scroll position onto whatever page it loaded.
    /// Hand it to the tab that is actually showing.
    property real contentY: 0
    onContentYChanged: {
        const page = swipeView.currentItem?.item ?? null;
        if (page && page.contentY !== undefined)
            page.contentY = hubRoot.contentY;
    }

    /// `name` is the untranslated key, translated in the tab delegate — the same split the page
    /// registry uses. Putting Translation.tr in here instead would rebuild the model on every
    /// language switch, and a rebuilt tab model drops SwipeView back to a different tab.
    readonly property var tabs: [
        { "id": "input", "name": "Input", "icon": "keyboard", "file": "hyprland/InputTab.qml" },
        { "id": "layout", "name": "Layout", "icon": "dashboard", "file": "hyprland/LayoutTab.qml" },
        { "id": "shortcuts", "name": "Shortcuts", "icon": "keyboard_command_key",
          "file": "hyprland/ShortcutsTab.qml" },
        { "id": "rules", "name": "Rules", "icon": "filter_alt", "file": "hyprland/RulesTab.qml" },
        { "id": "environment", "name": "Environment", "icon": "terminal",
          "file": "hyprland/EnvironmentTab.qml" },
        { "id": "allOptions", "name": "All options", "icon": "tune",
          "file": "hyprland/AllOptionsTab.qml" }
    ]

    /// A tab keeps its component tree once it has been opened, so switching back is instant and
    /// the slide animates between two real pages instead of one and a hole.
    property var visited: [true, false, false, false, false, false]

    function markVisited(index: int) {
        if (index < 0 || index >= hubRoot.tabs.length || hubRoot.visited[index])
            return;
        const next = Array.from(hubRoot.visited);
        next[index] = true;
        hubRoot.visited = next;
    }

    /// A settings search result knows the file its section was indexed from, not the tab. Map
    /// it back, otherwise every hit on this page would land on whichever tab happened to be open.
    function tabIndexForSource(sourceKey: string): int {
        const name = String(sourceKey ?? "").split("/").pop();
        return hubRoot.tabs.findIndex(tab => tab.file.split("/").pop() === name);
    }

    function revealSection(title: string) {
        if (!title || title === "")
            return;
        for (const section of Array.from(SearchRegistry.sections ?? [])) {
            if (section.pageId !== "hyprland" || section.title !== title)
                continue;
            const index = hubRoot.tabIndexForSource(section.sourceKey);
            if (index >= 0)
                swipeView.currentIndex = index;
            return;
        }
    }

    Component.onCompleted: HyprlandGui.attach()
    Component.onDestruction: HyprlandGui.detach()

    Connections {
        target: SearchRegistry
        function onCurrentSearchChanged() {
            hubRoot.revealSection(SearchRegistry.currentSearch);
        }
    }

    ColumnLayout {
        id: pageLayout
        anchors.fill: parent
        spacing: 10
        opacity: subPageOverlay.slideProgress

        HyprlandHealthStrip {
            Layout.fillWidth: true
            onReviewRequested: hubRoot.openReview()
            onRemoveAllRequested: removeDialog.show = true
        }

        Item {
            id: tabStrip
            Layout.fillWidth: true
            implicitHeight: 52

            // Six tabs fit at the window's normal width and stop fitting when it is dragged
            // narrow, so the strip scrolls rather than spilling over the page.
            Flickable {
                anchors.fill: parent
                contentWidth: Math.max(width, toolbar.implicitWidth)
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Toolbar {
                    id: toolbar
                    enableShadow: false
                    width: implicitWidth
                    height: implicitHeight
                    x: Math.max(0, (tabStrip.width - implicitWidth) / 2)
                    y: (tabStrip.height - height) / 2

                    ToolbarTabBar {
                        id: tabBar
                        tabButtonList: hubRoot.tabs

                        delegate: ToolbarTabButton {
                            required property int index
                            required property var modelData

                            current: index === tabBar.currentIndex
                            text: Translation.tr(modelData.name)
                            materialSymbol: modelData.icon
                            onClicked: tabBar.setCurrentIndex(index)
                        }

                        Synchronizer on currentIndex {
                            property alias source: swipeView.currentIndex
                        }
                    }
                }
            }
        }

        SwipeView {
            id: swipeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            // Tabs are switched from the bar. A horizontal drag inside a settings page belongs
            // to whatever control is under the finger, not to the tab strip.
            interactive: false

            onCurrentIndexChanged: hubRoot.markVisited(swipeView.currentIndex)

            Repeater {
                model: hubRoot.tabs

                delegate: Loader {
                    required property var modelData
                    required property int index

                    active: hubRoot.visited[index] ?? false
                    source: Qt.resolvedUrl(modelData.file)
                }
            }
        }
    }

    // ── Review dialog ─────────────────────────────────────────────────────────
    /// [{ file, text, pending }] - the pending ones are a diff of what has not been written
    /// yet, the rest are the block exactly as it sits on disk.
    property var reviewBlocks: []
    property int reviewPending: 0
    /// Reopening the dialog while the previous round of diffs is still in flight would let those
    /// answers land in the new list. They are stamped instead, and stale ones are dropped.
    property int reviewGeneration: 0

    function openReview() {
        hubRoot.reviewGeneration += 1;
        const generation = hubRoot.reviewGeneration;
        const targets = Object.keys(HyprlandGui.targetFiles);
        hubRoot.reviewBlocks = [];
        hubRoot.reviewPending = targets.length;
        reviewDialog.show = true;
        for (const target of targets)
            HyprlandGui.previewDiff(target, (name, diff) => hubRoot.collectReview(generation, name, diff));
    }

    function collectReview(generation: int, target: string, diff: string) {
        if (generation !== hubRoot.reviewGeneration)
            return;
        const blocks = Array.from(hubRoot.reviewBlocks);
        const file = String(HyprlandGui.targetFiles[target] ?? target).split("/").pop();
        const current = HyprlandGui.regionText(target);
        if (diff !== "")
            blocks.push({ "file": file, "text": diff, "pending": true });
        else if (current !== "")
            blocks.push({ "file": file, "text": current, "pending": false });
        hubRoot.reviewBlocks = blocks;
        hubRoot.reviewPending -= 1;
    }

    WindowDialog {
        id: reviewDialog
        parent: hubRoot.parent ?? hubRoot
        anchors.fill: parent
        show: false
        backgroundWidth: 720
        onDismiss: show = false
        z: 100000

        WindowDialogTitle {
            text: Translation.tr("Managed Lua")
        }

        WindowDialogParagraph {
            Layout.fillWidth: true
            text: Translation.tr("Everything below sits between this page's own markers at the end of the file. Anything you wrote above them is never touched.")
        }

        StyledFlickable {
            id: reviewFlickable
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(blockColumn.implicitHeight, 360)
            contentHeight: blockColumn.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            clip: true

            ColumnLayout {
                id: blockColumn
                width: reviewFlickable.width
                spacing: 10

                StyledText {
                    Layout.fillWidth: true
                    visible: hubRoot.reviewBlocks.length === 0
                    text: hubRoot.reviewPending > 0 ? Translation.tr("Reading…")
                        : Translation.tr("This page has not written anything yet.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                Repeater {
                    model: hubRoot.reviewBlocks

                    delegate: ColumnLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.pending
                                ? Translation.tr("%1 — not written yet").arg(modelData.file) : modelData.file
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: modelData.pending ? Appearance.colors.colPrimary
                                : Appearance.colors.colSubtext
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: blockText.implicitHeight + 16
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colSurfaceContainerHigh

                            StyledText {
                                id: blockText
                                anchors.fill: parent
                                anchors.margins: 8
                                text: modelData.text
                                font.family: Appearance.font.family.monospace || "monospace"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnSurface
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }
            }
        }

        WindowDialogButtonRow {
            DialogButton {
                buttonText: Translation.tr("Close")
                onClicked: reviewDialog.show = false
            }
        }
    }

    // ── Remove-all confirmation ───────────────────────────────────────────────
    WindowDialog {
        id: removeDialog
        parent: hubRoot.parent ?? hubRoot
        anchors.fill: parent
        show: false
        backgroundWidth: 400
        onDismiss: show = false
        z: 100000

        WindowDialogTitle {
            text: Translation.tr("Remove every managed setting?")
        }

        WindowDialogParagraph {
            text: Translation.tr("The block this page writes is deleted from every file in ~/.config/hypr/custom/. Your own Lua above it is left alone, and each file is backed up first.")
        }

        WindowDialogButtonRow {
            DialogButton {
                buttonText: Translation.tr("Cancel")
                onClicked: removeDialog.show = false
            }
            DialogButton {
                buttonText: Translation.tr("Remove")
                colText: Appearance.colors.colError
                onClicked: {
                    HyprlandGui.stripAll();
                    removeDialog.show = false;
                }
            }
        }
    }

    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }
}
