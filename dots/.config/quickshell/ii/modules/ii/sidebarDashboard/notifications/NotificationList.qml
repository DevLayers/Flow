import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../SidebarSpaceArbitration.js" as SpaceArbitration

Item {
    id: root

    property int entranceTrigger: -1
    property bool collapsed: false
    property real _entranceScale: 0.94
    property bool _entranceDone: false
    readonly property bool _animationsDisabled: (Config.options?.appearance?.animationMultiplier ?? 1.0) <= 0.25
    readonly property real listStatusSpacing: 5
    property real _measuredNotificationHeight: 0
    readonly property real representativeNotificationHeight: _measuredNotificationHeight > 0
        ? _measuredNotificationHeight
        : statusRow.implicitHeight * 2.5
    readonly property real collapsedHeight: statusRow.implicitHeight
    // Compare the group's total height with one and a half representative
    // cards. Adding the permanent status row here would count that space twice
    // and activate compact mode while a useful notification area still fits.
    readonly property real minimumExpandedHeight: SpaceArbitration.minimumUsefulNotificationHeight(
        representativeNotificationHeight,
        1.5
    )

    function scheduleRepresentativeHeightMeasurement() {
        representativeHeightTimer.restart();
    }

    function updateRepresentativeNotificationHeight() {
        let totalHeight = 0;
        let sampleCount = 0;
        const maximumSamples = Math.min(3, listview.count);

        for (let i = 0; i < maximumSamples; i++) {
            const item = listview.itemAtIndex(i);
            if (!item || item.expanded || item.implicitHeight <= 0)
                continue;
            totalHeight += item.implicitHeight;
            sampleCount++;
        }

        if (sampleCount > 0)
            _measuredNotificationHeight = totalHeight / sampleCount;
    }

    onEntranceTriggerChanged: {
        if (_animationsDisabled) {
            _entranceDone = true;
            _entranceScale = 1;
            return;
        }
        _entranceDone = false;
        _entranceScale = 0.94;
        Qt.callLater(function() {
            notifScaleAnim.start();
        });
    }

    Component.onCompleted: {
        if (_animationsDisabled) {
            _entranceDone = true;
            _entranceScale = 1;
            return;
        }
        _entranceDone = false;
        _entranceScale = 0.94;
        Qt.callLater(function() {
            notifScaleAnim.start();
        });
    }

    SequentialAnimation {
        id: notifScaleAnim
        PauseAnimation { duration: 100 }
        NumberAnimation {
            target: root
            property: "_entranceScale"
            from: 0.94
            to: 1.0
            duration: 350
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
        PropertyAction { target: root; property: "_entranceDone"; value: true }
    }

    scale: root._entranceDone ? 1.0 : root._entranceScale

    Timer {
        id: representativeHeightTimer
        interval: 0
        repeat: false
        onTriggered: root.updateRepresentativeNotificationHeight()
    }

    Item {
        id: expandedContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: statusRow.top
        anchors.bottomMargin: root.listStatusSpacing
        opacity: root.collapsed ? 0 : 1
        visible: opacity > 0
        enabled: !root.collapsed

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration / 2
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        NotificationListView { // Scrollable window
            id: listview
            anchors.fill: parent

            clip: true
            // layer.enabled and OpacityMask removed to optimize performance and prevent lag on dashboard open
            // layer.enabled: true
            // layer.effect: OpacityMask {
            //     maskSource: Rectangle {
            //         width: Math.floor(listview.width)
            //         height: Math.floor(listview.height)
            //         radius: Appearance.rounding.windowRounding
            //     }
            // }

            popup: false
            entranceTrigger: root.entranceTrigger
            onCountChanged: root.scheduleRepresentativeHeightMeasurement()
            onContentHeightChanged: root.scheduleRepresentativeHeightMeasurement()
        }

        // Placeholder when list is empty
        PagePlaceholder {
            anchors.fill: parent
            shown: Notifications.list.length === 0
            icon: "notifications_active"
            description: Translation.tr("Nothing")
            shape: MaterialShape.Shape.Ghostish
            descriptionHorizontalAlignment: Text.AlignHCenter
        }
    }

    ButtonGroup {
        id: statusRow
        clip: true
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        property int entranceTrigger: root.entranceTrigger
        property real _leftTranslateX: -40
        property real _rightTranslateX: 40
        property real _entranceOpacity: 0
        property bool _entranceDone: false
        readonly property bool _animationsDisabled: (Config.options?.appearance?.animationMultiplier ?? 1.0) <= 0.25

        onEntranceTriggerChanged: {
            if (_animationsDisabled) {
                _entranceDone = true;
                _entranceOpacity = 1;
                _leftTranslateX = 0;
                _rightTranslateX = 0;
                return;
            }
            _entranceDone = false;
            _entranceOpacity = 0;
            _leftTranslateX = -40;
            _rightTranslateX = 40;
            Qt.callLater(function() {
                entranceAnim.start();
            });
        }

        Component.onCompleted: {
            if (_animationsDisabled) {
                _entranceDone = true;
                _entranceOpacity = 1;
                _leftTranslateX = 0;
                _rightTranslateX = 0;
                return;
            }
            _entranceDone = false;
            _entranceOpacity = 0;
            _leftTranslateX = -40;
            _rightTranslateX = 40;
            Qt.callLater(function() {
                entranceAnim.start();
            });
        }

        SequentialAnimation {
            id: entranceAnim
            PauseAnimation { duration: 250 }
            ParallelAnimation {
                NumberAnimation { target: statusRow; property: "_entranceOpacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                NumberAnimation { target: statusRow; property: "_leftTranslateX"; from: -40; to: 0; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: statusRow; property: "_rightTranslateX"; from: 40; to: 0; duration: 350; easing.type: Easing.OutCubic }
            }
            PropertyAction { target: statusRow; property: "_entranceDone"; value: true }
        }

        GroupButtonWithIcon {
            id: snoozeButton
            Layout.fillWidth: false
            buttonIcon: "notifications_paused"
            toggled: Notifications.silent
            onClicked: () => {
                Notifications.silent = !Notifications.silent;
            }
            opacity: statusRow._entranceDone ? 1.0 : statusRow._entranceOpacity
            transform: Translate {
                x: statusRow._entranceDone ? 0 : statusRow._leftTranslateX
            }
        }
        GroupButtonWithIcon {
            id: countButton
            enabled: false
            Layout.fillWidth: true
            buttonText: Translation.tr("%1 notifications").arg(String(Notifications.list.length))
            opacity: statusRow._entranceDone ? 1.0 : statusRow._entranceOpacity
        }
        GroupButtonWithIcon {
            id: deleteAllButton
            Layout.fillWidth: false
            buttonIcon: "delete_sweep"
            onClicked: () => {
                Notifications.discardAllNotifications()
            }
            opacity: statusRow._entranceDone ? 1.0 : statusRow._entranceOpacity
            transform: Translate {
                x: statusRow._entranceDone ? 0 : statusRow._rightTranslateX
            }
        }
    }
}
