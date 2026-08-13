pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property int currentPageIndex: 0
    property int pageCount: 7

    implicitHeight: 8

    StyledProgressBar {
        anchors.fill: parent
        from: 0
        to: 1
        value: root.pageCount > 0
            ? (root.currentPageIndex + 1) / root.pageCount
            : 0
        valueBarHeight: 8
        valueBarGap: 0
        wavy: false
        highlightColor: Appearance.colors.colPrimary
        trackColor: Appearance.colors.colLayer2
    }
}
