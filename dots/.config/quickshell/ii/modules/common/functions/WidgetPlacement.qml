pragma Singleton
import Quickshell

/**
 * Per-monitor placement of desktop widgets.
 *
 * An activeWidgets entry carries a legacy top-level x/y/scale plus an optional
 * `positions` map keyed by monitor name:
 *
 *     { "id": "widget_clock_cookie_1", "x": 200, "y": 200, "scale": 1.25,
 *       "positions": { "DP-1": { "x": 640, "y": 80, "scale": 1.25 } } }
 *
 * A monitor with an entry in the map owns its own placement; every other
 * monitor shows the legacy values. The first move or resize on a monitor forks
 * it into the map, and this shell never writes the legacy values again for
 * that entry. An older shell keeps reading and writing the legacy values and
 * carries the map along untouched (every writer clones the whole entry), so
 * neither side loses the other's layout.
 *
 * Entries are plain JS objects here: readers get them straight out of the
 * config list, writers get the JSON clone Config makes before reassigning.
 */
Singleton {
    id: root

    function fork(entry, monitorName) {
        if (!entry || !monitorName)
            return null;
        const map = entry.positions;
        if (!map || typeof map !== "object")
            return null;
        const forked = map[monitorName];
        return (forked && typeof forked === "object") ? forked : null;
    }

    // What `entry` shows on `monitorName`: {x, y, scale, forked}. Never null.
    function resolve(entry, monitorName) {
        if (!entry)
            return { "x": 0, "y": 0, "scale": 1.0, "forked": false };
        const forked = root.fork(entry, monitorName);
        const src = forked ?? entry;
        return {
            "x": Number(src.x ?? entry.x ?? 0),
            "y": Number(src.y ?? entry.y ?? 0),
            "scale": Number(src.scale ?? entry.scale ?? 1.0),
            "forked": forked !== null
        };
    }

    function findEntry(list, instanceId) {
        const entries = list || [];
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].id === instanceId)
                return entries[i];
        }
        return null;
    }

    function resolveIn(list, instanceId, monitorName) {
        return root.resolve(root.findEntry(list, instanceId), monitorName);
    }

    // The fork starts from whatever the monitor currently shows, so forking a
    // monitor never moves anything.
    function _ensureFork(entry, monitorName) {
        if (!entry.positions || typeof entry.positions !== "object")
            entry.positions = {};
        let forked = entry.positions[monitorName];
        if (!forked || typeof forked !== "object") {
            const current = root.resolve(entry, monitorName);
            forked = { "x": current.x, "y": current.y };
            if (entry.scale !== undefined)
                forked.scale = current.scale;
            entry.positions[monitorName] = forked;
        }
        return forked;
    }

    // Writers mutate `entry` in place; callers pass a clone. Without a monitor
    // name the legacy values are written, which is what every pre-fork caller
    // did and what a monitor without a fork follows.
    function setPosition(entry, monitorName, x, y) {
        if (!entry)
            return;
        if (!monitorName) {
            entry.x = x;
            entry.y = y;
            return;
        }
        const forked = root._ensureFork(entry, monitorName);
        forked.x = x;
        forked.y = y;
    }

    function setScale(entry, monitorName, scale) {
        if (!entry)
            return;
        if (!monitorName) {
            entry.scale = scale;
            return;
        }
        root._ensureFork(entry, monitorName).scale = scale;
    }

    // Drops the monitor's fork so it follows the legacy values again. Returns
    // whether anything changed.
    function clearFork(entry, monitorName) {
        if (!root.fork(entry, monitorName))
            return false;
        delete entry.positions[monitorName];
        if (Object.keys(entry.positions).length === 0)
            delete entry.positions;
        return true;
    }
}
