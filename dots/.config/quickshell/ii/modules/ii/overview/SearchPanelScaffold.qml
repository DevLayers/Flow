pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string title: ""
    property string icon: ""
    property bool accent: false
    property string statusText: ""
    property var primaryHint: ({})
    property var hints: []
    property var onBack: null
    default property alias content: contentSlot.data

    implicitWidth: contentColumn.implicitWidth
    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            RippleButton {
                visible: typeof root.onBack === "function"
                implicitWidth: Appearance.sizes.normalIcon
                implicitHeight: implicitWidth
                buttonRadius: Appearance.rounding.full
                onClicked: root.onBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                }
            }

            MaterialSymbol {
                text: root.icon
                iconSize: Appearance.font.pixelSize.large
                color: root.accent ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
        }

        Item {
            id: contentSlot
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: childrenRect.height
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.statusText.length > 0 || root.hints.length > 0 || Object.keys(root.primaryHint).length > 0

            StyledText {
                Layout.fillWidth: true
                text: root.statusText
                elide: Text.ElideRight
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
            }

            KeyHintBar {
                hints: root.primaryHint.label ? [root.primaryHint].concat(root.hints) : root.hints
                surface: root.accent ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh
                onSurface: root.accent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
            }
        }
    }
}
