pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    readonly property int configuredShown: Math.max(1, Config.options.bar.workspaces.shown || 1)
    readonly property int previewLimit: Math.min(configuredShown, 6)
    readonly property bool dynamicWorkspaces: Config.options.bar.workspaces.dynamicWorkspaces
    readonly property bool showAppIcons: Config.options.bar.workspaces.showAppIcons
    readonly property bool alwaysShowNumbers: Config.options.bar.workspaces.alwaysShowNumbers
    readonly property bool useWorkspaceMap: Config.options.bar.workspaces.useWorkspaceMap
    readonly property var numberMap: Config.options.bar.workspaces.numberMap || []
    readonly property int activeWorkspaceIndex: Math.min(1, previewLimit - 1)

    // This is intentionally deterministic: settings must never instantiate or inspect real workspaces.
    readonly property var allPreviewWorkspaces: {
        const workspaces = [];
        for (let index = 0; index < previewLimit; index++) {
            const active = index === activeWorkspaceIndex;
            workspaces.push({
                "index": index,
                "active": active,
                "occupied": active || index === 0 || index === previewLimit - 1,
                "icon": ["terminal", "language", "folder", "music_note", "code", "mail"][index]
            });
        }
        return workspaces;
    }
    readonly property var displayedWorkspaces: dynamicWorkspaces
        ? allPreviewWorkspaces.filter((workspace) => workspace.occupied)
        : allPreviewWorkspaces

    implicitHeight: content.implicitHeight

    function workspaceLabel(index) {
        if (index < numberMap.length && String(numberMap[index]).length > 0)
            return String(numberMap[index]);
        return String(index + 1);
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Appearance.font.pixelSize.small
            spacing: Appearance.font.pixelSize.smallest

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.font.pixelSize.smallest

                MaterialSymbol {
                    text: "preview"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Workspace preview")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: root.dynamicWorkspaces
                        ? Translation.tr("Dynamic")
                        : Translation.tr("%1 shown").arg(String(root.configuredShown))
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.font.pixelSize.hugeass * 3
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.font.pixelSize.smallest
                    spacing: Appearance.font.pixelSize.smallest

                    Repeater {
                        model: root.displayedWorkspaces

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: Appearance.font.pixelSize.hugeass * 1.55
                            radius: Appearance.rounding.normal
                            color: modelData.active
                                ? Appearance.colors.colPrimary
                                : (modelData.occupied
                                    ? Appearance.colors.colSecondaryContainer
                                    : Appearance.colors.colLayer2)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Appearance.font.pixelSize.smallest
                                spacing: 0

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: root.showAppIcons && modelData.occupied
                                    text: modelData.icon
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: modelData.active
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colOnSecondaryContainer
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: root.alwaysShowNumbers || modelData.active
                                    text: root.workspaceLabel(modelData.index)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: modelData.active
                                        ? Appearance.colors.colOnPrimary
                                        : (modelData.occupied
                                            ? Appearance.colors.colOnSecondaryContainer
                                            : Appearance.colors.colOnLayer2)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.font.pixelSize.smallest

                MaterialSymbol {
                    text: "radio_button_checked"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: Translation.tr("Active")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }

                MaterialSymbol {
                    text: "apps"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSecondary
                }

                StyledText {
                    text: Translation.tr("Occupied")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.useWorkspaceMap
                        ? Translation.tr("Workspace map on")
                        : Translation.tr("Workspace map off")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.dynamicWorkspaces
                    ? Translation.tr("Empty workspaces are hidden in this preview.")
                    : (root.alwaysShowNumbers
                        ? Translation.tr("Numbers are shown on every workspace.")
                        : Translation.tr("Numbers are shown only on the active workspace."))
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.configuredShown > root.previewLimit
                text: Translation.tr("Showing the first %1 of %2 configured workspaces.")
                    .arg(String(root.previewLimit))
                    .arg(String(root.configuredShown))
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }
}
