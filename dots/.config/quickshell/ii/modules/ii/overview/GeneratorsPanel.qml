pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: 0
    property string generatedValue: ""
    property string noticeText: ""
    readonly property bool supportsSectionToggle: true
    readonly property var generators: [
        { id: "uuid", name: Translation.tr("UUID"), icon: "fingerprint", description: Translation.tr("Universally unique identifier"), keywords: "uuid guid identifier id" },
        { id: "password", name: Translation.tr("Password"), icon: "password", description: Translation.tr("20 characters without ambiguous glyphs"), keywords: "password pass senha secret" },
        { id: "lorem", name: Translation.tr("Lorem Ipsum"), icon: "notes", description: Translation.tr("Short placeholder paragraph"), keywords: "lorem ipsum text placeholder" }
    ]
    readonly property var rows: root.filteredRows()
    readonly property var selectedGenerator: root.selectedIndex >= 0 && root.selectedIndex < root.rows.length ? root.rows[root.selectedIndex] : null
    readonly property string statusText: root.noticeText.length > 0
        ? root.noticeText
        : Translation.tr("Generated locally · nothing is sent to the network")

    implicitWidth: Config.options.search.appearance.panelWidth
    implicitHeight: scaffold.implicitHeight

    function filteredRows() {
        const generic = ["generator", "generators", "generate", "gerador", "gerar"];
        const terms = root.searchQuery.trim().toLocaleLowerCase().split(/\s+/).filter(term => term.length > 0 && !generic.includes(term));
        if (terms.length === 0)
            return root.generators;
        return root.generators.filter(generator => {
            const text = [generator.name, generator.description, generator.keywords].join(" ").toLocaleLowerCase();
            return terms.every(term => text.includes(term));
        });
    }

    function clampSelection() {
        root.selectedIndex = root.rows.length === 0 ? -1 : Math.max(0, Math.min(root.selectedIndex, root.rows.length - 1));
        root.regenerate(false);
    }
    function regenerate(showFeedback = true): bool {
        if (!root.selectedGenerator) {
            root.generatedValue = "";
            return false;
        }
        root.generatedValue = LauncherSearch.generatorValue(root.selectedGenerator.id);
        if (showFeedback)
            root.showNotice(Translation.tr("Generated a new %1").arg(root.selectedGenerator.name));
        return true;
    }
    function copySelected(): bool {
        if (root.generatedValue.length === 0 && !root.regenerate(false))
            return false;
        Quickshell.clipboardText = root.generatedValue;
        root.showNotice(Translation.tr("%1 copied to clipboard").arg(root.selectedGenerator.name));
        return true;
    }
    function activateSelected(): bool { root.regenerate(false); return root.copySelected(); }
    function secondaryActivateSelected(): bool { return root.regenerate(true); }
    function toggleSection(): bool { return root.regenerate(true); }
    function navigateLeft(): bool {
        if (root.selectedIndex > 0)
            root.selectedIndex--;
        return true;
    }
    function navigateRight(): bool {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.rows.length - 1)
            root.selectedIndex++;
        return true;
    }
    function navigateUp(): bool { return root.navigateLeft(); }
    function navigateDown(): bool { return root.navigateRight(); }
    function focusInput(): bool { return false; }
    function showNotice(message) {
        root.noticeText = String(message ?? "");
        noticeTimer.restart();
    }

    onRowsChanged: root.clampSelection()
    onSelectedIndexChanged: root.regenerate(false)
    Component.onCompleted: root.clampSelection()

    Timer {
        id: noticeTimer
        interval: 3200
        onTriggered: root.noticeText = ""
    }

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Generators")
        icon: "wand_stars"
        accent: true
        showStatus: true
        statusText: root.statusText
        primaryHint: ({ label: Translation.tr("Generate & copy"), keys: ["↵"] })
        hints: [
            { label: Translation.tr("New value"), keys: ["Tab"] },
            { label: Translation.tr("Choose"), keys: ["←", "→"] }
        ]

        ColumnLayout {
            width: parent.width
            height: parent.height
            spacing: Appearance.sizes.elevationMargin

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2
                Repeater {
                    model: root.rows
                    delegate: RippleButton {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: generatorContent.implicitHeight + Appearance.sizes.elevationMargin * 2
                        buttonRadius: root.selectedIndex === index ? Appearance.rounding.large : Appearance.rounding.normal
                        colBackground: root.selectedIndex === index ? Appearance.colors.colSecondaryContainer : Appearance.colors.colSurfaceContainerHigh
                        colBackgroundHover: root.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSurfaceContainerHighestHover
                        colRipple: root.selectedIndex === index ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colSurfaceContainerHighestActive
                        onClicked: root.selectedIndex = index
                        onDoubleClicked: root.activateSelected()
                        ColumnLayout {
                            id: generatorContent
                            anchors.fill: parent
                            anchors.margins: Appearance.sizes.elevationMargin
                            spacing: Appearance.sizes.elevationMargin / 2
                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: Appearance.font.pixelSize.huge
                                color: root.selectedIndex === index ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.weight: Font.DemiBold
                                color: root.selectedIndex === index ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.description
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.selectedIndex === index ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.rows.length > 0
                radius: Appearance.rounding.large
                color: Appearance.colors.colSurfaceContainerHigh
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.sizes.elevationMargin * 2
                    spacing: Appearance.sizes.elevationMargin
                    RowLayout {
                        Layout.fillWidth: true
                        MaterialSymbol {
                            text: root.selectedGenerator?.icon ?? "wand_stars"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.selectedGenerator ? Translation.tr("Generated %1").arg(root.selectedGenerator.name) : Translation.tr("Choose a generator")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnSurface
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colSurfaceContainerHighest
                        StyledText {
                            anchors.fill: parent
                            anchors.margins: Appearance.sizes.elevationMargin
                            text: root.generatedValue
                            wrapMode: Text.WrapAnywhere
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: root.selectedGenerator?.id === "lorem" ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnSurface
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Appearance.sizes.elevationMargin / 2
                        RippleButton {
                            implicitWidth: regenerateContent.implicitWidth + Appearance.sizes.elevationMargin * 2
                            implicitHeight: Appearance.sizes.elevationMargin * 3
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colSecondaryContainer
                            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                            colRipple: Appearance.colors.colSecondaryContainerActive
                            onClicked: root.regenerate(true)
                            RowLayout {
                                id: regenerateContent
                                anchors.centerIn: parent
                                spacing: Appearance.sizes.elevationMargin / 2
                                MaterialSymbol { text: "refresh"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnSecondaryContainer }
                                StyledText { text: Translation.tr("Generate again"); color: Appearance.colors.colOnSecondaryContainer }
                            }
                        }
                        RippleButton {
                            implicitWidth: copyContent.implicitWidth + Appearance.sizes.elevationMargin * 2
                            implicitHeight: Appearance.sizes.elevationMargin * 3
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colPrimaryContainer
                            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                            colRipple: Appearance.colors.colPrimaryContainerActive
                            onClicked: root.copySelected()
                            RowLayout {
                                id: copyContent
                                anchors.centerIn: parent
                                spacing: Appearance.sizes.elevationMargin / 2
                                MaterialSymbol { text: "content_copy"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnPrimaryContainer }
                                StyledText { text: Translation.tr("Copy"); font.weight: Font.DemiBold; color: Appearance.colors.colOnPrimaryContainer }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.rows.length === 0
                MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "search_off"; iconSize: Appearance.font.pixelSize.huge; color: Appearance.colors.colPrimary }
                StyledText { Layout.alignment: Qt.AlignHCenter; text: Translation.tr("No generator matches this search"); color: Appearance.colors.colSubtext }
            }
        }
    }
}
