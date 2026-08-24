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
        for panel_id in ("calendar", "tasks", "timers", "emojis", "screenshots", "windows", "settings", "keybinds", "commands", "gmail", "sports", "generators"):
            self.assertIn('id: "' + panel_id + '"', registry)
        self.assertGreaterEqual(registry.count("hosted: true"), 12)

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
            "GeneratorsPanel.qml",
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
        self.assertGreaterEqual(registry.count("Config.options.search.appearance.panelWidth"), 12)
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
        self.assertIn("structureTimer", emojis)
        self.assertNotIn("root.entries = root.list.map", emojis)
        list_change = emojis.split("onListChanged:", 1)[1].split("function ensurePrepared", 1)[0]
        self.assertNotIn("preparationTimer.restart()", list_change)

        emoji_panel = source("modules/ii/overview/EmojiPanel.qml")
        self.assertIn("StyledComboBox", emoji_panel)
        self.assertIn("GridView", emoji_panel)
        self.assertIn("showStatus: true", emoji_panel)
        self.assertIn("Math.min(8", emoji_panel)
        self.assertIn("skinTone", emoji_panel)

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
        shell_actions = source("modules/common/ShellActionRegistry.qml")
        for term in ('id: "notes"', 'notesOpen = true', 'notes", "notas'):
            self.assertIn(term, shell_actions)

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
        self.assertIn("modelData.home?.logo", sports_panel)
        self.assertIn("modelData.away?.logo", sports_panel)
        self.assertIn("height: parent.height", sports_panel)
        self.assertIn("function navigateUp(): bool", timers)
        self.assertIn("function navigateDown(): bool", timers)
        self.assertIn("function secondaryActivateSelected(): bool", timers)
        self.assertIn("property int displayClockTick", timers)
        self.assertIn('(?:h|hr|hour|hours)', timers)
        self.assertIn("TimerService.addCountdown", timers)

        timer_service = source("services/TimerService.qml")
        self.assertIn("return countdown", timer_service)

    def test_screenshot_preview_uses_the_working_clipboard_wrapper(self):
        screenshots = source("modules/ii/overview/ScreenshotsPanel.qml")
        self.assertIn("CliphistImage", screenshots)
        self.assertIn("height: parent.height", screenshots)
        self.assertIn("bottomMargin: 0", screenshots)
        self.assertIn("Preparing preview", screenshots)

        wrapper = source("modules/common/widgets/CliphistImage.qml")
        self.assertIn("Qt.md5(root.entry)", wrapper)
        self.assertIn("readonly property real fitScale", wrapper)
        self.assertNotIn("Component.onDestruction", wrapper)

    def test_normal_results_are_deduplicated_and_grouped(self):
        widget = source("modules/ii/overview/SearchWidget.qml")
        launcher = source("services/LauncherSearch.qml")
        self.assertIn("function organizeResults(results): var", widget)
        self.assertIn("Best match", widget)
        self.assertIn('const hasApplications = unique.some', widget)
        self.assertIn('key !== "panel:settings"', widget)
        self.assertIn('{ id: "settings", label: Translation.tr("Settings")', widget)
        self.assertIn('section.property: "sectionId"', widget)
        self.assertIn("const seenKeys = new Set()", widget)
        self.assertIn("dynamicRoles: true", widget)
        self.assertIn("result.length === 0", launcher)

    def test_collapsed_search_does_not_reserve_hidden_result_margins(self):
        widget = source("modules/ii/overview/SearchWidget.qml")
        self.assertIn("implicitHeight: !resultsActive", widget)
        self.assertIn("? 0", widget)
        self.assertIn("rowSpacing: 0", widget)
        self.assertIn("topMargin: 0", widget)
        self.assertIn("? Appearance.rounding.windowRounding", widget)
        self.assertIn(": Appearance.rounding.verylarge", widget)
        self.assertNotIn("Behavior on radius", widget)
        self.assertIn("showIdleNowPlaying", widget)
        self.assertNotIn('searchingText === "" && LauncherSearch.results.length > 0', widget)
        self.assertIn("Layout.bottomMargin: root.isAiMode ? 0 : verticalPadding", widget)

    def test_calendar_has_upcoming_agenda_and_real_create_form(self):
        panel = source("modules/ii/overview/CalendarPanel.qml")
        form = source("modules/ii/overview/calendar/CalendarCreateForm.qml")
        google = source("services/GoogleCalendarService.qml")
        self.assertIn("property bool upcomingMode: true", panel)
        self.assertIn("CalendarCreateForm", panel)
        self.assertIn("function submitFields(fields): bool", panel)
        for field in ("titleField", "startDateField", "startTimeField", "endDateField", "endTimeField", "locationField", "allDayButton"):
            self.assertIn("id: " + field, form)
        self.assertIn('mutationState = "success"', google)
        self.assertIn('root.syncing = false;\n                    root.mutationState = "success"', google)
        self.assertIn("Qt.callLater(root.refresh)", google)

    def test_window_panel_targets_live_open_windows(self):
        panel = source("modules/ii/overview/WindowManagementPanel.qml")
        self.assertIn("HyprlandData.windowList", panel)
        self.assertIn("HyprlandData.activeWorkspace", panel)
        self.assertIn("targetAddress", panel)
        self.assertIn("targetStrip", panel)
        self.assertIn("WindowActionRegistry.execute", panel)

    def test_generators_have_a_panel_preview_and_feedback(self):
        registry = source("modules/common/SearchPanelRegistry.qml")
        panel = source("modules/ii/overview/GeneratorsPanel.qml")
        launcher = source("services/LauncherSearch.qml")
        self.assertIn('id: "generators"', registry)
        for generator_id in ("uuid", "password", "lorem"):
            self.assertIn('id: "' + generator_id + '"', panel)
        self.assertIn("generatedValue", panel)
        self.assertIn("copied to clipboard", panel)
        self.assertIn("feedbackText", launcher)

    def test_settings_pages_are_discoverable_and_close_search_before_opening(self):
        registry = source("modules/common/SettingsPageRegistry.qml")
        panel = source("modules/ii/overview/SettingsTogglesPanel.qml")
        launcher = source("services/LauncherSearch.qml")
        for page in ("LauncherModulesConfig.qml", "LauncherQuicklinksConfig.qml", "LauncherSnippetsConfig.qml", "LauncherShortcutsConfig.qml", "LauncherAppearanceConfig.qml", "LauncherDataConfig.qml"):
            self.assertIn(page, registry)
        self.assertIn("function humanizeSubPage(path)", panel)
        self.assertIn("GlobalStates.overviewOpen = false", panel)
        settings_result = launcher.split("function createSettingsResultObject", 1)[1].split("function createSettingsPanelResultObject", 1)[0]
        self.assertIn("GlobalStates.overviewOpen = false", settings_result)

    def test_new_search_surfaces_do_not_introduce_borders(self):
        paths = (
            "modules/ii/overview/CalendarPanel.qml",
            "modules/ii/overview/calendar/CalendarCreateForm.qml",
            "modules/ii/overview/TasksPanel.qml",
            "modules/ii/overview/TimersPanel.qml",
            "modules/ii/overview/EmojiPanel.qml",
            "modules/ii/overview/ScreenshotsPanel.qml",
            "modules/ii/overview/WindowManagementPanel.qml",
            "modules/ii/overview/SettingsTogglesPanel.qml",
            "modules/ii/overview/CommandsPanel.qml",
            "modules/ii/overview/GmailPanel.qml",
            "modules/ii/overview/SportsPanel.qml",
            "modules/ii/overview/GeneratorsPanel.qml",
        )
        for path in paths:
            self.assertNotIn("border.", source(path), path)

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
        self.assertIn("property list<var> historySeen", persistent)

    def test_clipboard_retention_is_configurable_and_preserves_pins(self):
        config = source("modules/common/Config.qml")
        settings = source("modules/settings/configs/ClipboardConfig.qml")
        cliphist = source("services/Cliphist.qml")
        self.assertIn("property JsonObject autoDelete", config)
        self.assertIn("retentionDays", config)
        self.assertIn("Delete clipboard history automatically", settings)
        self.assertIn("function synchronizeRetention()", cliphist)
        self.assertIn("!root.isPinned(entry)", cliphist)
        self.assertIn("function wipeUnpinned()", cliphist)
        self.assertIn("function wipeUnpinnedOnShutdown()", cliphist)
        self.assertIn("onAboutToQuit", cliphist)

    def test_shortcuts_are_local_and_processes_stay_in_user_scope(self):
        search_bar = source("modules/ii/overview/SearchBar.qml")
        resources = source("services/ResourceUsage.qml")
        self.assertIn("configuredShortcut", search_bar)
        self.assertIn("matchesShortcut", search_bar)
        self.assertIn('ps -u \\"$(id -u)\\"', resources)
        self.assertIn("pid=,comm=,pcpu=,pmem=", resources)
        self.assertIn('"kill", "-TERM"', source("services/LauncherSearch.qml"))

    def test_quicklinks_support_custom_images_and_generic_panel_routing(self):
        result_model = source("modules/common/models/LauncherSearchResult.qml")
        quicklinks = source("modules/settings/configs/widgets/LauncherQuicklinksConfig.qml")
        launcher = source("services/LauncherSearch.qml")
        item = source("modules/ii/overview/SearchItem.qml")
        states = source("GlobalStates.qml")
        overview = source("modules/ii/overview/Overview.qml")
        self.assertIn("System, Image, None", result_model)
        self.assertIn("iconPathDraft", quicklinks)
        self.assertIn("FileDialog", quicklinks)
        self.assertIn("link?.iconPath", launcher)
        self.assertIn("function quicklinkFavicon(url)", launcher)
        self.assertIn("fetchFavicons", quicklinks)
        self.assertIn("LauncherSearchResult.IconType.Image", item)
        self.assertIn('source: visible ? root.iconName : ""', item)
        self.assertIn('target: "searchPanel"', states)
        self.assertIn('name: "overviewCommandsOpen"', overview)


if __name__ == "__main__":
    unittest.main()
