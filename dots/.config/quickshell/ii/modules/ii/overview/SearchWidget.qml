pragma ComponentBehavior: Bound

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs
import qs.services
import qs.services.ai
import qs.services.ai.blocks
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    width: implicitWidth
    height: searchWidgetContent.height + (GlobalStates.searchConnectActive ? 0 : Appearance.sizes.elevationMargin * 2)
    focus: true
    signal requestToggleActions
    property bool inNotchMode: false
    // Set by the per-monitor Overview host so a deep-link is acknowledged by
    // the monitor that is actually rendering the Search surface.
    property string surfaceMonitorName: ""
    property string routedSessionRequestId: ""
    // Explicit panel requests come from normal search rows and external
    // deep-links. The text remains editable as that panel's local filter.
    property string requestedPanelId: ""

    readonly property string xdgConfigHome: Directories.config
    readonly property int typingDebounceInterval: 200
    readonly property int typingResultLimit: {
        const query = LauncherSearch.query;
        if (!query)
            return 15;
        const isPrefixed = query.startsWith(Config.options.search.prefix.app) || query.startsWith(Config.options.search.prefix.fileBrowser) || query.startsWith(Config.options.search.prefix.emojis) || query.startsWith(Config.options.search.prefix.windowSearch) || query.startsWith(Config.options.search.prefix.fileSearch);
        return isPrefixed ? 500 : 15;
    }
    readonly property bool isSearching: false
    readonly property bool showSkeletons: false

    property int loadedResultsCount: 50
    // Left/Right stays available to edit the query unless the selected row is
    // one of the Settings controls that can consume a horizontal adjustment.
    property bool selectedResultHandlesHorizontalNavigation: false

    function getFilteredResultsCount() {
        const results = LauncherSearch.results;
        const q = LauncherSearch.query.trim().toLowerCase();
        let count = 0;
        for (let i = 0; i < results.length; i++) {
            const item = results[i];
            if (item && (!(Config.options.search.alwaysListApps || q !== "" || !Config.options.search.showNowPlayingBubble) || item.key !== "mpris:now-playing"))
                count++;
        }
        return count;
    }

    function loadMoreResults() {
        if (!GlobalStates.overviewOpen)
            return;
        const total = root.getFilteredResultsCount();
        if (loadedResultsCount < total) {
            loadedResultsCount = Math.min(total, loadedResultsCount + 50);
            appResults.applyResultDiff(root.processResults(LauncherSearch.results));
        }
    }

    // Keep one authoritative query path. Binding this property directly to
    // LauncherSearch while also synchronizing it from SearchBar created a
    // QML binding loop during the AI handoff (the query is intentionally
    // cleared when the chat surface takes over).
    property string searchingText: ""

    Connections {
        target: LauncherSearch
        function onQueryChanged() {
            if (root.searchingText !== LauncherSearch.query)
                root.searchingText = LauncherSearch.query;
        }
    }
    readonly property var resolvedPanel: SearchPanelRegistry.resolve(root.searchingText)
    readonly property string activePanelId: root.isAiMode ? "ai" : (root.requestedPanelId || root.resolvedPanel?.id || "")
    readonly property var activePanel: SearchPanelRegistry.byId(root.activePanelId)
    readonly property bool isClipboardMode: root.activePanelId === "clipboard"
    readonly property bool isBluetoothMode: root.activePanelId === "bluetooth"
    readonly property bool isTranslatorMode: root.activePanelId === "translator"
    readonly property bool isMediaDownloaderMode: root.activePanelId === "mediaDownloader"
    readonly property bool isMaterialSymbolsMode: root.activePanelId === "materialSymbols"
    /**
     * Whether the AI surface owns the search.
     *
     * This is state, not a formula. It used to be derived from the query —
     * and entering AI mode clears the query, which fed straight back into the
     * formula. Qt saw a binding loop and froze the property, so Escape and
     * the back button had nothing left to change and the panel could not be
     * left. Every way in sets the latch; only `exitAiMode()` clears it.
     */
    readonly property bool isAiMode: Ai.enabled && root.aiModeLocked
    // Auto AI recognition: when enabled, a settled query that matches no app,
    // command or prefix hands the search over to the AI chat. Kept apart from
    // the latch so the timer cannot fire twice for one query.
    property bool aiAutoEngaged: false
    property bool aiModeLocked: false
    // Prevents a query that entered AI mode from being copied repeatedly when
    // the launcher query is cleared or the draft is restored asynchronously.
    property bool aiDraftHydrated: false
    readonly property bool aiAutoTriggerEnabled: Ai.enabled && (Config.options.search.ai?.trigger ?? "prefix") === "auto"
    readonly property var searchPrefixValues: SearchPanelRegistry.activePrefixes.concat([
        Config.options.search.prefix.action, Config.options.search.prefix.app,
        Config.options.search.prefix.fileSearch, Config.options.search.prefix.emojis,
        Config.options.search.prefix.math, Config.options.search.prefix.shellCommand,
        Config.options.search.prefix.webSearch, Config.options.search.prefix.windowSearch,
        Config.options.search.prefix.fileBrowser
    ]).filter((value, index, values) => value && values.indexOf(value) === index)
    readonly property bool queryHasAnyPrefix: root.searchPrefixValues.some(prefix => root.searchingText.startsWith(prefix))
    // Results that are actual matches — the always-there fallback rows
    // (shell command, math, web, ask-AI) never count.
    readonly property int realResultCount: LauncherSearch.results.filter(r => r && r.key !== "cmd:shell" && r.key !== "web:search" && r.key !== "ai:ask" && r.key !== "mpris:now-playing" && !r.key.startsWith("math:")).length
    readonly property bool isAnySpecialMode: root.activePanelId.length > 0

    readonly property var activePanelItem: {
        switch (root.activePanelId) {
        case "clipboard": return clipboardPanelLoader.item;
        case "bluetooth": return bluetoothPanelLoader.item;
        case "translator": return translatorPanelLoader.item;
        case "mediaDownloader": return mediaDownloaderPanelLoader.item;
        case "materialSymbols": return materialSymbolsPanelLoader.item;
        case "ai": return aiPanelLoader.item;
        case "settings": return registeredPanelHost.activeItem;
        case "keybinds": return registeredPanelHost.activeItem;
        default: return null;
        }
    }

    SearchKeyRouter {
        id: searchKeyRouter
        activePanelItem: root.activePanelItem
        resultsList: appResults
        searchWidget: root
    }

    // Latch: however AI mode was entered (prefix typed, suggestion row or
    // auto detection), it stays on until back/Esc — deleting the text must
    // not yank the panel away mid-conversation.
    onIsAiModeChanged: {
        if (root.isAiMode) {
            if (!root.aiDraftHydrated) {
                root.aiDraftHydrated = true;
                const initialDraft = StringUtils.cleanOnePrefix(root.searchingText, [Config.options.search.prefix.ai]).trim();
                if (Ai.draft.trim().length === 0 && initialDraft.length > 0)
                    Ai.draft = initialDraft;
                LauncherSearch.query = "";
            }
            // Focus the AI composer immediately so the user can type without
            // clicking. The latch is *not* set here: `isAiMode` reads
            // `aiModeLocked`, so writing it back from this handler made the
            // binding depend on its own result — Qt broke the loop by
            // freezing the property, and Escape then had nothing to change.
            Qt.callLater(root.focusSearchInput);
        } else {
            root.aiDraftHydrated = false;
        }
        root.tryConsumeSurfaceIntent();
    }

    /**
     * Enters AI mode and keeps it: however it was entered, deleting the text
     * must not yank the panel away mid-conversation. Every way in calls this;
     * only the back button and Escape call `exitAiMode()`.
     */
    function engageAiMode() {
        if (!Ai.enabled)
            return;
        root.aiModeLocked = true;
    }

    // Debounce so a query that is still matching things asynchronously does
    // not flip the whole widget into AI mode between keystrokes.
    Timer {
        id: aiAutoEngageTimer
        interval: 350
        onTriggered: {
            if (root.aiAutoTriggerEnabled && !root.aiAutoEngaged && !root.queryHasAnyPrefix && root.searchingText.trim().length >= 3 && root.realResultCount === 0) {
                root.aiAutoEngaged = true;
                root.engageAiMode();
            }
        }
    }

    onSearchingTextChanged: {
        // Typing the prefix is one of the ways in, so it latches here rather
        // than as a reaction to the mode changing.
        if (Ai.enabled && root.searchingText.startsWith(Config.options.search.prefix.ai))
            root.engageAiMode();
        if (root.searchingText === "" || root.queryHasAnyPrefix) {
            root.aiAutoEngaged = false;
            aiAutoEngageTimer.stop();
        } else if (root.aiAutoTriggerEnabled && !root.aiAutoEngaged && root.searchingText.trim().length >= 3 && root.realResultCount === 0) {
            aiAutoEngageTimer.restart();
        }
    }

    Component.onCompleted: root.searchingText = LauncherSearch.query

    onRealResultCountChanged: {
        if (root.aiAutoEngaged)
            return;
        if (root.aiAutoTriggerEnabled && !root.queryHasAnyPrefix && root.searchingText.trim().length >= 3 && root.realResultCount === 0)
            aiAutoEngageTimer.restart();
        else
            aiAutoEngageTimer.stop();
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen) {
                root.requestedPanelId = "";
                if (root.isAiMode || root.aiAutoEngaged || root.aiModeLocked)
                    root.resetAiSearchState(false);
                else
                    root.cancelSearch();
            }
        }
    }

    function consumePanelIntent() {
        if (!GlobalStates.overviewOpen)
            return;
        const requested = GlobalStates.consumePendingSearchPanel();
        const panel = SearchPanelRegistry.byId(requested);
        if (panel && panel.enabled()) {
            root.requestedPanelId = requested;
            Qt.callLater(root.focusSearchInput);
        }
    }

    Connections {
        target: GlobalStates
        function onSearchPanelNavigationRequestChanged() {
            root.consumePanelIntent();
        }
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen)
                root.consumePanelIntent();
        }
    }
    readonly property bool showSuggestionsPanel: Config.options.search.suggestions.enable && !root.isAnySpecialMode && root.searchingText === ""
    readonly property bool alwaysListAppsMode: Config.options.search.alwaysListApps && !root.isAnySpecialMode
    property bool showResults: searchingText != "" || isAnySpecialMode || alwaysListAppsMode || (searchingText === "" && LauncherSearch.results.length > 0)
    property string overviewPosition: (Config.options.bar?.bottom ? "bottom" : (Config.options.overview?.position ?? ""))

    // Re-enable item transitions after panel open animation completes
    Timer {
        id: enableTransitionsTimer
        interval: 400
        repeat: false
        onTriggered: root.suppressItemTransitions = false
    }

    // Suppress item transitions during panel open/close to avoid flicker
    property bool suppressItemTransitions: true
    // Keep list movement animations for settled results, not for every keypress.
    // Reordering delegates while the fuzzy search is still changing competes
    // with text input on the GUI thread.
    Timer {
        id: typingTransitionTimer
        interval: 140
        repeat: false
        onTriggered: root.suppressItemTransitions = false
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                // Suppress transitions while panel is animating open
                root.suppressItemTransitions = true;
                // Wipe stale results immediately so panel opens empty (no ghost expansion)
                resultModel.clear();
                root.loadedResultsCount = 50;
                if (root.alwaysListAppsMode) {
                    Qt.callLater(() => {
                        // Show first 15 immediately for instant response,
                        // then load the rest after a short delay
                        const allResults = LauncherSearch.results;
                        appResults.applyResultDiff(allResults.slice(0, 15));
                        root.focusFirstItem();
                        resultsDebounce.restart();
                    });
                }
                // Re-enable transitions after open animation
                enableTransitionsTimer.restart();
            } else {
                resultsDebounce.stop();
                // Suppress transitions then clear immediately.
                // Since suppressItemTransitions=true, remove transitions run at duration:0
                // (instantaneous/invisible), so no flicker even though model clears now.
                root.suppressItemTransitions = true;
                resultModel.clear();
            }
        }
    }

    Connections {
        target: LauncherSearch
        function onRequestOpenSettings() {
            GlobalStates.overviewOpen = false;
            Qt.callLater(() => {
                GlobalStates.openSettings();
            });
        }
    }
    implicitWidth: searchWidgetContent.implicitWidth + (GlobalStates.searchConnectActive ? 0 : Appearance.sizes.elevationMargin * 2)
    implicitHeight: searchWidgetContent.implicitHeight + (GlobalStates.searchConnectActive ? 0 : Appearance.sizes.elevationMargin * 2)

    // Track animation state via Connections to the animation IDs
    property bool _heightAnimating: false
    property bool _widthAnimating: false

    Connections {
        target: heightAnim
        function onRunningChanged() {
            root._heightAnimating = heightAnim.running;
        }
    }

    Connections {
        target: widthAnim
        function onRunningChanged() {
            root._widthAnimating = widthAnim.running;
        }
    }

    // Signals to DynamicIslandStyle that the open animation is stable (no active resize)
    // When true, the DI pill disables its own behaviors and follows SearchWidget's animations directly.
    // In notch mode we always return false so the DI pill remains responsible for all animations.
    readonly property bool openStateStable: root.inNotchMode ? false : (!root._heightAnimating && !root._widthAnimating)

    function focusFirstItem() {
        if (root.showSuggestionsPanel) {
            if (suggestionsPanelLoader.item)
                suggestionsPanelLoader.item.focusFirst();
        } else if (root.isAiMode) {
            root.focusSearchInput();
        } else if (root.activePanelItem && typeof root.activePanelItem.focusInput === "function") {
            root.activePanelItem.focusInput();
        } else {
            appResults.currentIndex = 0;
        }
    }

    function focusSearchInput() {
        if (root.isAiMode && aiPanelLoader.item) {
            aiPanelLoader.item.focusComposer();
            return;
        }
        searchBar.forceFocus();
    }

    function selectedResultRow(): var {
        if (appResults.currentIndex < 0 || appResults.currentIndex >= appResults.count)
            return null;
        const delegate = appResults.itemAtIndex(appResults.currentIndex);
        return delegate?.item ?? delegate ?? null;
    }

    function refreshSelectedResultNavigation() {
        const row = root.selectedResultRow();
        root.selectedResultHandlesHorizontalNavigation = row?.supportsHorizontalNavigation === true;
    }

    function navigateSelectedResult(direction: string): bool {
        const row = root.selectedResultRow();
        if (!row)
            return false;
        if (direction === "left" && typeof row.navigateLeft === "function")
            return row.navigateLeft();
        if (direction === "right" && typeof row.navigateRight === "function")
            return row.navigateRight();
        return false;
    }

    function continueInSidebar() {
        const panel = aiPanelLoader.item;
        Ai.surfaceRouter.open({
            surface: "sidebar",
            monitorName: root.surfaceMonitorName,
            sessionId: Ai.sessions.currentId,
            focusIntent: "composer",
            scrollAnchor: panel && typeof panel.captureHandoffState === "function"
                ? panel.captureHandoffState()
                : null
        });
    }

    // A router request is consumed only after this per-monitor Search host is
    // visible and the AI panel exists. Session loading is also acknowledged
    // only after Ai has selected the requested session, so a deep-link cannot
    // clear itself while another conversation is still on screen.
    function tryConsumeSurfaceIntent() {
        const intent = Ai.surfaceRouter.pendingIntent;
        if (!intent || intent.surface !== "search" || intent.monitorName !== root.surfaceMonitorName)
            return;
        // A chat handed over from the sidebar opens the panel rather than
        // waiting for someone to type the prefix first.
        if (GlobalStates.overviewOpen && !root.isAiMode)
            root.engageAiMode();
        if (!GlobalStates.overviewOpen || !root.isAiMode || !aiPanelLoader.item)
            return;
        if (intent.sessionId.length > 0 && Ai.sessions.currentId !== intent.sessionId) {
            if (root.routedSessionRequestId !== intent.requestId) {
                root.routedSessionRequestId = intent.requestId;
                Ai.openSession(intent.sessionId);
            }
            return;
        }
        const panel = aiPanelLoader.item;
        if (!panel || typeof panel.applySurfaceIntent !== "function")
            return;
        if (!panel.applySurfaceIntent(intent))
            return;
        Ai.surfaceRouter.acknowledge(intent.requestId);
        root.routedSessionRequestId = "";
    }

    Connections {
        target: Ai.surfaceRouter
        function onPendingIntentChanged() {
            root.tryConsumeSurfaceIntent();
        }
    }

    Connections {
        target: Ai.sessions
        function onCurrentIdChanged() {
            root.tryConsumeSurfaceIntent();
        }
        function onLoadedChanged() {
            root.tryConsumeSurfaceIntent();
        }
    }

    Connections {
        target: Ai
        function onMessageIDsChanged() {
            root.tryConsumeSurfaceIntent();
        }
        function onMessageByIDChanged() {
            root.tryConsumeSurfaceIntent();
        }
    }

    Connections {
        target: aiPanelLoader
        function onStatusChanged() {
            root.tryConsumeSurfaceIntent();
        }
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            root.tryConsumeSurfaceIntent();
        }
    }

    function disableExpandAnimation() {
        searchBar.animateWidth = false;
    }

    function cancelSearch() {
        // Normal Search is intentionally ephemeral. The AI composer owns its
        // draft per session; the launcher query must not become a second draft
        // store that brings the last ordinary search back on the next open.
        root.searchingText = "";
        root.requestedPanelId = "";
        LauncherSearch.query = "";
        searchBar.searchInput.text = "";
        searchBar.animateWidth = true;
    }

    // AI state belongs to the AI surface, never to the normal launcher. Clear
    // both halves of the query synchronizer so a previous "&" handoff cannot
    // immediately relatch the panel when the ordinary Search opens again.
    // `Ai.draft` remains untouched: the AI panel alone owns that unsent text.
    function resetAiSearchState(focusNormalSearch = false) {
        root.aiAutoEngaged = false;
        root.aiModeLocked = false;
        root.aiDraftHydrated = false;
        aiAutoEngageTimer.stop();
        root.searchingText = "";
        LauncherSearch.query = "";
        searchBar.searchInput.text = "";
        if (focusNormalSearch) {
            Qt.callLater(() => {
                root.focusSearchInput();
                searchBar.searchInput.forceActiveFocus();
            });
        }
    }

    // Leave AI chat and return to the plain search without discarding an
    // unsent AI draft. Sent drafts are cleared by Ai after submission starts.
    function exitAiMode() {
        root.resetAiSearchState(true);
    }

    // One Escape path for the whole overview surface. A PanelWindow cannot
    // host a Keys attached property, so Overview's window shortcut delegates
    // here; the focused composer and child controls use the same function.
    function handleEscape(): bool {
        if (!root.isAiMode)
            return false;
        if (aiPanelLoader.item && typeof aiPanelLoader.item.handleEscape === "function" && aiPanelLoader.item.handleEscape())
            return true;
        root.exitAiMode();
        return true;
    }

    // Send the current search bar text as a chat message. The search bar is
    // the composer in AI mode, so both Enter in the field and the send button
    // in the panel funnel through here.
    function sendAiMessage(messageText) {
        const raw = (typeof messageText === "string" && messageText.length > 0) ? messageText : Ai.draft;
        const cleaned = StringUtils.cleanOnePrefix(raw, [Config.options.search.prefix.ai]).trim();
        if (!cleaned)
            return;
        const parsed = AiActionRegistry.parseInput(cleaned, "/");
        if (parsed.kind === "command" || parsed.kind === "unknown-command") {
            if (root.executeAiCommand(parsed))
                Ai.clearDraftIfCurrent();
        } else {
            Ai.sendUserMessage(Ai.expandComposerReferences(parsed.text));
        }
        if (aiPanelLoader.item && typeof aiPanelLoader.item.focusComposer === "function")
            aiPanelLoader.item.focusComposer();
    }

    // Search and sidebar share the parser; commands that need a sidebar host
    // hand off through the same router instead of becoming accidental prompts.
    function executeAiCommand(parsed: var) {
        if (parsed.kind === "unknown-command") {
            Ai.submissionNotice = Translation.tr("Unknown AI command: %1").arg(parsed.name);
            return false;
        }
        const args = parsed.args ?? [];
        switch (parsed.id) {
        case "model":
            Ai.setModel(args.join(" ").trim());
            break;
        case "provider":
            Ai.setProvider(args.join(" ").trim());
            break;
        case "temp":
        case "temperature":
            Ai.setTemperature(Number(args[0] ?? 0.7));
            break;
        case "think":
            Ai.setThinkingLevel(args[0] ?? "medium");
            break;
        case "effort":
            Ai.setResponseMode(args[0] ?? "balanced");
            break;
        case "web":
            Ai.setWebMode(args[0] ?? "auto");
            break;
        case "tools":
            Ai.setFunctionExposure(args[0] ?? "all");
            break;
        case "tool":
            Ai.setTool(args[0] ?? "");
            break;
        case "chats":
            if (aiPanelLoader.item)
                aiPanelLoader.item.historyOpen = true;
            break;
        case "clear":
        case "new":
            Ai.newChat();
            break;
        default:
            Ai.submissionNotice = Translation.tr("/%1 is available in the sidebar.").arg(parsed.name);
            return false;
        }
        return true;
    }

    function setSearchingText(text) {
        searchBar.searchInput.text = text;
        LauncherSearch.query = text;
    }

    function processResults(results) {
        const q = LauncherSearch.query.trim().toLowerCase();
        const excludeMpris = Config.options.search.alwaysListApps || q !== "" || !Config.options.search.showNowPlayingBubble;
        const out = [];
        const limit = root.loadedResultsCount;
        for (let i = 0; i < results.length && out.length < limit; i++) {
            const item = results[i];
            if (item && (!excludeMpris || item.key !== "mpris:now-playing"))
                out.push(item);
        }
        return out;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier) && root.isAiMode) {
            root.continueInSidebar();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
            if (root.isAiMode) {
                // The app result list is hidden while AI owns the surface;
                // never toggle an action panel the user cannot see.
                root.focusSearchInput();
                event.accepted = true;
                return;
            }
            if (appResults.visible) {
                root.requestToggleActions();
                event.accepted = true;
            }
            return;
        }

        // ESC: in AI mode, delegate to panel (closes history first, then exits AI mode)
        if (event.key === Qt.Key_Escape) {
            if (root.isAiMode) {
                root.handleEscape();
                event.accepted = true;
            }
            // In non-AI mode, let the event propagate to OverviewWindow for closing
            return;
        }

        // TAB / Backtab: route navigation inside AI panel when in AI mode
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (root.isAiMode) {
                if (aiPanelLoader.item) {
                    if (event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier))
                        aiPanelLoader.item.focusPrev();
                    else
                        aiPanelLoader.item.focusNext();
                }
                event.accepted = true;
                return;
            }
        }

        // Handle Backspace: focus and delete character if not focused
        if (event.key === Qt.Key_Backspace) {
            if (root.isAiMode) {
                root.focusSearchInput();
                return;
            }
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput();
                if (event.modifiers & Qt.ControlModifier) {
                    // Delete word before cursor
                    let text = searchBar.searchInput.text;
                    let pos = searchBar.searchInput.cursorPosition;
                    if (pos > 0) {
                        // Find the start of the previous word
                        let left = text.slice(0, pos);
                        let match = left.match(/(\s*\S+)\s*$/);
                        let deleteLen = match ? match[0].length : 1;
                        searchBar.searchInput.text = text.slice(0, pos - deleteLen) + text.slice(pos);
                        searchBar.searchInput.cursorPosition = pos - deleteLen;
                    }
                } else {
                    // Delete character before cursor if any
                    if (searchBar.searchInput.cursorPosition > 0) {
                        searchBar.searchInput.text = searchBar.searchInput.text.slice(0, searchBar.searchInput.cursorPosition - 1) + searchBar.searchInput.text.slice(searchBar.searchInput.cursorPosition);
                        searchBar.searchInput.cursorPosition -= 1;
                    }
                }
                // Always move cursor to end after programmatic edit
                searchBar.searchInput.cursorPosition = searchBar.searchInput.text.length;
                event.accepted = true;
            }
            // If already focused, let TextField handle it
            return;
        }

        // Only handle visible printable characters (ignore control chars, arrows, etc.)
        if (event.text && event.text.length === 1 && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && event.key !== Qt.Key_Delete && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab && event.text.charCodeAt(0) >= 0x20)
        {
            if (root.isAiMode) {
                root.focusSearchInput();
                const input = searchBar.searchInput;
                const position = input.cursorPosition;
                input.text = input.text.slice(0, position) + event.text + input.text.slice(position);
                input.cursorPosition = position + event.text.length;
                event.accepted = true;
                return;
            }
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput();
                // Insert the character at the cursor position
                searchBar.searchInput.text = searchBar.searchInput.text.slice(0, searchBar.searchInput.cursorPosition) + event.text + searchBar.searchInput.text.slice(searchBar.searchInput.cursorPosition);
                searchBar.searchInput.cursorPosition += 1;
                event.accepted = true;
                root.focusFirstItem();
            }
        }
    }

    property real shadowOpacity: 1.0

    StyledRectangularShadow {
        target: searchWidgetContent
        visible: !GlobalStates.searchConnectActive && !Config.options.appearance.transparency.popups && !Config.options.appearance.transparency.enable
        opacity: root.shadowOpacity
        offset: Qt.vector2d(0.0, 0.0)
    }
    Rectangle {
        id: searchWidgetContent
        // Centered vertically like every other mode — the AI panel is just
        // another panel below the search bar, same as clipboard/translator.
        anchors.centerIn: parent
        width: GlobalStates.searchConnectActive ? parent.width : implicitWidth
        height: GlobalStates.searchConnectActive ? parent.height : implicitHeight
        clip: true
        layer.enabled: !GlobalStates.searchConnectActive
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: searchWidgetContent.width
                height: searchWidgetContent.height
                radius: searchWidgetContent.radius
            }
        }

        MouseArea {
            anchors.fill: parent
            // Absorb clicks inside search widget so they do not hit the full-screen dismiss MouseArea
            onClicked: {}
        }
        implicitWidth: {
            let baseW = 0;
            if (root.activePanel)
                baseW = root.activePanel.width();
            else
                baseW = Math.max(Config.options.search.baseWidth, gridLayout.implicitWidth);

            // In notch mode, the DI container already provides horizontal spacing.
            // Only add the 48px offset in non-notch connect mode.
            if (GlobalStates.searchConnectActive && !root.inNotchMode)
                return baseW + 48;
            return baseW;
        }
        implicitHeight: {
            let bottomMargin = GlobalStates.searchConnectActive ? 16 : 10;
            if (root.showSuggestionsPanel)
                return (suggestionsPanelLoader.item ? suggestionsPanelLoader.item.implicitHeight : (Config.options.search.baseHeight ?? 500)) + searchBar.height + searchBar.verticalPadding * 2 + bottomMargin;
            if (root.activePanel)
                return (root.activePanelItem?.implicitHeight ?? 520) + (root.isAiMode ? 16 : searchBar.height + searchBar.verticalPadding * 2 + bottomMargin);
            return gridLayout.implicitHeight;
        }
        radius: root.isAiMode ? Appearance.rounding.verylarge : Appearance.rounding.windowRounding
        color: GlobalStates.searchConnectActive ? "transparent"
             : (root.activePanel?.accent ? Appearance.colors.colBackgroundSurfaceContainerAccent
                                        : Appearance.colors.colBackgroundSurfaceContainer)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Behavior on implicitWidth {
            id: searchWidthBehavior
            // In notch mode, DI pill drives sizing — disable internal animation to avoid double-animation
            enabled: !root.inNotchMode
            NumberAnimation {
                id: widthAnim
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }
        }

        Behavior on implicitHeight {
            id: searchHeightBehavior
            // In notch mode, DI pill drives sizing — disable internal animation to avoid double-animation
            enabled: !root.inNotchMode
            NumberAnimation {
                id: heightAnim
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }
        }

        Behavior on radius {
            enabled: !root.inNotchMode
            NumberAnimation {
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }
        }

        GridLayout {
            id: gridLayout
            anchors.left: parent.left
            anchors.right: parent.right
            // In notch mode the DI container provides spacing — adding margins here would double-pad
            anchors.leftMargin: (GlobalStates.searchConnectActive && !root.inNotchMode) ? 24 : 0
            anchors.rightMargin: (GlobalStates.searchConnectActive && !root.inNotchMode) ? 24 : 0
            anchors.top: parent.top
            columns: 1
            rowSpacing: root.isAiMode ? 0 : 5
            clip: true

            SearchBar {
                id: searchBar
                property real verticalPadding: 4
                Layout.fillWidth: true
                Layout.preferredHeight: root.isAiMode ? 0 : implicitHeight
                Layout.minimumHeight: 0
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.topMargin: root.isAiMode ? 0 : verticalPadding
                Layout.bottomMargin: root.isAiMode ? 0 : verticalPadding
                Layout.row: root.overviewPosition == "bottom" ? 1 : 0
                visible: !root.isAiMode
                animateWidth: true
                aiModeActive: root.isAiMode
                Binding {
                    target: searchBar
                    property: "searchingText"
                    value: root.searchingText
                }

                clipboardMode: root.isClipboardMode || root.isBluetoothMode || root.isTranslatorMode || root.isMediaDownloaderMode || root.isMaterialSymbolsMode
                activePanelMode: root.activePanelItem !== null
                supportsPanelSectionToggle: root.activePanelId === "settings"
                clipboardWidth: 830
                currentResultIndex: appResults.currentIndex
                isTranslatorPanelFocused: root.isTranslatorMode && translatorPanelLoader.item && translatorPanelLoader.item.focusedControlIndex !== -1
                isMediaDownloaderPanelFocused: root.isMediaDownloaderMode && mediaDownloaderPanelLoader.item && mediaDownloaderPanelLoader.item.focusedControlIndex !== -1
                isMaterialSymbolsPanelFocused: root.isMaterialSymbolsMode && materialSymbolsPanelLoader.item && materialSymbolsPanelLoader.item.focusedControlIndex !== -1
                showSuggestionsPanel: root.showSuggestionsPanel
                enabled: !root.isAiMode
                opacity: root.isAiMode ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveSmall.duration
                        easing.type: Appearance.animation.elementMoveSmall.type
                        easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
                    }
                }

                onCtrlKPressed: {
                    if (appResults.visible) {
                        root.requestToggleActions();
                    }
                }

                onTogglePanelSection: {
                    searchKeyRouter.dispatch("toggleSection");
                }

                onCopySelected: {
                    searchKeyRouter.dispatch("copySelected");
                }

                onOpenSelectedInCheatsheet: {
                    searchKeyRouter.dispatch("openSelectedInCheatsheet");
                }

                onEscapeToSearch: {
                    if (root.isAiMode)
                        root.handleEscape();
                }

                onSendMessage: {
                    if (root.isAiMode)
                        root.sendAiMessage();
                }

                onNavigateUp: {
                    if (root.showSuggestionsPanel) {
                        if (suggestionsPanelLoader.item)
                            suggestionsPanelLoader.item.navigateUp();
                    } else {
                        searchKeyRouter.dispatch("navigateUp");
                    }
                }

                onNavigateDown: {
                    if (root.showSuggestionsPanel) {
                        if (suggestionsPanelLoader.item)
                            suggestionsPanelLoader.item.navigateDown();
                    } else {
                        searchKeyRouter.dispatch("navigateDown");
                    }
                }

                onNavigateLeft: {
                    if (root.activePanelItem)
                        searchKeyRouter.dispatch("navigateLeft");
                    else if (root.selectedResultHandlesHorizontalNavigation)
                        searchKeyRouter.dispatch("navigateLeft");
                }

                onNavigateRight: {
                    if (root.activePanelItem)
                        searchKeyRouter.dispatch("navigateRight");
                    else if (root.selectedResultHandlesHorizontalNavigation)
                        searchKeyRouter.dispatch("navigateRight");
                }

                onActivate: {
                    if (root.showSuggestionsPanel && suggestionsPanelLoader.item)
                        suggestionsPanelLoader.item.activateSelected();
                    else
                        searchKeyRouter.dispatch("activateSelected");
                }

                onDeleteSelected: {
                    if (root.activePanelItem && typeof root.activePanelItem.deleteSelected === "function")
                        root.activePanelItem.deleteSelected();
                }
            }

            Item {
                // Use opacity-driven visibility so results fade out before collapsing on close
                readonly property bool resultsActive: root.showResults && !root.isAnySpecialMode
                opacity: resultsActive ? 1.0 : 0.0
                visible: opacity > 0.01
                Layout.fillWidth: true
                implicitHeight: root.showSkeletons ? searchSkeletons.implicitHeight + (GlobalStates.searchConnectActive ? 16 : 20) : Math.min(600, appResults.contentHeight + appResults.topMargin + appResults.bottomMargin)
                Layout.row: root.overviewPosition == "bottom" ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                Behavior on implicitHeight {
                    enabled: !root.inNotchMode
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveSmall.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                ListView {
                    id: appResults
                    anchors.fill: parent
                    visible: opacity > 0
                    opacity: root.showSkeletons ? 0.0 : 1.0
                    Behavior on opacity {
                        enabled: !root.inNotchMode
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveEffects
                        }
                    }
                    clip: true
                    topMargin: 10
                    bottomMargin: GlobalStates.searchConnectActive ? 16 : 10
                    spacing: 2
                    KeyNavigation.up: searchBar
                    highlightMoveDuration: 100

                    layer.enabled: root.searchingText != "" && appResults.count > 0
                    layer.effect: OpacityMask {
                        maskSource: Item {
                            id: maskRoot
                            width: appResults.width
                            height: appResults.height

                            property color topFadeColor: {
                                if (appResults.currentItem) {
                                    const visY = appResults.currentItem.y - appResults.contentY;
                                    if (visY <= appResults.topMargin + 36)
                                        return "white";
                                }
                                return appResults.atYBeginning ? "white" : "transparent";
                            }
                            property color bottomFadeColor: {
                                if (appResults.currentItem) {
                                    const visBottom = appResults.currentItem.y - appResults.contentY + appResults.currentItem.height;
                                    if (visBottom >= appResults.height - appResults.bottomMargin - 36)
                                        return "white";
                                }
                                return appResults.atYEnd ? "white" : "transparent";
                            }

                            Behavior on topFadeColor {
                                enabled: !root.inNotchMode
                                ColorAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                                }
                            }
                            Behavior on bottomFadeColor {
                                enabled: !root.inNotchMode
                                ColorAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                                }
                            }

                            Column {
                                anchors.fill: parent
                                spacing: 0

                                Rectangle {
                                    width: parent.width
                                    height: Math.min(46, parent.height / 2)
                                    color: "transparent"
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: maskRoot.topFadeColor
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: "white"
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: Math.max(0, parent.height - Math.min(46, parent.height / 2) - Math.min(56, parent.height / 2))
                                    color: "white"
                                }

                                Rectangle {
                                    width: parent.width
                                    height: Math.min(56, parent.height / 2)
                                    color: "transparent"
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: "white"
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: maskRoot.bottomFadeColor
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Touchpad and mouse scroll physics adjustments
                    property real scrollTargetY: 0
                    property real touchpadScrollFactor: Config?.options.interactions.scrolling.touchpadScrollFactor ?? 100
                    property real mouseScrollFactor: Config?.options.interactions.scrolling.mouseScrollFactor ?? 50
                    property real mouseScrollDeltaThreshold: Config?.options.interactions.scrolling.mouseScrollDeltaThreshold ?? 120

                    maximumFlickVelocity: 3500

                    MouseArea {
                        z: 99
                        visible: Config?.options.interactions.scrolling.fasterTouchpadScroll
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function (wheelEvent) {
                            const delta = wheelEvent.angleDelta.y / appResults.mouseScrollDeltaThreshold;
                            var scrollFactor = Math.abs(wheelEvent.angleDelta.y) >= appResults.mouseScrollDeltaThreshold ? appResults.mouseScrollFactor : appResults.touchpadScrollFactor;

                            const maxY = Math.max(0, appResults.contentHeight - appResults.height);
                            const base = scrollAnim.running ? appResults.scrollTargetY : appResults.contentY;
                            var targetY = Math.max(0, Math.min(base - delta * scrollFactor, maxY));

                            appResults.scrollTargetY = targetY;
                            appResults.contentY = targetY;
                            wheelEvent.accepted = true;
                        }
                    }

                    Behavior on contentY {
                        NumberAnimation {
                            id: scrollAnim
                            alwaysRunToEnd: true
                            duration: Appearance.animation.scroll.duration
                            easing.type: Appearance.animation.scroll.type
                            easing.bezierCurve: Appearance.animation.scroll.bezierCurve
                        }
                    }

                    onContentYChanged: {
                        if (contentHeight > 0 && contentY + height > contentHeight - 150) {
                            root.loadMoreResults();
                        }
                        if (!scrollAnim.running) {
                            appResults.scrollTargetY = appResults.contentY;
                        }
                    }

                    onCurrentIndexChanged: {
                        const selected = currentIndex >= 0 && currentIndex < resultModel.count
                            ? resultModel.get(currentIndex)?.modelRef ?? null
                            : null;
                        LauncherSearch.selectedResult = selected;
                        root.refreshSelectedResultNavigation();
                        if (currentIndex >= count - 5 && count < root.getFilteredResultsCount()) {
                            root.loadMoreResults();
                        }
                    }

                    // ── Diff-based model update: triggers move/add/remove transitions ──
                    function applyResultDiff(newItems) {
                        if (newItems.length === 0) {
                            if (resultModel.count > 0)
                                resultModel.clear();
                            return;
                        }

                        const currentKeys = [];
                        for (let i = 0; i < resultModel.count; i++)
                            currentKeys.push(resultModel.get(i).key);

                        const newKeys = newItems.map(item => item.key);
                        const newKeySet = new Set(newKeys);

                        // Remove stale rows from the end so model indexes remain valid.
                        for (let i = currentKeys.length - 1; i >= 0; i--) {
                            if (!newKeySet.has(currentKeys[i])) {
                                resultModel.remove(i);
                                currentKeys.splice(i, 1);
                            }
                        }

                        // Move/insert each desired row once. The old implementation
                        // rebuilt a full index map after every operation.
                        for (let newIndex = 0; newIndex < newItems.length; newIndex++) {
                            const item = newItems[newIndex];
                            const currentIndex = currentKeys.indexOf(item.key);

                            if (currentIndex === -1) {
                                resultModel.insert(newIndex, {
                                    key: item.key,
                                    modelRef: item
                                });
                                currentKeys.splice(newIndex, 0, item.key);
                            } else if (currentIndex !== newIndex) {
                                resultModel.move(currentIndex, newIndex, 1);
                                const movedKey = currentKeys.splice(currentIndex, 1)[0];
                                currentKeys.splice(newIndex, 0, movedKey);
                            }

                            const row = resultModel.get(newIndex);
                            if (row.modelRef !== item)
                                resultModel.setProperty(newIndex, "modelRef", item);
                        }
                    }

                    Connections {
                        target: root
                        function onSearchingTextChanged() {
                            root.loadedResultsCount = 50;
                            if (appResults.count > 0)
                                appResults.currentIndex = 0;

                            // Defer movement animations until typing settles. This
                            // keeps the input path free of overlapping ListView work.
                            root.suppressItemTransitions = true;
                            if (root.searchingText !== "")
                                typingTransitionTimer.restart();
                            else
                                typingTransitionTimer.stop();
                        }
                    }

                    // Debounce timer: delivers full results 150ms after the last
                    // results change, avoiding per-keystroke full list recomputation
                    Timer {
                        id: resultsDebounce
                        interval: 150
                        repeat: false
                        onTriggered: {
                            if (!GlobalStates.overviewOpen)
                                return;
                            appResults.applyResultDiff(root.processResults(LauncherSearch.results));
                        }
                    }

                    Connections {
                        target: LauncherSearch
                        function onResultsChanged() {
                            // Guard: don't populate while overview is closed/closing
                            // (stale LauncherSearch.results from previous session would cause ghost expansion)
                            if (!GlobalStates.overviewOpen)
                                return;
                            root.loadedResultsCount = 50;

                            // When query is emptied, instantly clear model and cancel debounce for instant height shrink
                            if (root.searchingText === "") {
                                resultsDebounce.stop();
                                typingTransitionTimer.stop();
                                root.suppressItemTransitions = true;
                                resultModel.clear();
                                return;
                            }

                            // Immediately show first 15 results for snappy visual feedback
                            const immediate = root.processResults(LauncherSearch.results);
                            const quickSlice = immediate.length > 15 ? immediate.slice(0, 15) : immediate;
                            appResults.applyResultDiff(quickSlice);
                            root.focusFirstItem();

                            // Schedule full result delivery after debounce
                            if (immediate.length > 15)
                                resultsDebounce.restart();
                        }
                    }

                    model: ListModel {
                        id: resultModel
                    }

                    Component.onCompleted: {
                        applyResultDiff(root.processResults(LauncherSearch.results));
                    }

                    delegate: Loader {
                        id: resultDelegate
                        required property int index
                        required property var modelData
                        width: appResults.width
                        height: item ? item.implicitHeight : 0
                        sourceComponent: resultDelegate.modelData.modelRef?.settingRef ? settingResultCard : normalSearchItem
                        onLoaded: root.refreshSelectedResultNavigation()

                        // Animate y when ListView repositions this delegate (via move/displaced)
                        Behavior on y {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves.emphasized
                            }
                        }

                        Component {
                            id: settingResultCard

                            // Loader owns this item's explicit width and
                            // resizes it to the delegate. The card must be a
                            // child instead: a direct child gets stretched
                            // back to full width after its x inset is applied.
                            Item {
                                implicitHeight: settingCardItem.implicitHeight
                                readonly property bool supportsHorizontalNavigation: settingCardItem.supportsHorizontalNavigation

                                function activate(): bool {
                                    return settingCardItem.activate();
                                }

                                function clicked(): bool {
                                    return settingCardItem.clicked();
                                }

                                function navigateLeft(): bool {
                                    return settingCardItem.navigateLeft();
                                }

                                function navigateRight(): bool {
                                    return settingCardItem.navigateRight();
                                }

                                AiSettingResultCard {
                                    id: settingCardItem
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: Appearance.sizes.elevationMargin
                                    height: implicitHeight
                                    setting: resultDelegate.modelData.modelRef.settingRef
                                    compact: true
                                    launcherStyle: true
                                    listIndex: resultDelegate.index
                                    listCount: appResults.count
                                    listCurrentIndex: appResults.currentIndex
                                }
                            }
                        }

                        Component {
                            id: normalSearchItem

                            SearchItem {
                                id: searchItem
                                width: resultDelegate.width
                                listIndex: resultDelegate.index
                                listCurrentIndex: appResults.currentIndex
                                // modelData is {key, modelRef} from ListModel — pass the actual result object
                                entry: resultDelegate.modelData.modelRef
                                query: StringUtils.cleanOnePrefix(root.searchingText, [Config.options.search.prefix.action, Config.options.search.prefix.app, Config.options.search.prefix.clipboard, Config.options.search.prefix.emojis, Config.options.search.prefix.math, Config.options.search.prefix.shellCommand, Config.options.search.prefix.webSearch])

                                Connections {
                                    target: root
                                    function onRequestToggleActions() {
                                        if (searchItem.listIndex === appResults.currentIndex) {
                                            searchItem.actionPanelOpen = !searchItem.actionPanelOpen;
                                            searchItem.actionSelectedIndex = 0;
                                            if (searchItem.actionPanelOpen) {
                                                searchItem.forceActiveFocus();
                                            } else {
                                                root.focusSearchInput();
                                            }
                                        }
                                    }
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
                                        searchItem.actionPanelOpen = !searchItem.actionPanelOpen;
                                        searchItem.actionSelectedIndex = 0;
                                        if (searchItem.actionPanelOpen) {
                                            searchItem.forceActiveFocus();
                                        } else {
                                            root.focusSearchInput();
                                        }
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Tab) {
                                        if (searchItem.actionPanelOpen)
                                            return;
                                        if (LauncherSearch.results.length === 0)
                                            return;
                                        const tabbedText = resultDelegate.modelData.name;
                                        LauncherSearch.query = tabbedText;
                                        searchBar.searchInput.text = tabbedText;
                                        event.accepted = true;
                                        root.focusSearchInput();
                                    }
                                }
                            }
                        }
                    }

                    // ── Reorder animation: items jump to new positions as results change ──
                    move: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: root.suppressItemTransitions ? 0 : 220
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.emphasized
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: root.suppressItemTransitions ? 0 : 220
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.emphasized
                        }
                    }

                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                property: "opacity"
                                from: 0.0
                                to: 1.0
                                duration: root.suppressItemTransitions ? 0 : 180
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                property: "y"
                                duration: root.suppressItemTransitions ? 0 : 220
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                            }
                        }
                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0.0
                            duration: root.suppressItemTransitions ? 0 : 120
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                ColumnLayout {
                    id: searchSkeletons
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 8
                    visible: opacity > 0
                    opacity: root.showSkeletons ? 1.0 : 0.0
                    Behavior on opacity {
                        enabled: !root.inNotchMode
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                        }
                    }

                    Repeater {
                        model: 4
                        Rectangle {
                            id: skeletonRow
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colSurfaceContainerHigh
                            antialiasing: true

                            // Shimmer animation with wave phase shift
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: searchSkeletons.visible
                                NumberAnimation {
                                    from: 0.25
                                    to: 0.65
                                    duration: 600 + skeletonRow.index * 100
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    from: 0.65
                                    to: 0.25
                                    duration: 600 + skeletonRow.index * 100
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Rectangle {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: Appearance.rounding.full
                                    color: Appearance.colors.colSurfaceContainerHighest
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        implicitHeight: 12
                                        radius: Appearance.rounding.verysmall
                                        color: Appearance.colors.colSurfaceContainerHighest
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        implicitHeight: 8
                                        radius: Appearance.rounding.verysmall
                                        color: Appearance.colors.colSurfaceContainerHighest
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                id: clipboardPanelLoader
                active: root.isClipboardMode || opacity > 0.01
                visible: opacity > 0.01
                Layout.fillWidth: true
                Layout.preferredHeight: (root.isClipboardMode || opacity > 0.01) ? (item ? item.implicitHeight : 520) : 0
                height: Layout.preferredHeight
                source: "ClipboardPanel.qml"
                Layout.row: root.overviewPosition == "bottom" ? 0 : 1

                opacity: root.isClipboardMode ? 1.0 : 0.0
                transform: Translate {
                    y: (1.0 - clipboardPanelLoader.opacity) * 16
                }
                layer.enabled: opacity > 0.001 && opacity < 0.999
                layer.effect: MultiEffect {
                    blurEnabled: (1.0 - parent.opacity) > 0.001
                    blurMax: 32.0
                    blur: (1.0 - parent.opacity) * 0.5
                }
                Behavior on opacity {
                    enabled: !root.inNotchMode
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                Binding {
                    target: clipboardPanelLoader.item
                    property: "searchQuery"
                    value: StringUtils.cleanOnePrefix(root.searchingText, [Config.options.search.prefix.clipboard])
                    when: clipboardPanelLoader.status === Loader.Ready
                }
            }

            Loader {
                id: bluetoothPanelLoader
                active: root.isBluetoothMode || opacity > 0.01
                visible: opacity > 0.01
                Layout.fillWidth: true
                Layout.preferredHeight: (root.isBluetoothMode || opacity > 0.01) ? (item ? item.implicitHeight : 520) : 0
                height: Layout.preferredHeight
                source: "BluetoothPanel.qml"
                Layout.row: root.overviewPosition == "bottom" ? 0 : 1

                opacity: root.isBluetoothMode ? 1.0 : 0.0
                transform: Translate {
                    y: (1.0 - bluetoothPanelLoader.opacity) * 16
                }
                layer.enabled: opacity > 0.001 && opacity < 0.999
                layer.effect: MultiEffect {
                    blurEnabled: (1.0 - parent.opacity) > 0.001
                    blurMax: 32.0
                    blur: (1.0 - parent.opacity) * 0.5
                }
                Behavior on opacity {
                    enabled: !root.inNotchMode
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                Binding {
                    target: bluetoothPanelLoader.item
                    property: "searchQuery"
                    value: StringUtils.cleanOnePrefix(root.searchingText, [Config.options.search.prefix.bluetooth])
                    when: bluetoothPanelLoader.status === Loader.Ready
                }
            }

            Loader {
                id: translatorPanelLoader
                active: root.isTranslatorMode || opacity > 0.01
                visible: opacity > 0.01
                Layout.fillWidth: true
                Layout.preferredHeight: (root.isTranslatorMode || opacity > 0.01) ? (item ? item.implicitHeight : 520) : 0
                height: Layout.preferredHeight
                source: "TranslatorPanel.qml"
                Layout.row: root.overviewPosition == "bottom" ? 0 : 1

                opacity: root.isTranslatorMode ? 1.0 : 0.0
                transform: Translate {
                    y: (1.0 - translatorPanelLoader.opacity) * 16
                }
                layer.enabled: opacity > 0.001 && opacity < 0.999
                layer.effect: MultiEffect {
                    blurEnabled: (1.0 - parent.opacity) > 0.001
                    blurMax: 32.0
                    blur: (1.0 - parent.opacity) * 0.5
                }
                Behavior on opacity {
                    enabled: !root.inNotchMode
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                Binding {
                    target: translatorPanelLoader.item
                    property: "searchQuery"
                    value: StringUtils.cleanOnePrefix(root.searchingText, [Config.options.search.prefix.translator])
                    when: translatorPanelLoader.status === Loader.Ready
                }

                Connections {
                    target: translatorPanelLoader.item
                    ignoreUnknownSignals: true
                    function onRequestSetSearchQuery(query) {
                        root.setSearchingText(Config.options.search.prefix.translator + query);
                    }
                    function onRequestFocusSearchInput() {
                        root.focusSearchInput();
                    }
                }
            }

            Loader {
                id: mediaDownloaderPanelLoader
                active: root.isMediaDownloaderMode || opacity > 0.01
                visible: opacity > 0.01
                Layout.fillWidth: true
                Layout.preferredHeight: (root.isMediaDownloaderMode || opacity > 0.01) ? (item ? item.implicitHeight : 520) : 0
                height: Layout.preferredHeight
                source: "MediaDownloaderPanel.qml"
                Layout.row: root.overviewPosition == "bottom" ? 0 : 1

                opacity: root.isMediaDownloaderMode ? 1.0 : 0.0
                transform: Translate {
                    y: (1.0 - mediaDownloaderPanelLoader.opacity) * 16
                }
                layer.enabled: opacity > 0.001 && opacity < 0.999
                layer.effect: MultiEffect {
                    blurEnabled: (1.0 - parent.opacity) > 0.001
                    blurMax: 32.0
                    blur: (1.0 - parent.opacity) * 0.5
                }
                Behavior on opacity {
                    enabled: !root.inNotchMode
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                Binding {
                    target: mediaDownloaderPanelLoader.item
                    property: "searchQuery"
                    value: StringUtils.cleanOnePrefix(root.searchingText, [Config.options.search.prefix.mediaDownloader])
                    when: mediaDownloaderPanelLoader.status === Loader.Ready
                }
            }

            Loader {
                id: materialSymbolsPanelLoader
                active: root.isMaterialSymbolsMode || opacity > 0.01
                visible: opacity > 0.01
                Layout.preferredWidth: 380
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: (root.isMaterialSymbolsMode || opacity > 0.01) ? (item ? item.implicitHeight : 520) : 0
                height: Layout.preferredHeight
                source: "MaterialSymbolsPanel.qml"
                Layout.row: root.overviewPosition == "bottom" ? 0 : 1

                opacity: root.isMaterialSymbolsMode ? 1.0 : 0.0
                transform: Translate {
                    y: (1.0 - materialSymbolsPanelLoader.opacity) * 16
                }
                layer.enabled: opacity > 0.001 && opacity < 0.999
                layer.effect: MultiEffect {
                    blurEnabled: (1.0 - parent.opacity) > 0.001
                    blurMax: 32.0
                    blur: (1.0 - parent.opacity) * 0.5
                }
                Behavior on opacity {
                    enabled: !root.inNotchMode
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                Binding {
                    target: materialSymbolsPanelLoader.item
                    property: "searchQuery"
                    value: StringUtils.cleanOnePrefix(root.searchingText, [Config.options.search.prefix.materialSymbols])
                    when: materialSymbolsPanelLoader.status === Loader.Ready
                }
            }

            SearchPanelHost {
                id: registeredPanelHost
                Layout.fillWidth: true
                Layout.preferredHeight: activePanelId === "settings" || activePanelId === "keybinds"
                    ? implicitHeight
                    : 0
                height: Layout.preferredHeight
                activePanelId: root.activePanelId === "settings" || root.activePanelId === "keybinds"
                    ? root.activePanelId
                    : ""
                searchQuery: root.searchingText
                inNotchMode: root.inNotchMode
                Layout.row: root.overviewPosition == "bottom" ? 0 : 1
            }

            Loader {
                id: aiPanelLoader
                active: root.isAiMode || opacity > 0.01
                visible: opacity > 0.01
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                Layout.preferredHeight: (root.isAiMode || opacity > 0.01) ? (item ? item.implicitHeight : 520) : 0
                height: Layout.preferredHeight
                source: "AiChatPanel.qml"
                Layout.row: root.overviewPosition == "bottom" ? 0 : 1

                opacity: root.isAiMode ? 1.0 : 0.0
                transform: Translate {
                    y: (1.0 - aiPanelLoader.opacity) * 16
                }
                layer.enabled: opacity > 0.001 && opacity < 0.999
                layer.effect: MultiEffect {
                    blurEnabled: (1.0 - parent.opacity) > 0.001
                    blurMax: 32.0
                    blur: (1.0 - parent.opacity) * 0.5
                }
                Behavior on opacity {
                    enabled: !root.inNotchMode
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }

                Connections {
                    target: aiPanelLoader.item
                    ignoreUnknownSignals: true
                    function onRequestBackToSearch() {
                        root.exitAiMode();
                    }
                    function onRequestFocusComposer() {
                        if (aiPanelLoader.item && typeof aiPanelLoader.item.focusComposer === "function")
                            aiPanelLoader.item.focusComposer();
                    }
                    function onRequestSendMessage(text) {
                        root.sendAiMessage(text);
                    }
                    function onRequestContinueInSidebar() {
                        root.continueInSidebar();
                    }
                }

                Binding {
                    target: aiPanelLoader.item
                    property: "activeSurface"
                    value: root.isAiMode
                    when: aiPanelLoader.status === Loader.Ready
                }

                // The panel remains reusable on its own, but when hosted by
                // Search it can leave through this direct, synchronous route.
                // This avoids a Loader signal being the only path back to the
                // normal search surface.
                Binding {
                    target: aiPanelLoader.item
                    property: "searchHost"
                    value: root
                    when: aiPanelLoader.status === Loader.Ready
                }
            }

            Loader {
                id: suggestionsPanelLoader
                active: root.showSuggestionsPanel || opacity > 0.01
                visible: opacity > 0.01
                Layout.fillWidth: true
                Layout.preferredHeight: (root.showSuggestionsPanel || opacity > 0.01) ? (item ? item.implicitHeight : (Config.options.search.baseHeight ?? 500)) : 0
                height: Layout.preferredHeight
                source: "SuggestionsPanel.qml"
                Layout.row: root.overviewPosition == "bottom" ? 0 : 1

                opacity: root.showSuggestionsPanel ? 1.0 : 0.0
                transform: Translate {
                    y: (1.0 - suggestionsPanelLoader.opacity) * -16
                }
                layer.enabled: opacity > 0.001 && opacity < 0.999
                layer.effect: MultiEffect {
                    blurEnabled: (1.0 - parent.opacity) > 0.001
                    blurMax: 32.0
                    blur: (1.0 - parent.opacity) * 0.5
                }

                Behavior on opacity {
                    enabled: !root.inNotchMode
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }
            }

            // Service lifecycle: activate/deactivate with mode
            Connections {
                target: root
                function onIsMediaDownloaderModeChanged() {
                    MediaDownloaderService.active = root.isMediaDownloaderMode;
                }
            }
        }
    }
}
