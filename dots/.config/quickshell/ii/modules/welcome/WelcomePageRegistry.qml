pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

/**
 * Active Welcome setup pages. Page IDs are stable contracts; page order is
 * presentation metadata and must never be used as identity.
 */
QtObject {
    id: root

    readonly property var pages: [{
        "id": "start",
        "titleKey": "Get connected",
        "subtitleKey": "Connect the essentials before you start. You can change these later.",
        "icon": "waving_hand",
        "component": "WelcomeStartPage.qml"
    }, {
        "id": "personalize",
        "titleKey": "Make it yours",
        "subtitleKey": "Choose a wallpaper and a color scheme.",
        "icon": "palette",
        "component": "WelcomePersonalizePage.qml"
    }, {
        "id": "displays",
        "titleKey": "Set up your displays",
        "subtitleKey": "Arrange the screens you use every day.",
        "icon": "desktop_windows",
        "component": "WelcomeDisplaysPage.qml"
    }, {
        "id": "experience",
        "titleKey": "Choose how II behaves",
        "subtitleKey": "Pick a shell mode and the bar placement that fits your workflow.",
        "icon": "dashboard_customize",
        "component": "WelcomeExperiencePage.qml"
    }, {
        "id": "essentials",
        "titleKey": "Keep the essentials close",
        "subtitleKey": "Learn the shortcuts that make II feel fast.",
        "icon": "keyboard",
        "component": "WelcomeEssentialsPage.qml"
    }, {
        "id": "learn",
        "titleKey": "Learn the useful features",
        "subtitleKey": "Set up only the integrations you plan to use.",
        "icon": "school",
        "component": "WelcomeLearnPage.qml"
    }, {
        "id": "finish",
        "titleKey": "All set!",
        "subtitleKey": "II is ready for you to use.",
        "icon": "check_circle",
        "component": "WelcomeFinishPage.qml"
    }]

    function pageIndexById(id: string): int {
        for (let i = 0; i < root.pages.length; i++) {
            if (root.pages[i].id === id)
                return i;
        }
        return -1;
    }

    function pageById(id: string): var {
        const index = root.pageIndexById(id);
        return index >= 0 ? root.pages[index] : null;
    }

    function titleFor(id: string): string {
        const page = root.pageById(id);
        return page ? Translation.tr(page.titleKey) : "";
    }

    function subtitleFor(id: string): string {
        const page = root.pageById(id);
        return page ? Translation.tr(page.subtitleKey) : "";
    }
}
