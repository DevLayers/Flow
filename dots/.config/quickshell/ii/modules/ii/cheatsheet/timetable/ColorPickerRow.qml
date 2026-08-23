import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import "TimetableHelpers.js" as H

RowLayout {
    id: root

    property string currentToken: ""
    property bool includeCalendarDefault: true
    signal tokenSelected(string token)

    readonly property var options: [
        { token: "", label: Translation.tr("Calendar") },
        { token: "primary", label: Translation.tr("Primary") },
        { token: "secondary", label: Translation.tr("Secondary") },
        { token: "tertiary", label: Translation.tr("Tertiary") },
        { token: "error", label: Translation.tr("Error") }
    ]

    spacing: 6

    Repeater {
        model: root.includeCalendarDefault ? root.options : root.options.slice(1)

        delegate: RippleButton {
            required property var modelData

            readonly property bool selected: root.currentToken === modelData.token
            readonly property color tokenColor: modelData.token
                ? H.themeColorForToken(modelData.token, Appearance.colors)
                : Appearance.colors.colSurfaceContainerHighest

            implicitWidth: 34
            implicitHeight: 34
            buttonRadius: Appearance.rounding.full
            colBackground: tokenColor
            colBackgroundHover: ColorUtils.mix(tokenColor, Appearance.colors.colOnSurface, 0.88)
            onClicked: root.tokenSelected(modelData.token)

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                visible: selected
                text: "check"
                iconSize: Appearance.font.pixelSize.small
                color: ColorUtils.getContrastingTextColor(tokenColor)
            }

            StyledToolTip {
                extraVisibleCondition: parent.hovered
                text: modelData.label
            }
        }
    }
}
