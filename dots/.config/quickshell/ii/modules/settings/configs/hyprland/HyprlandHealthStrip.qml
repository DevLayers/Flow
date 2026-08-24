pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Page-level strip for Settings -> Hyprland.
 *
 * Says the three things no individual control can: what this page currently owns on disk,
 * how old the backup behind it is, and anything that would stop a setting here from taking
 * effect - a line inside our own block that this version did not write, or a key that
 * Modes / Game Mode / the screen shader re-push after the file has loaded.
 */
Rectangle {
    id: root

    signal reviewRequested
    signal removeAllRequested

    readonly property var status: HyprlandGui.status
    readonly property bool failed: HyprlandGui.lastError !== ""
    readonly property bool ownsAnything: root.status.managed > 0 || root.status.files.length > 0
    /// Kept fresh by the timer below so "backed up 4 min ago" does not freeze at whatever it
    /// said when the page was opened.
    property int nowSeconds: Math.floor(Date.now() / 1000)

    readonly property string backupAge: {
        const at = root.status.backupAt;
        if (!at)
            return "";
        const seconds = Math.max(0, root.nowSeconds - at);
        if (seconds < 90)
            return Translation.tr("just now");
        const minutes = Math.round(seconds / 60);
        if (minutes < 60)
            return Translation.tr("%1 min ago").arg(minutes);
        const hours = Math.round(minutes / 60);
        if (hours < 48)
            return Translation.tr("%1 h ago").arg(hours);
        return Translation.tr("%1 days ago").arg(Math.round(hours / 24));
    }

    readonly property string summaryText: {
        if (!HyprlandGui.ready)
            return Translation.tr("Reading ~/.config/hypr/custom…");
        if (!root.ownsAnything)
            return Translation.tr("Nothing written yet — changes here are appended to ~/.config/hypr/custom/, after your own Lua");
        const owned = Translation.tr("%1 settings in %2")
            .arg(root.status.managed).arg(root.status.files.join(", "));
        if (root.backupAge === "")
            return owned;
        return `${owned} · ${Translation.tr("backed up %1").arg(root.backupAge)}`;
    }

    /// One line each, and only when there is something to say.
    readonly property var notes: {
        const list = [];
        if (root.failed)
            list.push({ icon: "error", text: HyprlandGui.lastError.split("\n")[0] });
        if (root.status.unrecognised > 0)
            list.push({
                icon: "help",
                text: Translation.tr("%1 line(s) inside the managed block were not written by this version. They are left exactly as they are.").arg(root.status.unrecognised)
            });
        if (root.status.shadowed.length > 0)
            list.push({
                icon: "layers",
                text: Translation.tr("Overridden after load by Modes, Game Mode or the screen shader: %1").arg(root.status.shadowed.join(", "))
            });
        return list;
    }

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: root.failed ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer1

    Timer {
        interval: 60000
        repeat: true
        running: root.visible
        onTriggered: root.nowSeconds = Math.floor(Date.now() / 1000)
    }

    ColumnLayout {
        id: layout
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 10
            topMargin: 10
            bottomMargin: 10
        }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconSize: 20
                text: root.failed ? "sync_problem" : (root.ownsAnything ? "edit_document" : "draft")
                color: root.failed ? Appearance.colors.colOnErrorContainer
                    : Appearance.colors.colSubtext
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.summaryText
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.failed ? Appearance.colors.colOnErrorContainer
                    : Appearance.colors.colSubtext
            }

            RippleButtonWithIcon {
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 32
                materialIcon: "code"
                mainText: Translation.tr("Review")
                onClicked: root.reviewRequested()

                StyledToolTip {
                    text: Translation.tr("Show the Lua this page has written, and anything not saved yet")
                }
            }

            RippleButtonWithIcon {
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 32
                visible: root.ownsAnything
                materialIcon: "delete_sweep"
                mainText: Translation.tr("Remove all")
                colBackground: Appearance.colors.colLayer2
                colText: Appearance.colors.colError
                onClicked: root.removeAllRequested()

                StyledToolTip {
                    text: Translation.tr("Delete the managed block from every file, leaving your own Lua untouched")
                }
            }
        }

        Repeater {
            model: root.notes

            delegate: RowLayout {
                required property var modelData

                Layout.fillWidth: true
                Layout.leftMargin: 30
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignTop
                    iconSize: 16
                    text: modelData.icon
                    color: root.failed ? Appearance.colors.colOnErrorContainer
                    : Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    text: modelData.text
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.failed ? Appearance.colors.colOnErrorContainer
                    : Appearance.colors.colSubtext
                }
            }
        }
    }
}
