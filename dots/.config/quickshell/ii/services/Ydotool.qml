pragma Singleton

import qs.modules.common
import Quickshell

/**
 * Injects key events through ydotool, at the evdev level.
 *
 * Two APIs live here:
 *  - The classic press()/release()/shiftMode trio, used by the original on-screen keyboard,
 *    which physically holds keys down between a touch down and its release.
 *  - The latch registry below, used by the deck keyboard. Nothing is ever held down there:
 *    every tap is emitted as one atomic ydotool invocation that presses the latched modifiers,
 *    taps the key and releases the modifiers again, so no key can be left stuck.
 */
Singleton {
    id: root

    // Classic API
    property int shiftMode: 0 // 0: off, 1: on, 2: lock
    property list<int> shiftKeys: [42, 54] // Keycodes for Shift keys (left and right)
    property list<int> altKeys: [56, 100] // Keycodes for Alt keys (left and right)
    property list<int> ctrlKeys: [29, 97] // Keycodes for Ctrl keys (left and right)

    // Latch registry
    readonly property int latchOff: 0
    readonly property int latchOneShot: 1
    readonly property int latchLocked: 2
    readonly property int lockWindowMs: 300 // A second tap within this window locks the modifier

    property var latched: ({}) // keycode -> latchOff | latchOneShot | latchLocked
    property var latchTimes: ({}) // keycode -> timestamp of the tap that armed it

    function emitEvents(events) {
        if (events.length === 0) return;
        Quickshell.execDetached(["ydotool", "key", "--key-delay", "0", ...events]);
    }

    function latchState(keycode) {
        return root.latched[keycode] ?? root.latchOff;
    }

    function isLatched(keycode) {
        return root.latchState(keycode) !== root.latchOff;
    }

    function setLatch(keycode, state) {
        const next = Object.assign({}, root.latched);
        if (state === root.latchOff) delete next[keycode];
        else next[keycode] = state;
        root.latched = next;
    }

    /**
     * Cycles a modifier: off -> one-shot -> (tapped again within lockWindowMs) locked -> off.
     * A second tap after the window simply turns it back off.
     */
    function toggleLatch(keycode) {
        const state = root.latchState(keycode);
        const now = Date.now();
        if (state === root.latchOff) {
            root.latchTimes[keycode] = now;
            root.setLatch(keycode, root.latchOneShot);
            return;
        }
        if (state === root.latchOneShot) {
            const armedAt = root.latchTimes[keycode] ?? 0;
            root.setLatch(keycode, (now - armedAt <= root.lockWindowMs) ? root.latchLocked : root.latchOff);
            return;
        }
        root.setLatch(keycode, root.latchOff);
    }

    function latchedKeycodes() {
        return Object.keys(root.latched).map(keycode => parseInt(keycode)).filter(keycode => !isNaN(keycode));
    }

    function clearOneShotLatches() {
        const next = {};
        Object.keys(root.latched).forEach(keycode => {
            if (root.latched[keycode] === root.latchLocked) next[keycode] = root.latchLocked;
        });
        root.latched = next;
    }

    function clearLatches() {
        root.latched = ({});
        root.latchTimes = ({});
    }

    /**
     * Taps a key with every latched modifier wrapped around it, as a single ydotool call, then
     * drops the one-shot latches. Locked modifiers survive for the next tap.
     */
    function tapKey(keycode) {
        const modifiers = root.latchedKeycodes().filter(modifier => modifier !== keycode);
        const events = [];
        modifiers.forEach(modifier => events.push(`${modifier}:1`));
        events.push(`${keycode}:1`, `${keycode}:0`);
        for (let i = modifiers.length - 1; i >= 0; i--) events.push(`${modifiers[i]}:0`);
        root.emitEvents(events);
        root.clearOneShotLatches();
    }

    function releaseAllKeys() {
        const keycodes = Array.from(Array(249).keys());
        root.emitEvents(keycodes.map(keycode => `${keycode}:0`));
        root.shiftMode = 0; // Reset shift mode
        root.clearLatches();
    }

    function releaseShiftKeys() {
        root.emitEvents(root.shiftKeys.map(keycode => `${keycode}:0`));
        root.shiftMode = 0; // Reset shift mode
    }

    function press(keycode) {
        root.emitEvents([`${keycode}:1`]);
    }

    function release(keycode) {
        root.emitEvents([`${keycode}:0`]);
    }
}
