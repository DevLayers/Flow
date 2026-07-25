pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    property bool smartTray: Config.options.tray.filterPassive

    function getItemKey(item) {
        if (!item) return "";
        var baseId = item.id || "";
        if (baseId.indexOf("chrome_status_icon") !== -1 || baseId === "electron" || baseId === "") {
            var extra = (item.tooltipTitle || item.title || item.icon || "").toLowerCase();
            if (extra.length > 0) return baseId + "_" + extra;
        }
        return baseId;
    }

    property list<var> itemsInUserList: SystemTray.items.values.filter(i => {
        if (!i || i.id === undefined) return false;
        var key = root.getItemKey(i);
        var pins = Config.options.tray.pinnedItems || [];
        var isPinned = pins.includes(key) || pins.includes(i.id);
        return isPinned && (!smartTray || i.status !== Status.Passive);
    })

    property list<var> itemsNotInUserList: SystemTray.items.values.filter(i => {
        if (!i || i.id === undefined) return false;
        var key = root.getItemKey(i);
        var pins = Config.options.tray.pinnedItems || [];
        var isPinned = pins.includes(key) || pins.includes(i.id);
        return !isPinned && (!smartTray || i.status !== Status.Passive);
    })

    property bool invertPins: Config.options.tray.invertPinnedItems
    property list<var> pinnedItems: invertPins ? itemsNotInUserList : itemsInUserList
    property list<var> unpinnedItems: invertPins ? itemsInUserList : itemsNotInUserList

    function getTooltipForItem(item) {
        if (!item) return "";
        var result = item.tooltipTitle && item.tooltipTitle.length > 0 ? item.tooltipTitle
                : (item.title && item.title.length > 0 ? item.title : (item.id || ""));
        if (item.tooltipDescription && item.tooltipDescription.length > 0) result += " • " + item.tooltipDescription;
        if (Config.options.tray.showItemId && item.id) result += "\n[" + item.id + "]";
        return result;
    }

    // Pinning
    function pin(itemOrId) {
        var key = typeof itemOrId === "object" ? getItemKey(itemOrId) : itemOrId;
        if (!key) return;
        var pins = (Config.options.tray.pinnedItems || []).slice();
        if (pins.includes(key)) return;
        pins.push(key);
        Config.options.tray.pinnedItems = pins;
    }

    function unpin(itemOrId) {
        var key = typeof itemOrId === "object" ? getItemKey(itemOrId) : itemOrId;
        if (!key) return;
        var rawId = typeof itemOrId === "object" ? (itemOrId.id || "") : itemOrId;
        Config.options.tray.pinnedItems = (Config.options.tray.pinnedItems || []).filter(id => id !== key && id !== rawId);
    }

    function isPinned(itemOrId) {
        if (!itemOrId) return false;
        var key = typeof itemOrId === "object" ? getItemKey(itemOrId) : itemOrId;
        var rawId = typeof itemOrId === "object" ? (itemOrId.id || "") : itemOrId;
        for (var i = 0; i < root.pinnedItems.length; i++) {
            var it = root.pinnedItems[i];
            if (!it) continue;
            if (getItemKey(it) === key || (rawId && it.id === rawId))
                return true;
        }
        return false;
    }

    function togglePin(itemOrId) {
        if (isPinned(itemOrId)) {
            unpin(itemOrId);
        } else {
            pin(itemOrId);
        }
    }

}

