pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
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
        "headerShape": MaterialShape.Shape.Cookie9Sided,
        "accentRole": "primary",
        "nextLabelKey": "Continue",
        "nextIcon": "arrow_forward",
        "component": "WelcomeStartPage.qml"
    }, {
        "id": "personalize",
        "titleKey": "Make it yours",
        "subtitleKey": "Choose a wallpaper and a color scheme.",
        "icon": "palette",
        "headerShape": MaterialShape.Shape.SoftBurst,
        "accentRole": "secondary",
        "nextLabelKey": "Set up displays",
        "nextIcon": "desktop_windows",
        "component": "WelcomePersonalizePage.qml"
    }, {
        "id": "displays",
        "titleKey": "Set up your displays",
        "subtitleKey": "Arrange the screens you use every day.",
        "icon": "desktop_windows",
        "headerShape": MaterialShape.Shape.Cookie7Sided,
        "accentRole": "tertiary",
        "nextLabelKey": "Choose your experience",
        "nextIcon": "dashboard_customize",
        "component": "WelcomeDisplaysPage.qml"
    }, {
        "id": "experience",
        "titleKey": "Choose how II behaves",
        "subtitleKey": "Pick a shell mode and the bar placement that fits your workflow.",
        "icon": "dashboard_customize",
        "headerShape": MaterialShape.Shape.Sunny,
        "accentRole": "primary",
        "nextLabelKey": "See the essentials",
        "nextIcon": "keyboard",
        "component": "WelcomeExperiencePage.qml"
    }, {
        "id": "essentials",
        "titleKey": "Keep the essentials close",
        "subtitleKey": "Set up keyboard, language and time preferences, then learn the shortcuts that make II feel fast.",
        "icon": "keyboard",
        "headerShape": MaterialShape.Shape.Clover4Leaf,
        "accentRole": "secondary",
        "nextLabelKey": "Explore tutorials",
        "nextIcon": "school",
        "component": "WelcomeEssentialsPage.qml"
    }, {
        "id": "learn",
        "titleKey": "Learn the useful features",
        "subtitleKey": "Set up only the integrations you plan to use.",
        "icon": "school",
        "headerShape": MaterialShape.Shape.Flower,
        "accentRole": "tertiary",
        "nextLabelKey": "Finish setup",
        "nextIcon": "check",
        "component": "WelcomeLearnPage.qml"
    }, {
        "id": "finish",
        "titleKey": "All set!",
        "subtitleKey": "II is ready for you to use.",
        "icon": "check_circle",
        "headerShape": MaterialShape.Shape.SoftBurst,
        "accentRole": "primary",
        "nextLabelKey": "Start using II",
        "nextIcon": "arrow_forward",
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

    function headerShapeFor(id: string): var {
        const page = root.pageById(id);
        return page ? page.headerShape : MaterialShape.Shape.Cookie9Sided;
    }

    function nextLabelFor(id: string): string {
        const page = root.pageById(id);
        return page ? Translation.tr(page.nextLabelKey) : Translation.tr("Continue");
    }

    function nextIconFor(id: string): string {
        const page = root.pageById(id);
        return page ? page.nextIcon : "arrow_forward";
    }
}
