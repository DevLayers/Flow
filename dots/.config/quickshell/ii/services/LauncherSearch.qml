pragma Singleton

import qs
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.services
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property string query: ""
    property int mprisTrigger: 0
    property string processConfirmKey: ""
    readonly property int quickToggleRevision: QuickToggleRegistry.revision
    readonly property bool barOpenForSearch: GlobalStates.barOpen
    // Published by the visible Overview delegate. It is metadata only and is
    // never sent unless the user explicitly attaches it from an AI composer.
    property var selectedResult: null
    // The generated Settings index is shared with AI but does not depend on a
    // model or network. Watching readiness makes a query recompute once a
    // missing/stale index finishes rebuilding in the background.
    readonly property bool settingsIndexReady: Ai.settingsIntegration.ready

    onSettingsIndexReadyChanged: root._scheduleResultsUpdate()
    onQuickToggleRevisionChanged: root._scheduleResultsUpdate()
    onBarOpenForSearchChanged: root._scheduleResultsUpdate()

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen) {
                root.rememberQuery(root.query);
                root.query = "";
                root.selectedResult = null;
            }
        }
    }

    Component.onCompleted: Qt.callLater(_scheduleResultsUpdate)

    function enabledUtilityPrefixes(): var {
        const prefixes = Config.options.search.prefix;
        const values = [prefixes.action, prefixes.app];
        const modules = Config.options.search.modules;
        if (modules.fileBrowser) values.push(prefixes.fileBrowser);
        if (modules.fileSearch) values.push(prefixes.fileSearch);
        if (modules.math) values.push(prefixes.math);
        if (modules.shellCommand) values.push(prefixes.shellCommand);
        if (modules.webSearch) values.push(prefixes.webSearch);
        if (modules.windowSearch) values.push(prefixes.windowSearch);
        return values.filter(value => String(value ?? "").length > 0);
    }

    function ensurePrefix(prefix) {
        const knownPrefixes = SearchPanelRegistry.activePrefixes.concat(root.enabledUtilityPrefixes());
        if (knownPrefixes.some(existing => root.query.startsWith(existing))) {
            root.query = prefix + root.query.slice(1);
        } else {
            root.query = prefix + root.query;
        }
    }

    function queryUsesPrefix(value) {
        const prefixes = SearchPanelRegistry.activePrefixes.concat(root.enabledUtilityPrefixes());
        return prefixes.some(prefix => String(value ?? "").startsWith(prefix));
    }

    // Called from SearchItem to open settings - must be a QML function (not a JS closure)
    // so that GlobalStates is accessible in the correct QML context
    signal requestOpenSettings

    function isMathQuery(expr) {
        if (!Config.options.search.modules.math)
            return false;
        expr = expr.trim();
        if (expr.length === 0)
            return false;
        const prefixMath = Config.options.search.prefix.math;
        const hasPrefix = prefixMath && expr.startsWith(prefixMath);
        const hasDigitsAndOp = /^\d/.test(expr) && /[+\-\*\/^()%]/.test(expr);
        const hasFunc = /^(sqrt|sin|cos|tan|log|ln)\b/i.test(expr);
        return hasPrefix || hasDigitsAndOp || hasFunc;
    }

    function isSettingsSearchQuery(queryText: string): bool {
        const query = String(queryText ?? "").trim();
        if (query.length < 2)
            return false;
        const reserved = SearchPanelRegistry.activePrefixes.concat(root.enabledUtilityPrefixes());
        return !reserved.some(prefix => query.startsWith(prefix));
    }

    function createSettingsResultObject(setting: var): var {
        const label = String(setting?.labelLocalized ?? setting?.label ?? setting?.key ?? "");
        const path = [
            setting?.pageNameLocalized ?? setting?.pageName ?? "",
            setting?.sectionTitleLocalized ?? setting?.sectionTitle ?? ""
        ].filter(part => String(part).length > 0).join(" › ");
        return resultComp.createObject(null, {
            key: "setting:" + String(setting?.key ?? label),
            name: label,
            type: Translation.tr("Setting"),
            verb: Translation.tr("Open"),
            iconName: String(setting?.icon ?? "tune"),
            iconType: LauncherSearchResult.IconType.Material,
            comment: path,
            category: "setting",
            settingRef: setting,
            keepOverviewOpen: true,
            execute: () => {
                const pageId = String(setting?.pageId ?? "");
                const subPage = String(setting?.subPage ?? "");
                const section = String(setting?.sectionTitleLocalized ?? setting?.sectionTitle ?? "");
                GlobalStates.overviewOpen = false;
                Qt.callLater(() => GlobalStates.openSettingsPage(pageId, subPage, section));
            }
        });
    }

    function createSettingsPanelResultObject(matchCount: int): var {
        const queryText = root.query.trim();
        const comment = matchCount > 0
            ? Translation.tr("%1 results for \"%2\"").arg(String(matchCount)).arg(queryText)
            : Translation.tr("Search settings for \"%1\"").arg(queryText);
        return resultComp.createObject(null, {
            key: "panel:settings",
            name: Translation.tr("Settings"),
            type: Translation.tr("Settings"),
            verb: Translation.tr("Open"),
            iconName: "settings",
            iconType: LauncherSearchResult.IconType.Material,
            comment,
            panelId: "settings",
            keepOverviewOpen: true,
            execute: () => GlobalStates.openSearchPanel("settings", "", queryText)
        });
    }

    function keybindMatches(queryText: string, limit: int): var {
        const terms = String(queryText ?? "").trim().toLocaleLowerCase().split(/\s+/).filter(term => term.length > 0);
        if (terms.length === 0)
            return [];
        const output = [];

        function collect(nodes, source, parentSection) {
            for (const node of Array.from(nodes ?? [])) {
                const section = String(node?.name ?? parentSection ?? "").trim() || Translation.tr("Keybinds");
                for (const binding of Array.from(node?.keybinds ?? [])) {
                    const keys = Array.from(binding?.mods ?? []).map(part => String(part))
                        .concat([String(binding?.key ?? "")]).filter(part => part.length > 0);
                    const name = String(binding?.comment ?? "").trim()
                        || `${String(binding?.dispatcher ?? "").trim()} ${String(binding?.params ?? "").trim()}`.trim();
                    const haystack = [section, name, keys.join(" "), binding?.dispatcher ?? "", binding?.params ?? ""]
                        .join(" ").toLocaleLowerCase();
                    if (keys.length > 0 && name.length > 0 && terms.every(term => haystack.includes(term))) {
                        output.push({
                            section,
                            source,
                            keys,
                            name,
                            dispatcher: String(binding?.dispatcher ?? "").trim(),
                            params: String(binding?.params ?? "").trim()
                        });
                    }
                }
                collect(node?.children, source, section);
            }
        }

        if (Config.options.search.modules.keybinds.includeDefaultBinds)
            collect(HyprlandKeybinds.defaultKeybinds?.children, "default", "");
        if (Config.options.search.modules.keybinds.includeUserBinds)
            collect(HyprlandKeybinds.userKeybinds?.children, "user", "");
        return output.slice(0, limit);
    }

    function createKeybindResultObject(binding: var): var {
        return resultComp.createObject(null, {
            key: "keybind:" + binding.keys.join("+") + ":" + binding.name,
            name: binding.name,
            type: Translation.tr("Keybind"),
            verb: binding.dispatcher.length > 0 ? Translation.tr("Run") : Translation.tr("Copy"),
            iconName: "keyboard",
            iconType: LauncherSearchResult.IconType.Material,
            comment: binding.section,
            keyHints: binding.keys,
            keepOverviewOpen: binding.dispatcher.length === 0,
            execute: () => HyprlandKeybinds.dispatchBinding(binding)
                || (Quickshell.clipboardText = binding.keys.join("+")),
            actions: [
                resultComp.createObject(null, {
                    name: Translation.tr("Copy shortcut"),
                    iconName: "content_copy",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => Quickshell.clipboardText = binding.keys.join("+")
                }),
                resultComp.createObject(null, {
                    name: Translation.tr("Open in Cheat Sheet"),
                    iconName: "help",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => GlobalStates.openCheatsheet("keybinds")
                })
            ]
        });
    }

    function searchPanelMatches(queryText: string): var {
        const terms = String(queryText ?? "").trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
        if (terms.length === 0)
            return [];
        return SearchPanelRegistry.enabledPanels.filter(panel => {
            if (panel.id === "ai")
                return false;
            const searchable = [panel.id, panel.label, ...(panel.keywords ?? [])]
                .join(" ").toLocaleLowerCase();
            return terms.every(term => searchable.includes(term));
        });
    }

    function createSearchPanelResult(panel: var): var {
        return resultComp.createObject(null, {
            key: "panel:" + panel.id,
            name: panel.label,
            iconName: panel.icon,
            iconType: LauncherSearchResult.IconType.Material,
            type: Translation.tr("Search panel"),
            verb: Translation.tr("Open"),
            comment: Translation.tr("Search tools"),
            panelId: panel.id,
            keepOverviewOpen: true,
            execute: () => {
                root.query = "";
                root.recordPanelUse(panel.id);
                GlobalStates.openSearchPanel(panel.id);
            }
        });
    }

    function liveSportsResults(queryText: string): var {
        if (!Config.options.search.modules.sports.enable)
            return [];
        const query = String(queryText ?? "").trim().toLocaleLowerCase();
        const cutoff = Date.now() + 3 * 60 * 60 * 1000;
        return Array.from(SportsService.allGames ?? []).filter(game => {
            const date = new Date(game?.date);
            const upcoming = game?.state === "in" || (!isNaN(date.getTime()) && date.getTime() <= cutoff && date.getTime() >= Date.now() - 3 * 60 * 60 * 1000);
            if (!upcoming)
                return false;
            const haystack = [game?.name, game?.league, game?.home?.name, game?.away?.name].join(" ").toLocaleLowerCase();
            return query.length === 0 || haystack.includes(query);
        }).slice(0, 2);
    }

    function createLiveSportsResult(game: var): var {
        return resultComp.createObject(null, {
            key: "sports:" + String(game?.id ?? game?.name ?? ""),
            name: String(game?.home?.name ?? "") + " " + String(game?.home?.score ?? "") + " × " + String(game?.away?.score ?? "") + " " + String(game?.away?.name ?? ""),
            type: game?.state === "in" ? Translation.tr("Live") : Translation.tr("Upcoming game"),
            verb: Translation.tr("Open"),
            iconName: "sports_soccer",
            iconType: LauncherSearchResult.IconType.Material,
            comment: String(game?.league ?? "") + " · " + String(game?.status ?? ""),
            panelId: "sports",
            keepOverviewOpen: true,
            execute: () => GlobalStates.openSearchPanel("sports")
        });
    }

    function quicklinkMatches(queryText: string): var {
        if (!Config.options.search.modules.quicklinks.enable)
            return [];
        const query = String(queryText ?? "").trim();
        if (query.length === 0)
            return [];
        const [first, ...rest] = query.split(/\s+/);
        const alias = first.toLocaleLowerCase();
        return Array.from(Config.options.search.modules.quicklinks.links ?? [])
            .map(link => {
                const linkAlias = String(link?.alias ?? "").trim().toLocaleLowerCase();
                const name = String(link?.name ?? "").toLocaleLowerCase();
                const matches = linkAlias === alias || linkAlias.includes(alias) || name.includes(query.toLocaleLowerCase());
                return matches ? { link, remainder: rest.join(" "), exact: linkAlias === alias } : null;
            })
            .filter(Boolean)
            .sort((left, right) => Number(right.exact) - Number(left.exact));
    }

    function quicklinkUrl(match) {
        const url = String(match?.link?.url ?? "").trim();
        return url.split("{query}").join(encodeURIComponent(String(match?.remainder ?? "")));
    }

    function openQuicklink(match, forceCopy = false) {
        const url = root.quicklinkUrl(match);
        if (url.length === 0)
            return false;
        const openWith = String(match?.link?.openWith ?? "default");
        if (forceCopy || Config.options.search.modules.quicklinks.copyOnEnter || openWith === "copy") {
            Quickshell.clipboardText = url;
            return true;
        }
        if (openWith.startsWith("app:"))
            Quickshell.execDetached(["gtk-launch", openWith.slice(4)]);
        else
            Quickshell.execDetached(["xdg-open", url]);
        return true;
    }

    function quicklinkFavicon(url) {
        const host = String(url ?? "").match(/^https?:\/\/([^\/?#:]+)/i)?.[1] ?? "";
        return host.length > 0
            ? "https://www.google.com/s2/favicons?domain=" + encodeURIComponent(host) + "&sz=64"
            : "";
    }

    function createQuicklinkResult(match: var): var {
        const link = match.link;
        const url = root.quicklinkUrl(match);
        let customImage = String(link?.iconPath ?? "").trim();
        if (customImage.startsWith("~/"))
            customImage = "file://" + Directories.home + customImage.slice(1);
        else if (customImage.startsWith("/"))
            customImage = "file://" + customImage;
        const fallbackImage = Config.options.search.modules.quicklinks.fetchFavicons
            ? root.quicklinkFavicon(url)
            : "";
        const imageSource = customImage || fallbackImage;
        const icon = imageSource || String(link?.icon ?? "").trim() || "link";
        return resultComp.createObject(null, {
            key: "quicklink:" + String(link.alias ?? url),
            name: String(link.name ?? link.alias ?? url),
            iconName: icon,
            iconType: imageSource.length > 0
                ? LauncherSearchResult.IconType.Image
                : LauncherSearchResult.IconType.Material,
            type: Translation.tr("Quicklink"),
            verb: Config.options.search.modules.quicklinks.copyOnEnter ? Translation.tr("Copy") : Translation.tr("Open"),
            comment: url,
            keepOverviewOpen: Config.options.search.modules.quicklinks.copyOnEnter,
            feedbackText: Config.options.search.modules.quicklinks.copyOnEnter ? Translation.tr("Link copied to clipboard") : "",
            execute: () => root.openQuicklink(match),
            actions: [
                resultComp.createObject(null, {
                    name: Translation.tr("Copy link"),
                    iconName: "content_copy",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => root.openQuicklink(match, true)
                }),
                resultComp.createObject(null, {
                    name: Translation.tr("Open link"),
                    iconName: "open_in_new",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        Quickshell.execDetached(["xdg-open", url]);
                    }
                })
            ]
        });
    }

    function rememberQuery(value) {
        if (!Config.options.search.history.enable || !Persistent.ready)
            return;
        const query = String(value ?? "").trim();
        if (query.length === 0)
            return;
        const prior = Array.from(Persistent.states.search.recentQueries ?? []).filter(item => item !== query);
        Persistent.states.search.recentQueries = [query].concat(prior).slice(0, Math.max(1, Config.options.search.history.maxItems));
    }

    function recentQuery(offset) {
        const entries = Array.from(Persistent.states.search.recentQueries ?? []);
        return offset >= 0 && offset < entries.length ? String(entries[offset]) : "";
    }

    function recordPanelUse(panelId) {
        if (!Config.options.search.frecencyData.trackPanels || !Persistent.ready)
            return;
        const rows = Array.from(Persistent.states.search.panelUsage ?? []);
        const id = String(panelId ?? "");
        const previous = rows.find(row => String(row?.id ?? "") === id) ?? ({ id: id, count: 0 });
        const next = rows.filter(row => String(row?.id ?? "") !== id);
        next.unshift({ id: id, count: Number(previous.count ?? 0) + 1, usedAt: Date.now() });
        Persistent.states.search.panelUsage = next.slice(0, 64);
    }

    function toggleFavorite(result) {
        if (!Config.options.search.favorites.enable || !result?.pinnable || !result?.key || !Persistent.ready)
            return false;
        const key = String(result.key);
        if (!/^(app:|panel:|quicklink:)/.test(key))
            return false;
        const prior = Array.from(Persistent.states.search.pinnedEntries ?? []);
        Persistent.states.search.pinnedEntries = prior.includes(key)
            ? prior.filter(entry => entry !== key)
            : [key].concat(prior).slice(0, 24);
        return true;
    }

    function favoriteResults() {
        if (!Config.options.search.favorites.enable)
            return [];
        const results = [];
        for (const key of Array.from(Persistent.states.search.pinnedEntries ?? [])) {
            if (key.startsWith("app:")) {
                const app = DesktopEntries.byId(key.slice(4));
                if (app)
                    results.push(root.createAppResultObject(app));
                continue;
            }
            if (key.startsWith("panel:")) {
                const panel = SearchPanelRegistry.byId(key.slice(6));
                if (panel?.enabled())
                    results.push(root.createSearchPanelResult(panel));
                continue;
            }
            if (key.startsWith("quicklink:")) {
                const link = Array.from(Config.options.search.modules.quicklinks.links ?? [])
                    .find(item => "quicklink:" + String(item?.alias ?? item?.url ?? "") === key);
                if (link)
                    results.push(root.createQuicklinkResult({ link: link, remainder: "" }));
            }
        }
        return results.map(result => Object.assign({}, result, { pinned: true, type: Translation.tr("Favorite") }));
    }

    function snippetMatches(queryText: string): var {
        if (!Config.options.search.modules.snippets.enable)
            return [];
        const query = String(queryText ?? "").trim().toLocaleLowerCase();
        if (query.length === 0)
            return [];
        return Array.from(Config.options.search.modules.snippets.items ?? []).filter(item => {
            const alias = String(item?.alias ?? "").toLocaleLowerCase();
            const name = String(item?.name ?? "").toLocaleLowerCase();
            return alias === query || alias.startsWith(query) || name.includes(query);
        });
    }

    function expandSnippet(item) {
        const date = Qt.formatDate(new Date(), "yyyy-MM-dd");
        return String(item?.text ?? item?.content ?? "")
            .split("{clipboard}").join(Quickshell.clipboardText ?? "")
            .split("{date}").join(date)
            .split("{cursor}").join("");
    }

    function createSnippetResult(item: var): var {
        const text = root.expandSnippet(item);
        return resultComp.createObject(null, {
            key: "text-snippet:" + String(item?.alias ?? item?.name ?? ""),
            name: String(item?.name ?? item?.alias ?? Translation.tr("Text snippet")),
            type: Translation.tr("Text snippet"),
            verb: Translation.tr("Copy"),
            iconName: "content_copy",
            iconType: LauncherSearchResult.IconType.Material,
            comment: text,
            execute: () => Quickshell.clipboardText = text
        });
    }

    function processMatches(queryText: string): var {
        if (!Config.options.search.modules.processes.enable)
            return [];
        const query = String(queryText ?? "").trim().toLocaleLowerCase();
        if (query.length < 2)
            return [];
        const terms = query.replace(/\b(kill|quit|process|processo|fechar)\b/g, "").trim().split(/\s+/).filter(Boolean);
        return Array.from(ResourceUsage.topProcesses ?? []).filter(process => {
            const name = String(process?.name ?? "").toLocaleLowerCase();
            return terms.length > 0 ? terms.every(term => name.includes(term)) : /\b(kill|quit|process|processo|fechar)\b/.test(query);
        });
    }

    function createProcessResult(process: var): var {
        const key = "process:" + String(process?.pid ?? "");
        const awaitingConfirmation = root.processConfirmKey === key;
        return resultComp.createObject(null, {
            key,
            name: awaitingConfirmation
                ? Translation.tr("%1 — press Enter again to quit").arg(String(process?.name ?? Translation.tr("Process")))
                : String(process?.name ?? Translation.tr("Process")),
            type: Translation.tr("Process"),
            verb: awaitingConfirmation ? Translation.tr("Confirm") : Translation.tr("Quit"),
            iconName: "cancel",
            iconType: LauncherSearchResult.IconType.Material,
            comment: Translation.tr("PID %1 · CPU %2% · RAM %3%").arg(String(process?.pid ?? "")).arg(String(process?.cpuPercent ?? 0)).arg(String(process?.memoryPercent ?? 0)),
            execute: () => {
                if (root.processConfirmKey === key) {
                    root.processConfirmKey = "";
                    Quickshell.execDetached(["kill", "-TERM", String(process?.pid ?? "")]);
                    return;
                }
                root.processConfirmKey = key;
                root._scheduleResultsUpdate();
            }
        });
    }

    function generatorEntries(queryText: string): var {
        if (!Config.options.search.modules.generators.enable)
            return [];
        const query = String(queryText ?? "").trim().toLocaleLowerCase();
        if (query.length < 2)
            return [];
        const genericTerms = ["generator", "generators", "generate", "gerador", "geradores", "gerar"];
        const isGeneric = genericTerms.some(term => term === query);
        const subject = genericTerms.reduce((value, term) => value.replace(new RegExp("^" + term + "\\s+"), ""), query).trim();
        return [
            { id: "uuid", name: Translation.tr("Generate UUID"), keywords: ["uuid", "guid"], icon: "fingerprint" },
            { id: "password", name: Translation.tr("Generate password"), keywords: ["password", "senha", "pass"], icon: "password" },
            { id: "lorem", name: Translation.tr("Generate Lorem Ipsum"), keywords: ["lorem", "ipsum", "text"], icon: "notes" }
        ].filter(entry => isGeneric || entry.keywords.some(keyword => keyword.includes(subject) || subject.includes(keyword)));
    }

    function generatorValue(id) {
        if (id === "uuid") {
            const hex = () => Math.floor(Math.random() * 16).toString(16);
            return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, key => key === "x" ? hex() : (8 + Math.floor(Math.random() * 4)).toString(16));
        }
        if (id === "password") {
            const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
            let value = "";
            for (let index = 0; index < 20; index++)
                value += alphabet[Math.floor(Math.random() * alphabet.length)];
            return value;
        }
        return "Lorem ipsum dolor sit amet, consectetur adipiscing elit.";
    }

    function createGeneratorResult(entry: var): var {
        return resultComp.createObject(null, {
            key: "generator:" + entry.id,
            name: entry.name,
            type: Translation.tr("Generator"),
            verb: Translation.tr("Copy"),
            iconName: entry.icon,
            iconType: LauncherSearchResult.IconType.Material,
            comment: Translation.tr("Press Enter to generate and copy locally"),
            keepOverviewOpen: true,
            feedbackText: Translation.tr("Generated value copied to clipboard"),
            execute: () => Quickshell.clipboardText = root.generatorValue(entry.id)
        });
    }

    function modeMatches(queryText: string): var {
        if (!Config.options.modes.enable)
            return [];
        const query = String(queryText ?? "").trim().toLocaleLowerCase();
        if (query.length < 2)
            return [];
        return Array.from(Modes.modes ?? []).filter(mode => [mode?.name, mode?.id, mode?.description].join(" ").toLocaleLowerCase().includes(query));
    }

    function createModeResult(mode: var): var {
        const active = Modes.activeModeId === String(mode?.id ?? "");
        return resultComp.createObject(null, {
            key: "mode:" + String(mode?.id ?? ""), name: String(mode?.name ?? ""), type: Translation.tr("Mode"),
            verb: active ? Translation.tr("Turn off") : Translation.tr("Activate"), iconName: String(mode?.icon ?? "routine"),
            iconType: LauncherSearchResult.IconType.Material, comment: String(mode?.description ?? ""), keepOverviewOpen: true,
            execute: () => Modes.toggle(String(mode?.id ?? ""))
        });
    }

    function bluetoothMatches(queryText: string): var {
        if (!Config.options.search.modules.bluetooth)
            return [];
        const query = String(queryText ?? "").trim().toLocaleLowerCase();
        if (query.length < 2)
            return [];
        return Array.from(BluetoothStatus.friendlyDeviceList ?? []).filter(device => [device?.name, device?.address].join(" ").toLocaleLowerCase().includes(query));
    }

    function createBluetoothResult(device: var): var {
        return resultComp.createObject(null, {
            key: "bluetooth-device:" + String(device?.address ?? ""), name: String(device?.name ?? device?.address ?? ""),
            type: Translation.tr("Bluetooth device"), verb: device?.connected ? Translation.tr("Disconnect") : Translation.tr("Connect"),
            iconName: "bluetooth", iconType: LauncherSearchResult.IconType.Material,
            comment: String(device?.address ?? ""), keepOverviewOpen: true,
            execute: () => { if (device?.connected) device.disconnect(); else device.connect(); }
        });
    }

    function fallbackResults() {
        if (!Config.options.search.fallbacks.enable)
            return [];
        const actions = Array.from(Config.options.search.fallbacks.actions ?? []);
        const output = [];
        if (actions.includes("ai") && Ai.enabled)
            output.push(root.createResult({ key: "fallback:ai", name: Translation.tr("Ask AI"), type: Translation.tr("Fallback"), verb: Translation.tr("Open"), iconName: "auto_awesome", iconType: LauncherSearchResult.IconType.Material, keepOverviewOpen: true, execute: () => root.query = Config.options.search.prefix.ai + root.query }));
        if (actions.includes("web") && Config.options.search.modules.webSearch)
            output.push(root.createResult({ key: "fallback:web", name: Translation.tr("Search the web"), type: Translation.tr("Fallback"), verb: Translation.tr("Search"), iconName: "travel_explore", iconType: LauncherSearchResult.IconType.Material, execute: () => Qt.openUrlExternally(Config.options.search.engineBaseUrl + encodeURIComponent(root.query)) }));
        if (actions.includes("tasks") && SearchPanelRegistry.byId("tasks")?.enabled())
            output.push(root.createSearchPanelResult(SearchPanelRegistry.byId("tasks")));
        if (actions.includes("calendar") && SearchPanelRegistry.byId("calendar")?.enabled())
            output.push(root.createSearchPanelResult(SearchPanelRegistry.byId("calendar")));
        return output;
    }

    function cheatsheetTabMatches(queryText: string): var {
        const query = String(queryText ?? "").trim().toLocaleLowerCase();
        if (query.length < 2 || !Config.options.search.modules.cheatsheet.enable)
            return [];
        const tabs = [
            { id: "keybinds", label: Translation.tr("Keybinds"), icon: "keyboard", keywords: ["keybinds", "atalhos", "shortcuts", "binds"], enabled: true },
            { id: "email", label: Translation.tr("Email"), icon: "mail", keywords: ["gmail", "email", "inbox", "mail"], enabled: Config.options.cheatsheet.enableGmail },
            { id: "commands", label: Translation.tr("Commands"), icon: "terminal", keywords: ["commands", "comandos", "cmd"], enabled: Config.options.cheatsheet.enableCommands },
            { id: "timetable", label: Translation.tr("Timetable"), icon: "calendar_month", keywords: ["timetable", "horário", "aula", "agenda escolar"], enabled: Config.options.cheatsheet.enableTimetable },
            { id: "elements", label: Translation.tr("Elements"), icon: "experiment", keywords: ["periodic", "elements", "tabela periódica"], enabled: Config.options.cheatsheet.enablePeriodicTable },
            { id: "aminoAcids", label: Translation.tr("Amino acids"), icon: "biotech", keywords: ["amino", "aminoácidos", "protein"], enabled: Config.options.cheatsheet.enableAminoAcids },
            { id: "workspaces", label: Translation.tr("Workspaces"), icon: "dashboard", keywords: ["workspaces", "layouts", "perfis"], enabled: Config.options.cheatsheet.enableWorkspaceProfiles }
        ];
        return tabs.filter(tab => tab.enabled && tab.keywords.some(keyword => keyword.includes(query)));
    }

    // Instantly evaluate simple arithmetic using JS — no qalc needed
    // Only allows digits, basic operators, parens, dots, spaces — safe subset
    function jsEvalMath(expr) {
        expr = expr.trim();
        const prefixMath = Config.options.search.prefix.math;
        // Strip leading math prefix if present
        if (prefixMath && expr.startsWith(prefixMath))
            expr = expr.slice(prefixMath.length).trim();
        // Only allow safe chars: digits, operators, parens, dot, space
        const isSafe = /^[\d\s\+\-\*\/\.\(\)%]+$/.test(expr);
        const hasOp = /[\+\-\*\/\%]/.test(expr);
        if (!isSafe || !hasOp)
            return null;
        try {
            // eslint-disable-next-line no-eval
            const result = eval(expr);
            if (typeof result === 'number' && isFinite(result)) {
                // Format nicely: trim trailing zeros for floats
                return String(result);
            }
        } catch (e) {
            // Silently ignore eval errors
        }
        return null;
    }

    // https://specifications.freedesktop.org/menu/latest/category-registry.html
    property list<string> mainRegisteredCategories: ["AudioVideo", "Development", "Education", "Game", "Graphics", "Network", "Office", "Science", "Settings", "System", "Utility"]
    property list<string> appCategories: DesktopEntries.applications.values.reduce((acc, entry) => {
        for (const category of entry.categories) {
            if (!acc.includes(category) && mainRegisteredCategories.includes(category)) {
                acc.push(category);
            }
        }
        return acc;
    }, []).sort()

    // Load user action scripts from ~/.config/illogical-impulse/actions/
    // Uses FolderListModel to auto-reload when scripts are added/removed
    property var userActionScripts: {
        const actions = [];
        for (let i = 0; i < userActionsFolder.count; i++) {
            const fileName = userActionsFolder.get(i, "fileName");
            const filePath = userActionsFolder.get(i, "filePath");
            if (fileName && filePath) {
                const actionName = fileName.replace(/\.[^/.]+$/, ""); // strip extension
                actions.push({
                    action: actionName,
                    execute: (path => args => {
                                Quickshell.execDetached([path, ...(args ? args.split(" ") : [])]);
                            })(FileUtils.trimFileProtocol(filePath.toString()))
                });
            }
        }
        return actions;
    }

    FolderListModel {
        id: userActionsFolder
        folder: Qt.resolvedUrl(Directories.userActions)
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    property var searchActions: [
        {
            action: "accentcolor",
            execute: args => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", ...(args != '' ? [`${args}`] : [])]);
            }
        },
        {
            action: "dark",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
            }
        },
        {
            action: "konachanwallpaper",
            execute: () => {
                Quickshell.execDetached([Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")]);
            }
        },
        {
            action: "light",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
            }
        },
        {
            action: "superpaste",
            execute: args => {
                if (!/^(\d+)/.test(args.trim())) {
                    // Invalid if doesn't start with numbers
                    Quickshell.execDetached(["notify-send", Translation.tr("Superpaste"), Translation.tr("Usage: <tt>%1superpaste NUM_OF_ENTRIES[i]</tt>\nSupply <tt>i</tt> when you want images\nExamples:\n<tt>%1superpaste 4i</tt> for the last 4 images\n<tt>%1superpaste 7</tt> for the last 7 entries").arg(Config.options.search.prefix.action), "-a", "Shell"]);
                    return;
                }
                const syntaxMatch = /^(?:(\d+)(i)?)/.exec(args.trim());
                const count = syntaxMatch[1] ? parseInt(syntaxMatch[1]) : 1;
                const isImage = !!syntaxMatch[2];
                Cliphist.superpaste(count, isImage);
            }
        },
        {
            action: "todo",
            execute: args => {
                Todo.addTask(args);
            }
        },
        {
            action: "wallpaper",
            execute: () => {
                Hyprland.dispatch(`hl.dsp.global("quickshell:wallpaperSelectorToggle")`);
            }
        },
        {
            action: "settings",
            execute: () => {
                GlobalStates.policiesPanelOpen = !GlobalStates.policiesPanelOpen;
            }
        },
        {
            action: "wipeclipboard",
            execute: () => {
                Cliphist.wipe();
            }
        },
        {
            action: "genius",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "Genius API", Translation.tr("Usage: /genius YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "genius"], args.trim());
                Quickshell.execDetached(["notify-send", "Genius API", Translation.tr("API key saved!"), "-a", "Shell"]);
            }
        },
        {
            action: "songrec",
            execute: () => {
                SongRec.toggleRunning(true);
            }
        },
    ]

    // Combined built-in and user actions
    property var allActions: searchActions.concat(userActionScripts)

    property string mathResult: ""
    property string confirmKey: ""
    property bool clipboardWorkSafetyActive: {
        const enabled = Config.options.workSafety.enable.clipboard;
        const sensitiveNetwork = (StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
        return enabled && sensitiveNetwork;
    }

    function containsUnsafeLink(entry) {
        if (entry == undefined)
            return false;
        const unsafeKeywords = Config.options.workSafety.triggerCondition.linkKeywords;
        return StringUtils.stringListContainsSubstring(entry.toLowerCase(), unsafeKeywords);
    }

    Timer {
        id: nonAppResultsTimer
        interval: Math.max(150, Config.options.search.nonAppResultDelay)
        onTriggered: {
            let expr = root.query;
            if (expr.startsWith(Config.options.search.prefix.math))
                expr = expr.slice(Config.options.search.prefix.math.length);
            mathProc.calculateExpression(expr);
        }
    }

    onQueryChanged: {
        root.selectedResult = null;
        root.processConfirmKey = "";
        fileProc.running = false;
        mathProc.running = false; // Stop active math calculation instantly to resolve race conditions and QML coalescing

        // Files are the slow lane: a process launch and a filesystem walk. The
        // walk is queued, never run from the keystroke itself, and the in-flight
        // one was already cancelled above.
        const fileExpression = root.fileSearchExpression(root.query);
        root._fileQueryPrefixed = root.queryIsFileSearchPrefixed(root.query);
        const fileMinimum = root._fileQueryPrefixed
            ? 2
            : Math.max(2, Config.options.search.fileSearch?.minimumQueryLength ?? 3);
        if (fileExpression.length >= fileMinimum) {
            root._fileQuery = fileExpression;
            fileSearchDebounce.restart();
        } else {
            fileSearchDebounce.stop();
            root._fileQuery = "";
            if (root.fileResults.length > 0)
                root.fileResults = [];
        }

        if (!root.isMathQuery(root.query)) {
            root.mathResult = "";
        } else {
            // Try instant JS eval first for simple arithmetic
            const instant = root.jsEvalMath(root.query);
            if (instant !== null) {
                root.mathResult = instant;
            } else {
                root.mathResult = "";
                nonAppResultsTimer.restart();
            }
        }
        root.confirmKey = "";

        // Schedule results recomputation (debounced to avoid per-keystroke stutter)
        root._scheduleResultsUpdate();
    }

    Process {
        id: mathProc
        function calculateExpression(expression) {
            mathProc.running = false;
            mathProc.command = ["qalc", "-t", expression];
            mathProc.running = true;
        }
        stdout: StdioCollector {
            id: mathCollector
            onStreamFinished: {
                const r = mathCollector.text.trim();
                if (r.length > 0)
                    root.mathResult = r;
            }
        }
    }

    // ========== File search ==========
    //
    // Every other source in this service answers from memory. This one shells
    // out and walks a directory tree, so it is the only one that has to stay
    // off the keystroke path entirely: the query queues a walk, the rest of the
    // results render immediately, and the list simply grows when files arrive.
    property var fileResults: []
    property string _fileQuery: ""
    property bool _fileQueryPrefixed: false

    readonly property bool fileSearchInlineEnabled: Config.options.search.modules.fileSearch
        && (Config.options.search.fileSearch?.inlineResults ?? false)

    function queryIsFileSearchPrefixed(query: string): bool {
        const prefix = String(Config.options.search.prefix.fileSearch ?? "");
        return Config.options.search.modules.fileSearch && prefix.length > 0 && query.startsWith(prefix);
    }

    /**
     * The expression the walk should run for, or "" for "do not walk".
     *
     * The prefixed form is an explicit request and always runs. The inline form
     * is a side effect of an ordinary query, so it stays out of the way of text
     * that already belongs to something else — another prefix, or a sum.
     */
    function fileSearchExpression(query: string): string {
        if (root.queryIsFileSearchPrefixed(query))
            return query.slice(String(Config.options.search.prefix.fileSearch).length).trim();
        if (!root.fileSearchInlineEnabled)
            return "";
        if (root.queryUsesPrefix(query) || root.isMathQuery(query))
            return "";
        return query.trim();
    }

    /**
     * `fd --max-results` returns what it found first, not what fits best, so the
     * ordering has to be rebuilt here.
     *
     * A hit on the entry's own name is what the user meant; one that exists only
     * somewhere up the path is a weak fallback. Shallow beats deep — "downloads"
     * almost always means the folder, not a file six levels inside it.
     */
    function rankFilePaths(paths, query, limit): var {
        const tokens = String(query).toLowerCase().split(/\s+/).filter(token => token.length > 0);
        if (tokens.length === 0)
            return paths.slice(0, limit);

        const scored = [];
        for (let i = 0; i < paths.length; i++) {
            const path = paths[i];
            const trimmed = path.endsWith("/") ? path.slice(0, -1) : path;
            const base = trimmed.slice(trimmed.lastIndexOf("/") + 1).toLowerCase();

            let matchedInName = 0;
            for (let t = 0; t < tokens.length; t++) {
                if (base.indexOf(tokens[t]) !== -1)
                    matchedInName++;
            }

            let score = matchedInName * 200;
            if (matchedInName === tokens.length)
                score += 300;
            if (base.startsWith(tokens[0]))
                score += 200;
            if (base === tokens.join(" "))
                score += 400;
            score -= trimmed.split("/").length * 8;
            score -= base.length;

            scored.push({
                path: path,
                score: score
            });
        }
        scored.sort((a, b) => b.score - a.score);

        const ranked = [];
        for (let i = 0; i < scored.length && i < limit; i++)
            ranked.push(scored[i].path);
        return ranked;
    }

    function shortenHomePath(path: string): string {
        const home = FileUtils.trimFileProtocol(Directories.home);
        if (home.length > 0 && path.startsWith(home))
            return "~" + path.slice(home.length);
        return path;
    }

    /**
     * Symbol per file kind.
     *
     * Built once into a lookup rather than walked as a switch: it is consulted
     * for every file row of every result update, and a row without an icon reads
     * as a broken row.
     */
    readonly property var fileIconsByExtension: {
        const groups = [
            ["image", ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tif", "tiff", "svg", "svgz", "ico", "avif", "heic", "heif", "psd", "xcf", "raw", "cr2", "nef", "dng"]],
            ["movie", ["mp4", "mkv", "webm", "mov", "avi", "flv", "wmv", "m4v", "mpg", "mpeg", "3gp", "ogv", "ts", "m2ts"]],
            ["music_note", ["mp3", "flac", "wav", "ogg", "opus", "m4a", "aac", "wma", "aiff", "mid", "midi"]],
            ["picture_as_pdf", ["pdf"]],
            ["folder_zip", ["zip", "tar", "gz", "bz2", "xz", "zst", "7z", "rar", "tgz", "txz", "tbz", "lz4", "iso", "img", "dmg"]],
            ["article", ["doc", "docx", "odt", "rtf", "pages"]],
            ["table", ["xls", "xlsx", "ods", "csv", "tsv", "numbers"]],
            ["slideshow", ["ppt", "pptx", "odp", "key"]],
            ["description", ["txt", "md", "rst", "org", "log", "adoc", "tex", "nfo"]],
            ["code", ["qml", "js", "mjs", "cjs", "jsx", "ts", "tsx", "py", "rs", "go", "c", "h", "cpp", "hpp", "cc", "cxx", "java", "kt", "kts", "swift", "rb", "php", "lua", "pl", "sh", "bash", "zsh", "fish", "vim", "el", "scm", "hs", "ml", "ex", "exs", "dart", "scala", "r", "css", "scss", "html", "htm", "vue", "svelte"]],
            ["data_object", ["json", "jsonc", "yaml", "yml", "toml", "ini", "conf", "cfg", "xml", "plist", "env", "properties"]],
            ["database", ["db", "sqlite", "sqlite3", "sql", "parquet"]],
            ["font_download", ["ttf", "otf", "woff", "woff2", "ttc", "pfb"]],
            ["menu_book", ["epub", "mobi", "azw3", "djvu", "fb2", "cbz", "cbr"]],
            ["deployed_code", ["appimage", "exe", "msi", "deb", "rpm", "pkg", "apk", "flatpakref", "snap", "blend", "obj", "stl", "fbx", "gltf", "glb"]],
            ["subtitles", ["srt", "vtt", "ass", "ssa", "sub"]],
            ["key", ["pem", "crt", "cer", "gpg", "asc", "kdbx", "p12", "pub"]],
            ["hard_drive", ["qcow2", "vdi", "vmdk", "vhd", "vhdx"]],
            ["difference", ["patch", "diff"]],
            ["launch", ["desktop"]],
            ["science", ["ipynb"]],
            ["downloading", ["torrent"]]
        ];
        const map = ({});
        for (let g = 0; g < groups.length; g++) {
            const icon = groups[g][0];
            const extensions = groups[g][1];
            for (let e = 0; e < extensions.length; e++)
                map[extensions[e]] = icon;
        }
        return map;
    }

    // Formats Qt can decode for the row thumbnail. Deliberately narrower than
    // the icon map: an extension we cannot draw must fall back to its symbol
    // rather than leave the row's icon slot empty.
    readonly property var previewableExtensions: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tif", "tiff", "svg", "ico"]

    function fileExtensionOf(name: string): string {
        const dot = String(name).lastIndexOf(".");
        return dot > 0 ? String(name).slice(dot + 1).toLowerCase() : "";
    }

    function fileResultIcon(name: string, isDirectory: bool): string {
        if (isDirectory)
            return "folder";
        return root.fileIconsByExtension[root.fileExtensionOf(name)] ?? "draft";
    }

    /**
     * Path to draw in the row's icon slot, or "" to use the symbol.
     *
     * Images and vectors are the one case where the file *is* its own icon, and
     * they are also the case with no meaningful symbol to show. Everything else
     * keeps its symbol, and so does every image when previews are turned off.
     */
    function fileResultPreview(path: string, isDirectory: bool): string {
        if (isDirectory || Config.options.search.blurFileSearchResultPreviews)
            return "";
        return root.previewableExtensions.indexOf(root.fileExtensionOf(path)) !== -1 ? path : "";
    }

    Timer {
        id: fileSearchDebounce
        // The rest of the results are already on screen by the time this fires,
        // so the wait costs nothing the user can see — and a burst of keystrokes
        // starts one walk instead of one per letter.
        interval: 200
        repeat: false
        onTriggered: fileProc.searchFiles(root._fileQuery)
    }

    Process {
        id: fileProc

        /**
         * Whitespace-separated tokens become an ordered "contains" pattern, so
         * "project logo" finds "Project - Logo.png". Every token is regex
         * escaped: the query is user text, not a pattern, and a stray bracket
         * would otherwise make fd exit with an error instead of results.
         */
        function searchPattern(expression) {
            return String(expression).trim().split(/\s+/)
                .filter(token => token.length > 0)
                .map(token => token.replace(/[.*+?^${}()|[\]\\\/-]/g, "\\$&"))
                .join(".*");
        }

        function searchFiles(expression) {
            const pattern = fileProc.searchPattern(expression);
            if (pattern.length === 0)
                return;
            const settings = Config.options.search.fileSearch;
            const budget = Math.max(20, settings?.walkLimit ?? 60);
            // An explicit `,` query asked for files and nothing else, so it can
            // afford a wider walk than one riding along with an ordinary query.
            const walkLimit = root._fileQueryPrefixed ? budget * 4 : budget;

            // `--max-results` is the first half of the performance story: fd
            // quits as soon as it has enough instead of traversing the tree —
            // ~9ms against ~290ms on a real home directory.
            //
            // The second half is the query that matches almost nothing, which
            // never fills that budget and so pays for the whole walk anyway.
            // `--threads` bounds what that costs: measured on 16 cores, the
            // default saturated every one of them for 0.70s of CPU time, while
            // four threads did the same walk for 0.28s and 50ms more wall time.
            const command = ["fd", "--color", "never", "--absolute-path", "--max-results", String(walkLimit)];
            const threads = Math.max(0, settings?.threads ?? 4);
            if (threads > 0)
                command.push("--threads", String(threads));
            // An explicit `,` query is allowed to reach as deep as it likes.
            const maxDepth = root._fileQueryPrefixed ? 0 : Math.max(0, settings?.maxDepth ?? 0);
            if (maxDepth > 0)
                command.push("--max-depth", String(maxDepth));
            if (settings?.includeHidden === true)
                command.push("--hidden");
            const excluded = settings?.excludedDirectories ?? [];
            for (let i = 0; i < excluded.length; i++) {
                const directory = String(excluded[i] ?? "");
                if (directory.length > 0)
                    command.push("--exclude", directory);
            }
            command.push(pattern, Config.options.search.fileSearchDirectory);

            fileProc.running = false;
            fileProc.command = command;
            fileProc.running = true;
        }

        stdout: StdioCollector {
            id: fileCollector
            onStreamFinished: {
                const lines = fileCollector.text.split("\n").filter(line => line.length > 0);
                const settings = Config.options.search.fileSearch;
                const limit = root._fileQueryPrefixed ? 60 : Math.max(1, settings?.maxResults ?? 8);
                root.fileResults = root.rankFilePaths(lines, root._fileQuery, limit);
            }
        }
    }

    // ========== Window Search ==========
    function getWindowResults(searchString) {
        const windows = HyprlandData.windowList || [];
        if (searchString === "")
            return windows;
        const lower = searchString.toLowerCase();
        return windows.filter(w => {
            const title = (w.title || "").toLowerCase();
            const cls = (w.class || "").toLowerCase();
            return title.includes(lower) || cls.includes(lower);
        });
    }

    // ========== Shell Snippets ==========
    function getShellSnippetActions() {
        const snippets = Config.options?.search?.shellSnippets ?? [];
        return snippets.map(snippet => ({
                    action: snippet.alias || snippet.name || "snippet",
                    name: snippet.name || snippet.alias || "Shell Snippet",
                    command: snippet.command || "",
                    execute: args => {
                        let cmd = snippet.command || "";
                        if (args)
                            cmd += " " + args;
                        Quickshell.execDetached(["bash", "-c", cmd]);
                    }
                }));
    }

    function appResultKey(app) {
        return "app:" + (app && app.id ? app.id : "");
    }

    function createAppResultObject(entry) {
        return resultComp.createObject(null, {
            key: root.appResultKey(entry),
            type: Translation.tr("App"),
            id: entry.id,
            name: entry.name,
            iconName: entry.icon,
            iconType: LauncherSearchResult.IconType.System,
            verb: Translation.tr("Open"),
            execute: () => {
                AppUsage.recordLaunch(entry.id);
                if (!entry.runInTerminal)
                    entry.execute();
                else {
                    Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(entry.command.join(' '))}'`]);
                }
            },
            comment: entry.comment,
            runInTerminal: entry.runInTerminal,
            genericName: entry.genericName,
            keywords: entry.keywords,
            actions: entry.actions.map(action => {
                return resultComp.createObject(null, {
                    name: action.name,
                    iconName: action.icon,
                    iconType: LauncherSearchResult.IconType.System,
                    execute: () => {
                        if (!action.runInTerminal)
                            action.execute();
                        else {
                            Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(action.command.join(' '))}'`]);
                        }
                    }
                });
            })
        });
    }

    // Results are rebuilt once per event-loop turn. The previous scheduler
    // computed immediately and then armed a second 16ms recomputation, which
    // made every normal keystroke do the expensive fuzzy search twice.
    property list<var> results: []
    property bool _resultsUpdateQueued: false

    function _scheduleResultsUpdate() {
        if (root._resultsUpdateQueued)
            return;

        root._resultsUpdateQueued = true;
        Qt.callLater(function () {
            root._resultsUpdateQueued = false;
            root.results = root._computeResults();
        });
    }

    // Re-schedule when reactive sources (other than query) change
    onMathResultChanged: _scheduleResultsUpdate()
    onFileResultsChanged: _scheduleResultsUpdate()
    onMprisTriggerChanged: _scheduleResultsUpdate()

    function _computeResults() {
        let _apps = AppSearch.list; // Keep reference for reactive tracking (unused directly)

        ////////////////// MPRIS (empty query) //////////////////
        if (root.query === "") {
            let mprisResults = [];
            if (Config.options.search.showNowPlayingBubble && MprisController.activePlayer) {
                const player = MprisController.activePlayer;
                const title = player.trackTitle || Translation.tr("Unknown");
                const artist = player.trackArtist || "";
                const displayName = artist ? `${title} — ${artist}` : title;

                mprisResults.push(resultComp.createObject(null, {
                    key: "mpris:now-playing",
                    name: displayName,
                    type: Translation.tr("Now Playing"),
                    verb: MprisController.isPlaying ? Translation.tr("Pause") : Translation.tr("Play"),
                    iconName: MprisController.isPlaying ? "pause" : "play_arrow",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        MprisController.togglePlaying();
                    },
                    actions: [resultComp.createObject(null, {
                            name: Translation.tr("Previous"),
                            iconName: "skip_previous",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                MprisController.previous();
                            }
                        }), resultComp.createObject(null, {
                            name: Translation.tr("Next"),
                            iconName: "skip_next",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                MprisController.next();
                            }
                        })]
                }));
            }

            if (Config.options.search.alwaysListApps) {
                const appResultObjects = AppSearch.fuzzyQuery("").slice(0, 60).map(entry => root.createAppResultObject(entry));
                return mprisResults.concat(appResultObjects);
            }

            return mprisResults;
        }

        ///////////// Special cases ///////////////
        if (Config.options.search.modules.clipboard && root.query.startsWith(Config.options.search.prefix.clipboard)) {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.clipboard);

            const pinnedMatches = Cliphist.pinnedEntries.filter(e => {
                if (searchString === "")
                    return true;
                return e.toLowerCase().includes(searchString.toLowerCase());
            });

            const fuzzyResults = Cliphist.fuzzyQuery(searchString).filter(e => !Cliphist.isPinned(e));
            const allResults = pinnedMatches.concat(fuzzyResults);

            return allResults.slice(0, 60).map((entry, index, array) => {
                const isPinned = index < pinnedMatches.length;
                const mightBlurImage = Cliphist.entryIsImage(entry) && root.clipboardWorkSafetyActive;
                let shouldBlurImage = mightBlurImage;
                if (mightBlurImage) {
                    shouldBlurImage = shouldBlurImage && (root.containsUnsafeLink(array[index - 1]) || root.containsUnsafeLink(array[index + 1]));
                }
                const type = `#${entry.match(/^\s*(\S+)/)?.[1] || ""}`;
                const contentType = Cliphist.classifyEntry(entry);
                return resultComp.createObject(null, {
                    key: "clip:" + entry.split("\t")[0],
                    rawValue: entry,
                    name: StringUtils.cleanCliphistEntry(entry),
                    verb: "",
                    type: type,
                    pinned: isPinned,
                    category: contentType || "clipboard",
                    execute: () => {
                        Cliphist.copy(entry);
                    },
                    actions: [resultComp.createObject(null, {
                            name: Translation.tr("Copy"),
                            iconName: "content_copy",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Cliphist.copy(entry);
                            }
                        }), resultComp.createObject(null, {
                            name: isPinned ? Translation.tr("Unpin") : Translation.tr("Pin"),
                            iconName: isPinned ? "keep_off" : "keep",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                if (isPinned)
                                    Cliphist.unpin(entry);
                                else
                                    Cliphist.pin(entry);
                            }
                        }), resultComp.createObject(null, {
                            name: Translation.tr("Delete"),
                            iconName: "delete",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Cliphist.deleteEntry(entry);
                            }
                        })],
                    blurImage: shouldBlurImage
                });
            }).filter(Boolean);
        } else if (Config.options.search.modules.emojis.enable && root.query.startsWith(Config.options.search.prefix.emojis)) {
            // `:` resolves to the registered grid panel. Keeping this branch
            // empty prevents a second, hidden list of emoji rows from being
            // built on every query.
            return [];
        } else if (Config.options.search.modules.windowSearch && root.query.startsWith(Config.options.search.prefix.windowSearch)) {
            const searchString = root.query.slice(Config.options.search.prefix.windowSearch.length);
            const windows = getWindowResults(searchString);
            return windows.map(w => {
                return resultComp.createObject(null, {
                    key: "win:" + (w.address || w.title || w.class),
                    name: w.title || w.class || "Unknown",
                    type: Translation.tr("Window"),
                    verb: Translation.tr("Focus"),
                    iconName: AppSearch.guessIcon(w.class || ""),
                    iconType: LauncherSearchResult.IconType.System,
                    comment: `${w.class} — Workspace ${w.workspace?.id ?? "?"}`,
                    execute: () => {
                        Hyprland.dispatch(`hl.dsp.focus({window = "address:${w.address}"})`);
                    },
                    actions: [resultComp.createObject(null, {
                            name: Translation.tr("Close"),
                            iconName: "close",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Hyprland.dispatch(`hl.dsp.window.close({window = "address:${w.address}"})`);
                            }
                        }), resultComp.createObject(null, {
                            name: Translation.tr("Move here"),
                            iconName: "move_item",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                const activeWsId = Hyprland.focusedMonitor?.activeWorkspace?.id;
                                if (activeWsId) {
                                    Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${activeWsId}, follow = false, window = "address:${w.address}" })`);
                                } else {
                                    Hyprland.dispatch(`hl.dsp.window.move({ workspace = "e+0", follow = false, window = "address:${w.address}" })`);
                                }
                            }
                        }), resultComp.createObject(null, {
                            name: Translation.tr("Copy title"),
                            iconName: "content_copy",
                            iconType: LauncherSearchResult.IconType.Material,
                            execute: () => {
                                Quickshell.clipboardText = w.title || w.class || "";
                            }
                        })]
                });
            }).filter(Boolean);
        }

        ////////////////// Init ///////////////////
        // NOTE: nonAppResultsTimer is restarted in onQueryChanged, not here
        const mathResultObject = root.mathResult ? resultComp.createObject(null, {
            key: "math:" + root.mathResult,
            name: root.mathResult,
            verb: Translation.tr("Copy"),
            type: Translation.tr("Math result"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'calculate',
            iconType: LauncherSearchResult.IconType.Material,
            isMath: Config.options.search.enableMathPreview,
            execute: () => {
                Quickshell.clipboardText = root.mathResult;
            }
        }) : null;
        const fileResultsObject = root.fileResults.map(entry => {
            // fd already marks directories with a trailing separator, so the
            // type comes back for free — no stat, no second process.
            const isDirectory = entry.endsWith("/");
            const path = isDirectory ? entry.slice(0, -1) : entry;
            const separator = path.lastIndexOf("/");
            const displayName = separator >= 0 ? path.slice(separator + 1) : path;
            const parent = separator > 0 ? path.slice(0, separator) : "/";
            const preview = root.fileResultPreview(path, isDirectory);
            return resultComp.createObject(null, {
                key: "fsearch:" + entry,
                // "Directory" is the type SearchItem keys its folder actions off.
                type: isDirectory ? Translation.tr("Directory") : Translation.tr("File"),
                // The row has two lines; a bare path wastes both. The name is
                // what the user typed towards, the location is the context.
                name: displayName,
                comment: root.shortenHomePath(parent),
                category: "filepath",
                filePath: path,
                verb: Translation.tr("Open"),
                // An image is its own icon; everything else gets the symbol for
                // its kind. Either way the row's icon slot is filled — a file
                // row with an empty slot reads as a broken row.
                iconName: preview.length > 0 ? preview : root.fileResultIcon(displayName, isDirectory),
                iconType: preview.length > 0 ? LauncherSearchResult.IconType.Image : LauncherSearchResult.IconType.Material,
                fallbackIconName: root.fileResultIcon(displayName, isDirectory),
                execute: () => {
                    Quickshell.execDetached(["xdg-open", path]);
                },
                actions: [resultComp.createObject(null, {
                        name: Translation.tr("Copy path"),
                        iconName: "content_copy",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.clipboardText = path;
                        }
                    }), resultComp.createObject(null, {
                        name: isDirectory ? Translation.tr("Open in file manager") : Translation.tr("Open folder"),
                        iconName: "folder_open",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            Quickshell.execDetached(["xdg-open", isDirectory ? path : parent]);
                        }
                    }), resultComp.createObject(null, {
                        name: Translation.tr("Browse here"),
                        iconName: "folder_data",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => {
                            const home = FileUtils.trimFileProtocol(Directories.home);
                            const target = isDirectory ? path : parent;
                            root.query = Config.options.search.prefix.fileBrowser + target.replace(home, "") + "/";
                        }
                    })]
            });
        });

        // MPRIS handled above (empty query case)

        const appResultObjects = AppSearch.fuzzyQuery(StringUtils.cleanPrefix(root.query, Config.options.search.prefix.app)).slice(0, 60).map(entry => root.createAppResultObject(entry));
        const settingsSearchActive = root.isSettingsSearchQuery(root.query)
            && Config.options.search.modules.settingsToggles.enable;
        const settingsMatches = settingsSearchActive && root.settingsIndexReady
            ? Ai.settingsIntegration.search(root.query, 100)
            : [];
        if (settingsSearchActive && !root.settingsIndexReady)
            Ai.settingsIntegration.ensureIndex();
        const maxInlineSettings = Math.max(0, Config.options.search.modules.settingsToggles.maxInlineResults);
        const settingsResultObjects = settingsSearchActive && maxInlineSettings > 0
            ? settingsMatches.slice(0, maxInlineSettings).map(setting => root.createSettingsResultObject(setting))
            : [];
        const settingsPanelResultObjects = settingsSearchActive && maxInlineSettings === 0
            && (!root.settingsIndexReady || settingsMatches.length > 0)
            ? [root.createSettingsPanelResultObject(settingsMatches.length)]
            : [];
        const commandResultObject = resultComp.createObject(null, {
            key: "cmd:shell",
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.shellCommand).replace("file://", ""),
            verb: Translation.tr("Run"),
            type: Translation.tr("Command"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: 'terminal',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let cleanedCommand = root.query.replace("file://", "");
                cleanedCommand = StringUtils.cleanPrefix(cleanedCommand, Config.options.search.prefix.shellCommand);
                if (cleanedCommand.startsWith(Config.options.search.prefix.shellCommand)) {
                    cleanedCommand = cleanedCommand.slice(Config.options.search.prefix.shellCommand.length);
                }
                Quickshell.execDetached(["bash", "-c", root.query.startsWith('sudo') ? `${Config.options.apps.terminal} fish -C '${cleanedCommand}'` : cleanedCommand]);
            }
        });
        const webSearchResultObject = resultComp.createObject(null, {
            key: "web:search",
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch),
            verb: Translation.tr("Search"),
            type: Translation.tr("Web search"),
            iconName: 'travel_explore',
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let query = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch);
                let url = Config.options.search.engineBaseUrl + query;
                for (let site of Config.options.search.excludedSites) {
                    url += ` -site:${site}`;
                }
                Qt.openUrlExternally(url);
            }
        });
        const aiAskResultObject = resultComp.createObject(null, {
            key: "ai:ask",
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.ai),
            verb: Translation.tr("Ask"),
            type: Translation.tr("AI chat"),
            iconName: 'auto_awesome',
            iconType: LauncherSearchResult.IconType.Material,
            keepOverviewOpen: true,
            execute: () => {
                const query = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.ai);
                // Defer: mutating the query synchronously rebuilds the result
                // list and destroys this delegate while its click event is
                // still being processed, which can re-dispatch the click onto
                // whatever row lands under the cursor and immediately undo
                // the mode switch.
                Qt.callLater(() => {
                    root.query = Config.options.search.prefix.ai + query;
                });
            }
        });
        const launcherActionObjects = root.allActions.map(action => {
            const actionString = `${Config.options.search.prefix.action}${action.action}`;
            if (actionString.startsWith(root.query) || root.query.startsWith(actionString)) {
                return resultComp.createObject(null, {
                    key: "action:" + action.action,
                    name: root.query.startsWith(actionString) ? root.query : actionString,
                    verb: Translation.tr("Run"),
                    type: Translation.tr("Action"),
                    iconName: 'settings_suggest',
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        action.execute(root.query.split(" ").slice(1).join(" "));
                    }
                });
            }
            return null;
        }).filter(Boolean);

        // Shell snippet results
        const snippetActions = getShellSnippetActions();
        const shellSnippetObjects = snippetActions.map(snippet => {
            const snippetString = `${Config.options.search.prefix.action}${snippet.action}`;
            if (snippetString.startsWith(root.query) || root.query.startsWith(snippetString)) {
                return resultComp.createObject(null, {
                    key: "snippet:" + snippet.action,
                    name: snippet.name,
                    verb: Translation.tr("Run"),
                    type: Translation.tr("Script"),
                    iconName: 'code',
                    iconType: LauncherSearchResult.IconType.Material,
                    comment: snippet.command,
                    execute: () => {
                        snippet.execute(root.query.split(" ").slice(1).join(" "));
                    }
                });
            }
            return null;
        }).filter(Boolean);

        //////// Prioritized by prefix /////////
        let result = [];

        if (root.query.trim().length === 0)
            result = result.concat(root.favoriteResults());

        // App/Folder/Command Aliases
        const aliases = Config.options?.search?.aliases ?? [];
        const aliasObjects = aliases.map(entry => {
            if (entry.alias && entry.alias.toLowerCase() === root.query.toLowerCase()) {
                if (entry.type === "app") {
                    const app = DesktopEntries.byId(entry.target);
                    if (app) {
                        return resultComp.createObject(null, {
                            key: root.appResultKey(app),
                            id: app.id,
                            name: app.name,
                            iconName: app.icon,
                            iconType: LauncherSearchResult.IconType.System,
                            verb: Translation.tr("Open"),
                            type: Translation.tr("App Alias"),
                            execute: () => {
                                AppUsage.recordLaunch(app.id);
                                if (!app.runInTerminal)
                                    app.execute();
                                else
                                    Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(app.command.join(' '))}'`]);
                            }
                        });
                    }
                } else if (entry.type === "folder") {
                    return resultComp.createObject(null, {
                        key: "alias:" + entry.alias,
                        name: entry.target,
                        iconName: "folder",
                        iconType: LauncherSearchResult.IconType.Material,
                        verb: Translation.tr("Browse"),
                        type: Translation.tr("Folder Alias"),
                        execute: () => {
                            root.query = Config.options.search.prefix.fileBrowser + entry.target;
                        }
                    });
                } else if (entry.type === "command") {
                    return resultComp.createObject(null, {
                        key: "alias:" + entry.alias,
                        name: entry.target,
                        iconName: "terminal",
                        iconType: LauncherSearchResult.IconType.Material,
                        verb: Translation.tr("Run"),
                        type: Translation.tr("Command Alias"),
                        execute: () => {
                            Quickshell.execDetached(["bash", "-c", entry.target]);
                        }
                    });
                } else if (entry.type === "builtin") {
                    let verb = Translation.tr("Open");
                    let icon = "explore";
                    let typeName = Translation.tr("Mode");
                    let name = entry.target;
                    let execFunc = () => {};
                    const registeredPanel = SearchPanelRegistry.byId(entry.target);

                    if (registeredPanel?.hosted === true) {
                        icon = registeredPanel.icon;
                        name = registeredPanel.label;
                        typeName = Translation.tr("Search panel");
                        execFunc = () => {
                            root.query = "";
                            GlobalStates.openSearchPanel(registeredPanel.id);
                        };
                    } else if (entry.target === "clipboard") {
                        icon = "content_paste";
                        name = Translation.tr("Clipboard");
                        execFunc = () => {
                            root.query = Config.options.search.prefix.clipboard;
                        };
                    } else if (entry.target === "emojis") {
                        icon = "mood";
                        name = Translation.tr("Emojis");
                        execFunc = () => {
                            root.query = Config.options.search.prefix.emojis;
                        };
                    } else if (entry.target === "math") {
                        icon = "calculate";
                        name = Translation.tr("Calculator");
                        execFunc = () => {
                            root.query = Config.options.search.prefix.math;
                        };
                    } else if (entry.target === "settings") {
                        icon = "settings";
                        name = Translation.tr("Dotfiles Settings");
                        typeName = Translation.tr("Settings");
                        execFunc = () => {
                            GlobalStates.overviewOpen = false;
                            GlobalStates.openSettings();
                        };
                    } else if (entry.target === "bluetooth") {
                        icon = "bluetooth";
                        name = Translation.tr("Bluetooth Manager");
                        typeName = Translation.tr("Settings");
                        execFunc = () => {
                            root.query = Config.options.search.prefix.bluetooth;
                        };
                    } else if (entry.target === "translator") {
                        icon = "translate";
                        name = Translation.tr("Translator");
                        typeName = Translation.tr("Tool");
                        execFunc = () => {
                            root.query = Config.options.search.prefix.translator;
                        };
                    }

                    return resultComp.createObject(null, {
                        key: "mock:" + entry.target,
                        name: name,
                        iconName: icon,
                        iconType: LauncherSearchResult.IconType.Material,
                        verb: verb,
                        type: typeName,
                        comment: Translation.tr("Alias: ") + entry.alias,
                        isBuiltin: true,
                        execute: execFunc
                    });
                }
            }
            return null;
        }).filter(Boolean);
        result = result.concat(aliasObjects);

        const isMath = root.isMathQuery(root.query);
        const startsWithShellCommandPrefix = Config.options.search.modules.shellCommand
            && root.query.startsWith(Config.options.search.prefix.shellCommand);
        const startsWithWebSearchPrefix = Config.options.search.modules.webSearch
            && root.query.startsWith(Config.options.search.prefix.webSearch);

        // System Controls matches
        const systemControlResults = [];
        let queryClean = root.query.toLowerCase().trim();
        const hasColonPrefix = queryClean.startsWith(":");
        if (hasColonPrefix) {
            queryClean = queryClean.slice(1);
        }

        if (Config.options.search.modules.systemControls && (hasColonPrefix || queryClean.length >= 2)) {
            const sysCommands = [
                {
                    cmd: "lock",
                    label: Translation.tr("Lock Screen"),
                    execute: () => Quickshell.execDetached(["hyprlock"]),
                    icon: "lock",
                    desc: Translation.tr("Lock the current session")
                },
                {
                    cmd: "poweroff",
                    label: Translation.tr("Shutdown PC"),
                    execute: () => Quickshell.execDetached(["systemctl", "poweroff"]),
                    icon: "power_settings_new",
                    desc: Translation.tr("Power off the computer")
                },
                {
                    cmd: "reboot",
                    label: Translation.tr("Reboot PC"),
                    execute: () => Quickshell.execDetached(["systemctl", "reboot"]),
                    icon: "restart_alt",
                    desc: Translation.tr("Restart the computer")
                },
                {
                    cmd: "suspend",
                    label: Translation.tr("Suspend PC"),
                    execute: () => Quickshell.execDetached(["systemctl", "suspend"]),
                    icon: "bedtime",
                    desc: Translation.tr("Put the computer to sleep")
                },
                {
                    cmd: "restart",
                    label: Translation.tr("Restart Quickshell"),
                    execute: () => Quickshell.reload(),
                    icon: "refresh",
                    desc: Translation.tr("Restart Quickshell shell seamlessly")
                },
            ];
            const matches = sysCommands.filter(c => c.cmd.startsWith(queryClean));
            for (const match of matches) {
                const isPendingConfirm = root.confirmKey === match.cmd;
                systemControlResults.push(resultComp.createObject(null, {
                    key: "sys:" + match.cmd,
                    name: isPendingConfirm ? match.label + " (" + Translation.tr("Are you sure?") + ")" : match.label,
                    type: Translation.tr("System Control"),
                    comment: isPendingConfirm ? Translation.tr("Press Enter again to confirm") : match.desc,
                    verb: isPendingConfirm ? Translation.tr("Confirm") : Translation.tr("Execute"),
                    iconName: match.icon,
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => {
                        if (root.confirmKey === match.cmd) {
                            root.confirmKey = "";
                            match.execute();
                        } else {
                            root.confirmKey = match.cmd;
                        }
                    }
                }));
            }
        }

        if (systemControlResults.length > 0) {
            result = result.concat(systemControlResults);
        }

        if (isMath && mathResultObject) {
            result.push(mathResultObject);
        } else if (startsWithShellCommandPrefix) {
            result.push(commandResultObject);
        } else if (startsWithWebSearchPrefix) {
            result.push(webSearchResultObject);
        }

        //////////////// Files /////////////////
        if (Config.options.search.modules.fileSearch)
            result = result.concat(fileResultsObject);

        //////////////// Apps //////////////////
        result = result.concat(appResultObjects);

        ////////////// Settings //////////////////
        // App rows remain the primary launcher results. Settings matches are
        // useful controls in the same list, but belong after the programs
        // rather than displacing them at the top of every broad query.
        result = result.concat(settingsResultObjects);
        result = result.concat(settingsPanelResultObjects);

        ////////// Cheat Sheet tabs //////////
        for (const tab of root.cheatsheetTabMatches(root.query)) {
            result.push(resultComp.createObject(null, {
                key: "cheatsheet:" + tab.id,
                name: tab.label,
                type: Translation.tr("Cheat Sheet"),
                verb: Translation.tr("Open"),
                iconName: tab.icon,
                iconType: LauncherSearchResult.IconType.Material,
                comment: Translation.tr("Cheat Sheet"),
                execute: () => GlobalStates.openCheatsheet(tab.id)
            }));
        }

        ////////// Hyprland keybinds //////////
        if (Config.options.search.modules.keybinds.enable && root.isSettingsSearchQuery(root.query)) {
            for (const binding of root.keybindMatches(root.query, 3))
                result.push(root.createKeybindResultObject(binding));
        }

        if (root.query.trim().length >= 2) {
            for (const panel of root.searchPanelMatches(root.query))
                result.push(root.createSearchPanelResult(panel));
        }

        for (const game of root.liveSportsResults(root.query))
            result.push(root.createLiveSportsResult(game));

        for (const quicklink of root.quicklinkMatches(root.query))
            result.push(root.createQuicklinkResult(quicklink));

        // Panels with no prefix stay discoverable through explicit, compact
        // rows; their query is preserved as the panel's own filter.
        const naturalQuery = root.query.trim().toLocaleLowerCase();
        if (Config.options.search.modules.settingsToggles.enable
                && settingsPanelResultObjects.length === 0
                && ["settings", "config", "configurar", "dotfiles"].some(keyword => keyword.includes(naturalQuery))) {
            result.push(root.createSettingsPanelResultObject(0));
        }
        if (Config.options.search.modules.keybinds.enable
                && ["keybind", "keybinds", "atalho", "shortcuts", "bind"].some(keyword => keyword.includes(naturalQuery))) {
            result.push(resultComp.createObject(null, {
                key: "panel:keybinds",
                name: Translation.tr("Keybinds"),
                type: Translation.tr("Keybinds"),
                verb: Translation.tr("Open"),
                iconName: "keyboard",
                iconType: LauncherSearchResult.IconType.Material,
                comment: Translation.tr("Search all Hyprland shortcuts"),
                panelId: "keybinds",
                keepOverviewOpen: true,
                execute: () => GlobalStates.openSearchPanel("keybinds")
            }));
        }

        ////////// Quick toggles //////////
        if (Config.options.search.modules.quickToggles.enable && root.query.trim().length >= 2) {
            const quickToggleQuery = root.query.trim().toLowerCase();
            for (const entry of QuickToggleRegistry.entries) {
                const model = entry.model;
                const matchesKeyword = entry.keywords.some(keyword => String(keyword).toLowerCase().includes(quickToggleQuery));
                const matchesName = String(model.name).toLowerCase().includes(quickToggleQuery);
                if (!matchesKeyword && !matchesName)
                    continue;
                result.push(resultComp.createObject(null, {
                    key: "qtoggle:" + entry.id,
                    name: model.name,
                    type: Translation.tr("Quick Toggle"),
                    comment: model.statusText,
                    iconName: model.icon,
                    iconType: LauncherSearchResult.IconType.Material,
                    verb: model.toggled ? Translation.tr("Disable") : Translation.tr("Enable"),
                    keepOverviewOpen: true,
                    controlKind: "switch",
                    controlValue: model.toggled,
                    execute: () => model.mainAction()
                }));
            }
        }

        ////////// Shell actions //////////
        if (Config.options.search.modules.shellActions && root.query.trim().length >= 2) {
            const shellActionQuery = root.query.trim().toLowerCase();
            for (const action of ShellActionRegistry.actions) {
                if (!action.searchable || !action.enabled())
                    continue;
                const matches = action.keywords.some(keyword => String(keyword).toLowerCase().includes(shellActionQuery));
                if (!matches)
                    continue;
                result.push(resultComp.createObject(null, {
                    key: "shell:" + action.id,
                    name: Translation.tr(action.name),
                    type: Translation.tr("Shell"),
                    comment: Translation.tr(action.category),
                    iconName: action.icon,
                    iconType: LauncherSearchResult.IconType.Material,
                    verb: Translation.tr("Open"),
                    controlKind: action.id === "barToggle" ? "switch" : "",
                    controlValue: action.id === "barToggle" ? GlobalStates.barOpen : null,
                    keepOverviewOpen: action.id === "barToggle",
                    execute: () => ShellActionRegistry.trigger(action.id)
                }));
            }
        }

        ////////// Launcher actions ////////////
        result = result.concat(launcherActionObjects);

        ////////// Shell snippets //////////////
        result = result.concat(shellSnippetObjects);

        ////////// Text snippets ///////////////
        for (const snippet of root.snippetMatches(root.query))
            result.push(root.createSnippetResult(snippet));

        ////////// Processes ///////////////////
        for (const process of root.processMatches(root.query))
            result.push(root.createProcessResult(process));

        ////////// Modes & routines ////////////
        for (const mode of root.modeMatches(root.query))
            result.push(root.createModeResult(mode));

        ////////// Bluetooth devices ///////////
        for (const device of root.bluetoothMatches(root.query))
            result.push(root.createBluetoothResult(device));

        ////////// Local generators ////////////
        for (const entry of root.generatorEntries(root.query))
            result.push(root.createGeneratorResult(entry));

        ////////// Module shortcuts ////////////
        // Typing module names shows a shortcut to switch to that mode
        const moduleShortcuts = [
            {
                names: ["clipboard", "clip", "paste", "copiar"],
                prefix: Config.options.search.prefix.clipboard,
                label: Translation.tr("Clipboard"),
                icon: "content_paste",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.clipboard
            },
            {
                names: ["emoji", "emojis", "emoticon"],
                prefix: Config.options.search.prefix.emojis,
                label: Translation.tr("Emojis"),
                icon: "mood",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.emojis.enable
            },
            {
                names: ["window", "windows", "janela"],
                prefix: Config.options.search.prefix.windowSearch,
                label: Translation.tr("Window Search"),
                icon: "select_window",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.windowSearch
            },
            {
                names: ["file", "files", "arquivo", "browse"],
                prefix: Config.options.search.prefix.fileBrowser,
                label: Translation.tr("File Browser"),
                icon: "folder_open",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.fileBrowser
            },
            {
                names: ["math", "calc", "calculator", "calcular"],
                prefix: Config.options.search.prefix.math,
                label: Translation.tr("Calculator"),
                icon: "calculate",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.math
            },
            {
                names: ["command", "commands", "terminal", "shell"],
                prefix: Config.options.search.prefix.shellCommand,
                label: Translation.tr("Shell Command"),
                icon: "terminal",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.shellCommand
            },
            {
                names: ["bluetooth"],
                prefix: Config.options.search.prefix.bluetooth,
                label: Translation.tr("Bluetooth Manager"),
                icon: "bluetooth",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.bluetooth
            },
            {
                names: ["translator", "translate", "tradutor", "traduzir"],
                prefix: Config.options.search.prefix.translator,
                label: Translation.tr("Translator"),
                icon: "translate",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.translator
            },
            {
                names: ["material symbols", "icons", "material", "symbols"],
                prefix: Config.options.search.prefix.materialSymbols,
                label: Translation.tr("Material Symbols"),
                icon: "font_download",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.materialSymbols
            },
            {
                names: ["download", "media downloader", "video download"],
                prefix: Config.options.search.prefix.mediaDownloader,
                label: Translation.tr("Media Downloader"),
                icon: "download",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.mediaDownloader && Config.options.mediaDownloader.enabled
            },
            {
                names: ["web", "web search", "internet search"],
                prefix: Config.options.search.prefix.webSearch,
                label: Translation.tr("Web Search"),
                icon: "travel_explore",
                isBuiltin: true,
                enabled: () => Config.options.search.modules.webSearch
            }
        ];

        const queryLower = root.query.toLowerCase();
        const registryOwnedPrefixes = new Set(SearchPanelRegistry.enabledPanels
            .map(panel => SearchPanelRegistry.prefixOf(panel))
            .filter(prefix => String(prefix).length > 0));
        for (const mod of moduleShortcuts) {
            if (!mod.enabled() || registryOwnedPrefixes.has(mod.prefix))
                continue;
            if (mod.names.some(n => n.startsWith(queryLower) && queryLower.length >= 2)) {
                const execFn = () => {
                    root.query = mod.prefix;
                };
                result.push(resultComp.createObject(null, {
                    key: "shortcut:" + mod.label,
                    name: mod.label,
                    type: Translation.tr("Built-in"),
                    verb: Translation.tr("Switch"),
                    iconName: mod.icon,
                    iconType: LauncherSearchResult.IconType.Material,
                    isBuiltin: true,
                    execute: execFn
                }));
            }
        }

        // Fallbacks are opt-in and only appear when the regular producers
        // found nothing. They replace the old unavoidable trio with a user
        // ordered list, while prefix modes keep their exact behavior.
        if (root.query.trim().length > 0 && result.length === 0 && !root.queryUsesPrefix(root.query))
            result = result.concat(root.fallbackResults());

        /// Math result, command, web search ///
        // Generic command/AI/web continuations are progressive fallbacks. A
        // broad query such as "bluetooth" must not append three unrelated
        // actions after already finding apps, controls and its dedicated panel.
        if (Config.options.search.prefix.showDefaultActionsWithoutPrefix && result.length === 0) {
            if (Config.options.search.modules.shellCommand && !startsWithShellCommandPrefix)
                result.push(commandResultObject);
            if (!isMath && mathResultObject)
                result.push(mathResultObject);
            if ((Config.options.search.ai?.trigger ?? "prefix") === "suggest"
                && Ai.enabled
                && !root.query.startsWith(Config.options.search.prefix.ai))
                result.push(aiAskResultObject);
            if (Config.options.search.modules.webSearch && !startsWithWebSearchPrefix)
                result.push(webSearchResultObject);
        }

        // Filter out duplicate original apps/folders/commands if an alias is shown.
        const activeAliases = (Config.options?.search?.aliases ?? []).filter(entry => entry.alias && entry.alias.toLowerCase() === root.query.toLowerCase());
        const activeAppAliasIds = new Set(activeAliases
            .filter(alias => alias.type === "app")
            .map(alias => {
                const app = DesktopEntries.byId(alias.target);
                return app ? app.id : alias.target;
            }));

        if (activeAliases.length > 0) {
            result = result.filter(item => {
                if (!item || !item.key)
                    return false;
                for (const alias of activeAliases) {
                    if (alias.type === "app" && item.type !== Translation.tr("App Alias") && item.key.startsWith("app:") && activeAppAliasIds.has(item.key.slice(4)))
                        return false;
                    if (alias.type === "folder" && item.key.startsWith("file:")) {
                        const filePath = item.key.slice(5);
                        const homePath = FileUtils.trimFileProtocol(Directories.home);
                        const targetNormalized = alias.target.startsWith("/") ? alias.target : alias.target.startsWith("~") ? alias.target.replace("~", homePath) : homePath + "/" + alias.target;
                        const cleanFilePath = filePath.replace(/\/+$/, "");
                        const cleanTarget = targetNormalized.replace(/\/+$/, "");
                        if (cleanFilePath === cleanTarget)
                            return false;
                    }
                    if (alias.type === "command" && item.key === "command:" + alias.target)
                        return false;
                }
                return true;
            });
        }

        return result;
    }

    Connections {
        target: MprisController
        function onActivePlayerChanged() {
            root.mprisTrigger++;
        }
        function onIsPlayingChanged() {
            root.mprisTrigger++;
        }
        function onTrackChanged() {
            root.mprisTrigger++;
        }
    }

    Connections {
        target: HyprlandKeybinds
        function onDefaultKeybindsChanged() {
            root._scheduleResultsUpdate();
        }
        function onUserKeybindsChanged() {
            root._scheduleResultsUpdate();
        }
    }

    function createResult(properties) {
        return {
            key: properties.key || "",
            type: properties.type || "",
            fontType: properties.fontType !== undefined ? properties.fontType : LauncherSearchResult.FontType.Normal,
            name: properties.name || "",
            rawValue: properties.rawValue || "",
            iconName: properties.iconName || "",
            iconType: properties.iconType !== undefined ? properties.iconType : LauncherSearchResult.IconType.None,
            verb: properties.verb || "",
            blurImage: !!properties.blurImage,
            pinned: !!properties.pinned,
            execute: properties.execute || (() => {
                    print("Not implemented");
                }),
            actions: properties.actions || [],
            id: properties.id || "",
            shown: properties.shown !== undefined ? properties.shown : true,
            comment: properties.comment || "",
            runInTerminal: !!properties.runInTerminal,
            genericName: properties.genericName || "",
            keywords: properties.keywords || [],
            isMath: !!properties.isMath,
            isBuiltin: !!properties.isBuiltin,
            keepOverviewOpen: !!properties.keepOverviewOpen,
            controlKind: properties.controlKind || "",
            controlValue: properties.controlValue ?? null,
            panelId: properties.panelId || "",
            pinnable: properties.pinnable !== undefined ? properties.pinnable : true,
            matchTerms: properties.matchTerms || [],
            category: properties.category || properties.type || "",
            settingRef: properties.settingRef ?? null,
            keyHints: properties.keyHints ?? [],
            feedbackText: properties.feedbackText || ""
        };
    }

    function settingsIntegrationSearch(query: string): var {
        const maxInline = Math.max(0, Config.options.search.modules.settingsToggles.maxInlineResults);
        return maxInline > 0 ? Ai.settingsIntegration.search(query, maxInline) : [];
    }

    readonly property var resultComp: {
        "createObject": function (parent, properties) {
            return root.createResult(properties);
        }
    }

    IpcHandler {
        target: "launcherSearch"
        function setQuery(q: string): void {
            root.query = q;
        }
    }
}
