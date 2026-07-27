import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "compact_media"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "center" || root.lockBehavior === "lockOnly"

    implicitWidth: 492
    implicitHeight: 240

    // --- Mpris ---
    property MprisPlayer player: MprisController.activePlayer

    readonly property string trackTitle: player?.trackTitle || Translation.tr("No media")
    readonly property string trackArtist: player?.trackArtist || Translation.tr("Unknown Artist")

    // --- Colors (WidgetColorScheme) ---
    readonly property color colSectionOne: WidgetColorScheme.cardBgColor
    readonly property color colSectionTwo: WidgetColorScheme.innerShapeColor
    readonly property color colSectionThree: WidgetColorScheme.accentColor
    readonly property color colTextOnOne: WidgetColorScheme.textColorOnBg
    readonly property color colSubtextOnOne: WidgetColorScheme.subtextColorOnBg
    readonly property color colIconOnTwo: WidgetColorScheme.textColorOnBg
    readonly property color colIconOnThree: WidgetColorScheme.onAccentColor

    // --- Layout proportions 6:4:2 (total 12) ---
    readonly property int gap: 6
    readonly property real totalGap: root.gap * 2
    readonly property real availableWidth: root.width - root.totalGap
    readonly property real sectionOneWidth: root.availableWidth * (6 / 12)
    readonly property real sectionTwoWidth: root.availableWidth * (4 / 12)
    readonly property real sectionThreeWidth: root.availableWidth * (2 / 12)

    readonly property int globalRadius: Appearance.rounding.large

    // --- Shadow ---
    StyledRectangularShadow {
        id: bgShadow
        target: mainContainer
        visible: Config.options.background.widgets.enableShadows ?? true
    }

    Row {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: 8
        spacing: root.gap

        // ─── SECTION 1: Title + Artist (6/12) ───
        Rectangle {
            id: sectionOne
            width: root.sectionOneWidth
            height: parent.height
            color: root.colSectionOne
            radius: root.globalRadius

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 48
                anchors.bottomMargin: 12
                spacing: 4

                // Song title — variable axis font, heavy weight + wide, max 3 lines
                Text {
                    id: titleText
                    Layout.fillWidth: true
                    text: root.trackTitle
                    color: root.colTextOnOne
                    font.family: Appearance.font.family.main
                    font.pixelSize: 34
                    font.weight: Font.Black
                    font.variableAxes: ({ "wght": 900, "wdth": 145 })
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignTop
                    renderType: Text.QtRendering
                }

                // Artist name — thinner, smaller, right below title
                Text {
                    Layout.fillWidth: true
                    text: root.trackArtist
                    color: root.colSubtextOnOne
                    font.family: Appearance.font.family.main
                    font.pixelSize: 14
                    font.weight: Font.Light
                    font.variableAxes: ({ "wght": 300 })
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignTop
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // ─── SECTION 2: Play/Pause (4/12) ───
        Rectangle {
            id: sectionTwo
            readonly property real pressExpansion: sectionTwoMouse.pressed ? 12 : 0
            width: root.sectionTwoWidth + pressExpansion
            height: parent.height
            radius: sectionTwoMouse.pressed ? Appearance.rounding.small : root.globalRadius
            color: {
                if (sectionTwoMouse.pressed) return Qt.darker(root.colSectionTwo, 1.2);
                if (sectionTwoMouse.containsMouse) return Qt.lighter(root.colSectionTwo, 1.1);
                return root.colSectionTwo;
            }

            Behavior on width {
                animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
            }

            Behavior on radius {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.player?.isPlaying ? "pause" : "play_arrow"
                iconSize: 32
                color: root.colIconOnTwo
                fill: 1
            }

            MouseArea {
                id: sectionTwoMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player?.togglePlaying()
            }
        }

        // ─── SECTION 3: Next (2/12) ───
        Rectangle {
            id: sectionThree
            readonly property real pressExpansion: sectionThreeMouse.pressed ? 12 : 0
            width: root.sectionThreeWidth + pressExpansion
            height: parent.height
            radius: sectionThreeMouse.pressed ? Appearance.rounding.small : root.globalRadius
            color: {
                if (sectionThreeMouse.pressed) return Qt.darker(root.colSectionThree, 1.2);
                if (sectionThreeMouse.containsMouse) return Qt.lighter(root.colSectionThree, 1.1);
                return root.colSectionThree;
            }

            Behavior on width {
                animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
            }

            Behavior on radius {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_next"
                iconSize: 22
                color: root.colIconOnThree
                fill: 1
            }

            MouseArea {
                id: sectionThreeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player?.next()
            }
        }
    }
}
