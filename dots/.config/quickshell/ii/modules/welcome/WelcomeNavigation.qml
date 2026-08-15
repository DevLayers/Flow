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
    property bool transitionRunning: false
    readonly property bool nextButtonHovered: primaryButton.hovered
    signal previousRequested()
    signal nextRequested()
    signal finishRequested()

    implicitHeight: Math.max(previousButtonWrapper.implicitHeight, nextButtonWrapper.implicitHeight)

    RowLayout {
        anchors.fill: parent
        spacing: Appearance.rounding.small

        Item {
            id: previousButtonWrapper
            property real targetWidth: root.pageIndex > 0 ? 56 : 0
            property real animatedWidth: targetWidth
            visible: animatedWidth > 0.5 || opacity > 0.01
            opacity: root.pageIndex > 0 ? 1 : 0
            clip: true

            Layout.preferredWidth: animatedWidth
            Layout.preferredHeight: 56
            implicitWidth: animatedWidth
            implicitHeight: 56

            Behavior on animatedWidth {
                enabled: WelcomeMotion.motionEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Behavior on opacity {
                enabled: WelcomeMotion.motionEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            RippleButtonWithIcon {
                id: previousButton
                anchors.fill: parent
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
                onClicked: if (!root.transitionRunning) root.previousRequested()
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Item {
            id: nextButtonWrapper
            property real targetWidth: primaryButton.implicitWidth
            property real animatedWidth: targetWidth

            Layout.preferredWidth: animatedWidth
            Layout.preferredHeight: primaryButton.implicitHeight
            implicitWidth: animatedWidth
            implicitHeight: primaryButton.implicitHeight

            Behavior on animatedWidth {
                enabled: WelcomeMotion.motionEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            RippleButtonWithIcon {
                id: primaryButton
                anchors.fill: parent
                implicitWidth: Math.max(148, contentImplicitWidth + 34)
                implicitHeight: 56
                centerContent: true
                iconOnRight: true
                materialIcon: WelcomePageRegistry.nextIconFor(WelcomePageRegistry.pages[root.pageIndex]?.id || "start")
                hoverMaterialIcon: root.pageIndex > 0 && root.pageIndex < root.pageCount - 1
                    ? "arrow_forward" : ""
                mainText: WelcomePageRegistry.nextLabelFor(WelcomePageRegistry.pages[root.pageIndex]?.id || "start")
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
                Accessible.name: mainText
                onClicked: {
                    if (!root.transitionRunning) {
                        hoverIconSuppressed = true;
                        if (root.pageIndex >= root.pageCount - 1)
                            root.finishRequested();
                        else
                            root.nextRequested();
                    }
                }
                onHoveredChanged: {
                    if (!hovered)
                        hoverIconSuppressed = false;
                }
            }
        }
    }

    Connections {
        target: root

        function onTransitionRunningChanged() {
            if (root.transitionRunning)
                primaryButton.hoverIconSuppressed = true;
        }
    }
}
