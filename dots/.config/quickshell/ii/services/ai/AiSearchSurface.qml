pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services.ai
import qs.modules.common
import qs.modules.common.widgets

/**
 * Inline page host for Search AI.
 *
 * The default child is the chat page. Future pages replace that child in the
 * same surface; they are not popup windows and do not create a second overlay.
 * Fixture pages intentionally stay small until the dedicated model/history/
 * tools commits migrate their real content.
 */
Item {
    id: root

    property AiSearchNavigator navigator: AiSearchNavigator {}
    property bool reducedMotion: false
    property string pageTitle: root.navigator.currentPage
    default property alias contentData: chatPage.data

    implicitWidth: chatPage.implicitWidth
    implicitHeight: chatPage.implicitHeight

    function navigateTo(page) {
        return root.navigator.push(page);
    }

    function replacePage(page) {
        return root.navigator.replace(page);
    }

    function handleEscape() {
        return root.navigator.handleEscape();
    }

    function pageOpacity(page) {
        const target = String(page ?? "");
        if (!root.navigator.transitioning)
            return root.navigator.currentPage === target ? 1 : 0;
        if (root.navigator.incomingPage === target)
            return root.navigator.transitionProgress;
        if (root.navigator.outgoingPage === target)
            return 1 - root.navigator.transitionProgress;
        return 0;
    }

    readonly property string fixturePageId: root.navigator.incomingPage.length > 0 ? root.navigator.incomingPage : root.navigator.currentPage

    Binding {
        target: root.navigator
        property: "reducedMotion"
        value: root.reducedMotion
    }

    Item {
        id: chatPage
        anchors.fill: parent
        visible: root.pageOpacity("chat") > 0
        opacity: root.pageOpacity("chat")
        x: root.navigator.pageOffset("chat") * width
        clip: true

        Behavior on opacity {
            enabled: !root.reducedMotion
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
    }

    Loader {
        id: fixturePage
        anchors.fill: parent
        active: root.navigator.currentPage !== "chat" || root.navigator.incomingPage.length > 0
        visible: active && root.pageOpacity(root.fixturePageId) > 0
        opacity: root.pageOpacity(root.fixturePageId)
        x: root.navigator.pageOffset(root.fixturePageId) * width
        sourceComponent: AiSearchPage {
            pageId: root.fixturePageId
            onRequestBack: root.navigator.back()
        }

        Behavior on opacity {
            enabled: !root.reducedMotion
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
    }
}
