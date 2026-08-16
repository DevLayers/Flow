pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Single owner for AI deep-links between the Search and sidebar surfaces.
 * Hosts consume pendingIntent and acknowledge it after the requested page is
 * actually visible; opening a surface never relies on a delayed callback.
 */
Scope {
    id: root

    property int requestSequence: 0
    property var pendingIntent: null

    signal requestOpened(var intent)
    signal requestAcknowledged(string requestId)

    function nextRequestId() {
        root.requestSequence += 1;
        return `ai-surface-${Date.now()}-${root.requestSequence}`;
    }

    function open(intent = null) {
        const requested = intent ?? ({});
        const surface = requested.surface === "sidebar" ? "sidebar" : "search";
        const monitorName = String(requested.monitorName ?? requested.screenName ?? Hyprland.focusedMonitor?.name ?? "");
        const normalized = Object.assign({}, requested, {
            requestId: root.nextRequestId(),
            surface: surface,
            monitorName: monitorName,
            sessionId: String(requested.sessionId ?? ""),
            messageId: String(requested.messageId ?? ""),
            blockId: String(requested.blockId ?? ""),
            focusIntent: String(requested.focusIntent ?? requested.focus ?? "composer")
        });
        root.pendingIntent = normalized;
        if (surface === "sidebar") {
            GlobalStates.activeLeftSidebarMonitor = monitorName;
            Persistent.states.sidebar.policies.tab = 0;
            GlobalStates.overviewOpen = false;
            GlobalStates.policiesPanelOpen = true;
        } else {
            GlobalStates.activeSearchMonitor = monitorName;
            // Search hosts consume this prefix through their normal mode
            // detection; assigning the service query also handles an already
            // open Overview without relying on a delayed callback.
            GlobalStates.activeSearchQuery = Config.options.search.prefix.ai;
            LauncherSearch.query = Config.options.search.prefix.ai;
            GlobalStates.overviewOpen = true;
        }
        root.requestOpened(normalized);
        return normalized.requestId;
    }

    function acknowledge(requestId: string) {
        if (!root.pendingIntent || root.pendingIntent.requestId !== requestId)
            return false;
        root.pendingIntent = null;
        root.requestAcknowledged(requestId);
        return true;
    }
}
