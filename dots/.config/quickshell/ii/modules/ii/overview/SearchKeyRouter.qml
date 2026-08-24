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
        case "navigateDown": {
            const step = methodName === "navigateUp" ? -1 : 1;
            // A list whose model carries non-selectable rows (section captions)
            // decides for itself which index the cursor may land on.
            if (typeof root.resultsList.moveSelection === "function")
                return root.resultsList.moveSelection(step);
            const target = root.resultsList.currentIndex + step;
            if (target < 0 || target > root.resultsList.count - 1)
                return false;
            root.resultsList.currentIndex = target;
            return true;
        }
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
