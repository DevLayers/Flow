pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "at_a_glance"

    readonly property var options: Config.options.background.widgets.at_a_glance
    readonly property int cellSize: 120
    readonly property int widthCells: Math.max(2, Math.min(3, options.widthCells || 3))
    implicitWidth: cellSize * widthCells
    implicitHeight: cellSize

    readonly property color cardBgColor: WidgetColorScheme.cardBgColor
    readonly property color textColorOnBg: WidgetColorScheme.textColorOnBg
    readonly property color subtextColorOnBg: WidgetColorScheme.subtextColorOnBg
    readonly property color accentColor: WidgetColorScheme.accentColor
    readonly property color pillBgColor: WidgetColorScheme.innerShapeColor
    readonly property color pillTextColor: WidgetColorScheme.textColorOnPillTrack
    readonly property bool compact: widthCells === 2
    readonly property string activeServiceKey: AtAGlanceService.activeItemKey

    function openCalendar() {
        calendarIpc.running = true;
    }

    function openMedia() {
        if (AtAGlanceService.player)
            AtAGlanceService.player.togglePlaying();
    }

    function refreshWeather() {
        Weather.getData(true);
    }

    Process {
        id: calendarIpc
        command: ["qs", "ipc", "-c", "ii", "call", "cheatsheet", "toggle"]
    }

    StyledDropShadow {
        target: mainContainer
        visible: Config.options.background.widgets.enableShadows ?? true
    }

    Rectangle {
        id: mainContainer
        anchors.fill: parent
        color: root.cardBgColor
        radius: Appearance.rounding.full
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: Appearance.font.pixelSize.smaller
            spacing: Appearance.font.pixelSize.smaller

            RippleButton {
                id: contextButton
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: root.cellSize
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(root.accentColor, 0.08)
                colRipple: ColorUtils.applyAlpha(root.accentColor, 0.16)
                topLeftRadius: Appearance.rounding.normal
                topRightRadius: Appearance.rounding.normal
                bottomLeftRadius: Appearance.rounding.normal
                bottomRightRadius: Appearance.rounding.normal

                onClicked: {
                    if (AtAGlanceService.activeService === "media") root.openMedia();
                    else if (AtAGlanceService.activeService === "calendar") root.openCalendar();
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.font.pixelSize.smaller
                    anchors.rightMargin: Appearance.font.pixelSize.smaller
                    spacing: Appearance.font.pixelSize.smaller

                    MaterialShape {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Appearance.font.pixelSize.huge * 2
                        implicitHeight: Appearance.font.pixelSize.huge * 2
                        shapeString: "Cookie7Sided"
                        color: root.pillBgColor

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: AtAGlanceService.activeIcon
                            iconSize: Appearance.font.pixelSize.large
                            color: root.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: AtAGlanceService.activeTitle
                            color: root.textColorOnBg
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: AtAGlanceService.activeSubtitle
                            color: root.subtextColorOnBg
                            font.pixelSize: Appearance.font.pixelSize.normal
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !root.compact && AtAGlanceService.activeMeta !== ""
                            text: AtAGlanceService.activeMeta
                            color: root.subtextColorOnBg
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Appearance.font.pixelSize.small
                Layout.maximumWidth: Appearance.font.pixelSize.small
                spacing: Appearance.font.pixelSize.smaller
                visible: options.showSeparators

                Repeater {
                    model: 3

                    delegate: Rectangle {
                        required property int index
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Appearance.font.pixelSize.smaller
                        implicitHeight: Appearance.font.pixelSize.smaller
                        radius: Appearance.rounding.full
                        color: root.subtextColorOnBg
                        opacity: 0.7 - (index * 0.12)
                    }
                }
            }

            RippleButton {
                id: weatherButton
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: root.cellSize * 0.75
                colBackground: root.pillBgColor
                colBackgroundHover: ColorUtils.mix(root.pillBgColor, root.accentColor, 0.12)
                colRipple: ColorUtils.mix(root.pillBgColor, root.accentColor, 0.2)
                topLeftRadius: Appearance.rounding.normal
                topRightRadius: Appearance.rounding.full
                bottomLeftRadius: Appearance.rounding.normal
                bottomRightRadius: Appearance.rounding.full
                enabled: options.enableWeather

                onClicked: root.refreshWeather()

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Appearance.font.pixelSize.smaller
                    anchors.bottomMargin: Appearance.font.pixelSize.smaller
                    anchors.leftMargin: Appearance.font.pixelSize.smaller
                    anchors.rightMargin: Appearance.font.pixelSize.smaller
                    spacing: 0

                    Image {
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                        Layout.fillHeight: true
                        source: WeatherIcons.getWeatherIcon(AtAGlanceService.weatherCode, false)
                        sourceSize: Qt.size(Appearance.font.pixelSize.huge * 2, Appearance.font.pixelSize.huge * 2)
                        opacity: options.enableWeather ? 1 : 0.35
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                        text: AtAGlanceService.weatherTemperature || Translation.tr("--")
                        color: root.pillTextColor
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Behavior on implicitWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
}
