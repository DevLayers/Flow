pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Pick a keyboard layout, and a variant of it, in one act.
 *
 * The catalogue is flat on purpose: "French (AZERTY)" is a row, not a French row you then have
 * to open. Choosing one writes kb_layout and kb_variant together, which is the only way to
 * leave the pair in a state that means what it says.
 *
 * The shortlist on top is the same one the Welcome flow offers, in the languages' own names.
 * Everything under it comes from the system's own XKB rules file.
 */
Item {
    id: root
    anchors.fill: parent

    signal goBack
    property bool showBackButton: false

    readonly property string currentLayout: String(HyprlandGui.displayValue("input:kb_layout", "us") ?? "")
    readonly property string currentVariant: String(HyprlandGui.displayValue("input:kb_variant", "") ?? "")
    readonly property bool multiple: root.currentLayout.indexOf(",") >= 0

    function matches(row: var, query: string): bool {
        if (query === "") return true;
        return row.name.toLowerCase().indexOf(query) >= 0
            || row.layout.indexOf(query) >= 0
            || row.variant.indexOf(query) >= 0;
    }

    readonly property var rows: {
        const query = searchField.text.trim().toLowerCase();
        const common = XkbCatalog.commonLayouts
            .map(entry => ({ "layout": entry.code, "variant": "", "name": entry.label }))
            .filter(row => root.matches(row, query));
        const all = XkbCatalog.pickerRows().filter(row => root.matches(row, query));
        let out = [];
        if (common.length > 0)
            out = out.concat([{ "header": Translation.tr("Common") }], common);
        if (all.length > 0)
            out = out.concat([{ "header": Translation.tr("All layouts") }], all);
        return out;
    }

    function apply(layout: string, variant: string) {
        HyprlandGui.setKey("input:kb_layout", layout);
        // An empty variant still has to be written when something else sets one, or the old
        // value survives; when nothing does, dropping the key is tidier than writing "".
        if (variant === "" && HyprlandGui.resolve("input:kb_variant").inherited === null)
            HyprlandGui.resetKey("input:kb_variant");
        else
            HyprlandGui.setKey("input:kb_variant", variant);
    }

    Component.onCompleted: {
        XkbCatalog.load();
        HyprlandGui.watch(["input:kb_layout", "input:kb_variant"]);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RippleButton {
                implicitWidth: implicitHeight
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: root.goBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: Translation.tr("Keyboard layout")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.multiple
                        ? Translation.tr("Currently %1 — picking one here replaces the whole list.")
                            .arg(root.currentLayout)
                        : Translation.tr("Currently %1").arg(
                            root.currentVariant === "" ? root.currentLayout
                                : `${root.currentLayout} ${root.currentVariant}`)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }

        MaterialTextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: XkbCatalog.loaded
                ? Translation.tr("Search %1 layouts").arg(XkbCatalog.layouts.length)
                : Translation.tr("Reading the system's layout list…")
        }

        StyledListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            clip: true
            model: root.rows

            delegate: Item {
                id: entryRow

                required property var modelData

                readonly property bool isHeader: modelData.header !== undefined
                readonly property bool current: !isHeader
                    && root.currentLayout === modelData.layout
                    && root.currentVariant === modelData.variant

                width: list.width
                implicitHeight: entryRow.isHeader ? 34 : 44

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    visible: entryRow.isHeader
                    text: entryRow.isHeader ? entryRow.modelData.header : ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                }

                RippleButton {
                    anchors.fill: parent
                    visible: !entryRow.isHeader
                    buttonRadius: Appearance.rounding.normal
                    colBackground: entryRow.current ? Appearance.colors.colPrimaryContainer
                        : Appearance.colors.colLayer1
                    colBackgroundHover: entryRow.current ? Appearance.colors.colPrimaryContainerHover
                        : Appearance.colors.colLayer1Hover
                    colRipple: entryRow.current ? Appearance.colors.colPrimaryContainerActive
                        : Appearance.colors.colLayer1Active
                    onClicked: root.apply(entryRow.modelData.layout, entryRow.modelData.variant)

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        MaterialSymbol {
                            visible: entryRow.current
                            text: "check"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: entryRow.isHeader ? "" : entryRow.modelData.name
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: entryRow.current ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnLayer1
                        }

                        StyledText {
                            text: entryRow.isHeader ? ""
                                : (entryRow.modelData.variant === "" ? entryRow.modelData.layout
                                    : `${entryRow.modelData.layout} ${entryRow.modelData.variant}`)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.family: Appearance.font.family.monospace
                            color: entryRow.current ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            visible: XkbCatalog.loaded && root.rows.length === 0
            text: Translation.tr("No layout matches \"%1\".").arg(searchField.text.trim())
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            visible: XkbCatalog.failed
            text: Translation.tr("Could not read %1, so only the shortlist is available.").arg(XkbCatalog.source)
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colError
            wrapMode: Text.WordWrap
        }
    }
}
