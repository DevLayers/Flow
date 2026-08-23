pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property Item activePanelItem: null
    property Item resultsList: null
    property var searchWidget: null

    function dispatch(methodName, ...args) {
        const panel = root.activePanelItem;
        if (panel && typeof panel[methodName] === "function" && panel[methodName](...args) !== false)
            return true;
        return root.fallback(methodName, ...args);
    }

    function fallback(methodName, ...args) {
        if (!root.resultsList)
            return false;
        switch (methodName) {
        case "navigateUp":
            if (root.resultsList.currentIndex > 0) {
                root.resultsList.currentIndex--;
                return true;
            }
            return false;
        case "navigateDown":
            if (root.resultsList.currentIndex < root.resultsList.count - 1) {
                root.resultsList.currentIndex++;
                return true;
            }
            return false;
        case "navigateLeft":
        case "navigateRight":
            return root.searchWidget?.navigateSelectedResult(methodName === "navigateLeft" ? "left" : "right") ?? false;
        case "activateSelected": {
            const delegate = root.resultsList.itemAtIndex(root.resultsList.currentIndex);
            const row = delegate?.item ?? delegate;
            if (row && typeof row.clicked === "function") {
                row.clicked();
                return true;
            }
            return false;
        }
        default:
            return false;
        }
    }
}
