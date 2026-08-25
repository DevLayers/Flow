import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * Timetable-local entry point for user-controlled calendar sources. Remote
 * URLs remain read-only vdirsyncer subscriptions; local files are copied into
 * the writable khal calendar through CalendarService's UID-safe bridge.
 */
Item {
    id: root

    z: 20
    visible: false
    focus: visible
    property string urlDraft: ""
    property string statusText: ""
    readonly property bool importsEnabled: Config.options.calendar.timetable.imports.enable

    function open() {
        root.visible = true;
        root.forceActiveFocus();
    }

    function close() {
        root.visible = false;
    }

    function importFile(path) {
        if (!root.importsEnabled)
            return;
        root.statusText = Translation.tr("Importing calendar…");
        CalendarService.importFromIcs(path, false, "", reply => {
            if (!reply?.ok) {
                root.statusText = String(reply?.error ?? Translation.tr("Could not import the calendar."));
                return;
            }
            const imported = Number(reply.imported ?? 0);
            const skipped = Number(reply.skipped ?? 0);
            root.statusText = skipped > 0
                ? Translation.tr("Imported %1 event(s), skipped %2 duplicate(s).").arg(String(imported)).arg(String(skipped))
                : Translation.tr("Imported %1 event(s).").arg(String(imported));
        });
    }

    function addSubscription() {
        if (!root.importsEnabled)
            return;
        if (CalendarSubscriptions.addSubscription(root.urlDraft)) {
            root.urlDraft = "";
            subscriptionInput.textField.clear();
        }
    }

    Keys.onEscapePressed: root.close()

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: panel
        width: Math.min(480, Math.max(330, root.width - 48))
        height: Math.min(root.height - 32, contentColumn.implicitHeight + 40)
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        radius: Appearance.rounding.large
        color: Appearance.m3colors.m3surfaceContainerHigh

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: Translation.tr("Calendar sources")
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Import local files or add read-only ICS links.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                        wrapMode: Text.Wrap
                    }
                }

                RippleButton {
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.close()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }

            ConfigSwitch {
                Layout.fillWidth: true
                buttonIcon: "calendar_add_on"
                text: Translation.tr("Enable calendar sources")
                checked: Config.options.calendar.timetable.imports.enable
                onCheckedChanged: Config.options.calendar.timetable.imports.enable = checked
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("When disabled, saved links are disconnected and local imports cannot modify your calendar.")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
                opacity: root.importsEnabled ? 1 : 0.7
                wrapMode: Text.Wrap
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                implicitHeight: 44
                centerContent: true
                materialIcon: "upload_file"
                mainText: Translation.tr("Import ICS file")
                enabled: root.importsEnabled && CalendarService.khalAvailable
                colText: Appearance.colors.colOnPrimaryContainer
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                onClicked: icsFileDialog.open()
            }

            ConfigTextField {
                id: subscriptionInput
                Layout.fillWidth: true
                enabled: root.importsEnabled
                icon: "link"
                text: Translation.tr("Calendar ICS URL")
                placeholderText: "https://…/calendar.ics"
                inputText: root.urlDraft
                textField.onTextChanged: root.urlDraft = textField.text
                textField.onAccepted: root.addSubscription()
            }

            RippleButtonWithIcon {
                Layout.alignment: Qt.AlignRight
                implicitHeight: 40
                centerContent: true
                materialIcon: "add"
                mainText: Translation.tr("Add URL")
                enabled: root.importsEnabled && !CalendarSubscriptions.applying && root.urlDraft.trim().length > 0
                colText: Appearance.colors.colOnPrimaryContainer
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                onClicked: root.addSubscription()
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.statusText.length > 0 || CalendarSubscriptions.lastError.length > 0
                text: CalendarSubscriptions.lastError.length > 0 ? CalendarSubscriptions.lastError : root.statusText
                font.pixelSize: Appearance.font.pixelSize.small
                color: CalendarSubscriptions.lastError.length > 0 ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                wrapMode: Text.Wrap
            }

            StyledText {
                Layout.fillWidth: true
                text: CalendarSubscriptions.applying
                    ? Translation.tr("Updating calendar configuration…")
                    : (CalendarSubscriptions.syncInProgress
                        ? Translation.tr("Synchronizing subscribed calendars…")
                        : Translation.tr("Links are always read-only."))
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
                wrapMode: Text.Wrap
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(148, subscriptionColumn.implicitHeight)
                contentWidth: width
                contentHeight: subscriptionColumn.implicitHeight
                clip: true
                visible: Config.options.calendar.timetable.subscriptions.length > 0

                ColumnLayout {
                    id: subscriptionColumn
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: Config.options.calendar.timetable.subscriptions

                        delegate: Rectangle {
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colLayer2

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 6
                                spacing: 8

                                MaterialSymbol {
                                    text: "cloud_download"
                                    iconSize: Appearance.font.pixelSize.large
                                    color: Appearance.colors.colPrimary
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer2
                                }

                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colErrorContainer
                                    onClicked: CalendarSubscriptions.removeSubscription(modelData)

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "close"
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: parent.hovered ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer2
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: icsFileDialog
        title: Translation.tr("Choose an ICS calendar file")
        currentFolder: "file://" + Quickshell.env("HOME")
        fileMode: FileDialog.OpenFile
        nameFilters: [Translation.tr("Calendar files (*.ics *.ical)"), Translation.tr("All files (*)")]
        onAccepted: root.importFile(decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
    }
}
