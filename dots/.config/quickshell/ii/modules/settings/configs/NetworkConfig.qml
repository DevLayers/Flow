import QtQuick
import qs
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

    /**
     * The wired tab is only built where there is a socket to talk about, so the
     * list is computed rather than fixed. Changing it rebuilds every tab
     * delegate, which is why the port is appended last: unplugging a USB
     * adapter must not renumber the three tabs that are always there.
     */
    readonly property var tabs: NetworkState.hasWiredDevice
        ? [...root.baseTabs, root.wiredTab] : root.baseTabs

    readonly property var baseTabs: [
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
        },
        {
            "source": "network/HotspotTab.qml",
            "icon": "wifi_tethering",
            "name": Translation.tr("Hotspot"),
            "sections": [Translation.tr("Hotspot"), Translation.tr("Access point"),
                Translation.tr("Connected devices")]
        }
    ]

    readonly property var wiredTab: ({
        "source": "network/WiredTab.qml",
        "icon": "settings_ethernet",
        "name": Translation.tr("Wired"),
        "sections": [Translation.tr("Ethernet ports"), Translation.tr("Saved connections"),
            Translation.tr("Addressing")]
    })

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
                root.selectTab(i);
                return;
            }
        }
    }

    /**
     * The tab that is actually wanted.
     *
     * The bar's own index cannot be trusted to hold it: the tab list is
     * recomputed whenever a translation or the wired device changes, every
     * button is rebuilt with it, and a rebuilt TabBar comes back pointing at the
     * button added last — which is why this page kept opening on Hotspot. Only a
     * deliberate pick is recorded here, and the bar is put back whenever it drifts.
     */
    property int wantedTab: 0

    function selectTab(index: int): void {
        if (index < 0 || index >= root.tabs.length)
            return;
        root.wantedTab = index;
        GlobalStates.settingsNetworkTab = index;
        tabBar.currentIndex = index;
    }

    function restoreWantedTab(): void {
        if (root.wantedTab >= root.tabs.length)
            root.wantedTab = 0;
        if (tabBar.currentIndex !== root.wantedTab)
            tabBar.currentIndex = root.wantedTab;
    }

    onContentYChanged: {
        const page = root.currentPage;
        if (page && page.contentY !== undefined)
            page.contentY = root.contentY;
    }
    onCurrentSearchChanged: root.focusSectionTab(root.currentSearch)

    // Come back to the tab this page was left on, but let a deep link or a
    // search hit override it — those name a section and mean to go there.
    Component.onCompleted: {
        const remembered = GlobalStates.settingsNetworkTab;
        root.selectTab(remembered >= 0 && remembered < root.tabs.length ? remembered : 0);
        root.focusSectionTab(SearchRegistry.currentSearch);
    }

    onCurrentTabChanged: {
        if (root.currentTab === root.wantedTab)
            return;
        Qt.callLater(root.restoreWantedTab);
    }
    onTabsChanged: Qt.callLater(root.restoreWantedTab)

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
                required property int index

                buttonText: modelData.name
                buttonIcon: modelData.icon
                // A click is the one thing that genuinely means "go here", so
                // it is recorded rather than read back off the bar afterwards.
                onClicked: root.selectTab(index)
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
