import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import qs
import ".."

DockContextMenuBase {
    id: root

    property string folderPath: ""
    property int maxItems: 8

    readonly property string folderName: {
        if (!folderPath) return "";
        const parts = folderPath.split("/").filter(s => s.length > 0);
        return parts[parts.length - 1] ?? folderPath;
    }

    headerText: root.folderName
    headerSymbol: "folder_open"

    FolderListModel {
        id: folderModel
        folder: root.folderPath ? ("file://" + root.folderPath) : ""
        showDirs: true
        showFiles: true
        showHidden: false
        showDotAndDotDot: false
        sortField: FolderListModel.Time
        sortReversed: true
    }

    contentComponent: ColumnLayout {
        spacing: 2
        implicitWidth: 240

        Repeater {
            model: Math.min(folderModel.count, root.maxItems)
            delegate: DockMenuButton {
                required property int index
                Layout.fillWidth: true

                readonly property var _fileName: folderModel.get(index, "fileName") || ""
                readonly property var _filePath: folderModel.get(index, "filePath") || (root.folderPath + "/" + _fileName)
                readonly property bool _isDir: folderModel.get(index, "fileIsDir") ?? false

                symbolName: _isDir ? "folder" : "insert_drive_file"
                labelText: _fileName

                onTriggered: {
                    root.close();
                    if (_filePath)
                        Quickshell.execDetached(["xdg-open", _filePath]);
                }
            }
        }

        Rectangle {
            visible: folderModel.count > 0
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            implicitHeight: 1
            color: Appearance.colors.colLayer0Border
        }

        DockMenuButton {
            Layout.fillWidth: true
            symbolName: "open_in_new"
            labelText: Translation.tr("Open in File Manager")
            onTriggered: {
                root.close();
                Quickshell.execDetached(["xdg-open", root.folderPath]);
            }
        }
    }
}
