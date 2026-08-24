import QtQuick
import qs.modules.common.widgets

/**
 * A switch whose value is owned by something else - a Hyprland option, a device override, a
 * window rule - rather than by the switch.
 *
 * ConfigSwitch flips its own `checked` when it is clicked, and a handler written at the call site
 * runs *after* that one rather than instead of it. Two things follow, and both had gone wrong in
 * this hub: the handler sees `checked` already holding the new value, so reading `!checked` there
 * writes back the value the setting already had; and the assignment has overwritten whatever
 * `checked` was bound to, so from the first click onwards the switch shows what it assumed rather
 * than what happened.
 *
 * So the value goes in through `switchOn` and the request comes out through `requested`, and the
 * binding is put back afterwards. A write that is refused therefore snaps the switch back, which
 * is the honest outcome.
 */
ConfigSwitch {
    id: root

    /// What the switch shows. Bind it to wherever the truth actually lives.
    property bool switchOn: false

    /// The state the user just asked for.
    signal requested(bool wanted)

    checked: root.switchOn

    onClicked: {
        const wanted = root.checked;
        root.requested(wanted);
        // Restored after the request, not before: putting it back first would show the old value
        // for the frame between the two, which reads as the switch bouncing.
        root.checked = Qt.binding(() => root.switchOn);
    }
}
