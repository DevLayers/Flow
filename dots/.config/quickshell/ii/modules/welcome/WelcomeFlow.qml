pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common

Item {
    id: root

    property string currentPageId: "start"
    property string previousPageId: ""
    property string incomingPageId: ""
    property string outgoingPageId: ""
    property int transitionDirection: 1
    property bool transitionRunning: false
    property real navigationSafeArea: 84

    readonly property real transitionOffset: Math.max(72, Math.min(144, width * 0.12))

    readonly property bool nestedPageOpen: {
        if (root.currentPageId !== "learn")
            return false;
        const learnLoader = root.loaderForPage("learn");
        return (learnLoader && learnLoader.item && learnLoader.item.tutorialOpen) === true;
    }

    signal pageChanged(string pageId)
    signal openSettingsPage(string pageId)
    signal openSettingsTarget(string pageId, string subPageId, string sectionId)
    signal openWifi()
    signal openBluetooth()
    signal openAudioOutput()
    signal trySidebar()
    signal trySearch()

    clip: true

    function pageIndex(pageId) {
        return WelcomePageRegistry.pageIndexById(pageId);
    }

    function loaderForPage(pageId) {
        const index = root.pageIndex(pageId);
        return index >= 0 ? pageLoaders.itemAt(index) : null;
    }

    function normalizePages() {
        for (let i = 0; i < pageLoaders.count; i++) {
            const pageLoader = pageLoaders.itemAt(i);
            if (!pageLoader)
                continue;
            const active = pageLoader.pageId === root.currentPageId;
            pageLoader.visualX = 0;
            pageLoader.visualOpacity = active ? 1 : 0;
            pageLoader.visualVisible = active;
            pageLoader.visualEnabled = active;
        }
        root.incomingPageId = "";
        root.outgoingPageId = "";
        root.transitionRunning = false;
    }

    function reset() {
        transitionAnimation.stop();
        root.currentPageId = "start";
        root.previousPageId = "";
        Qt.callLater(root.normalizePages);
    }

    function maybeStartTransition(pageLoader) {
        if (!root.transitionRunning || !pageLoader || pageLoader.pageId !== root.incomingPageId)
            return;
        if (pageLoader.status !== Loader.Ready)
            return;
        transitionAnimation.start();
    }

    function goToPage(pageId) {
        if (!pageId || pageId === root.currentPageId || root.pageIndex(pageId) < 0)
            return;

        if (transitionAnimation.running) {
            transitionAnimation.stop();
            root.normalizePages();
        }

        const fromIndex = root.pageIndex(root.currentPageId);
        const toIndex = root.pageIndex(pageId);
        root.previousPageId = root.currentPageId;
        root.transitionDirection = toIndex >= fromIndex ? 1 : -1;
        root.outgoingPageId = root.currentPageId;
        root.incomingPageId = pageId;
        root.transitionRunning = true;

        const outgoing = root.loaderForPage(root.outgoingPageId);
        const incoming = root.loaderForPage(root.incomingPageId);
        if (!outgoing || !incoming) {
            root.currentPageId = pageId;
            root.normalizePages();
            root.pageChanged(pageId);
            return;
        }

        outgoing.visualX = 0;
        outgoing.visualOpacity = 1;
        outgoing.visualVisible = true;
        outgoing.visualEnabled = false;

        incoming.visualX = root.transitionDirection > 0 ? root.transitionOffset : -root.transitionOffset;
        incoming.visualOpacity = 0;
        incoming.visualVisible = true;
        incoming.visualEnabled = false;

        root.currentPageId = pageId;
        if (incoming.status === Loader.Error) {
            root.normalizePages();
            root.pageChanged(pageId);
            return;
        }
        if (incoming.status === Loader.Ready)
            Qt.callLater(() => root.maybeStartTransition(incoming));
    }

    function goPrevious() {
        const index = root.pageIndex(root.currentPageId);
        if (index > 0)
            root.goToPage(WelcomePageRegistry.pages[index - 1].id);
    }

    function goNext() {
        const index = root.pageIndex(root.currentPageId);
        if (index >= 0 && index < WelcomePageRegistry.pages.length - 1)
            root.goToPage(WelcomePageRegistry.pages[index + 1].id);
    }

    function closeNestedPage(): bool {
        if (root.currentPageId !== "learn")
            return false;
        const learnLoader = root.loaderForPage("learn");
        const learnPage = learnLoader && learnLoader.item ? learnLoader.item : null;
        return learnPage && learnPage.closeNestedPage
            ? learnPage.closeNestedPage()
            : false;
    }

    function openTutorial(tutorialId: string): void {
        if (!tutorialId)
            return;
        if (root.currentPageId !== "learn") {
            root.goToPage("learn");
            Qt.callLater(() => root.openTutorial(tutorialId));
            return;
        }
        const learnLoader = root.loaderForPage("learn");
        const learnPage = learnLoader && learnLoader.item ? learnLoader.item : null;
        if (learnPage && learnPage.openTutorial)
            learnPage.openTutorial(tutorialId);
    }

    Repeater {
        id: pageLoaders
        model: WelcomePageRegistry.pages

        delegate: Loader {
            id: pageLoader
            required property var modelData
            required property int index

            readonly property string pageId: modelData.id
            property real visualX: 0
            property real visualOpacity: 0
            property bool visualVisible: false
            property bool visualEnabled: false

            width: root.width
            height: Math.max(0, root.height - (root.nestedPageOpen ? 0 : root.navigationSafeArea))
            x: visualX
            opacity: visualOpacity
            visible: visualVisible
            enabled: visualEnabled
            active: root.currentPageId === pageId
                || root.incomingPageId === pageId
                || root.outgoingPageId === pageId
            asynchronous: true
            source: Qt.resolvedUrl(modelData.component)

            onLoaded: root.maybeStartTransition(pageLoader)

            Connections {
                target: pageLoader.item
                ignoreUnknownSignals: true

                function onOpenSettingsPage(pageId) {
                    root.openSettingsPage(pageId);
                }

                function onOpenSettingsTarget(pageId, subPageId, sectionId) {
                    root.openSettingsTarget(pageId, subPageId, sectionId);
                }

                function onOpenTutorial(tutorialId) {
                    root.openTutorial(tutorialId);
                }

                function onOpenWifi() {
                    root.openWifi();
                }

                function onOpenBluetooth() {
                    root.openBluetooth();
                }

                function onOpenAudioOutput() {
                    root.openAudioOutput();
                }

                function onTrySidebar() {
                    root.trySidebar();
                }

                function onTrySearch() {
                    root.trySearch();
                }
            }
        }
    }

    ParallelAnimation {
        id: transitionAnimation

        NumberAnimation {
            target: root.loaderForPage(root.outgoingPageId)
            property: "visualX"
            to: root.transitionDirection > 0 ? -root.transitionOffset : root.transitionOffset
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }

        NumberAnimation {
            target: root.loaderForPage(root.outgoingPageId)
            property: "visualOpacity"
            to: 0
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }

        NumberAnimation {
            target: root.loaderForPage(root.incomingPageId)
            property: "visualX"
            to: 0
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }

        NumberAnimation {
            target: root.loaderForPage(root.incomingPageId)
            property: "visualOpacity"
            to: 1
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }

        onFinished: {
            const completedPage = root.incomingPageId;
            root.normalizePages();
            root.pageChanged(completedPage);
        }
    }

    Component.onCompleted: root.reset()
}
