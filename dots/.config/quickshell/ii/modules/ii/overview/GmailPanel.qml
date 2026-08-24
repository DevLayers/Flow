pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: 0
    property bool unreadOnly: false

    readonly property var rows: root.filteredMessages()
    readonly property var selectedMessage: root.selectedIndex >= 0 && root.selectedIndex < root.rows.length ? root.rows[root.selectedIndex] : null
    readonly property string statusText: !EmailService.authenticated
        ? Translation.tr("Gmail is not connected")
        : root.selectedMessage
            ? String(root.selectedMessage.subject ?? "")
            : Translation.tr("%1 messages").arg(String(root.rows.length))

    implicitWidth: 720
    implicitHeight: scaffold.implicitHeight

    function modelRows(model) {
        const rows = [];
        for (let index = 0; model && index < model.count; index++)
            rows.push(model.get(index));
        return rows;
    }

    function filteredMessages() {
        const query = root.searchQuery.trim().toLocaleLowerCase();
        const local = root.modelRows(EmailService.inboxMessages);
        const remote = root.modelRows(EmailService.searchMessagesModel);
        const seen = ({});
        return local.concat(remote).filter(message => {
            const id = String(message?.id ?? "");
            if (seen[id])
                return false;
            seen[id] = true;
            if (root.unreadOnly && !message?.unread)
                return false;
            if (query.length === 0)
                return true;
            return [message?.from, message?.subject, message?.snippet].join(" ").toLocaleLowerCase().includes(query);
        });
    }

    function clampSelection() {
        root.selectedIndex = root.rows.length === 0 ? -1 : Math.max(0, Math.min(root.selectedIndex, root.rows.length - 1));
    }

    function navigateUp(): bool {
        if (root.selectedIndex <= 0)
            return false;
        root.selectedIndex--;
        messageList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateDown(): bool {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.rows.length - 1)
            return false;
        root.selectedIndex++;
        messageList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateLeft(): bool { root.unreadOnly = !root.unreadOnly; return true; }
    function navigateRight(): bool { root.unreadOnly = !root.unreadOnly; return true; }

    function activateSelected(): bool {
        if (!root.selectedMessage?.id)
            return false;
        EmailService.fetchEmailBody(root.selectedMessage.id);
        if (root.selectedMessage.unread)
            EmailService.markAsRead(root.selectedMessage.id);
        return true;
    }

    function secondaryActivateSelected(): bool {
        if (!root.selectedMessage)
            return false;
        EmailService.composeDraftTo = String(root.selectedMessage.from ?? "");
        EmailService.composeDraftSubject = Translation.tr("Re: %1").arg(String(root.selectedMessage.subject ?? ""));
        GlobalStates.openCheatsheet("email");
        return true;
    }

    function editSelected(): bool {
        if (!root.selectedMessage?.id)
            return false;
        EmailService.markAsRead(root.selectedMessage.id);
        return true;
    }

    function focusInput(): bool { return false; }

    onRowsChanged: root.clampSelection()
    onSearchQueryChanged: {
        root.selectedIndex = 0;
        if (root.searchQuery.trim().length >= 2 && EmailService.authenticated)
            remoteSearchTimer.restart();
    }

    Timer {
        id: remoteSearchTimer
        interval: 350
        repeat: false
        onTriggered: EmailService.searchMessages(root.searchQuery.trim())
    }

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Email")
        icon: "mail"
        accent: true
        statusText: root.statusText
        showStatus: true
        primaryHint: ({ label: Translation.tr("Open"), keys: ["↵"] })
        hints: [
            { label: Translation.tr("Reply"), keys: ["Ctrl", "↵"] },
            { label: Translation.tr("Mark read"), keys: ["Ctrl", "E"] }
        ]

        ColumnLayout {
            width: parent.width
            height: parent.height
            spacing: Appearance.sizes.elevationMargin

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: EmailService.userEmail.length > 0 ? EmailService.userEmail : Translation.tr("Inbox")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }

                RippleButton {
                    implicitWidth: unreadLabel.implicitWidth + Appearance.sizes.elevationMargin * 2
                    implicitHeight: unreadLabel.implicitHeight + Appearance.sizes.elevationMargin
                    buttonRadius: Appearance.rounding.full
                    colBackground: root.unreadOnly ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh
                    colBackgroundHover: root.unreadOnly ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colSurfaceContainerHighHover
                    colRipple: root.unreadOnly ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colSurfaceContainerHighActive
                    onClicked: root.unreadOnly = !root.unreadOnly
                    StyledText {
                        id: unreadLabel
                        anchors.centerIn: parent
                        text: Translation.tr("Unread")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: root.unreadOnly ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: EmailService.authenticated
                spacing: Appearance.sizes.elevationMargin

                ListView {
                    id: messageList
                    Layout.preferredWidth: parent.width * 0.45
                    Layout.fillHeight: true
                    clip: true
                    spacing: Appearance.sizes.elevationMargin / 2
                    model: root.rows

                    delegate: RippleButton {
                        required property int index
                        required property var modelData
                        width: messageList.width
                        implicitHeight: messageContent.implicitHeight + Appearance.sizes.elevationMargin * 2
                        buttonRadius: Appearance.rounding.normal
                        colBackground: root.selectedIndex === index ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh
                        colBackgroundHover: root.selectedIndex === index ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colSurfaceContainerHighHover
                        colRipple: root.selectedIndex === index ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colSurfaceContainerHighActive
                        onClicked: { root.selectedIndex = index; root.activateSelected(); }

                        ColumnLayout {
                            id: messageContent
                            anchors.fill: parent
                            anchors.margins: Appearance.sizes.elevationMargin
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: String(modelData.from ?? "")
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: modelData.unread ? Font.DemiBold : Font.Normal
                                color: root.selectedIndex === index ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: String(modelData.subject ?? "")
                                elide: Text.ElideRight
                                font.weight: modelData.unread ? Font.DemiBold : Font.Normal
                                color: root.selectedIndex === index ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: String(modelData.snippet ?? "")
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.selectedIndex === index ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Appearance.sizes.elevationMargin / 2

                    StyledText {
                        Layout.fillWidth: true
                        text: String(root.selectedMessage?.subject ?? Translation.tr("Select a message"))
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnSurface
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: String(root.selectedMessage?.from ?? "")
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: EmailService.loadingEmailBody ? Translation.tr("Loading message…") : (EmailService.currentEmailBody || String(root.selectedMessage?.snippet ?? ""))
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignTop
                        color: Appearance.colors.colOnSurface
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: !EmailService.authenticated
                text: Translation.tr("Connect Gmail in Cheatsheet to search your inbox here.")
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
            }
        }
    }
}
