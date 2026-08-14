pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * The list of saved chats.
 *
 * The same component is the drawer's content on a narrow sidebar and the pane's
 * content on a wide one — only its host changes, so a chat is opened, renamed
 * or thrown away the same way at every width.
 *
 * Every action here is a button. The commands that used to be the only way to
 * save and load a chat still work, but nothing depends on them any more.
 */
Item {
    id: root

    signal closeRequested

    /** The drawer wants a way out; the pane does not need one. */
    property bool showCloseButton: false

    readonly property var sessions: Ai.sessions
    property string expandedId: ""
    property string renamingId: ""

    readonly property var visibleEntries: {
        const entries = root.sessions.index ?? [];
        const needle = searchField.text.trim().toLowerCase();
        if (needle.length === 0)
            return entries;
        // Titles filter as the user types; bodies come back from the helper a
        // moment later and widen the same list.
        const matched = root.sessions.matchedIds;
        return entries.filter(entry => entry.title.toLowerCase().includes(needle) || (matched?.indexOf(entry.id) ?? -1) >= 0);
    }

    function whenText(stamp: real): string {
        const date = new Date(stamp);
        const now = new Date();
        const sameDay = date.toDateString() === now.toDateString();
        if (sameDay)
            return Qt.formatDateTime(date, "HH:mm");
        const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        if (date.toDateString() === yesterday.toDateString())
            return Translation.tr("Yesterday");
        if (date.getFullYear() === now.getFullYear())
            return Qt.formatDateTime(date, "d MMM");
        return Qt.formatDateTime(date, "MMM yyyy");
    }

    Component.onCompleted: root.sessions.ensureLoaded()

    component ActionButton: RippleButton {
        id: actionButton

        property string symbol: ""
        property string tooltipText: ""

        implicitWidth: 30
        implicitHeight: 30
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: actionButton.symbol
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer2
        }

        StyledToolTip {
            text: actionButton.tooltipText
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: height / 2
                color: Appearance.colors.colLayer2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 6

                    MaterialSymbol {
                        text: "search"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colSubtext
                    }

                    StyledTextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: Appearance.colors.colOnLayer2
                        onTextChanged: searchDebounce.restart()
                        onAccepted: {
                            searchDebounce.stop();
                            root.sessions.search(searchField.text);
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchField.text.length === 0
                            text: Translation.tr("Search chats")
                            color: Appearance.colors.colSubtext
                            font: searchField.font
                        }
                    }

                    ActionButton {
                        visible: searchField.text.length > 0
                        implicitWidth: 24
                        implicitHeight: 24
                        symbol: "close"
                        tooltipText: Translation.tr("Clear")
                        onClicked: {
                            searchField.clear();
                            root.sessions.search("");
                        }
                    }
                }
            }

            ActionButton {
                symbol: "add_comment"
                tooltipText: Translation.tr("New chat")
                onClicked: {
                    Ai.newChat();
                    root.closeRequested();
                }
            }

            ActionButton {
                visible: root.showCloseButton
                symbol: "left_panel_close"
                tooltipText: Translation.tr("Close")
                onClicked: root.closeRequested()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledListView {
                id: sessionListView
                anchors.fill: parent
                spacing: 2
                clip: true

                model: ScriptModel {
                    values: root.visibleEntries
                }

                delegate: Rectangle {
                    id: sessionRow
                    required property var modelData

                    readonly property bool current: sessionRow.modelData.id === root.sessions.currentId
                    readonly property bool expanded: sessionRow.modelData.id === root.expandedId
                    readonly property bool renaming: sessionRow.modelData.id === root.renamingId

                    anchors.left: parent?.left
                    anchors.right: parent?.right
                    implicitHeight: rowColumnLayout.implicitHeight + 8 * 2
                    radius: Appearance.rounding.small
                    color: sessionRow.current ? Appearance.colors.colSecondaryContainer : (rowMouseArea.containsMouse ? Appearance.colors.colLayer2Hover : ColorUtils.transparentize(Appearance.colors.colLayer2, 1))

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }

                    MouseArea {
                        id: rowMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (sessionRow.renaming)
                                return;
                            Ai.openSession(sessionRow.modelData.id);
                            root.closeRequested();
                        }
                    }

                    ColumnLayout {
                        id: rowColumnLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                visible: sessionRow.modelData.pinned
                                text: "keep"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: !sessionRow.renaming
                                text: sessionRow.modelData.title.length > 0 ? sessionRow.modelData.title : Translation.tr("Untitled chat")
                                elide: Text.ElideRight
                                color: sessionRow.current ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
                            }

                            Loader {
                                Layout.fillWidth: true
                                active: sessionRow.renaming
                                visible: active
                                sourceComponent: StyledTextInput {
                                    text: sessionRow.modelData.title
                                    color: Appearance.colors.colOnLayer1
                                    Component.onCompleted: {
                                        forceActiveFocus();
                                        selectAll();
                                    }
                                    onAccepted: {
                                        root.sessions.rename(sessionRow.modelData.id, text);
                                        root.renamingId = "";
                                    }
                                    Keys.onEscapePressed: root.renamingId = ""
                                }
                            }

                            StyledText {
                                text: root.whenText(sessionRow.modelData.updatedAt)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }

                            ActionButton {
                                implicitWidth: 26
                                implicitHeight: 26
                                symbol: sessionRow.expanded ? "expand_less" : "more_horiz"
                                tooltipText: Translation.tr("More")
                                onClicked: root.expandedId = sessionRow.expanded ? "" : sessionRow.modelData.id
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: sessionRow.modelData.preview.length > 0 && !sessionRow.expanded
                            text: sessionRow.modelData.preview
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        Loader {
                            Layout.fillWidth: true
                            active: sessionRow.expanded
                            visible: active
                            sourceComponent: RowLayout {
                                spacing: 2

                                ActionButton {
                                    symbol: "edit"
                                    tooltipText: Translation.tr("Rename")
                                    onClicked: {
                                        root.renamingId = sessionRow.modelData.id;
                                        root.expandedId = "";
                                    }
                                }

                                ActionButton {
                                    symbol: sessionRow.modelData.pinned ? "keep_off" : "keep"
                                    tooltipText: sessionRow.modelData.pinned ? Translation.tr("Unpin") : Translation.tr("Pin to the top")
                                    onClicked: root.sessions.setPinned(sessionRow.modelData.id, !sessionRow.modelData.pinned)
                                }

                                ActionButton {
                                    symbol: "content_copy"
                                    tooltipText: Translation.tr("Duplicate")
                                    onClicked: root.sessions.duplicate(sessionRow.modelData.id)
                                }

                                ActionButton {
                                    symbol: "download"
                                    tooltipText: Translation.tr("Export as Markdown")
                                    onClicked: root.sessions.exportMarkdown(sessionRow.modelData.id)
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                ActionButton {
                                    symbol: "delete"
                                    tooltipText: Translation.tr("Delete")
                                    onClicked: {
                                        root.expandedId = "";
                                        root.sessions.remove(sessionRow.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            PagePlaceholder {
                shown: root.visibleEntries.length === 0
                icon: searchField.text.length > 0 ? "search_off" : "forum"
                title: searchField.text.length > 0 ? Translation.tr("Nothing found") : Translation.tr("No saved chats")
                description: searchField.text.length > 0 ? Translation.tr("No chat has that in its name or in what was said") : Translation.tr("Chats are saved as soon as you get an answer")
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.sessions.deletedEntry !== null
            visible: active
            sourceComponent: Rectangle {
                implicitHeight: undoRowLayout.implicitHeight + 8 * 2
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHighest

                RowLayout {
                    id: undoRowLayout
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Deleted “%1”").arg(root.sessions.deletedEntry?.title ?? "")
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }

                    RippleButton {
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 6
                        bottomPadding: 6
                        buttonRadius: Appearance.rounding.full
                        onClicked: root.sessions.undoDelete()

                        contentItem: StyledText {
                            text: Translation.tr("Undo")
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.sessions.lastError.length > 0
            visible: active
            sourceComponent: StyledText {
                text: root.sessions.lastError
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.m3colors.m3error
            }
        }
    }

    Timer {
        // Searching message bodies means opening every file, so it waits for
        // the typing to stop. Title matching is live either way.
        id: searchDebounce
        interval: 260
        onTriggered: root.sessions.search(searchField.text)
    }
}
