pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

/** Shared preview for update, complete and delete task mutations. */
Rectangle {
    id: root

    required property var messageData
    required property var card
    readonly property var preview: root.card?.data?.preview ?? ({})
    readonly property string operation: String(root.preview.operation ?? "")

    implicitHeight: content.implicitHeight + Appearance.rounding.normal
    radius: Appearance.rounding.normal
    color: Appearance.colors.colSecondaryContainer

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Appearance.rounding.unsharpenmore
        spacing: Appearance.rounding.unsharpenmore

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.rounding.unsharpenmore

            MaterialSymbol {
                Layout.alignment: Qt.AlignTop
                text: root.operation === "delete" ? "delete" : (root.operation === "complete" ? "task_alt" : "edit_note")
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.m3colors.m3onSecondaryContainer
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.rounding.unsharpenmore / 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.operation === "delete" ? Translation.tr("Delete this task?")
                        : (root.operation === "complete" ? Translation.tr("Complete this task?") : Translation.tr("Update this task?"))
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
                StyledText {
                    Layout.fillWidth: true
                    text: String(root.preview.title ?? root.preview.taskId ?? "")
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
                StyledText {
                    Layout.fillWidth: true
                    text: [String(root.preview.provider?.name ?? root.preview.providerId ?? ""),
                        String(root.preview.accountId ?? ""), String(root.preview.listName ?? "")]
                        .filter(value => value.length > 0).join(" · ")
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.operation === "update" && Object.keys(root.preview.changes ?? {}).length > 0
                    text: {
                        const changes = root.preview.changes ?? ({});
                        return Object.keys(changes).map(key => key + ": " + String(changes[key])).join(" · ");
                    }
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            RippleButton {
                leftPadding: Appearance.rounding.small
                rightPadding: Appearance.rounding.small
                topPadding: Appearance.rounding.unsharpenmore / 2
                bottomPadding: Appearance.rounding.unsharpenmore / 2
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: Ai.rejectTaskMutation(root.messageData)
                contentItem: StyledText {
                    text: Translation.tr("Discard")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
            RippleButton {
                leftPadding: Appearance.rounding.small
                rightPadding: Appearance.rounding.small
                topPadding: Appearance.rounding.unsharpenmore / 2
                bottomPadding: Appearance.rounding.unsharpenmore / 2
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colRipple: Appearance.colors.colPrimaryActive
                onClicked: Ai.approveTaskMutation(root.messageData)
                contentItem: StyledText {
                    text: root.operation === "delete" ? Translation.tr("Delete") : Translation.tr("Apply")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }
}
