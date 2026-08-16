pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
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
        sourceComponent: Component {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 10

                MaterialShape {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Appearance.colors.colLayer1
                    shape: MaterialShape.Shape.SoftBoom

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 8

                        MaterialSymbol {
                            text: "auto_awesome"
                            iconSize: Appearance.font.pixelSize.huge
                            color: Appearance.m3colors.m3primary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.fixturePageId.length > 0 ? root.fixturePageId : Translation.tr("AI Search")
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("This page is ready for the next AI Search surface.")
                            wrapMode: Text.Wrap
                            color: Appearance.colors.colSubtext
                        }

                        Item { Layout.fillHeight: true }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Esc to go back")
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        Behavior on opacity {
            enabled: !root.reducedMotion
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
    }
}
