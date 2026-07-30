pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "nagasaki_text"

    implicitWidth: 240
    implicitHeight: 240

    FontLoader {
        id: nagasakiFont
        source: "file://" + Directories.assetsPath + "/fonts/nagasaki.ttf"
    }

    readonly property string hour: DateTime.time.split(":")[0].padStart(2, "0")
    readonly property string minute: DateTime.time.split(":")[1].split(" ")[0].padStart(2, "0")
    readonly property string timeText: hour + minute

    readonly property color textColor: WidgetColorScheme.cardBgColor

    StyledText {
        id: timeLabel
        anchors.centerIn: parent
        text: root.timeText
        font.family: nagasakiFont.name
        font.pixelSize: Config.options.background.widgets.nagasaki_text.size
        color: root.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    StyledDropShadow {
        target: timeLabel
        visible: Config.options.background.widgets.enableShadows ?? false
    }
}
