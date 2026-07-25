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

    TextMetrics {
        id: timeMetrics
        font.family: nagasakiFont.name
        font.pixelSize: 100
        text: root.timeText
    }

    readonly property real computedFontSize: {
        if (timeMetrics.advanceWidth <= 0) return 100;
        const availableWidth = root.width * 0.9;
        const availableHeight = root.height * 0.9;
        const widthBased = 100 * (availableWidth / timeMetrics.advanceWidth);
        const heightBased = availableHeight * 0.85;
        return Math.min(widthBased, heightBased);
    }

    StyledText {
        id: timeLabel
        anchors.centerIn: parent
        text: root.timeText
        font.family: nagasakiFont.name
        font.pixelSize: root.computedFontSize
        color: root.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    StyledDropShadow {
        target: timeLabel
        visible: Config.options.background.widgets.enableShadows ?? true
    }
}
