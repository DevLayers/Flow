import QtQuick

/**
 * Session-local flow state for the Welcome window.
 *
 * visitedPageIds is intentionally not persisted: reopening Welcome starts a
 * fresh setup session, while the page registry remains the stable identity
 * source for navigation and future deep links.
 */
QtObject {
    id: root

    property list<string> visitedPageIds: []

    function markVisited(pageId: string) {
        if (!pageId || root.visitedPageIds.indexOf(pageId) >= 0)
            return;
        root.visitedPageIds = root.visitedPageIds.concat([pageId]);
    }

    function hasVisited(pageId: string): bool {
        return root.visitedPageIds.indexOf(pageId) >= 0;
    }

    function reset() {
        root.visitedPageIds = [];
    }
}
