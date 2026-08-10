import QtQuick
import Quickshell

import qs.modules.common

/**
 * A shell panel, created in its own turn of the event loop.
 *
 * The panel itself is built synchronously, exactly as it always was. What changed is
 * only when: a panel takes a slot from `PanelSchedule` the moment it first wants to
 * exist, and waits for that slot to come up instead of racing every other panel into
 * one pass. See PanelSchedule for why this is a queue and not asynchronous loading.
 */
LazyLoader {
    id: root

    property bool extraCondition: true

    readonly property bool wanted: Config.ready && root.extraCondition

    /// Zero until this panel has asked for a slot. Kept afterwards, so a panel that is
    /// torn down and wanted again comes straight back rather than queueing a second time.
    property int ticket: 0

    function takeTicket() {
        if (!root.wanted || root.ticket !== 0)
            return;
        root.ticket = PanelSchedule.take();
    }

    active: root.wanted && root.ticket > 0 && PanelSchedule.released >= root.ticket

    onWantedChanged: root.takeTicket()
    Component.onCompleted: root.takeTicket()
}
