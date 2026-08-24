import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Wi-Fi, Bluetooth, hotspot and wired settings, on one page.
 *
 * Each tab lives in its own file under configs/network/ and is built only
 * while it is the visible tab. Those files are indexed for search through the
 * page's `searchSources`, so a hit inside a tab that isn't open still arrives
 * here — `focusSectionTab` then brings the tab that owns the section forward.
 */
Item {
    id: root
    anchors.fill: parent

    property alias activeSubPage: subPageOverlay.activeSubPage
    property alias currentTab: tabBar.currentIndex

    // How the settings window restores a page's scroll position.
    property real contentY: 0

    readonly property var tabs: [
        {
            "source": "network/WifiTab.qml",
            "icon": "wifi",
            "name": Translation.tr("Wi-Fi"),
            "sections": [Translation.tr("Wi-Fi"), Translation.tr("Available networks"),
                Translation.tr("Saved networks"), Translation.tr("Hidden network"),
                Translation.tr("Connection details")]
        },
        {
            "source": "network/BluetoothTab.qml",
            "icon": "bluetooth",
            "name": Translation.tr("Bluetooth"),
            "sections": [Translation.tr("Bluetooth"), Translation.tr("Pairing"),
                Translation.tr("Paired devices"), Translation.tr("Nearby devices")]
        }
    ]

    readonly property Item currentPage: tabHost.currentPage

    readonly property string currentSearch: SearchRegistry.currentSearch

    // A search result or a deep link only names a section. Bring the tab that
    // owns it forward, or the highlight plays out on a page nobody can see.
    function focusSectionTab(title: string): void {
        if (!title || title.length === 0)
            return;
        const needle = title.toLowerCase();
        for (let i = 0; i < root.tabs.length; i++) {
            if (root.tabs[i].sections.some(section => section.toLowerCase() === needle)) {
                root.currentTab = i;
                return;
            }
        }
    }

    onContentYChanged: {
        const page = root.currentPage;
        if (page && page.contentY !== undefined)
            page.contentY = root.contentY;
    }
    onCurrentSearchChanged: root.focusSectionTab(root.currentSearch)
    Component.onCompleted: root.focusSectionTab(SearchRegistry.currentSearch)

    SecondaryTabBar {
        id: tabBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        visible: root.tabs.length > 1
        height: tabBar.visible ? tabBar.implicitHeight : 0
        opacity: subPageOverlay.slideProgress

        Repeater {
            model: root.tabs

            delegate: SecondaryTabButton {
                required property var modelData

                buttonText: modelData.name
                buttonIcon: modelData.icon
            }
        }
    }

    Item {
        id: tabHost

        // Set by whichever tab last finished loading. A binding through
        // Repeater.itemAt() cannot work here: it is a function call, so it
        // never re-runs when the delegate it would have returned appears.
        property Item currentPage: null

        anchors {
            top: tabBar.bottom
            topMargin: tabBar.visible ? 8 : 0
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        opacity: subPageOverlay.slideProgress
        visible: opacity > 0

        Repeater {
            id: tabRepeater
            model: root.tabs

            delegate: Loader {
                id: tabLoader
                required property var modelData
                required property int index

                anchors.fill: parent
                active: root.currentTab === index
                asynchronous: true
                source: Qt.resolvedUrl(modelData.source)
                onItemChanged: if (item) tabHost.currentPage = item

                // A tab is unloaded as soon as another one is picked, so the
                // sub-pages it opens have to be owned by this page instead.
                Connections {
                    target: tabLoader.item
                    ignoreUnknownSignals: true

                    function onOpenSubPage(page): void {
                        root.activeSubPage = page;
                    }
                }
            }
        }
    }

    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }
}
