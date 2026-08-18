import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property int entranceTrigger: -1
    property var tabButtonList: [
        {
            "name": Translation.tr("Pomodoro"),
            "icon": "search_activity"
        },
        {
            "name": Translation.tr("Stopwatch"),
            "icon": "timer"
        }
    ]
    property int selectedTab: Math.max(0, Math.min(root.tabButtonList.length - 1,
        Persistent.states.sidebar.bottomGroup.timerTab))

    function selectTab(index) {
        if (index < 0 || index >= root.tabButtonList.length || root.selectedTab === index)
            return;

        root.selectedTab = index;
        Persistent.states.sidebar.bottomGroup.timerTab = index;
    }

    // These are keybinds for stopwatch and pomodoro
    Keys.onPressed: event => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) { // Switch tabs
            if (event.key === Qt.Key_PageDown) {
                tabBar.incrementCurrentIndex();
            } else if (event.key === Qt.Key_PageUp) {
                tabBar.decrementCurrentIndex();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S) { // Pause/resume with Space or S
            if (tabBar.currentIndex === 0) {
                TimerService.togglePomodoro();
            } else {
                TimerService.toggleStopwatch();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_R) { // Reset with R
            if (tabBar.currentIndex === 0) {
                TimerService.resetPomodoro();
            } else {
                TimerService.stopwatchReset();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_L) { // Record lap with L
            TimerService.stopwatchRecordLap();
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Toolbar {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 52
            enableShadow: false
            colBackground: Appearance.colors.colSurfaceContainer
            ToolbarTabBar {
                id: tabBar
                tabButtonList: root.tabButtonList
                requestOnly: true
                currentIndex: root.selectedTab
                onIndexSelected: root.selectTab(index)
            }
        }

        SwipeView {
            id: swipeView
            property bool initialized: false
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            currentIndex: root.selectedTab
            Component.onCompleted: initialized = true
            onCurrentIndexChanged: {
                if (initialized && currentIndex !== root.selectedTab)
                    root.selectTab(currentIndex);
            }

            // Tabs: only the selected timer owns its visual tree.
            Loader {
                active: root.selectedTab === 0
                asynchronous: true
                sourceComponent: PomodoroTimer {
                    entranceTrigger: root.entranceTrigger
                }
            }
            Loader {
                active: root.selectedTab === 1
                asynchronous: true
                sourceComponent: Stopwatch {
                    entranceTrigger: root.entranceTrigger
                }
            }
        }
    }

    Connections {
        target: root
        function onSelectedTabChanged() {
            if (swipeView.currentIndex !== root.selectedTab)
                swipeView.currentIndex = root.selectedTab;
        }
    }
}
