import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal openSettingsPage(string pageId)
    signal openSettingsTarget(string pageId, string subPageId, string sectionId)

    property var selectedTutorial: null
    property bool tutorialOpen: false
    property bool tutorialLoaderEnabled: false

    function openTutorial(tutorialId) {
        const tutorial = WelcomeTutorialRegistry.tutorialFor(tutorialId);
        if (!tutorial)
            return;

        openTutorialAnimation.stop();
        closeTutorialAnimation.stop();
        root.selectedTutorial = tutorial;
        root.tutorialOpen = true;
        catalogLayer.visible = true;
        catalogLayer.x = 0;
        catalogLayer.opacity = 1;
        tutorialLayer.visible = true;
        tutorialLayer.x = root.width;
        tutorialLayer.opacity = 0;
        root.tutorialLoaderEnabled = true;
        openTutorialAnimation.start();
    }

    function closeTutorial() {
        if (!root.tutorialOpen)
            return;

        openTutorialAnimation.stop();
        closeTutorialAnimation.stop();
        root.tutorialOpen = false;
        catalogLayer.visible = true;
        catalogLayer.x = -root.width;
        catalogLayer.opacity = 0;
        tutorialLayer.visible = true;
        tutorialLayer.x = 0;
        tutorialLayer.opacity = 1;
        closeTutorialAnimation.start();
    }

    function closeNestedPage() {
        if (!root.tutorialOpen)
            return false;
        root.closeTutorial();
        return true;
    }

    // Main Catalog View (Compact 2x2 Grid)
    Item {
        id: catalogLayer
        anchors.fill: parent
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 760 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: WelcomeTutorialRegistry.tutorials

                    delegate: WelcomeIntegrationCard {
                        required property var modelData
                        Layout.fillWidth: true
                        materialIcon: modelData.icon
                        title: Translation.tr(modelData.titleKey)
                        description: Translation.tr(modelData.descriptionKey)
                        usedInChips: modelData.usedInChips
                        stateText: WelcomeTutorialRegistry.statusTextFor(modelData)
                        stateKind: WelcomeTutorialRegistry.stateKindFor(modelData)
                        onActivated: root.openTutorial(modelData.id)
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // Active Tutorial Subpage View
    Item {
        id: tutorialLayer
        anchors.fill: parent
        visible: false
        clip: true

        Loader {
            id: tutorialLoader
            anchors.fill: parent
            active: root.tutorialLoaderEnabled
                && (root.tutorialOpen || closeTutorialAnimation.running)
            source: root.selectedTutorial ? root.selectedTutorial.component : ""

            Connections {
                target: tutorialLoader.item
                ignoreUnknownSignals: true

                function onBackRequested() {
                    root.closeTutorial();
                }

                function onOpenSettingsTarget(pageId, subPageId, sectionId) {
                    root.openSettingsTarget(pageId, subPageId, sectionId);
                }
            }
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
            root.tutorialLoaderEnabled = false;
            root.selectedTutorial = null;
        }
    }
}
