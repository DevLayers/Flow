#!/usr/bin/env python3
"""Regression contracts for the Raycast-style Overview Search architecture."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def source(path):
    return (ROOT / path).read_text(encoding="utf-8")


class SearchRaycastContractTests(unittest.TestCase):
    def test_registry_is_the_single_catalog_for_hosted_panels(self):
        registry = source("modules/common/SearchPanelRegistry.qml")
        for panel_id in ("calendar", "tasks", "timers", "emojis", "screenshots", "windows", "settings", "keybinds", "commands", "gmail", "sports"):
            self.assertIn('id: "' + panel_id + '"', registry)
        self.assertGreaterEqual(registry.count("hosted: true"), 11)

    def test_hosted_panel_uses_the_single_results_surface(self):
        widget = source("modules/ii/overview/SearchWidget.qml")
        self.assertIn("SearchPanelHost", widget)
        self.assertIn("activePanelUsesHost", widget)
        self.assertIn("Appearance.sizes.elevationMargin", widget)

    def test_hosted_panels_share_insets_without_repeated_chrome(self):
        scaffold = source("modules/ii/overview/SearchPanelScaffold.qml")
        self.assertIn("property bool showHeader: false", scaffold)
        self.assertIn("property bool showStatus: false", scaffold)
        self.assertIn("anchors.margins: root.contentMargin", scaffold)

        for panel in (
            "CalendarPanel.qml", "TasksPanel.qml", "TimersPanel.qml",
            "EmojiPanel.qml", "ScreenshotsPanel.qml",
            "WindowManagementPanel.qml", "SettingsTogglesPanel.qml",
            "KeybindsPanel.qml", "CommandsPanel.qml", "GmailPanel.qml",
            "SportsPanel.qml",
        ):
            self.assertIn(
                "SearchPanelScaffold",
                source("modules/ii/overview/" + panel),
            )

    def test_hosted_panel_geometry_and_overview_visibility_are_shared(self):
        config = source("modules/common/Config.qml")
        registry = source("modules/common/SearchPanelRegistry.qml")
        scaffold = source("modules/ii/overview/SearchPanelScaffold.qml")
        overview = source("modules/ii/overview/Overview.qml")
        self.assertIn("property int panelWidth: 860", config)
        self.assertIn("property int panelBodyHeight: 420", config)
        self.assertGreaterEqual(registry.count("Config.options.search.appearance.panelWidth"), 11)
        self.assertIn("minimumContentHeight", scaffold)
        self.assertIn("searchWidget?.isAnySpecialMode", overview)

    def test_hosted_panel_back_navigation_precedes_overview_close(self):
        search_bar = source("modules/ii/overview/SearchBar.qml")
        widget = source("modules/ii/overview/SearchWidget.qml")
        self.assertIn("activePanelQueryEmpty", search_bar)
        self.assertIn("function exitActivePanel(): bool", widget)
        self.assertIn("return root.exitActivePanel()", widget)
        self.assertIn("activePanelMode: root.isAnySpecialMode", widget)

    def test_window_and_screenshot_panels_keep_real_context(self):
        states = source("GlobalStates.qml")
        screenshots = source("modules/ii/overview/ScreenshotsPanel.qml")
        self.assertIn("ToplevelManager.activeToplevel?.HyprlandToplevel?.address", states)
        self.assertNotIn("HyprlandData.activeWindow?.address", states)
        self.assertIn("function imageTitle(entry)", screenshots)
        self.assertIn("function imageMetadata(entry)", screenshots)
        self.assertIn("GlobalStates.overviewOpen = false", screenshots)

    def test_emoji_index_and_launcher_pages_avoid_known_runtime_regressions(self):
        emojis = source("services/Emojis.qml")
        self.assertIn("if (root.loaded || root.loading)", emojis)
        self.assertIn("entriesPrepared", emojis)
        self.assertIn("preparationTimer", emojis)
        self.assertIn("function ensurePrepared(): void", emojis)
        list_change = emojis.split("onListChanged:", 1)[1].split("function ensurePrepared", 1)[0]
        self.assertNotIn("preparationTimer.restart()", list_change)

        emoji_panel = source("modules/ii/overview/EmojiPanel.qml")
        self.assertIn("StyledComboBox", emoji_panel)
        self.assertIn("GridView", emoji_panel)
        self.assertIn("showStatus: true", emoji_panel)

        launcher_files = (
            "modules/settings/configs/LauncherConfig.qml",
            "modules/settings/configs/widgets/LauncherModulesConfig.qml",
            "modules/settings/configs/widgets/LauncherQuicklinksConfig.qml",
            "modules/settings/configs/widgets/LauncherSnippetsConfig.qml",
            "modules/settings/configs/widgets/LauncherShortcutsConfig.qml",
            "modules/settings/configs/widgets/LauncherAppearanceConfig.qml",
        )
        for path in launcher_files:
            content = source(path)
            self.assertIn("import qs.services", content)
            self.assertNotIn("Appearance.sizes.normalIcon", content)

    def test_launcher_producers_are_local_and_guarded(self):
        launcher = source("services/LauncherSearch.qml")
        for function in ("favoriteResults", "snippetMatches", "processMatches", "generatorEntries", "modeMatches", "bluetoothMatches", "fallbackResults"):
            self.assertIn("function " + function, launcher)
        self.assertIn("processConfirmKey", launcher)
        self.assertIn("_scheduleResultsUpdate", launcher)
        self.assertNotIn("XmlHttpRequest", launcher)
        self.assertIn('const genericTerms = ["generator"', launcher)
        self.assertIn("Config.options.search.modules.systemControls", launcher)

    def test_daily_sports_and_timer_panels_have_stable_empty_surfaces(self):
        sports_service = source("services/SportsService.qml")
        sports_panel = source("modules/ii/overview/SportsPanel.qml")
        timers = source("modules/ii/overview/TimersPanel.qml")
        self.assertIn("function fetchSearchGamesForToday()", sports_service)
        self.assertIn("function searchLeagueEntries()", sports_service)
        self.assertIn("scoreboard?dates=${date}", sports_service)
        self.assertIn("property var searchGames", sports_service)
        self.assertIn("property bool enabled: barEnabled || dockEnabled || lockEnabled", sports_service)
        self.assertIn('Translation.tr("No games today")', sports_panel)
        self.assertIn("height: parent.height", sports_panel)
        self.assertIn("function navigateUp(): bool", timers)
        self.assertIn("function navigateDown(): bool", timers)
        self.assertIn("function secondaryActivateSelected(): bool", timers)
        self.assertIn("property int displayClockTick", timers)

    def test_screenshot_preview_uses_the_working_clipboard_wrapper(self):
        screenshots = source("modules/ii/overview/ScreenshotsPanel.qml")
        self.assertIn("sourceComponent: Rectangle", screenshots)
        self.assertIn("CliphistImage", screenshots)
        self.assertIn("height: parent.height", screenshots)

    def test_launcher_module_settings_explain_exact_search_terms(self):
        switch = source("modules/common/widgets/ConfigSwitch.qml")
        modules = source("modules/settings/configs/widgets/LauncherModulesConfig.qml")
        self.assertIn('property string description: ""', switch)
        for term in ("calendar", "window", "screenshot", "generator", "uuid", "password", "lorem"):
            self.assertIn(term, modules.lower())

    def test_persistence_uses_explicit_list_types(self):
        config = source("modules/common/Config.qml")
        persistent = source("modules/common/Persistent.qml")
        self.assertIn("property list<var> keybindings", config)
        self.assertIn("property list<string> actions", config)
        self.assertIn("property list<string> recentQueries", persistent)
        self.assertIn("property list<string> pinnedEntries", persistent)
        self.assertIn("property list<var> panelUsage", persistent)

    def test_shortcuts_are_local_and_processes_stay_in_user_scope(self):
        search_bar = source("modules/ii/overview/SearchBar.qml")
        resources = source("services/ResourceUsage.qml")
        self.assertIn("configuredShortcut", search_bar)
        self.assertIn("matchesShortcut", search_bar)
        self.assertIn('ps -u \\"$(id -u)\\"', resources)
        self.assertIn("pid=,comm=,pcpu=,pmem=", resources)
        self.assertIn('"kill", "-TERM"', source("services/LauncherSearch.qml"))


if __name__ == "__main__":
    unittest.main()
