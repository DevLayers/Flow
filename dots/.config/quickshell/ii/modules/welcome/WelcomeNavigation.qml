pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property int pageIndex: 0
    property int pageCount: 6
    signal previousRequested()
    signal nextRequested()
    signal finishRequested()

    implicitHeight: 52

    RowLayout {
        anchors.fill: parent
        spacing: 10

        RippleButtonWithIcon {
            id: previousButton
            implicitWidth: 126
            implicitHeight: 48
            enabled: root.pageIndex > 0
            opacity: enabled ? 1 : 0.45
            centerContent: true
            materialIcon: "arrow_back"
            mainText: Translation.tr("Previous")
            colText: Appearance.colors.colOnLayer1
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colBackgroundActive: Appearance.colors.colLayer1Active
            colRipple: Appearance.colors.colLayer1Active
            onClicked: root.previousRequested()
        }

        Item {
            Layout.fillWidth: true
        }

        RippleButtonWithIcon {
            id: nextButton
            visible: root.pageIndex < root.pageCount - 1
            implicitWidth: 126
            implicitHeight: 48
            centerContent: true
            iconOnRight: true
            materialIcon: "arrow_forward"
            mainText: Translation.tr("Next")
            colText: Appearance.colors.colOnPrimary
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colBackgroundActive: Appearance.colors.colPrimaryActive
            colRipple: Appearance.colors.colPrimaryActive
            onClicked: root.nextRequested()
        }

        RippleButtonWithIcon {
            id: finishButton
            visible: root.pageIndex === root.pageCount - 1
            implicitWidth: 132
            implicitHeight: 48
            centerContent: true
            iconOnRight: true
            materialIcon: "check"
            mainText: Translation.tr("Finish")
            colText: Appearance.colors.colOnPrimary
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colBackgroundActive: Appearance.colors.colPrimaryActive
            colRipple: Appearance.colors.colPrimaryActive
            onClicked: root.finishRequested()
        }
    }
}
