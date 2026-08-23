import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import "TimetableHelpers.js" as H

Flow {
    id: root

    property string currentToken: ""
    property bool includeCalendarDefault: true
    signal tokenSelected(string token)

    readonly property var options: [
        { token: "", label: Translation.tr("Calendar") },
        { token: "primary", label: Translation.tr("Primary") },
        { token: "secondary", label: Translation.tr("Secondary") },
        { token: "tertiary", label: Translation.tr("Tertiary") },
        { token: "error", label: Translation.tr("Error") },
        { token: "primaryContainer", label: Translation.tr("Primary container") },
        { token: "secondaryContainer", label: Translation.tr("Secondary container") },
        { token: "tertiaryContainer", label: Translation.tr("Tertiary container") },
        { token: "errorContainer", label: Translation.tr("Error container") }
    ]

    spacing: 6

    Repeater {
        model: root.includeCalendarDefault ? root.options : root.options.slice(1)

        delegate: RippleButton {
            id: colorButton
            required property var modelData

            readonly property bool selected: root.currentToken === modelData.token
            readonly property color tokenColor: modelData.token
                ? H.themeColorForToken(modelData.token, Appearance.colors)
                : Appearance.colors.colSurfaceContainerHighest

            implicitWidth: 34
            implicitHeight: 34
            buttonRadius: Appearance.rounding.full
            colBackground: tokenColor
            colBackgroundHover: H.themeHoverColorForToken(modelData.token, Appearance.colors)
            onClicked: root.tokenSelected(modelData.token)

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                visible: selected
                text: "check"
                iconSize: Appearance.font.pixelSize.small
                color: ColorUtils.getContrastingTextColor(tokenColor)
            }

            StyledToolTip {
                extraVisibleCondition: colorButton.hovered
                text: modelData.label
            }
        }
    }
}
