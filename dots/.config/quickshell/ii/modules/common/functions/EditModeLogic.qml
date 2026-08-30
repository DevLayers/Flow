pragma Singleton
import Quickshell
import "edit_mode.js" as EditMode

/**
 * Wrapper for edit_mode.js (Edit Mode's Escape ladder and history-stack
 * arithmetic) so it can be reached through `qs.modules.common.functions`.
 */
Singleton {
    readonly property string desktopTab: EditMode.DESKTOP_TAB
    readonly property string lockscreenTab: EditMode.LOCKSCREEN_TAB
    readonly property int undoLimit: EditMode.UNDO_LIMIT

    function tabIndex(...args) {
        return EditMode.tabIndex(...args)
    }

    function tabAt(...args) {
        return EditMode.tabAt(...args)
    }

    function resolveEscape(...args) {
        return EditMode.resolveEscape(...args)
    }

    function undoPush(...args) {
        return EditMode.undoPush(...args)
    }

    function undoPop(...args) {
        return EditMode.undoPop(...args)
    }

    function listCopy(...args) {
        return EditMode.listCopy(...args)
    }
}
