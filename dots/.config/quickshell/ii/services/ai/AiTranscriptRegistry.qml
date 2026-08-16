pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common.functions

/**
 * Shared transcript vocabulary for every AI host.
 *
 * Rendering remains owned by each host so Search and the sidebar keep
 * independent viewport state. This singleton only normalises message blocks
 * and keyboard navigation decisions, preventing two transcript surfaces from
 * gradually growing different parsing or follow-scroll rules.
 */
Singleton {
    id: root

    readonly property list<string> rendererKinds: ["text", "code", "think", "error", "config"]
    readonly property int followThreshold: 28

    function blocksFor(message) {
        return StringUtils.splitMarkdownBlocks(String(message?.content ?? ""));
    }

    function isRenderable(kind) {
        return root.rendererKinds.indexOf(String(kind ?? "")) >= 0;
    }

    /** Keep the transcript pinned only while the viewport is near its end. */
    function shouldFollow(contentY, viewportHeight, contentHeight, threshold) {
        const edge = threshold === undefined ? root.followThreshold : threshold;
        return contentY + viewportHeight >= contentHeight - edge;
    }

    /** Move focus through a stable id list without leaking host-local state. */
    function nextSelection(ids, currentId, delta) {
        const values = Array.from(ids ?? []);
        if (values.length === 0)
            return "";
        const current = values.indexOf(currentId);
        const start = current < 0 ? (delta >= 0 ? 0 : values.length - 1) : current;
        const next = Math.max(0, Math.min(values.length - 1, start + delta));
        return String(values[next]);
    }
}
