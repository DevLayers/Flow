pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: 0

    readonly property real listSpacing: Appearance.sizes.elevationMargin / 2
    readonly property var entries: root.filteredEntries()
    readonly property var selectedEntry: root.selectedIndex >= 0 && root.selectedIndex < root.entries.length
        ? root.entries[root.selectedIndex]
        : ""
    readonly property bool shouldBlurPreview: Config.options.search.modules.screenshots.blurPreviews
        || Config.options.workSafety.enable.clipboard
    readonly property string statusText: root.selectedEntry.length > 0
        ? root.imageDescription(root.selectedEntry)
        : Translation.tr("%1 screenshots").arg(String(root.entries.length))

    implicitWidth: 720
    implicitHeight: scaffold.implicitHeight

    function filteredEntries() {
        const query = root.searchQuery.trim().toLocaleLowerCase();
        const rows = Array.from(Cliphist.imageEntries ?? [])
            .slice(0, Config.options.search.modules.screenshots.maxItems);
        if (query.length === 0)
            return rows;
        return rows.filter(entry => root.imageDescription(entry).toLocaleLowerCase().includes(query));
    }

    function imageDescription(entry) {
        const size = String(entry ?? "").match(/(\d+)x(\d+)/);
        const id = String(entry ?? "").match(/^(\d+)\t/);
        return size
            ? `${size[1]} × ${size[2]} · #${id?.[1] ?? ""}`
            : Translation.tr("Clipboard image");
    }

    function clampSelection() {
        if (root.entries.length === 0) {
            root.selectedIndex = -1;
            return;
        }
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.entries.length - 1));
    }

    function navigateUp(): bool {
        if (root.selectedIndex <= 0)
            return false;
        root.selectedIndex--;
        screenshotList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateDown(): bool {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.entries.length - 1)
            return false;
        root.selectedIndex++;
        screenshotList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function focusInput(): bool {
        return false;
    }

    function activateSelected(): bool {
        if (root.selectedEntry.length === 0)
            return false;
        Cliphist.copy(root.selectedEntry);
        return true;
    }

    function decodeCommand(targetPath) {
        const entry = StringUtils.shellSingleQuoteEscape(root.selectedEntry);
        const target = StringUtils.shellSingleQuoteEscape(targetPath);
        return `printf '%s' '${entry}' | ${Cliphist.cliphistBinary} decode > '${target}'`;
    }

    function savedPath() {
        return `${Directories.pictures}/Screenshots/screenshot-${Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss")}.png`;
    }

    function saveSelected(): bool {
        if (root.selectedEntry.length === 0)
            return false;
        const path = root.savedPath();
        const directory = StringUtils.shellSingleQuoteEscape(`${Directories.pictures}/Screenshots`);
        Quickshell.execDetached(["bash", "-c", `mkdir -p '${directory}' && ${root.decodeCommand(path)}`]);
        return true;
    }

    function editSelected(): bool {
        if (root.selectedEntry.length === 0)
            return false;
        const path = root.savedPath();
        const directory = StringUtils.shellSingleQuoteEscape(`${Directories.pictures}/Screenshots`);
        const escapedPath = StringUtils.shellSingleQuoteEscape(path);
        Quickshell.execDetached(["bash", "-c", `mkdir -p '${directory}' && ${root.decodeCommand(path)} && exec swappy -f '${escapedPath}'`]);
        return true;
    }

    function ocrSelected(): bool {
        if (root.selectedEntry.length === 0)
            return false;
        const path = `${Directories.screenshotTemp}/search-ocr-${Date.now()}.png`;
        const escapedPath = StringUtils.shellSingleQuoteEscape(path);
        Quickshell.execDetached(["bash", "-c", `mkdir -p '${StringUtils.shellSingleQuoteEscape(Directories.screenshotTemp)}' && ${root.decodeCommand(path)} && langs=$(tesseract --list-langs 2>/dev/null | sed 1d | paste -sd+ -) && tesseract '${escapedPath}' stdout -l "${'${langs:-eng}'}" 2>/dev/null | wl-copy; rm -f '${escapedPath}'`]);
        return true;
    }

    function deleteSelected(): bool {
        if (root.selectedEntry.length === 0)
            return false;
        Cliphist.deleteEntry(root.selectedEntry);
        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
        return true;
    }

    onEntriesChanged: root.clampSelection()

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Screenshots")
        icon: "screenshot"
        accent: true
        statusText: root.statusText
        primaryHint: ({ label: Translation.tr("Copy"), keys: ["↵"] })
        hints: [
            { label: Translation.tr("Save"), keys: ["Ctrl", "S"] },
            { label: Translation.tr("Edit"), keys: ["Ctrl", "E"] },
            { label: Translation.tr("OCR"), keys: ["Ctrl", "O"] },
            { label: Translation.tr("Delete"), keys: ["⇧", "⌫"] }
        ]

        RowLayout {
            width: parent.width
            spacing: Appearance.sizes.elevationMargin

            ListView {
                id: screenshotList
                Layout.preferredWidth: parent.width * Config.options.search.clipboard.listColumnRatio
                Layout.fillHeight: true
                Layout.preferredHeight: Appearance.sizes.elevationMargin * 34
                clip: true
                spacing: root.listSpacing
                model: root.entries

                delegate: RippleButton {
                    required property int index
                    required property var modelData
                    width: screenshotList.width
                    implicitHeight: rowContent.implicitHeight + Appearance.sizes.elevationMargin * 2
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
                    onClicked: root.selectedIndex = index

                    RowLayout {
                        id: rowContent
                        anchors.fill: parent
                        anchors.margins: Appearance.sizes.elevationMargin
                        spacing: Appearance.sizes.elevationMargin

                        MaterialSymbol {
                            text: "image"
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.imageDescription(modelData)
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.selectedIndex === index
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnSurface
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.entries.length === 0
                    text: Translation.tr("No screenshots in clipboard history")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Appearance.colors.colSubtext
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Appearance.sizes.elevationMargin * 34

                CliphistImage {
                    anchors.centerIn: parent
                    visible: root.selectedEntry.length > 0
                    entry: root.selectedEntry
                    maxWidth: parent.width - Appearance.sizes.elevationMargin * 2
                    maxHeight: parent.height - Appearance.sizes.elevationMargin * 2
                    blur: root.shouldBlurPreview
                    blurText: Translation.tr("Screenshot hidden")
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.selectedEntry.length === 0
                    text: Translation.tr("Select a screenshot")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
