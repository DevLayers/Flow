pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import "."

Item {
    id: root

    property var rows: []
    property int selectedIndex: 0
    signal selected(int index)
    signal activated(int index)

    implicitHeight: Math.min(agenda.contentHeight, Appearance.sizes.elevationMargin * 34)

    function positionViewAtIndex(index) {
        agenda.positionViewAtIndex(index, ListView.Contain);
    }

    ListView {
        id: agenda
        anchors.fill: parent
        clip: true
        spacing: Appearance.sizes.elevationMargin / 2
        model: root.rows

        delegate: CalendarEventBlock {
            required property int index
            required property var modelData
            width: agenda.width
            event: modelData
            selected: root.selectedIndex === index
            opacity: String(modelData?.status ?? "") === "cancelled" ? 0.5 : 1.0
            onActivated: {
                root.selected(index);
                root.activated(index);
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.rows.length === 0
            text: Translation.tr("No events for this day")
            color: Appearance.colors.colSubtext
        }
    }
}
