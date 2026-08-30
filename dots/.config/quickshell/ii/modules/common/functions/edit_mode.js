.pragma library
// Ported verbatim from XephyLon/immaterial-impulse (GPL-3.0), v0.32.0:
//   dots/.config/quickshell/imi/modules/common/functions/edit_mode.js
// Original author: XephyLon. Reached from QML through EditModeLogic.qml.
// Subset: the tab names, the Escape ladder and the history-stack arithmetic.
// The viewport/card geometry of the original is not ported here.

// Edit Mode's two pieces of arithmetic, kept here because they are the only
// parts of the mode a test can reach: everything else about it is a layer
// surface, a transform and a pointer, and `qmltestrunner` can construct none of
// those.
//
// See docs/superpowers/specs/2026-08-16-edit-mode-design.md §8.2 (the ladder)
// and §1.2 (the inset).

// The tab the mode opens on. A string rather than a boolean because the
// Lockscreen tab sits beside it (spec §1.4) and the ladder has to say which
// tab it returns to.
var DESKTOP_TAB = "desktop";

// The Lockscreen tab - a FILTER on the viewport, not a mode (spec §1.4): the
// same entry, the same exit ladder, the same chrome, one GlobalStates.editMode.
// Declared here so the rung above, GlobalStates' preview derivation and the
// chrome's tab bar all read one spelling; the contract holds the literal to
// this file.
var LOCKSCREEN_TAB = "lockscreen";

// The chrome's tab bar speaks indices and everything else speaks tab names.
// The mapping lives here, in the tab list's own order, so the bar's index and
// the ladder's answers cannot come from two spellings of the same list - the
// contract forbids an `editTab ===` comparison outside GlobalStates for
// exactly that reason. Unknown input lands on the Desktop tab both ways: a
// bad index or a stale stored string must not strand the bar pointing at
// nothing.
var TABS = [DESKTOP_TAB, LOCKSCREEN_TAB];

function tabIndex(tab) {
    const index = TABS.indexOf(tab);
    return index < 0 ? 0 : index;
}

function tabAt(index) {
    return TABS[index] || DESKTOP_TAB;
}

// Escape is overloaded on the desktop before Edit Mode exists: WidgetCanvas
// clears a marquee selection with it and PluginWidget cancels a grip resize
// with it. So the mode may not simply take the key - it resolves in order and
// the first match wins, which is what keeps both of those working while the
// mode is on.
//
// A pure function of three inputs, so the precedence is checkable without a
// canvas, a widget or a compositor. The caller does the work each answer names.
function resolveEscape(state) {
    const s = state || {};
    // The per-widget context menu is the topmost transient the mode draws - it
    // opens over the widget it belongs to and everything else waits behind it
    // until a click lands somewhere else - so it is dismissed before anything
    // under it is touched.
    if (s.menuOpen)
        return "closeMenu";
    if (s.gestureInFlight)
        return "cancelGesture";
    if ((s.selectionCount || 0) > 0)
        return "clearSelection";
    if ((s.tab || DESKTOP_TAB) !== DESKTOP_TAB)
        return "desktopTab";
    return "exit";
}

// Entries are opaque here - at the call sites each one is a closure over the
// store write that reverses a committed mutation, never a diff, because a
// diff needs a serialiser per store and there are three stores.

var UNDO_LIMIT = 50;

// A fresh stack on every operation, never a mutation: the stack sits in a
// `property var`, whose change signal fires on reassignment only, so an
// in-place push would leave every observer reading a depth that never moves.
// Bounded by dropping the OLDEST entry - a stack that refuses new work when
// full has stopped recording exactly the mutations the user is still making.
function undoPush(stack, entry) {
    var next = listCopy(stack);
    next.push(entry);
    if (next.length > UNDO_LIMIT)
        next.shift();
    return next;
}

function undoPop(stack) {
    var next = listCopy(stack);
    if (next.length === 0)
        return { stack: next, entry: null };
    var entry = next.pop();
    return { stack: next, entry: entry };
}

// The snapshot an undo closure captures, taken by index and length because a
// store list that has crossed the QML boundary keeps both and loses its
// Array brand (enabledWithout's rule, one shelf up).
function listCopy(list) {
    var out = [];
    var count = list && typeof list.length === "number" ? list.length : 0;
    for (var i = 0; i < count; i++)
        out.push(list[i]);
    return out;
}
