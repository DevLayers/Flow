pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import "filebrowser"

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: -1
    property int actionIndex: 0
    property var backHistory: []
    property var forwardHistory: []
    property var markedPaths: ({})
    property var stagedPaths: []
    property bool stagedCut: false
    property bool showHidden: false
    property string sortMode: "name"
    property bool sortDescending: false
    property bool actionMenuOpen: false
    property bool confirmTrash: false
    property string editorMode: ""
    property string editorValue: ""
    property string noticeText: ""
    property bool detailsFirst: false
    property bool consumingPathQuery: false
    readonly property bool supportsSectionToggle: true

    signal requestSetSearchQuery(string query)
    signal requestFocusSearchInput()

    readonly property string homePath: FileUtils.trimFileProtocol(Directories.home).replace(/\/$/, "")
    readonly property var filteredEntries: root.filterEntries()
    readonly property var selectedEntry: root.selectedIndex >= 0 && root.selectedIndex < root.filteredEntries.length
        ? root.filteredEntries[root.selectedIndex]
        : null
    readonly property var selectedMetadata: backend.metadata
    readonly property int markedCount: Object.keys(root.markedPaths).length
    readonly property var actionRows: root.buildActions()
    readonly property string statusText: root.noticeText.length > 0
        ? root.noticeText
        : backend.loading
            ? Translation.tr("Reading %1…").arg(root.displayPath(backend.pendingListPath))
            : backend.errorText.length > 0
                ? backend.errorText
                : Translation.tr("%1 items · %2").arg(String(root.filteredEntries.length)).arg(root.displayPath(backend.currentPath))

    readonly property var metadataRows: {
        const entry = root.selectedMetadata;
        if (!entry)
            return [];
        const children = Number(entry.childCount ?? -1);
        return [
            { label: Translation.tr("Type"), value: root.typeLabel(entry), icon: "draft" },
            { label: Translation.tr("Size"), value: entry.isDir && children >= 0 ? Translation.tr("%1 items").arg(String(children)) : root.formatBytes(entry.size), icon: "data_usage" },
            { label: Translation.tr("Modified"), value: root.formatDate(entry.modifiedMs), icon: "edit_calendar" },
            { label: Translation.tr("Created"), value: root.formatDate(entry.createdMs), icon: "calendar_add_on" },
            { label: Translation.tr("Permissions"), value: String(entry.permissions ?? "—") + "  " + String(entry.mode ?? ""), icon: "encrypted" },
            { label: Translation.tr("Owner"), value: String(entry.owner ?? "—") + " · " + String(entry.group ?? "—"), icon: "person" }
        ];
    }

    implicitWidth: Config.options.search.clipboard.panelWidth
    implicitHeight: scaffold.implicitHeight

    function displayPath(path): string {
        const value = String(path ?? "");
        if (value === root.homePath)
            return "~";
        if (value.startsWith(root.homePath + "/"))
            return "~" + value.slice(root.homePath.length);
        return value || "~";
    }

    function fileIcon(entry): string {
        if (!entry)
            return "draft";
        if (entry.isDir)
            return "folder";
        if (entry.isImage)
            return "image";
        if (entry.isVideo)
            return "movie";
        if (entry.isAudio)
            return "audio_file";
        if (entry.isPdf)
            return "picture_as_pdf";
        if (entry.isText)
            return "description";
        if (entry.executable)
            return "terminal";
        return "draft";
    }

    function fileShape(entry): string {
        if (entry?.isDir)
            return "Arch";
        if (entry?.isImage || entry?.isVideo)
            return "Gem";
        if (entry?.isAudio)
            return "Sunny";
        if (entry?.executable)
            return "PixelCircle";
        return "Cookie4Sided";
    }

    function typeLabel(entry): string {
        if (!entry)
            return Translation.tr("Unknown");
        if (entry.isDir)
            return Translation.tr("Directory");
        if (entry.isSymlink)
            return Translation.tr("Symbolic link");
        return String(entry.mime ?? Translation.tr("File"));
    }

    function formatBytes(value): string {
        let bytes = Math.max(0, Number(value ?? 0));
        const units = [Translation.tr("B"), Translation.tr("KB"), Translation.tr("MB"), Translation.tr("GB"), Translation.tr("TB")];
        let unit = 0;
        while (bytes >= 1024 && unit < units.length - 1) {
            bytes /= 1024;
            unit++;
        }
        const digits = unit === 0 || bytes >= 10 ? 0 : 1;
        return bytes.toFixed(digits) + " " + units[unit];
    }

    function formatDate(value): string {
        const timestamp = Number(value ?? 0);
        return timestamp > 0 ? Qt.formatDateTime(new Date(timestamp), "dd MMM yyyy · HH:mm") : "—";
    }

    function filterEntries(): var {
        const rows = Array.from(backend.entries ?? []);
        const terms = root.searchQuery.trim().toLocaleLowerCase().split(/\s+/).filter(term => term.length > 0);
        if (terms.length === 0)
            return rows;
        const ranked = [];
        for (const entry of rows) {
            const name = String(entry.name ?? "").toLocaleLowerCase();
            const haystack = [name, entry.extension, entry.mime].join(" ").toLocaleLowerCase();
            if (!terms.every(term => haystack.includes(term)))
                continue;
            let score = 0;
            for (const term of terms) {
                if (name === term)
                    score += 1000;
                else if (name.startsWith(term))
                    score += 300;
                else
                    score += Math.max(1, 100 - name.indexOf(term));
            }
            ranked.push({ entry: entry, score: score });
        }
        ranked.sort((a, b) => b.score - a.score || String(a.entry.name).localeCompare(String(b.entry.name)));
        return ranked.map(row => row.entry);
    }

    function buildActions(): var {
        const hasEntry = root.selectedEntry !== null;
        return [
            { id: "open", label: root.selectedEntry?.isDir ? Translation.tr("Open directory") : Translation.tr("Open file"), icon: "open_in_new", keys: ["↵"], enabled: hasEntry },
            { id: "external", label: Translation.tr("Open externally"), icon: "launch", actionId: "secondary", keys: ["Ctrl", "↵"], enabled: hasEntry },
            { id: "mark", label: root.isMarked(root.selectedEntry?.path) ? Translation.tr("Unmark item") : Translation.tr("Mark item"), icon: "select_check_box", actionId: "select", keys: ["Ctrl", "Space"], enabled: hasEntry },
            { id: "copy-path", label: Translation.tr("Copy path"), icon: "content_copy", actionId: "copy", keys: ["Ctrl", "C"], enabled: hasEntry },
            { id: "stage-copy", label: Translation.tr("Copy for paste"), icon: "file_copy", keys: [], enabled: hasEntry },
            { id: "cut", label: Translation.tr("Cut for paste"), icon: "content_cut", actionId: "cut", keys: ["Ctrl", "X"], enabled: hasEntry },
            { id: "paste", label: Translation.tr("Paste here"), icon: "content_paste", actionId: "paste", keys: ["Ctrl", "V"], enabled: root.stagedPaths.length > 0 },
            { id: "rename", label: Translation.tr("Rename"), icon: "drive_file_rename_outline", actionId: "edit", keys: ["Ctrl", "E"], enabled: hasEntry },
            { id: "duplicate", label: Translation.tr("Duplicate"), icon: "control_point_duplicate", actionId: "duplicate", keys: ["Ctrl", "D"], enabled: hasEntry },
            { id: "new-file", label: Translation.tr("New file"), icon: "note_add", actionId: "create", keys: ["Ctrl", "N"], enabled: backend.currentPath.length > 0 },
            { id: "new-folder", label: Translation.tr("New folder"), icon: "create_new_folder", actionId: "createFolder", keys: ["Ctrl", "Shift", "N"], enabled: backend.currentPath.length > 0 },
            { id: "hidden", label: root.showHidden ? Translation.tr("Hide dotfiles") : Translation.tr("Show dotfiles"), icon: root.showHidden ? "visibility_off" : "visibility", actionId: "toggleHidden", keys: ["Ctrl", "H"], enabled: true },
            { id: "refresh", label: Translation.tr("Refresh directory"), icon: "refresh", actionId: "refresh", keys: ["Ctrl", "R"], enabled: true },
            { id: "trash", label: Translation.tr("Move to Trash"), icon: "delete", actionId: "delete", keys: ["Shift", "Del"], enabled: hasEntry }
        ];
    }

    function clampSelection(): void {
        if (root.filteredEntries.length === 0) {
            root.selectedIndex = -1;
            backend.inspect("");
            return;
        }
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.filteredEntries.length - 1));
        fileList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        previewDebounce.restart();
    }

    function tryConsumePathQuery(): bool {
        if (root.consumingPathQuery)
            return false;
        const query = root.searchQuery.trim();
        if (query.length <= 1 || !query.startsWith("/") || !query.endsWith("/"))
            return false;
        root.consumingPathQuery = true;
        root.enterDirectory(root.homePath + query, true);
        root.requestSetSearchQuery("");
        root.consumingPathQuery = false;
        return true;
    }

    function enterDirectory(path, remember = true): bool {
        const target = String(path ?? "").replace(/\/$/, "") || "/";
        if (target.length === 0)
            return false;
        if (remember && backend.currentPath.length > 0 && target !== backend.currentPath) {
            root.backHistory = root.backHistory.concat([{ path: backend.currentPath, index: root.selectedIndex }]);
            root.forwardHistory = [];
        }
        root.confirmTrash = false;
        root.actionMenuOpen = false;
        root.requestSetSearchQuery("");
        backend.listDirectory(target, root.showHidden, root.sortMode, root.sortDescending);
        return true;
    }

    function navigateBack(): bool {
        if (root.handleEscape())
            return true;
        if (root.backHistory.length > 0) {
            const item = root.backHistory[root.backHistory.length - 1];
            root.backHistory = root.backHistory.slice(0, -1);
            if (backend.currentPath.length > 0)
                root.forwardHistory = root.forwardHistory.concat([{ path: backend.currentPath, index: root.selectedIndex }]);
            backend.listDirectory(item.path, root.showHidden, root.sortMode, root.sortDescending);
            return true;
        }
        if (backend.currentPath.length > 0 && backend.currentPath !== root.homePath && backend.currentPath !== "/")
            return root.enterDirectory(FileUtils.parentDirectory(backend.currentPath) || "/", true);
        return false;
    }

    function navigateForward(): bool {
        if (root.forwardHistory.length === 0)
            return false;
        const item = root.forwardHistory[root.forwardHistory.length - 1];
        root.forwardHistory = root.forwardHistory.slice(0, -1);
        if (backend.currentPath.length > 0)
            root.backHistory = root.backHistory.concat([{ path: backend.currentPath, index: root.selectedIndex }]);
        backend.listDirectory(item.path, root.showHidden, root.sortMode, root.sortDescending);
        return true;
    }

    function navigateUp(): bool {
        if (root.actionMenuOpen) {
            root.actionIndex = Math.max(0, root.actionIndex - 1);
            actionList.positionViewAtIndex(root.actionIndex, ListView.Contain);
            return true;
        }
        if (root.selectedIndex <= 0)
            return false;
        root.selectedIndex--;
        fileList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateDown(): bool {
        if (root.actionMenuOpen) {
            root.actionIndex = Math.min(root.actionRows.length - 1, root.actionIndex + 1);
            actionList.positionViewAtIndex(root.actionIndex, ListView.Contain);
            return true;
        }
        if (root.selectedIndex < 0 || root.selectedIndex >= root.filteredEntries.length - 1)
            return false;
        root.selectedIndex++;
        fileList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateLeft(): bool {
        return root.navigateBack();
    }

    function navigateRight(): bool {
        if (root.actionMenuOpen)
            return false;
        if (root.selectedEntry?.isDir)
            return root.enterDirectory(root.selectedEntry.path, true);
        return root.navigateForward();
    }

    function activateSelected(): bool {
        if (root.actionMenuOpen)
            return root.runAction(root.actionRows[root.actionIndex]?.id);
        if (root.confirmTrash)
            return root.confirmTrashNow();
        const entry = root.selectedEntry;
        if (!entry)
            return false;
        if (entry.isDir)
            return root.enterDirectory(entry.path, true);
        Quickshell.execDetached(["xdg-open", entry.path]);
        GlobalStates.overviewOpen = false;
        return true;
    }

    function secondaryActivateSelected(): bool {
        const entry = root.selectedEntry;
        if (!entry)
            return false;
        Quickshell.execDetached(["xdg-open", entry.isDir ? entry.path : entry.parent]);
        GlobalStates.overviewOpen = false;
        return true;
    }

    function focusInput(): bool {
        return false;
    }

    function handleEscape(): bool {
        if (root.actionMenuOpen) {
            root.actionMenuOpen = false;
            return true;
        }
        if (root.editorMode.length > 0) {
            root.closeEditor();
            return true;
        }
        if (root.confirmTrash) {
            root.confirmTrash = false;
            return true;
        }
        return false;
    }

    function toggleActions(): bool {
        root.actionMenuOpen = !root.actionMenuOpen;
        root.actionIndex = 0;
        return true;
    }

    function isMarked(path): bool {
        return String(path ?? "").length > 0 && root.markedPaths[String(path)] === true;
    }

    function toggleSelection(): bool {
        const path = String(root.selectedEntry?.path ?? "");
        if (path.length === 0)
            return false;
        const next = Object.assign({}, root.markedPaths);
        if (next[path])
            delete next[path];
        else
            next[path] = true;
        root.markedPaths = next;
        root.showNotice(next[path] ? Translation.tr("Item marked") : Translation.tr("Item unmarked"));
        return true;
    }

    function operationTargets(): var {
        const marked = Object.keys(root.markedPaths);
        if (marked.length > 0)
            return marked;
        const path = String(root.selectedEntry?.path ?? "");
        return path.length > 0 ? [path] : [];
    }

    function copySelected(): bool {
        const paths = root.operationTargets();
        if (paths.length === 0)
            return false;
        Quickshell.clipboardText = paths.join("\n");
        root.showNotice(paths.length === 1 ? Translation.tr("Path copied") : Translation.tr("%1 paths copied").arg(String(paths.length)));
        return true;
    }

    function stageCopy(): bool {
        const paths = root.operationTargets();
        if (paths.length === 0)
            return false;
        root.stagedPaths = paths;
        root.stagedCut = false;
        root.showNotice(Translation.tr("Ready to copy %1 item(s)").arg(String(paths.length)));
        return true;
    }

    function cutSelected(): bool {
        const paths = root.operationTargets();
        if (paths.length === 0)
            return false;
        root.stagedPaths = paths;
        root.stagedCut = true;
        root.showNotice(Translation.tr("Ready to move %1 item(s)").arg(String(paths.length)));
        return true;
    }

    function pasteClipboard(): bool {
        if (root.stagedPaths.length === 0 || backend.currentPath.length === 0)
            return false;
        return backend.operate(root.stagedCut ? "move" : "copy", {
            destination: backend.currentPath,
            paths: root.stagedPaths
        });
    }

    function editSelected(): bool {
        const entry = root.selectedEntry;
        if (!entry)
            return false;
        return root.openEditor("rename", entry.name);
    }

    function createFromQuery(): bool {
        const suggested = root.searchQuery.trim();
        return root.openEditor("create-file", suggested.length > 0 ? suggested : Translation.tr("New file"));
    }

    function createFolder(): bool {
        return root.openEditor("create-directory", Translation.tr("New folder"));
    }

    function duplicateSelected(): bool {
        const entry = root.selectedEntry;
        return entry ? backend.operate("duplicate", { path: entry.path }) : false;
    }

    function deleteSelected(): bool {
        if (root.operationTargets().length === 0)
            return false;
        root.actionMenuOpen = false;
        root.confirmTrash = true;
        root.showNotice(Translation.tr("Press Enter to move the selection to Trash"));
        return true;
    }

    function confirmTrashNow(): bool {
        const targets = root.operationTargets();
        root.confirmTrash = false;
        return targets.length > 0 && backend.operate("trash", { paths: targets });
    }

    function toggleHidden(): bool {
        root.showHidden = !root.showHidden;
        return root.refreshDirectory();
    }

    function refreshDirectory(): bool {
        if (backend.currentPath.length === 0)
            return false;
        backend.listDirectory(backend.currentPath, root.showHidden, root.sortMode, root.sortDescending);
        return true;
    }

    function cycleSort(): bool {
        const modes = ["name", "modified", "size", "type"];
        const index = modes.indexOf(root.sortMode);
        root.sortMode = modes[(index + 1) % modes.length];
        root.refreshDirectory();
        return true;
    }

    function toggleSection(): bool {
        root.detailsFirst = !root.detailsFirst;
        return true;
    }

    function openEditor(mode, value): bool {
        root.actionMenuOpen = false;
        root.confirmTrash = false;
        root.editorMode = String(mode ?? "");
        root.editorValue = String(value ?? "");
        Qt.callLater(() => {
            editorField.text = root.editorValue;
            editorField.selectAll();
            editorField.forceActiveFocus();
        });
        return true;
    }

    function closeEditor(): void {
        root.editorMode = "";
        root.editorValue = "";
        root.requestFocusSearchInput();
    }

    function submitEditor(): bool {
        const value = editorField.text.trim();
        if (value.length === 0)
            return false;
        let started = false;
        if (root.editorMode === "rename" && root.selectedEntry)
            started = backend.operate("rename", { path: root.selectedEntry.path, name: value });
        else if (root.editorMode === "create-file" || root.editorMode === "create-directory")
            started = backend.operate(root.editorMode, { destination: backend.currentPath, name: value });
        if (started)
            root.closeEditor();
        return started;
    }

    function runAction(actionId): bool {
        root.actionMenuOpen = false;
        switch (String(actionId ?? "")) {
        case "open": return root.activateSelected();
        case "external": return root.secondaryActivateSelected();
        case "mark": return root.toggleSelection();
        case "copy-path": return root.copySelected();
        case "stage-copy": return root.stageCopy();
        case "cut": return root.cutSelected();
        case "paste": return root.pasteClipboard();
        case "rename": return root.editSelected();
        case "duplicate": return root.duplicateSelected();
        case "new-file": return root.createFromQuery();
        case "new-folder": return root.createFolder();
        case "hidden": return root.toggleHidden();
        case "refresh": return root.refreshDirectory();
        case "trash": return root.deleteSelected();
        default: return false;
        }
    }

    function showNotice(message): void {
        root.noticeText = String(message ?? "");
        noticeTimer.restart();
    }

    onFilteredEntriesChanged: root.clampSelection()
    onSelectedIndexChanged: previewDebounce.restart()
    onSearchQueryChanged: {
        if (!root.tryConsumePathQuery()) {
            root.selectedIndex = root.filteredEntries.length > 0 ? 0 : -1;
            root.clampSelection();
        }
    }

    Component.onCompleted: backend.listDirectory(root.homePath, root.showHidden, root.sortMode, root.sortDescending)

    Timer {
        id: previewDebounce
        interval: 90
        onTriggered: backend.inspect(String(root.selectedEntry?.path ?? ""))
    }

    Timer {
        id: noticeTimer
        interval: 3200
        onTriggered: root.noticeText = ""
    }

    FileBrowserBackend {
        id: backend
    }

    Connections {
        target: backend

        function onDirectoryLoaded(path) {
            root.selectedIndex = backend.entries.length > 0 ? 0 : -1;
            root.clampSelection();
        }

        function onOperationFinished(success, operation, message, affected) {
            if (success) {
                root.markedPaths = ({});
                if (operation === "move") {
                    root.stagedPaths = [];
                    root.stagedCut = false;
                }
                root.showNotice(root.operationSuccessMessage(operation, affected));
                root.refreshDirectory();
            } else {
                root.showNotice(message);
            }
        }
    }

    function operationSuccessMessage(operation, affected): string {
        const count = Array.from(affected ?? []).length;
        switch (operation) {
        case "trash": return Translation.tr("Moved %1 item(s) to Trash").arg(String(count));
        case "copy": return Translation.tr("Copied %1 item(s)").arg(String(count));
        case "move": return Translation.tr("Moved %1 item(s)").arg(String(count));
        case "rename": return Translation.tr("Item renamed");
        case "duplicate": return Translation.tr("Item duplicated");
        case "create-file": return Translation.tr("File created");
        case "create-directory": return Translation.tr("Folder created");
        default: return Translation.tr("File operation completed");
        }
    }

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("File Browser")
        icon: "folder_data"
        accent: true
        showStatus: true
        statusText: root.statusText
        primaryHint: ({ label: root.selectedEntry?.isDir ? Translation.tr("Browse") : Translation.tr("Open"), actionId: "activate", keys: ["↵"] })
        hints: [
            { label: Translation.tr("Actions"), actionId: "actions", keys: ["Ctrl", "K"] },
            { label: Translation.tr("Mark"), actionId: "select", keys: ["Ctrl", "Space"] },
            { label: Translation.tr("Back"), keys: ["Backspace"] }
        ]

        ColumnLayout {
            width: parent.width
            height: parent.height
            spacing: Appearance.sizes.elevationMargin

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2

                RippleButton {
                    enabled: root.backHistory.length > 0 || (backend.currentPath !== root.homePath && backend.currentPath !== "/")
                    implicitWidth: Appearance.sizes.elevationMargin * 4
                    implicitHeight: implicitWidth
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    onClicked: root.navigateBack()
                    MaterialSymbol { anchors.centerIn: parent; text: "arrow_back"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnSecondaryContainer }
                }

                RippleButton {
                    implicitWidth: Appearance.sizes.elevationMargin * 4
                    implicitHeight: implicitWidth
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSurfaceContainerHigh
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                    colRipple: Appearance.colors.colSurfaceContainerHighestActive
                    onClicked: root.enterDirectory(root.homePath, true)
                    MaterialSymbol { anchors.centerIn: parent; text: "home"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnSurface }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Appearance.sizes.elevationMargin * 4
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colSurfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Appearance.sizes.elevationMargin
                        anchors.rightMargin: Appearance.sizes.elevationMargin
                        spacing: Appearance.sizes.elevationMargin / 2
                        MaterialSymbol { text: "folder_open"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colPrimary }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.displayPath(backend.currentPath || backend.pendingListPath)
                            elide: Text.ElideMiddle
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                        }
                        StyledText {
                            visible: root.markedCount > 0
                            text: Translation.tr("%1 marked").arg(String(root.markedCount))
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colPrimary
                        }
                    }
                }

                RippleButton {
                    implicitWidth: sortContent.implicitWidth + Appearance.sizes.elevationMargin * 2
                    implicitHeight: Appearance.sizes.elevationMargin * 4
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSurfaceContainerHigh
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                    colRipple: Appearance.colors.colSurfaceContainerHighestActive
                    onClicked: root.cycleSort()
                    RowLayout {
                        id: sortContent
                        anchors.centerIn: parent
                        spacing: Appearance.sizes.elevationMargin / 2
                        MaterialSymbol { text: "sort"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnSurface }
                        StyledText { text: Translation.tr(root.sortMode); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnSurface }
                    }
                }

                RippleButton {
                    implicitWidth: Appearance.sizes.elevationMargin * 4
                    implicitHeight: implicitWidth
                    buttonRadius: Appearance.rounding.full
                    toggled: root.showHidden
                    colBackground: Appearance.colors.colSurfaceContainerHigh
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                    colBackgroundToggled: Appearance.colors.colPrimaryContainer
                    colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colSurfaceContainerHighestActive
                    colRippleToggled: Appearance.colors.colPrimaryContainerActive
                    onClicked: root.toggleHidden()
                    MaterialSymbol { anchors.centerIn: parent; text: root.showHidden ? "visibility" : "visibility_off"; iconSize: Appearance.font.pixelSize.normal; color: root.showHidden ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface }
                }
            }

            Item {
                id: browserBody
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    spacing: Appearance.sizes.elevationMargin

                    Rectangle {
                        Layout.preferredWidth: browserBody.width * 0.42
                        Layout.fillHeight: true
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colSurfaceContainerHigh
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Appearance.sizes.elevationMargin / 2
                            spacing: Appearance.sizes.elevationMargin / 2

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Appearance.sizes.elevationMargin / 2
                                Layout.rightMargin: Appearance.sizes.elevationMargin / 2
                                StyledText { Layout.fillWidth: true; text: Translation.tr("Files"); font.weight: Font.DemiBold; color: Appearance.colors.colOnSurface }
                                StyledText { text: String(root.filteredEntries.length); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                            }

                            ListView {
                                id: fileList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: root.filteredEntries
                                clip: true
                                spacing: Appearance.sizes.elevationMargin / 3
                                boundsBehavior: Flickable.StopAtBounds
                                reuseItems: true
                                cacheBuffer: height
                                currentIndex: root.selectedIndex

                                delegate: RippleButton {
                                    id: fileRow
                                    required property int index
                                    required property var modelData
                                    readonly property bool selected: root.selectedIndex === index
                                    readonly property bool marked: root.isMarked(modelData.path)
                                    width: ListView.view.width
                                    implicitHeight: Appearance.sizes.elevationMargin * 5
                                    buttonRadius: selected ? Appearance.rounding.large : Appearance.rounding.normal
                                    colBackground: selected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh
                                    colBackgroundHover: selected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colSurfaceContainerHighestHover
                                    colRipple: selected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colSurfaceContainerHighestActive
                                    onClicked: root.selectedIndex = index
                                    onDoubleClicked: { root.selectedIndex = index; root.activateSelected(); }
                                    onHoveredChanged: if (hovered) root.selectedIndex = index

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Appearance.sizes.elevationMargin
                                        anchors.rightMargin: Appearance.sizes.elevationMargin
                                        spacing: Appearance.sizes.elevationMargin

                                        MaterialShape {
                                            implicitSize: Appearance.sizes.elevationMargin * 3.5
                                            shapeString: root.fileShape(fileRow.modelData)
                                            color: fileRow.selected ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: root.fileIcon(fileRow.modelData)
                                                iconSize: Appearance.font.pixelSize.normal
                                                color: fileRow.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: fileRow.modelData.name
                                                elide: Text.ElideMiddle
                                                font.weight: fileRow.selected ? Font.DemiBold : Font.Normal
                                                color: fileRow.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: fileRow.modelData.isDir
                                                    ? Translation.tr("Directory")
                                                    : root.formatBytes(fileRow.modelData.size) + " · " + String(fileRow.modelData.extension || fileRow.modelData.mime)
                                                elide: Text.ElideRight
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: fileRow.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                                                opacity: 0.78
                                            }
                                        }

                                        MaterialSymbol {
                                            visible: fileRow.marked || fileRow.modelData.isDir
                                            text: fileRow.marked ? "check_circle" : "chevron_right"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: fileRow.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary
                                        }

                                        ConfiguredKeyHint {
                                            visible: fileRow.selected && Config.options.search.appearance.showKeyHints
                                            fallbackKeys: ["↵"]
                                            surface: Appearance.colors.colPrimaryContainer
                                            onSurface: Appearance.colors.colOnPrimaryContainer
                                        }
                                    }
                                }

                                add: Transition {
                                    ParallelAnimation {
                                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Appearance.animation.elementMoveFast.duration }
                                        NumberAnimation { property: "y"; from: Appearance.sizes.elevationMargin; duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }
                                }

                                ScrollEdgeFade {}
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: !backend.loading && root.filteredEntries.length === 0
                                spacing: Appearance.sizes.elevationMargin
                                MaterialShape {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitSize: Appearance.sizes.elevationMargin * 7
                                    shapeString: "Puffy"
                                    color: Appearance.colors.colSecondaryContainer
                                    MaterialSymbol { anchors.centerIn: parent; text: root.searchQuery.trim().length > 0 ? "search_off" : "folder_off"; iconSize: Appearance.font.pixelSize.huge; color: Appearance.colors.colOnSecondaryContainer }
                                }
                                StyledText { Layout.alignment: Qt.AlignHCenter; text: root.searchQuery.trim().length > 0 ? Translation.tr("No file matches this search") : Translation.tr("This folder is empty"); font.weight: Font.DemiBold; color: Appearance.colors.colOnSurface }
                                StyledText { Layout.alignment: Qt.AlignHCenter; text: root.searchQuery.trim().length > 0 ? Translation.tr("Try fewer words or clear the search field") : Translation.tr("Create a file or folder with the shortcuts below"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: backend.loading
                                spacing: Appearance.sizes.elevationMargin
                                MaterialShape {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitSize: Appearance.sizes.elevationMargin * 7
                                    shapeString: "ClamShell"
                                    color: Appearance.colors.colPrimaryContainer
                                    MaterialSymbol { anchors.centerIn: parent; text: "folder_sync"; iconSize: Appearance.font.pixelSize.huge; color: Appearance.colors.colOnPrimaryContainer }
                                }
                                StyledText { Layout.alignment: Qt.AlignHCenter; text: Translation.tr("Reading directory…"); color: Appearance.colors.colSubtext }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colSurfaceContainerHigh
                        clip: true

                        ColumnLayout {
                            id: previewContent
                            anchors.fill: parent
                            anchors.margins: Appearance.sizes.elevationMargin
                            spacing: Appearance.sizes.elevationMargin
                            opacity: 1

                            Behavior on opacity {
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.sizes.elevationMargin
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    StyledText { Layout.fillWidth: true; text: root.selectedMetadata?.name ?? Translation.tr("Select a file"); elide: Text.ElideMiddle; font.pixelSize: Appearance.font.pixelSize.large; font.weight: Font.DemiBold; color: Appearance.colors.colOnSurface }
                                    StyledText { Layout.fillWidth: true; text: root.selectedMetadata ? root.displayPath(root.selectedMetadata.path) : Translation.tr("Preview and metadata appear here"); elide: Text.ElideMiddle; font.pixelSize: Appearance.font.pixelSize.smallest; font.family: Appearance.font.family.monospace; color: Appearance.colors.colSubtext }
                                }
                                ConfiguredKeyHint { visible: root.selectedEntry !== null && Config.options.search.appearance.showKeyHints; actionId: "actions"; fallbackKeys: ["Ctrl", "K"]; surface: Appearance.colors.colSecondaryContainer; onSurface: Appearance.colors.colOnSecondaryContainer }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: browserBody.height * 0.42
                                radius: Appearance.rounding.normal
                                color: Appearance.colors.colSurfaceContainerHighest
                                clip: true

                                ThumbnailImage {
                                    anchors.fill: parent
                                    anchors.margins: Appearance.sizes.elevationMargin
                                    visible: ["image", "video", "pdf"].includes(String(root.selectedMetadata?.previewKind ?? ""))
                                    sourcePath: String(root.selectedMetadata?.path ?? "")
                                    fillMode: Image.PreserveAspectFit
                                    generateThumbnail: visible
                                }

                                StyledFlickable {
                                    anchors.fill: parent
                                    anchors.margins: Appearance.sizes.elevationMargin
                                    visible: root.selectedMetadata?.previewKind === "text"
                                    contentHeight: previewText.implicitHeight
                                    clip: true
                                    StyledText {
                                        id: previewText
                                        width: parent.width
                                        text: String(root.selectedMetadata?.previewText ?? "")
                                        textFormat: Text.PlainText
                                        wrapMode: Text.WrapAnywhere
                                        font.family: Appearance.font.family.monospace
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnSurface
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    visible: root.selectedMetadata !== null
                                        && !["image", "video", "pdf", "text"].includes(String(root.selectedMetadata?.previewKind ?? ""))
                                    spacing: Appearance.sizes.elevationMargin
                                    MaterialShape {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitSize: Appearance.sizes.elevationMargin * 9
                                        shapeString: root.fileShape(root.selectedMetadata)
                                        color: Appearance.colors.colPrimaryContainer
                                        MaterialSymbol { anchors.centerIn: parent; text: root.fileIcon(root.selectedMetadata); iconSize: Appearance.font.pixelSize.huge; color: Appearance.colors.colOnPrimaryContainer }
                                    }
                                    StyledText { Layout.alignment: Qt.AlignHCenter; text: root.typeLabel(root.selectedMetadata); color: Appearance.colors.colSubtext }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    visible: root.selectedMetadata === null
                                    spacing: Appearance.sizes.elevationMargin
                                    MaterialShape {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitSize: Appearance.sizes.elevationMargin * 8
                                        shapeString: "ClamShell"
                                        color: Appearance.colors.colSecondaryContainer
                                        MaterialSymbol { anchors.centerIn: parent; text: backend.inspecting ? "hourglass_top" : "preview"; iconSize: Appearance.font.pixelSize.huge; color: Appearance.colors.colOnSecondaryContainer }
                                    }
                                    StyledText { Layout.alignment: Qt.AlignHCenter; text: backend.inspecting ? Translation.tr("Preparing preview…") : Translation.tr("Choose an item to inspect"); color: Appearance.colors.colSubtext }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: Appearance.sizes.elevationMargin
                                rowSpacing: Appearance.sizes.elevationMargin / 2
                                Repeater {
                                    model: root.metadataRows
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: metaRow.implicitHeight + Appearance.sizes.elevationMargin
                                        radius: Appearance.rounding.normal
                                        color: Appearance.colors.colSurfaceContainerHighest
                                        RowLayout {
                                            id: metaRow
                                            anchors.fill: parent
                                            anchors.leftMargin: Appearance.sizes.elevationMargin
                                            anchors.rightMargin: Appearance.sizes.elevationMargin
                                            spacing: Appearance.sizes.elevationMargin / 2
                                            MaterialSymbol { text: parent.parent.modelData.icon; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colPrimary }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                StyledText { Layout.fillWidth: true; text: parent.parent.parent.modelData.label; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                                                StyledText { Layout.fillWidth: true; text: parent.parent.parent.modelData.value; elide: Text.ElideMiddle; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnSurface }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: actionMenu
                    z: 5
                    visible: root.actionMenuOpen
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Appearance.sizes.elevationMargin
                    width: parent.width * 0.46
                    height: Math.min(parent.height - Appearance.sizes.elevationMargin * 2, actionColumn.implicitHeight + Appearance.sizes.elevationMargin * 2)
                    radius: Appearance.rounding.verylarge
                    color: Appearance.colors.colSurfaceContainerHighest

                    ColumnLayout {
                        id: actionColumn
                        anchors.fill: parent
                        anchors.margins: Appearance.sizes.elevationMargin
                        spacing: Appearance.sizes.elevationMargin / 2
                        RowLayout {
                            Layout.fillWidth: true
                            MaterialShape { implicitSize: Appearance.sizes.elevationMargin * 4; shapeString: "Burst"; color: Appearance.colors.colTertiaryContainer; MaterialSymbol { anchors.centerIn: parent; text: "bolt"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnTertiaryContainer } }
                            ColumnLayout { Layout.fillWidth: true; spacing: 0; StyledText { text: Translation.tr("File actions"); font.weight: Font.DemiBold; color: Appearance.colors.colOnSurface } StyledText { text: Translation.tr("Every action is keyboard-accessible"); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext } }
                        }
                        ListView {
                            id: actionList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, browserBody.height - Appearance.sizes.elevationMargin * 9)
                            model: root.actionRows
                            spacing: Appearance.sizes.elevationMargin / 3
                            clip: true
                            currentIndex: root.actionIndex
                            delegate: RippleButton {
                                id: actionRow
                                required property int index
                                required property var modelData
                                width: ListView.view.width
                                implicitHeight: Appearance.sizes.elevationMargin * 4.5
                                enabled: modelData.enabled
                                buttonRadius: root.actionIndex === index ? Appearance.rounding.large : Appearance.rounding.normal
                                colBackground: root.actionIndex === index ? Appearance.colors.colTertiaryContainer : Appearance.colors.colSurfaceContainerHigh
                                colBackgroundHover: root.actionIndex === index ? Appearance.colors.colTertiaryContainerHover : Appearance.colors.colSurfaceContainerHighestHover
                                colRipple: root.actionIndex === index ? Appearance.colors.colTertiaryContainerActive : Appearance.colors.colSurfaceContainerHighestActive
                                onHoveredChanged: if (hovered) root.actionIndex = index
                                onClicked: { root.actionIndex = index; root.runAction(modelData.id); }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Appearance.sizes.elevationMargin
                                    anchors.rightMargin: Appearance.sizes.elevationMargin
                                    spacing: Appearance.sizes.elevationMargin
                                    MaterialSymbol { text: actionRow.modelData.icon; iconSize: Appearance.font.pixelSize.normal; color: root.actionIndex === actionRow.index ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colPrimary }
                                    StyledText { Layout.fillWidth: true; text: actionRow.modelData.label; color: root.actionIndex === actionRow.index ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnSurface }
                                    ConfiguredKeyHint { visible: (actionRow.modelData.keys ?? []).length > 0 && Config.options.search.appearance.showKeyHints; actionId: actionRow.modelData.actionId ?? ""; fallbackKeys: actionRow.modelData.keys ?? []; surface: root.actionIndex === actionRow.index ? Appearance.colors.colTertiaryContainer : Appearance.colors.colSurfaceContainerHigh; onSurface: root.actionIndex === actionRow.index ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnSurface }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    z: 6
                    visible: root.editorMode.length > 0
                    anchors.centerIn: parent
                    width: parent.width * 0.58
                    height: editorColumn.implicitHeight + Appearance.sizes.elevationMargin * 3
                    radius: Appearance.rounding.verylarge
                    color: Appearance.colors.colSurfaceContainerHighest

                    ColumnLayout {
                        id: editorColumn
                        anchors.fill: parent
                        anchors.margins: Appearance.sizes.elevationMargin * 1.5
                        spacing: Appearance.sizes.elevationMargin
                        RowLayout {
                            Layout.fillWidth: true
                            MaterialShape { implicitSize: Appearance.sizes.elevationMargin * 5; shapeString: root.editorMode === "create-directory" ? "Arch" : "Cookie4Sided"; color: Appearance.colors.colPrimaryContainer; MaterialSymbol { anchors.centerIn: parent; text: root.editorMode === "rename" ? "drive_file_rename_outline" : (root.editorMode === "create-directory" ? "create_new_folder" : "note_add"); iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnPrimaryContainer } }
                            ColumnLayout { Layout.fillWidth: true; spacing: 0; StyledText { text: root.editorMode === "rename" ? Translation.tr("Rename item") : (root.editorMode === "create-directory" ? Translation.tr("Create folder") : Translation.tr("Create file")); font.pixelSize: Appearance.font.pixelSize.large; font.weight: Font.DemiBold; color: Appearance.colors.colOnSurface } StyledText { Layout.fillWidth: true; text: root.displayPath(backend.currentPath); elide: Text.ElideMiddle; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext } }
                        }
                        ToolbarTextField {
                            id: editorField
                            Layout.fillWidth: true
                            implicitHeight: Appearance.sizes.elevationMargin * 5
                            placeholderText: Translation.tr("Name")
                            colBackground: Appearance.colors.colSurfaceContainerHigh
                            onAccepted: root.submitEditor()
                            Keys.onEscapePressed: event => { root.closeEditor(); event.accepted = true; }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            RippleButton { implicitWidth: cancelLabel.implicitWidth + Appearance.sizes.elevationMargin * 2; implicitHeight: Appearance.sizes.elevationMargin * 4; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colSurfaceContainerHigh; colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover; colRipple: Appearance.colors.colSurfaceContainerHighestActive; onClicked: root.closeEditor(); StyledText { id: cancelLabel; anchors.centerIn: parent; text: Translation.tr("Cancel"); color: Appearance.colors.colOnSurface } }
                            RippleButton { implicitWidth: confirmLabel.implicitWidth + Appearance.sizes.elevationMargin * 2; implicitHeight: Appearance.sizes.elevationMargin * 4; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colPrimaryContainer; colBackgroundHover: Appearance.colors.colPrimaryContainerHover; colRipple: Appearance.colors.colPrimaryContainerActive; onClicked: root.submitEditor(); RowLayout { id: confirmLabel; anchors.centerIn: parent; MaterialSymbol { text: "check"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnPrimaryContainer } StyledText { text: Translation.tr("Apply"); font.weight: Font.DemiBold; color: Appearance.colors.colOnPrimaryContainer } ConfiguredKeyHint { fallbackKeys: ["↵"]; surface: Appearance.colors.colPrimaryContainer; onSurface: Appearance.colors.colOnPrimaryContainer } } }
                        }
                    }
                }

                Rectangle {
                    z: 6
                    visible: root.confirmTrash
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Appearance.sizes.elevationMargin
                    width: parent.width * 0.68
                    height: trashContent.implicitHeight + Appearance.sizes.elevationMargin * 2
                    radius: Appearance.rounding.verylarge
                    color: Appearance.colors.colErrorContainer

                    RowLayout {
                        id: trashContent
                        anchors.fill: parent
                        anchors.margins: Appearance.sizes.elevationMargin
                        spacing: Appearance.sizes.elevationMargin
                        MaterialShape { implicitSize: Appearance.sizes.elevationMargin * 5; shapeString: "Boom"; color: Appearance.colors.colError; MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnError } }
                        ColumnLayout { Layout.fillWidth: true; spacing: 0; StyledText { text: Translation.tr("Move %1 item(s) to Trash?").arg(String(root.operationTargets().length)); font.weight: Font.DemiBold; color: Appearance.colors.colOnErrorContainer } StyledText { text: Translation.tr("This is recoverable from your desktop Trash"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnErrorContainer } }
                        RippleButton { implicitWidth: trashCancel.implicitWidth + Appearance.sizes.elevationMargin * 2; implicitHeight: Appearance.sizes.elevationMargin * 4; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colSurfaceContainerHigh; colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover; colRipple: Appearance.colors.colSurfaceContainerHighestActive; onClicked: root.confirmTrash = false; StyledText { id: trashCancel; anchors.centerIn: parent; text: Translation.tr("Cancel"); color: Appearance.colors.colOnSurface } }
                        RippleButton { implicitWidth: trashConfirm.implicitWidth + Appearance.sizes.elevationMargin * 2; implicitHeight: Appearance.sizes.elevationMargin * 4; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colError; colBackgroundHover: Appearance.colors.colErrorHover; colRipple: Appearance.colors.colErrorActive; onClicked: root.confirmTrashNow(); RowLayout { id: trashConfirm; anchors.centerIn: parent; StyledText { text: Translation.tr("Move to Trash"); font.weight: Font.DemiBold; color: Appearance.colors.colOnError } ConfiguredKeyHint { fallbackKeys: ["↵"]; surface: Appearance.colors.colError; onSurface: Appearance.colors.colOnError } } }
                    }
                }
            }
        }
    }
}
