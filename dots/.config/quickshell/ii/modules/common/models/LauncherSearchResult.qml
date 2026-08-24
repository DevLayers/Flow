import QtQuick
import Quickshell

QtObject {
    enum IconType { Material, Text, System, Image, None }
    enum FontType { Normal, Monospace }

    // General stuff
    property string key: ""  // Stable identity key for ScriptModel tracking
    property string type: ""
    property var fontType: LauncherSearchResult.FontType.Normal
    property string name: ""
    property string rawValue: ""
    property string iconName: ""
    property var iconType: LauncherSearchResult.IconType.None
    property string verb: ""
    property bool blurImage: false
    property bool pinned: false
    property var execute: () => {
        print("Not implemented");
    }
    property var actions: []
    
    // Stuff needed for DesktopEntry 
    property string id: ""
    property bool shown: true
    property string comment: ""
    property bool runInTerminal: false
    property string genericName: ""
    property list<string> keywords: []
    property bool isMath: false
    property bool isBuiltin: false
    property bool keepOverviewOpen: false
    property var settingRef: null
    property string controlKind: ""
    property var controlValue: null
    property string panelId: ""
    property bool pinnable: true
    property list<string> matchTerms: []
    property list<string> keyHints: []
    property string feedbackText: ""

    // Extra stuff to allow for more flexibility
    property string category: type
}
