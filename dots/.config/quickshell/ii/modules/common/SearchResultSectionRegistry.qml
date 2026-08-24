pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/**
 * Catalogue of the result classes the launcher groups by.
 *
 * The presentation of a section and the priority it is shown at used to live as
 * two parallel switch statements inside SearchWidget, which meant the Settings
 * window had no way to name a section, let alone reorder one. They live here so
 * the surface that renders the groups and the surface that lets the user
 * arrange them read the same list.
 *
 * `Config.options.search.sectionOrder` holds the user's arrangement; this is the
 * catalogue behind it, the source of the shipped order, and the fallback for a
 * list that has been emptied out.
 */
Singleton {
    id: root

    readonly property var sections: [
        {
            id: "media",
            title: qsTr("Now playing"),
            icon: "music_note"
        },
        {
            id: "best",
            title: qsTr("Best match"),
            icon: "stars"
        },
        {
            id: "apps",
            title: qsTr("Applications"),
            icon: "apps"
        },
        {
            id: "controls",
            title: qsTr("Controls"),
            icon: "tune"
        },
        {
            id: "tools",
            title: qsTr("Search tools"),
            icon: "widgets"
        },
        {
            id: "actions",
            title: qsTr("Actions & shortcuts"),
            icon: "bolt"
        },
        {
            id: "content",
            title: qsTr("Files, links & text"),
            icon: "link"
        },
        {
            id: "other",
            title: qsTr("More results"),
            icon: "search"
        },
        {
            id: "settings",
            title: qsTr("Settings"),
            icon: "settings"
        },
        {
            id: "files",
            title: qsTr("Files & folders"),
            icon: "folder"
        },
        {
            id: "continue",
            title: qsTr("Continue with"),
            icon: "arrow_forward"
        }
    ]

    readonly property var defaultOrder: root.sections.map(section => section.id)

    function getComponent(id: string): var {
        const wanted = String(id ?? "");
        for (let i = 0; i < root.sections.length; i++) {
            if (root.sections[i].id === wanted)
                return root.sections[i];
        }
        return null;
    }

    function getAvailableComponents(usedIds: var): var {
        const used = Array.from(usedIds ?? []);
        return root.sections.filter(section => used.indexOf(section.id) === -1);
    }

    /**
     * The order the launcher actually renders.
     *
     * A section the user removed from the list is a section whose results are
     * not shown, so the list doubles as the on/off switch. An empty list would
     * mean "no results at all", which is never what someone meant to configure —
     * that falls back to the full catalogue.
     */
    readonly property var activeOrder: {
        const configured = Array.from(Config.options.search.sectionOrder ?? []);
        const order = [];
        for (let i = 0; i < configured.length; i++) {
            const id = String(configured[i]?.id ?? configured[i] ?? "");
            // Ignore ids from a config written by a newer or older build, and
            // ignore duplicates: either would make a section render twice.
            if (id.length > 0 && root.getComponent(id) !== null && order.indexOf(id) === -1)
                order.push(id);
        }
        return order.length > 0 ? order : root.defaultOrder;
    }
}
