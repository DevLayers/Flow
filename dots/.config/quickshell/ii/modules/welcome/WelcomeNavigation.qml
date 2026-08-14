pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property int pageIndex: 0
    property int pageCount: 7
    signal previousRequested()
    signal nextRequested()
    signal finishRequested()

    implicitHeight: Math.max(previousButton.implicitHeight, nextButton.implicitHeight, finishButton.implicitHeight)

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.rounding.small

        RippleButtonWithIcon {
            id: previousButton
            visible: root.pageIndex > 0
            implicitWidth: 56
            implicitHeight: 56
            centerContent: true
            materialIcon: "arrow_back"
            mainText: ""
            mainTextWeight: Font.Bold
            mainTextFontFamily: Appearance.font.family.title
            mainTextVariableAxes: Appearance.font.variableAxes.titleRounded
            iconPixelSize: Appearance.font.pixelSize.hugeass + Appearance.rounding.verysmall
            materialIconFill: true
            buttonRadius: Appearance.rounding.full
            colText: Appearance.colors.colOnSecondaryContainer
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colBackgroundActive: Appearance.colors.colSecondaryContainerActive
            colRipple: Appearance.colors.colSecondaryContainerActive
            Accessible.name: Translation.tr("Previous")
            onClicked: root.previousRequested()
        }

        Item {
            Layout.fillWidth: true
        }

        Item {
            id: nextButtonWrapper
            visible: root.pageIndex < root.pageCount - 1
            Layout.preferredWidth: nextButton.implicitWidth
            Layout.preferredHeight: nextButton.implicitHeight
            implicitWidth: nextButton.implicitWidth
            implicitHeight: nextButton.implicitHeight

            RippleButtonWithIcon {
                id: nextButton
                anchors.fill: parent
                implicitWidth: 148
                implicitHeight: 56
                centerContent: true
                iconOnRight: true
                materialIcon: "arrow_forward"
                mainText: Translation.tr("Next")
                mainTextWeight: Font.Bold
                mainTextFontFamily: Appearance.font.family.title
                mainTextVariableAxes: Appearance.font.variableAxes.titleRounded
                textPixelSize: Appearance.font.pixelSize.larger
                iconPixelSize: Appearance.font.pixelSize.hugeass + Appearance.rounding.verysmall
                materialIconFill: true
                buttonRadius: Appearance.rounding.full
                colText: Appearance.colors.colOnPrimary
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colBackgroundActive: Appearance.colors.colPrimaryActive
                colRipple: Appearance.colors.colPrimaryActive
                Accessible.name: Translation.tr("Next")
                onClicked: {
                    nextPageFeedback.restart();
                    root.nextRequested();
                }
            }

            SequentialAnimation {
                id: nextPageFeedback
                NumberAnimation {
                    target: nextButtonWrapper
                    property: "scale"
                    to: 1.04
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
                NumberAnimation {
                    target: nextButtonWrapper
                    property: "scale"
                    to: 1
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        RippleButtonWithIcon {
            id: finishButton
            visible: root.pageIndex === root.pageCount - 1
            implicitWidth: 148
            implicitHeight: 56
            centerContent: true
            iconOnRight: true
            materialIcon: "check"
            mainText: Translation.tr("Finish")
            mainTextWeight: Font.Bold
            mainTextFontFamily: Appearance.font.family.title
            mainTextVariableAxes: Appearance.font.variableAxes.titleRounded
            textPixelSize: Appearance.font.pixelSize.larger
            iconPixelSize: Appearance.font.pixelSize.large
            buttonRadius: Appearance.rounding.full
            colText: Appearance.colors.colOnPrimary
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colBackgroundActive: Appearance.colors.colPrimaryActive
            colRipple: Appearance.colors.colPrimaryActive
            Accessible.name: Translation.tr("Finish")
            onClicked: root.finishRequested()
        }
    }

    onPageIndexChanged: {
        if (root.pageIndex > 0 && root.pageIndex < root.pageCount - 1)
            nextPageFeedback.restart();
    }
}
