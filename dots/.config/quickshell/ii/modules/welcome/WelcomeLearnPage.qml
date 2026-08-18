import QtQuick
import QtQuick.Effects
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
    property bool tutorialTransitionRunning: false
    property bool tutorialTransitionReady: false
    readonly property bool nestedPageOpen: root.tutorialOpen || root.tutorialTransitionRunning

    readonly property int connectedCount: {
        let count = 0;
        for (const tutorial of WelcomeTutorialRegistry.tutorials) {
            const kind = WelcomeTutorialRegistry.stateKindFor(tutorial);
            if (kind === "ready" || kind === "configured")
                count++;
        }
        return count;
    }
    readonly property int remainingCount: Math.max(0, WelcomeTutorialRegistry.tutorials.length - root.connectedCount)

    function tutorialOffset(): real {
        return WelcomeMotion.offsetFor(root.width);
    }

    function prepareCatalog(): void {
        catalogLayer.visible = true;
        catalogLayer.x = 0;
        catalogLayer.opacity = 1;
        catalogLayer.visualBlur = 0;
        catalogLayer.scale = 1;
    }

    function prepareTutorial(): void {
        tutorialLayer.visible = true;
        tutorialLayer.x = root.tutorialOpen ? tutorialOffset() : 0;
        tutorialLayer.opacity = root.tutorialOpen ? WelcomeMotion.pageOpacityIn : 1;
        tutorialLayer.visualBlur = 0;
        tutorialLayer.scale = root.tutorialOpen ? WelcomeMotion.pageScale : 1;
    }

    function startTutorialOpen(): void {
        if (!root.tutorialOpen || !root.tutorialTransitionReady)
            return;
        tutorialLayer.visualBlur = WelcomeMotion.blurProgress;
        if (!WelcomeMotion.motionEnabled) {
            catalogLayer.visible = false;
            tutorialLayer.x = 0;
            tutorialLayer.opacity = 1;
            tutorialLayer.visualBlur = 0;
            tutorialLayer.scale = 1;
            root.tutorialTransitionRunning = false;
            return;
        }
        openTutorialAnimation.start();
    }

    function openTutorial(tutorialId) {
        const tutorial = WelcomeTutorialRegistry.tutorialFor(tutorialId);
        if (!tutorial || root.tutorialTransitionRunning)
            return;

        openTutorialAnimation.stop();
        closeTutorialAnimation.stop();
        root.selectedTutorial = tutorial;
        root.tutorialOpen = true;
        root.tutorialTransitionRunning = true;
        root.tutorialTransitionReady = false;
        prepareCatalog();
        prepareTutorial();
        root.tutorialLoaderEnabled = true;
    }

    function closeTutorial() {
        if (!root.tutorialOpen || root.tutorialTransitionRunning)
            return;

        openTutorialAnimation.stop();
        closeTutorialAnimation.stop();
        root.tutorialOpen = false;
        root.tutorialTransitionRunning = true;
        root.tutorialTransitionReady = true;
        catalogLayer.visible = true;
        catalogLayer.x = -tutorialOffset();
        catalogLayer.opacity = WelcomeMotion.pageOpacityOut;
        catalogLayer.visualBlur = WelcomeMotion.blurProgress;
        catalogLayer.scale = WelcomeMotion.pageScale;
        tutorialLayer.visible = true;
        tutorialLayer.x = 0;
        tutorialLayer.opacity = 1;
        tutorialLayer.visualBlur = 0;
        tutorialLayer.scale = 1;
        if (!WelcomeMotion.motionEnabled) {
            root.finishTutorialClose();
            return;
        }
        closeTutorialAnimation.start();
    }

    function finishTutorialClose(): void {
        tutorialLayer.visible = false;
        root.tutorialLoaderEnabled = false;
        root.selectedTutorial = null;
        root.tutorialTransitionReady = false;
        root.tutorialTransitionRunning = false;
        prepareCatalog();
    }

    function closeNestedPage() {
        if (!root.tutorialOpen)
            return false;
        root.closeTutorial();
        return true;
    }

    // Keep the catalog itself as the content hero; the global Welcome header
    // already supplies the page title and progress context.
    RowLayout {
        id: catalogLayer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Appearance.rounding.normal
        clip: true

        property real visualBlur: 0
        layer.enabled: visualBlur > 0.01
        layer.effect: MultiEffect {
            blurEnabled: catalogLayer.visualBlur > 0.01
            blurMax: WelcomeMotion.blurMax
            blur: catalogLayer.visualBlur
        }

        WelcomeIntegrationCard {
            id: catalogHero
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 2
            hero: true
            materialIcon: WelcomeTutorialRegistry.tutorials[0].icon
            title: Translation.tr(WelcomeTutorialRegistry.tutorials[0].titleKey)
            description: Translation.tr(WelcomeTutorialRegistry.tutorials[0].descriptionKey)
            usedInChips: WelcomeTutorialRegistry.tutorials[0].usedInChips
            stateText: WelcomeTutorialRegistry.statusTextFor(WelcomeTutorialRegistry.tutorials[0])
            stateKind: WelcomeTutorialRegistry.stateKindFor(WelcomeTutorialRegistry.tutorials[0])
            onActivated: root.openTutorial(WelcomeTutorialRegistry.tutorials[0].id)
        }

        ColumnLayout {
            id: catalogSecondary
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: Appearance.rounding.normal

            Repeater {
                model: WelcomeTutorialRegistry.tutorials.slice(1)

                delegate: WelcomeIntegrationCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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
    }

    Item {
        id: tutorialLayer
        anchors.fill: parent
        visible: false
        clip: true

        property real visualBlur: 0
        layer.enabled: visualBlur > 0.01
        layer.effect: MultiEffect {
            blurEnabled: tutorialLayer.visualBlur > 0.01
            blurMax: WelcomeMotion.blurMax
            blur: tutorialLayer.visualBlur
        }

        Loader {
            id: tutorialLoader
            anchors.fill: parent
            active: root.tutorialLoaderEnabled
                && (root.tutorialOpen || closeTutorialAnimation.running)
            source: root.selectedTutorial ? root.selectedTutorial.component : ""

            onStatusChanged: {
                if (status === Loader.Ready) {
                    root.tutorialTransitionReady = true;
                    root.startTutorialOpen();
                }
            }

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
            to: -root.tutorialOffset()
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
        NumberAnimation {
            target: catalogLayer
            property: "opacity"
            to: WelcomeMotion.pageOpacityOut
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
        NumberAnimation {
            target: catalogLayer
            property: "visualBlur"
            to: WelcomeMotion.blurProgress
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
        NumberAnimation {
            target: tutorialLayer
            property: "visualBlur"
            to: 0
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
        onFinished: {
            catalogLayer.visible = false;
            root.tutorialTransitionRunning = false;
        }
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
            target: catalogLayer
            property: "visualBlur"
            to: 0
            duration: Appearance.animation.elementMoveExit.duration
            easing.type: Appearance.animation.elementMoveExit.type
            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
        }
        NumberAnimation {
            target: tutorialLayer
            property: "x"
            to: root.tutorialOffset()
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
        NumberAnimation {
            target: tutorialLayer
            property: "visualBlur"
            to: WelcomeMotion.blurProgress
            duration: Appearance.animation.elementMoveExit.duration
            easing.type: Appearance.animation.elementMoveExit.type
            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
        }
        onFinished: root.finishTutorialClose()
    }
}
