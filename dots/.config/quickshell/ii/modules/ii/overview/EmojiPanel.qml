pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    property string searchQuery: ""

    readonly property int panelWidth: 620
    readonly property int gridColumns: 6
    readonly property int maxItems: 120

    implicitWidth: panelWidth
    implicitHeight: 520

    property var allEmojis: Emojis.list
    property var filteredEmojis: []
    property bool dataLoaded: Emojis.list.length > 0

    property color colItemBgHover: Appearance.colors.colSurfaceContainerHighest
    property color colItemSelected: Appearance.colors.colPrimaryContainer
    property color colText: Appearance.colors.colOnSurface
    property color colSubtext: Appearance.colors.colSubtext

    property int focusedControlIndex: 0

    readonly property real touchpadScrollFactor: Config?.options.interactions.scrolling.touchpadScrollFactor ?? 100
    readonly property real mouseScrollFactor: Config?.options.interactions.scrolling.mouseScrollFactor ?? 50
    readonly property real mouseScrollDeltaThreshold: Config?.options.interactions.scrolling.mouseScrollDeltaThreshold ?? 120

    readonly property int cellWidth: Math.floor((gridFlickable.width - (root.gridSpacing * (root.gridColumns - 1))) / root.gridColumns)
    readonly property int cellSize: root.cellWidth
    readonly property int cellHeight: root.cellSize
    readonly property int gridSpacing: 8

    function filterEmojis() {
        if (!dataLoaded || allEmojis.length === 0) {
            filteredEmojis = [];
            updateSlots();
            return;
        }

        const query = root.searchQuery.trim().toLowerCase();
        if (query.length === 0) {
            filteredEmojis = allEmojis.slice(0, maxItems);
            updateSlots();
            return;
        }

        filteredEmojis = Emojis.fuzzyQuery(query).slice(0, maxItems);
        updateSlots();
    }

    function navigateUp() {
        if (filteredEmojis.length === 0) return;
        const cols = root.gridColumns;
        if (focusedControlIndex < 0) {
            focusedControlIndex = 0;
        } else if (focusedControlIndex >= cols) {
            focusedControlIndex -= cols;
        } else {
            focusedControlIndex = -1;
            root.requestFocusSearchInput();
        }
        ensureVisible();
    }

    function navigateDown() {
        if (filteredEmojis.length === 0) return;
        const cols = root.gridColumns;
        if (focusedControlIndex < 0) {
            focusedControlIndex = 0;
        } else {
            const next = focusedControlIndex + cols;
            if (next < filteredEmojis.length) {
                focusedControlIndex = next;
            }
        }
        ensureVisible();
    }

    function navigateLeft() {
        if (filteredEmojis.length === 0) return;
        if (focusedControlIndex < 0) {
            focusedControlIndex = 0;
        } else if (focusedControlIndex > 0) {
            focusedControlIndex--;
        } else {
            focusedControlIndex = -1;
            root.requestFocusSearchInput();
        }
        ensureVisible();
    }

    function navigateRight() {
        if (filteredEmojis.length === 0) return;
        if (focusedControlIndex < 0) {
            focusedControlIndex = 0;
        } else if (focusedControlIndex < filteredEmojis.length - 1) {
            focusedControlIndex++;
        }
        ensureVisible();
    }

    function activateSelected() {
        if (focusedControlIndex >= 0 && focusedControlIndex < filteredEmojis.length) {
            copyEmoji(filteredEmojis[focusedControlIndex]);
        } else if (filteredEmojis.length > 0) {
            copyEmoji(filteredEmojis[0]);
        }
        GlobalStates.overviewOpen = false;
    }

    function focusInput() {
        focusedControlIndex = -1;
        root.requestFocusSearchInput();
    }

    function ensureVisible() {
        if (focusedControlIndex < 0) return;
        const cols = root.gridColumns;
        const row = Math.floor(focusedControlIndex / cols);
        const itemTop = row * (root.cellHeight + root.gridSpacing);
        const itemBottom = itemTop + root.cellSize;
        const viewTop = gridFlickable.contentY;
        const viewBottom = viewTop + gridFlickable.height;

        if (itemTop < viewTop) {
            gridFlickable.contentY = itemTop - 8;
        } else if (itemBottom > viewBottom) {
            gridFlickable.contentY = itemBottom - gridFlickable.height + 8;
        }
    }

    function copyEmoji(fullString) {
        if (!fullString) return;
        const parts = fullString.split(" ");
        const emoji = parts[0];
        Quickshell.clipboardText = emoji;
    }

    property var emojiMap: ({})

    function updateSlots() {
        const newUids = filteredEmojis;
        const slots = [];
        for (let i = 0; i < iconRepeater.count; i++) {
            slots.push(iconRepeater.itemAt(i));
        }

        const oldUids = [];
        for (let i = 0; i < slots.length; i++) {
            oldUids.push(slots[i] ? slots[i].uniqueId : "");
        }

        for (let i = 0; i < slots.length; i++) {
            if (slots[i]) {
                slots[i].uniqueId = "";
                slots[i].hasData = false;
                slots[i].currentPosition = -1;
            }
        }

        const slotToNewPos = {};
        const usedNewPositions = new Set();

        for (let slotIdx = 0; slotIdx < slots.length; slotIdx++) {
            const oldUid = oldUids[slotIdx];
            if (!oldUid) continue;
            const newPos = newUids.indexOf(oldUid);
            if (newPos >= 0) {
                slotToNewPos[slotIdx] = newPos;
                usedNewPositions.add(newPos);
            }
        }

        for (let newPos = 0; newPos < newUids.length; newPos++) {
            if (usedNewPositions.has(newPos)) continue;
            for (let slotIdx = 0; slotIdx < slots.length; slotIdx++) {
                if (!(slotIdx in slotToNewPos)) {
                    slotToNewPos[slotIdx] = newPos;
                    usedNewPositions.add(newPos);
                    break;
                }
            }
        }

        for (let slotIdx = 0; slotIdx < slots.length; slotIdx++) {
            const slot = slots[slotIdx];
            if (!slot) continue;
            const newPos = slotToNewPos[slotIdx];
            if (newPos === undefined) continue;
            const uid = newUids[newPos];
            slot.uniqueId = uid;
            slot.hasData = true;
            slot.currentPosition = newPos;
        }

        updatePositions();
    }

    function updatePositions() {
        const cols = root.gridColumns;
        const ch = root.cellHeight;
        const spacing = root.gridSpacing;
        let visibleCount = 0;
        for (let i = 0; i < iconRepeater.count; i++) {
            const slot = iconRepeater.itemAt(i);
            if (!slot) continue;
            if (slot.hasData && slot.currentPosition >= 0) {
                visibleCount++;
            }
        }
        const totalRows = Math.ceil(visibleCount / cols);
        const totalHeight = totalRows > 0 ? totalRows * ch + (totalRows - 1) * spacing : 0;
        contentContainer.height = Math.max(0, totalHeight);
    }

    signal requestFocusSearchInput()

    onSearchQueryChanged: {
        root.filterEmojis();
        focusedControlIndex = -1;
    }

    Connections {
        target: Emojis
        function onListChanged() {
            root.allEmojis = Emojis.list;
            root.dataLoaded = Emojis.list.length > 0;
            root.filterEmojis();
        }
    }

    Component.onCompleted: {
        Emojis.load();
        root.filterEmojis();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 10
        anchors.topMargin: 0
        spacing: 6

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: gridFlickable
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                contentHeight: contentContainer.height
                contentWidth: width

                maximumFlickVelocity: 3500
                boundsBehavior: Flickable.DragOverBounds
                pixelAligned: true
                property real scrollTargetY: 0

                Behavior on contentY {
                    NumberAnimation {
                        id: scrollAnim
                        alwaysRunToEnd: true
                        duration: Appearance.animation.scroll.duration
                        easing.type: Appearance.animation.scroll.type
                        easing.bezierCurve: Appearance.animation.scroll.bezierCurve
                    }
                }

                onContentYChanged: {
                    if (!scrollAnim.running) {
                        gridFlickable.scrollTargetY = gridFlickable.contentY;
                    }
                }

                MouseArea {
                    z: 99
                    visible: Config?.options.interactions.scrolling.fasterTouchpadScroll
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheelEvent) {
                        const delta = wheelEvent.angleDelta.y / root.mouseScrollDeltaThreshold;
                        var scrollFactor = Math.abs(wheelEvent.angleDelta.y) >= root.mouseScrollDeltaThreshold ? root.mouseScrollFactor : root.touchpadScrollFactor;
                        const maxY = Math.max(0, gridFlickable.contentHeight - gridFlickable.height);
                        const base = scrollAnim.running ? gridFlickable.scrollTargetY : gridFlickable.contentY;
                        var targetY = Math.max(0, Math.min(base - delta * scrollFactor, maxY));
                        gridFlickable.scrollTargetY = targetY;
                        gridFlickable.contentY = targetY;
                        wheelEvent.accepted = true;
                    }
                }

                Item {
                    id: gridArea
                    width: gridFlickable.width
                    implicitHeight: contentContainer.height

                    Item {
                        id: contentContainer
                        width: gridArea.width
                        height: 0

                        Repeater {
                            id: iconRepeater
                            model: root.maxItems

                            delegate: Item {
                                id: delegateItem
                                required property int index

                                readonly property int slotIndex: index
                                property string uniqueId: ""
                                property int currentPosition: -1
                                property bool hasData: uniqueId !== ""

                                readonly property bool isFocused: {
                                    const fi = root.focusedControlIndex;
                                    const cp = currentPosition;
                                    if (fi < 0 || cp < 0) return false;
                                    return (fi === cp) && hasData;
                                }

                                readonly property int targetCol: currentPosition >= 0 ? currentPosition % root.gridColumns : 0
                                readonly property int targetRow: currentPosition >= 0 ? Math.floor(currentPosition / root.gridColumns) : 0
                                x: targetCol * (root.cellWidth + root.gridSpacing)
                                y: targetRow * (root.cellHeight + root.gridSpacing)
                                width: root.cellWidth
                                height: hasData ? root.cellHeight : 0
                                opacity: hasData ? 1.0 : 0.0
                                visible: hasData || opacity > 0.01
                                clip: true

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Appearance.animationCurves.emphasized
                                    }
                                }
                                Behavior on y {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Appearance.animationCurves.emphasized
                                    }
                                }
                                Behavior on height {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Appearance.animationCurves.emphasized
                                    }
                                }
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Appearance.animationCurves.emphasized
                                    }
                                }

                                RippleButton {
                                    id: iconMouseArea
                                    anchors.fill: parent
                                    buttonRadius: Appearance.rounding.normal
                                    colBackground: delegateItem.isFocused ? root.colItemSelected : "transparent"
                                    colBackgroundHover: root.colItemBgHover
                                    enabled: delegateItem.hasData

                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            if (!delegateItem.uniqueId) return "";
                                            const parts = delegateItem.uniqueId.split(" ");
                                            return parts[0] || "";
                                        }
                                        font.pixelSize: 26
                                        font.family: "Noto Color Emoji"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    onClicked: {
                                        root.focusedControlIndex = delegateItem.currentPosition;
                                        root.copyEmoji(delegateItem.uniqueId);
                                        GlobalStates.overviewOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                anchors.centerIn: parent
                visible: root.filteredEmojis.length === 0 && root.dataLoaded && root.searchQuery.trim().length > 0
                implicitWidth: noResultsColumn.implicitWidth
                implicitHeight: noResultsColumn.implicitHeight

                ColumnLayout {
                    id: noResultsColumn
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialSymbol {
                        text: "search_off"
                        iconSize: 48
                        color: Appearance.colors.colSubtext
                        Layout.alignment: Qt.AlignHCenter
                        opacity: 0.5
                    }

                    StyledText {
                        text: Translation.tr("No emojis found")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.normal
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        StyledText {
            text: Translation.tr("Enter to copy emoji • ↑↓←→ to navigate")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
            opacity: 0.6
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
