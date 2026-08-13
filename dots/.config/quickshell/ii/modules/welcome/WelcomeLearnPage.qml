import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal openSettingsPage(string pageId)

    // Exposed for WelcomeFlow's Escape priority: a tutorial is an internal
    // overlay of the Learn stage, so Escape should return to this catalog
    // before closing the Welcome window itself.

    property var selectedTutorial: null
    property bool tutorialOpen: false

    function openTutorial(tutorialId: string): void {
        const tutorial = WelcomeTutorialRegistry.tutorialFor(tutorialId);
        if (!tutorial)
            return;

        openTutorialAnimation.stop();
        closeTutorialAnimation.stop();
        root.selectedTutorial = tutorial;
        catalogLayer.visible = true;
        tutorialLayer.visible = true;
        catalogLayer.x = 0;
        catalogLayer.opacity = 1;
        tutorialLayer.x = root.width;
        tutorialLayer.opacity = 0;
        root.tutorialOpen = true;
        openTutorialAnimation.start();
    }

    function closeTutorial(): void {
        if (!root.tutorialOpen)
            return;

        openTutorialAnimation.stop();
        closeTutorialAnimation.stop();
        catalogLayer.visible = true;
        tutorialLayer.visible = true;
        catalogLayer.x = -root.width;
        catalogLayer.opacity = 0;
        tutorialLayer.x = 0;
        tutorialLayer.opacity = 1;
        root.tutorialOpen = false;
        closeTutorialAnimation.start();
    }

    function closeNestedPage(): bool {
        if (!root.tutorialOpen)
            return false;
        root.closeTutorial();
        return true;
    }

    Item {
        id: catalogLayer
        anchors.fill: parent
        visible: true
        clip: true

        ContentPage {
            anchors.fill: parent
            bottomContentPadding: 28

            ContentSection {
                Layout.fillWidth: true
                icon: "school"
                title: Translation.tr("Optional integrations")

                NoticeBox {
                    Layout.fillWidth: true
                    materialIcon: "info"
                    text: Translation.tr("Pick a guide when you are ready. Welcome only reads each service's current state; setup remains in the existing Settings pages.")
                }
            }

            ContentSection {
                Layout.fillWidth: true
                icon: "menu_book"
                title: Translation.tr("Learn and connect")

                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 820 ? 2 : 1
                    columnSpacing: 12
                    rowSpacing: 12

                    Repeater {
                        model: WelcomeTutorialRegistry.tutorials
                        delegate: WelcomeActionCard {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 132
                            materialIcon: modelData.icon
                            title: Translation.tr(modelData.titleKey)
                            description: Translation.tr(modelData.descriptionKey)
                            statusText: WelcomeTutorialRegistry.estimatedTimeFor(modelData)
                                + " · " + WelcomeTutorialRegistry.statusTextFor(modelData)
                                + " · " + WelcomeTutorialRegistry.actionTextFor(modelData)
                            selected: WelcomeTutorialRegistry.stateFor(modelData).usable
                            onClicked: root.openTutorial(modelData.id)
                        }
                    }
                }
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "settings"
                mainText: Translation.tr("Open Accounts & feature settings")
                onClicked: root.openSettingsPage("tasksAccounts")
            }

            WelcomeActionCard {
                Layout.fillWidth: true
                visible: WelcomeProjectLinks.documentationAvailable
                materialIcon: "help_center"
                title: Translation.tr("Project documentation")
                description: Translation.tr("Read the complete reference when you want more detail.")
                onClicked: Qt.openUrlExternally(WelcomeProjectLinks.documentationUrl)
            }
        }
    }

    Item {
        id: tutorialLayer
        anchors.fill: parent
        visible: false
        clip: true

        WelcomeTutorialPage {
            anchors.fill: parent
            tutorial: root.selectedTutorial
            onBackRequested: root.closeTutorial()
            onOpenSettingsPage: pageId => root.openSettingsPage(pageId)
        }
    }

    ParallelAnimation {
        id: openTutorialAnimation

        NumberAnimation {
            target: catalogLayer
            property: "x"
            to: -root.width
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
        NumberAnimation {
            target: catalogLayer
            property: "opacity"
            to: 0
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
        NumberAnimation {
            target: tutorialLayer
            property: "x"
            to: 0
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
        NumberAnimation {
            target: tutorialLayer
            property: "opacity"
            to: 1
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
        onFinished: catalogLayer.visible = false
    }

    ParallelAnimation {
        id: closeTutorialAnimation

        NumberAnimation {
            target: catalogLayer
            property: "x"
            to: 0
            duration: Appearance.animation.elementMoveExit.duration
            easing.type: Appearance.animation.elementMoveExit.type
            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
        }
        NumberAnimation {
            target: catalogLayer
            property: "opacity"
            to: 1
            duration: Appearance.animation.elementMoveExit.duration
            easing.type: Appearance.animation.elementMoveExit.type
            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
        }
        NumberAnimation {
            target: tutorialLayer
            property: "x"
            to: root.width
            duration: Appearance.animation.elementMoveExit.duration
            easing.type: Appearance.animation.elementMoveExit.type
            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
        }
        NumberAnimation {
            target: tutorialLayer
            property: "opacity"
            to: 0
            duration: Appearance.animation.elementMoveExit.duration
            easing.type: Appearance.animation.elementMoveExit.type
            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
        }
        onFinished: {
            tutorialLayer.visible = false;
            root.selectedTutorial = null;
        }
    }
}
