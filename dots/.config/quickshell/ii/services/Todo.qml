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

    // Use TickTick if available
    readonly property bool useTickTick: TickTickService.available

    // Unified task list: either from TickTick or local file
    property var list: root.useTickTick ? TickTickService.tasks : root.localList
    property var localList: []

    // Sync state (for UI indicator)
    readonly property bool syncing: TickTickService.syncing

    readonly property string aiProviderId: "local"
    readonly property string aiListId: "local"

    function persistLocalTasks(next) {
        root.localList = Array.from(next ?? []);
        todoFileView.setText(JSON.stringify(root.localList));
    }

    /** Provider-facing local task contract. It never routes through TickTick. */
    function aiListTaskLists() {
        return [{
            id: root.aiListId,
            name: qsTr("Local tasks"),
            accountId: qsTr("This device")
        }];
    }

    function aiListTasks(filters = null) {
        const query = String(filters?.query ?? "").trim().toLowerCase();
        return root.localList.filter(task => {
            if (query.length === 0)
                return true;
            return String(task?.content ?? task?.title ?? "").toLowerCase().includes(query)
                || String(task?.notes ?? "").toLowerCase().includes(query);
        }).map(task => Object.assign({}, task, {
            provider: root.aiProviderId,
            accountId: qsTr("This device"),
            listId: root.aiListId,
            listName: qsTr("Local tasks"),
            taskId: String(task?.id ?? "")
        }));
    }

    function aiCreateTask(input) {
        const title = String(input?.title ?? input?.content ?? "").trim();
        if (title.length === 0)
            return { ok: false, error: "A task needs a title" };
        const task = {
            id: "local-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 8),
            provider: root.aiProviderId,
            accountId: qsTr("This device"),
            listId: root.aiListId,
            listName: qsTr("Local tasks"),
            content: title,
            title: title,
            notes: String(input?.notes ?? input?.content ?? ""),
            dueDate: input?.dueDate ?? null,
            date: input?.dueDate ? new Date(input.dueDate) : new Date(),
            hasDate: !!input?.dueDate,
            done: false
        };
        root.persistLocalTasks(root.localList.concat([task]));
        return { ok: true, task: task };
    }

    function aiUpdateTask(ref, changes) {
        const taskId = String(ref?.taskId ?? ref?.id ?? "");
        const index = root.localList.findIndex(task => String(task?.id ?? "") === taskId);
        if (index < 0)
            return { ok: false, error: "Task was not found" };
        const next = root.localList.slice(0);
        const current = Object.assign({}, next[index]);
        if (changes?.title !== undefined || changes?.content !== undefined) {
            const title = String(changes.title ?? changes.content).trim();
            if (title.length === 0)
                return { ok: false, error: "A task needs a title" };
            current.title = title;
            current.content = title;
        }
        if (changes?.notes !== undefined || changes?.contentText !== undefined)
            current.notes = String(changes.notes ?? changes.contentText);
        if (changes?.dueDate !== undefined) {
            current.dueDate = changes.dueDate;
            current.date = changes.dueDate ? new Date(changes.dueDate) : new Date();
            current.hasDate = !!changes.dueDate;
        }
        if (changes?.done !== undefined)
            current.done = changes.done === true;
        next[index] = current;
        root.persistLocalTasks(next);
        return { ok: true, task: current };
    }

    function aiCompleteTask(ref) {
        return root.aiUpdateTask(ref, { done: true });
    }

    function aiDeleteTask(ref) {
        const taskId = String(ref?.taskId ?? ref?.id ?? "");
        const index = root.localList.findIndex(task => String(task?.id ?? "") === taskId);
        if (index < 0)
            return { ok: false, error: "Task was not found" };
        const next = root.localList.slice(0);
        const removed = next.splice(index, 1)[0];
        root.persistLocalTasks(next);
        return { ok: true, task: removed };
    }

    function addItem(item) {
        if (root.useTickTick) {
            TickTickService.createTask(item.content);
            return;
        }
        localList.push(item)
        root.localList = localList.slice(0)
        todoFileView.setText(JSON.stringify(root.localList))
    }

    function addTask(desc) {
        const item = {
            "content": desc,
            "done": false,
        }
        addItem(item)
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
        if (root.useTickTick) {
            let task = root.list[index];
            if (task && task.id) {
                TickTickService.completeTask(task.id, task.projectId);
            }
            return;
        }
        if (index >= 0 && index < localList.length) {
            localList[index].done = true
            root.localList = localList.slice(0)
            todoFileView.setText(JSON.stringify(root.localList))
        }
    }

    function markUnfinished(index) {
        if (root.useTickTick) {
            // TickTick API doesn't have a simple "uncomplete" — refresh instead
            TickTickService.refresh();
            return;
        }
        if (index >= 0 && index < localList.length) {
            localList[index].done = false
            root.localList = localList.slice(0)

            if(CalendarService.khalAvailable){
              return
            }
            todoFileView.setText(JSON.stringify(root.localList))
        }
    }

    function deleteItem(index) {
        if (root.useTickTick) {
            let task = root.list[index];
            if (task && task.id) {
                TickTickService.deleteTask(task.id, task.projectId);
            }
            return;
        }
        if (index >= 0 && index < localList.length) {
            let item = localList[index]
            localList.splice(index, 1)
            root.localList = localList.slice(0)
            todoFileView.setText(JSON.stringify(root.localList))
        }
    }

    function refresh() {
        if (root.useTickTick) {
            TickTickService.refresh();
            return;
        }
        todoFileView.reload()
    }

    Component.onCompleted: {
        refresh()
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
              if (!root.localList[i].id)
                  root.localList[i].id = "local-legacy-" + i;
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
