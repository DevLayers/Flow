pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

// Compatibility-first facade. Touch gestures keep their public API while the
// Search consumes this shell-wide registry as its single action source.
Singleton {
    readonly property var actions: TouchGestureActionRegistry.actions.map(action => Object.assign({}, action, {
        keywords: action.keywords ?? [action.name.toLowerCase()],
        category: action.category ?? "shell",
        searchable: action.searchable !== false,
        enabled: action.enabled ?? (() => true)
    }))

    function actionById(actionId) {
        return actions.find(action => action.id === actionId) ?? actions[0];
    }

    function trigger(actionId, screenName) {
        TouchGestureActionRegistry.trigger(actionId, screenName);
    }
}
