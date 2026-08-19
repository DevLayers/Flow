pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell;
import qs.services
import Quickshell.Io;
import QtQuick;
import qs.modules.common.functions


/**
 * Simple to-do list manager.
 * Each item is an object with "content" and "done" properties.
 * When TickTick is available, syncs with the TickTick API.
 */
Singleton {
    id: root
    property var filePath: Directories.todoPath

    // See Config.qml for the rationale on these guards (avoid clobbering user
    // data during transient file inaccessibility; write atomically).
    property real initTimestamp: Date.now()
    property int missingFileGracePeriod: 2000
    property int missingFileRetryInterval: 1500

    // Provider resolution
    function resolveProvider() {
        const configured = Config.options.todo ? Config.options.todo.provider : "local";
        if (configured === "ticktick" || configured === "googleTasks" || configured === "local")
            return configured;
        return "local";
    }

    readonly property string configuredProvider: Config.options.todo ? Config.options.todo.provider : "local"
    readonly property string provider: root.resolveProvider()
    readonly property bool remoteEnabled: provider === "ticktick" || provider === "googleTasks"

    readonly property bool connected: {
        if (provider === "ticktick")
            return TickTickService.available;
        if (provider === "googleTasks")
            return GoogleTasksService.available;
        return true;
    }

    readonly property bool syncing: {
        if (provider === "ticktick")
            return TickTickService.syncing;
        if (provider === "googleTasks")
            return GoogleTasksService.syncing;
        return false;
    }

    readonly property string providerName: {
        if (provider === "ticktick")
            return "TickTick";
        if (provider === "googleTasks")
            return "Google Tasks";
        return Translation.tr("Local");
    }

    // Unified task list: either from TickTick, Google Tasks or local file
    property var list: {
        if (root.provider === "ticktick")
            return TickTickService.tasks;
        if (root.provider === "googleTasks")
            return GoogleTasksService.tasks;
        return root.localList;
    }
    property var localList: []

    function addLocalItem(item) {
        root.localList.push(item);
        root.localList = root.localList.slice(0);
        todoFileView.setText(JSON.stringify(root.localList));
    }

    function setLocalTaskDone(index, done) {
        if (index >= 0 && index < root.localList.length) {
            root.localList[index].done = done;
            root.localList = root.localList.slice(0);
            if (!done && CalendarService.khalAvailable) {
                return;
            }
            todoFileView.setText(JSON.stringify(root.localList));
        }
    }

    function deleteLocalItem(index) {
        if (index >= 0 && index < root.localList.length) {
            root.localList.splice(index, 1);
            root.localList = root.localList.slice(0);
            todoFileView.setText(JSON.stringify(root.localList));
        }
    }

    function addItem(item) {
        if (!item)
            return;
        switch (root.provider) {
        case "ticktick":
            TickTickService.createTask(item.content);
            return;
        case "googleTasks":
            GoogleTasksService.createTask(item.content);
            return;
        default:
            root.addLocalItem(item);
            return;
        }
    }

    function addTask(desc) {
        const item = {
            "content": desc,
            "done": false,
        };
        addItem(item);
    }

    function getTasksByDate(currentDate) {
        const res = [];

        const currentDay = currentDate.getDate();
        const currentMonth = currentDate.getMonth();
        const currentYear = currentDate.getFullYear();

        for (let i = 0; i < root.list.length; i++) {
            const taskDate = new Date(root.list[i]['date']);
            if (
                taskDate.getDate() === currentDay &&
                taskDate.getMonth() === currentMonth &&
                taskDate.getFullYear() === currentYear
              ) {
                res.push(root.list[i]);
              }
        }

        return res;
    }

    function markDone(index) {
        const task = root.list[index];
        if (!task)
            return;

        switch (root.provider) {
        case "ticktick":
            TickTickService.setTaskDone(task, true);
            return;
        case "googleTasks":
            GoogleTasksService.setTaskDone(task, true);
            return;
        default:
            root.setLocalTaskDone(index, true);
            return;
        }
    }

    function markUnfinished(index) {
        const task = root.list[index];
        if (!task)
            return;

        switch (root.provider) {
        case "ticktick":
            TickTickService.setTaskDone(task, false);
            return;
        case "googleTasks":
            GoogleTasksService.setTaskDone(task, false);
            return;
        default:
            root.setLocalTaskDone(index, false);
            return;
        }
    }

    function deleteItem(index) {
        const task = root.list[index];
        if (!task)
            return;

        switch (root.provider) {
        case "ticktick":
            TickTickService.deleteTask(task);
            return;
        case "googleTasks":
            GoogleTasksService.deleteTask(task);
            return;
        default:
            root.deleteLocalItem(index);
            return;
        }
    }

    function refresh() {
        switch (root.provider) {
        case "ticktick":
            TickTickService.refresh();
            return;
        case "googleTasks":
            GoogleTasksService.refresh();
            return;
        default:
            todoFileView.reload();
            return;
        }
    }

    onProviderChanged: {
        if (root.remoteEnabled && root.connected) {
            providerRefreshTimer.restart();
            root.refresh();
        } else {
            providerRefreshTimer.stop();
        }
    }

    Component.onCompleted: {
        refresh();
    }

    Timer {
        id: providerRefreshTimer
        interval: Math.max(1, (Config.options.todo ? Config.options.todo.refreshIntervalMinutes : 5)) * 60 * 1000
        repeat: true
        running: root.remoteEnabled && root.connected
        onTriggered: root.refresh()
    }

    FileView {
        id: todoFileView
        path: Qt.resolvedUrl(root.filePath)
        atomicWrites: true
        onLoaded: {
            const fileContents = todoFileView.text()
            root.localList = JSON.parse(fileContents)

            for (let i=0; i< root.localList.length; i++){
              let d = root.localList[i]['date'];
              root.localList[i]['date'] = d ? new Date(d) : new Date();
              root.localList[i]['hasDate'] = d !== undefined && d !== null;
            }

            console.log("[To Do] File loaded")
        }
        onLoadFailed: (error) => {
            if(error != FileViewError.FileNotFound) {
                console.log("[To Do] Error loading file: " + error)
                return
            }
            // File might be transiently missing during a shell hot-reload or
            // restart — retrying first avoids wiping the user's todo list with
            // an empty array.
            if (Date.now() - root.initTimestamp > root.missingFileGracePeriod) {
                console.log("[To Do] File not found after grace, creating new file.")
                root.localList = []
                todoFileView.setText(JSON.stringify(root.localList))
            } else {
                missingFileRetryTimer.restart()
            }
        }
    }

    Timer {
        id: missingFileRetryTimer
        interval: root.missingFileRetryInterval
        repeat: false
        onTriggered: todoFileView.reload()
    }
}
