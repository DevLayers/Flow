pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property string currentPageId: "start"
    property var visitedPageIds: []
    signal pageRequested(string pageId)

    implicitHeight: 28

    RowLayout {
        anchors.fill: parent
        spacing: 7

        Repeater {
            model: WelcomePageRegistry.pages

            delegate: RippleButton {
                id: segmentButton
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colBackgroundActive: Appearance.colors.colLayer1Active
                colRipple: Appearance.colors.colPrimaryActive

                contentItem: Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(16, parent.width - 12)
                    height: 6
                    radius: Appearance.rounding.full
                    color: root.currentPageId === segmentButton.modelData.id
                        ? Appearance.colors.colPrimary
                        : (root.visitedPageIds.indexOf(segmentButton.modelData.id) >= 0
                            ? Appearance.colors.colSecondary
                            : Appearance.colors.colLayer2)
                }

                Accessible.name: WelcomePageRegistry.titleFor(segmentButton.modelData.id)
                ToolTip.visible: hovered
                ToolTip.text: WelcomePageRegistry.titleFor(segmentButton.modelData.id)
                onClicked: root.pageRequested(segmentButton.modelData.id)
            }
        }
    }
}
