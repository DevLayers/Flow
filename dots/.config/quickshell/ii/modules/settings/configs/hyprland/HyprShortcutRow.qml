pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * One shortcut in the list: the keys on the left, what they do on the right.
 *
 * The badges are the part that is easy to get wrong. A shortcut can be stock, replaced from
 * here, written by hand in custom/keybinds.lua, sharing its key with something else, or only
 * live inside a key mode - and every one of those changes what pressing the key actually does,
 * so each gets said rather than folded into a single "custom" flag.
 */
RippleButton {
    id: root

    required property var row
    readonly property var others: HyprlandBinds.othersOn(root.row)

    signal openSubPage

    Layout.fillWidth: true
    implicitHeight: contentLayout.implicitHeight + 20
    useDynamicRadius: true

    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colRipple: Appearance.colors.colLayer2Active

    onClicked: root.openSubPage()

    HighlightOverlay {
        anchors.fill: parent
        radius: root.buttonEffectiveRadius
        color: Appearance.colors.colSecondaryContainer
    }

    ScrollAnimate {}

    contentItem: Item {
        anchors.fill: parent

        RowLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 12

            // A fixed width rather than a maximum: a Flow only knows to wrap once it has been
            // given one, and four modifiers plus a key is wider than a settings row.
            Flow {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 170
                spacing: 4

                Repeater {
                    model: HyprlandBinds.sortMods(root.row.mods ?? [])

                    delegate: HyprKeyChip {
                        required property var modelData

                        subdued: true
                        text: HyprlandBinds.modLabels[modelData] ?? modelData
                    }
                }

                HyprKeyChip {
                    text: root.row.resolved ? HyprlandBinds.keyLabel(root.row.key)
                        : Translation.tr("Built in a loop")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: HyprlandBinds.titleOf(root.row)
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer2
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: {
                        const parts = [];
                        if (root.row.managed) parts.push(Translation.tr("Set here"));
                        else if (root.row.file !== "") parts.push(`${root.row.file}:${root.row.line}`);
                        if (root.row.submap !== "")
                            parts.push(Translation.tr("only in the %1 mode").arg(root.row.submap));
                        if (root.others.length > 0)
                            parts.push(Translation.tr("%1 more on this key").arg(root.others.length));
                        return parts.join(" · ");
                    }
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.others.length > 0 ? Appearance.colors.colOnSurfaceVariant
                        : Appearance.colors.colSubtext
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: root.row.complex === true
                text: "code"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colSubtext
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "chevron_right"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colSubtext
            }
        }
    }
}
