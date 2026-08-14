pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root

    property int labelPixelSize: Appearance.font.pixelSize.larger
    property int labelWeight: Font.Bold
    property string labelFontFamily: Appearance.font.family.title
    property var labelVariableAxes: Appearance.font.variableAxes.titleRounded
    property real toggleIconSize: Appearance.font.pixelSize.hugeass + Appearance.rounding.verysmall
    readonly property real toggleHeight: Appearance.font.pixelSize.hugeass * 2 + Appearance.rounding.small

    Layout.alignment: Qt.AlignHCenter
    Layout.fillWidth: true
    Layout.minimumHeight: toggleHeight
    Layout.preferredHeight: toggleHeight
    Layout.maximumHeight: toggleHeight
    uniformCellSizes: true

    component ModeButton: RippleButton {
        id: button

        required property bool dark

        property color colText: enabled
            ? toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
            : Appearance.colors.colOnLayer3

        Layout.fillWidth: true
        Layout.minimumHeight: root.toggleHeight
        Layout.preferredHeight: root.toggleHeight
        Layout.maximumHeight: root.toggleHeight
        padding: Appearance.rounding.unsharpenmore
        buttonRadius: Appearance.rounding.full
        toggled: Appearance.m3colors.darkmode === dark
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colBackgroundActive: Appearance.colors.colLayer2Active
        colRipple: Appearance.colors.colLayer2Active

        onClicked: {
            if (Config.options?.background?.useSeparateLightModeWallpaper) {
                if (dark) {
                    const darkPath = Config.options.background.wallpaperPath;
                    if (darkPath && darkPath !== "")
                        Wallpapers.apply(darkPath, true);
                    else
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`]);
                } else {
                    const lightPath = Config.options.background.lightModeWallpaperPath;
                    if (lightPath && lightPath !== "")
                        Wallpapers.applyLightModeWallpaper(lightPath);
                    else
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`]);
                }
            } else {
                Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`]);
            }
        }

        StyledToolTip {
            extraVisibleCondition: !button.enabled
            text: Translation.tr("Custom color scheme has been selected")
        }

        contentItem: Item {
            anchors.fill: parent

            RowLayout {
                anchors.centerIn: parent
                spacing: Appearance.rounding.small

                MaterialSymbol {
                    id: themeModeIcon
                    Layout.alignment: Qt.AlignVCenter
                    iconSize: root.toggleIconSize
                    text: dark ? "dark_mode" : "light_mode"
                    fill: toggled ? 1 : 0
                    color: button.colText
                    rotation: toggled ? (dark ? -4 : 4) : 0

                    Behavior on rotation {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: dark ? Translation.tr("Dark") : Translation.tr("Light")
                    font.family: root.labelFontFamily
                    font.variableAxes: root.labelVariableAxes
                    font.pixelSize: root.labelPixelSize
                    font.weight: root.labelWeight
                    color: button.colText
                }
            }
        }
    }

    ModeButton { dark: false }
    ModeButton { dark: true }
}
