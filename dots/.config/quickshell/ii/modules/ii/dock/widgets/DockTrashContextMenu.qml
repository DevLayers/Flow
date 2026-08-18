import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import qs
import ".."

DockContextMenuBase {
    id: root

    property int trashCount: 0

    headerText: root.trashCount > 0 
          ? Translation.tr("Trash (%1 items)").arg(root.trashCount)
          : Translation.tr("Trash (Empty)")
    headerSymbol: root.trashCount > 0 ? "delete" : "delete_outline"

    contentComponent: ColumnLayout {
        spacing: 0

        DockMenuButton {
            Layout.fillWidth: true
            symbolName: "folder_open"
            labelText: Translation.tr("Open Trash")
            onTriggered: {
                Quickshell.execDetached(["xdg-open", "trash:///"]);
                root.close();
            }
        }

        DockMenuButton {
            Layout.fillWidth: true
            visible: root.trashCount > 0
            symbolName: "delete_sweep"
            labelText: Translation.tr("Empty Trash")
            onTriggered: {
                if (root.anchorItem && root.anchorItem.dockContent) {
                    root.anchorItem.dockContent.emptyTrash();
                }
                root.close();
            }
        }
    }
}
