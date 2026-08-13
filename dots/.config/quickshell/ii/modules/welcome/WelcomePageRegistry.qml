pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

/**
 * Active Welcome MVP pages. Page IDs are stable contracts; page order is only
 * presentation metadata and must never be used as identity.
 */
QtObject {
    id: root

    readonly property var pages: [{
        "id": "start",
        "titleKey": "Welcome to illogical-impulse",
        "subtitleKey": "Connect the essentials first. Everything here is optional.",
        "icon": "waving_hand",
        "component": "WelcomeStartPage.qml"
    }, {
        "id": "experience",
        "titleKey": "Choose your shell experience",
        "subtitleKey": "Pick the layout that feels right for your workflow.",
        "icon": "dashboard_customize",
        "component": "WelcomeExperiencePage.qml"
    }, {
        "id": "personalize",
        "titleKey": "Make it yours",
        "subtitleKey": "Tune colors, wallpaper and the way your desktop feels.",
        "icon": "palette",
        "component": "WelcomePersonalizePage.qml"
    }, {
        "id": "essentials",
        "titleKey": "Keep the essentials close",
        "subtitleKey": "Shortcuts and useful places for everyday work.",
        "icon": "keyboard",
        "component": "WelcomeEssentialsPage.qml"
    }, {
        "id": "learn",
        "titleKey": "Learn the useful features",
        "subtitleKey": "Optional guides for the integrations you want to use.",
        "icon": "school",
        "component": "WelcomeLearnPage.qml"
    }, {
        "id": "diagnostics",
        "titleKey": "Check that everything is ready",
        "subtitleKey": "A quick health check before you get started.",
        "icon": "health_and_safety",
        "component": "WelcomeDiagnosticsPage.qml"
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
