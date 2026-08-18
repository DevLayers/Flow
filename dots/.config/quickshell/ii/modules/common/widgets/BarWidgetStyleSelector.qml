import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Compact style picker used by each Bar settings row. Uses Flickable + Row + Repeater
// to avoid heavyweight nested ListView virtualizers while retaining full visual feedback
// and horizontal scrolling if the options exceed available width.
Item {
    id: root

    property string styleConfigKey: ""
    property list<var> styleOptions: []
    property string currentValue: "default"
    readonly property bool performanceMode: Config.options?.appearance?.settingsPerformanceMode ?? false

    property real pillHeight: 30
    property real maxPreferredWidth: 360
    property real pillSpacing: Appearance.rounding.unsharpenmore

    signal selected(var newValue)

    implicitHeight: root.pillHeight
    implicitWidth: Math.min(styleRow.implicitWidth, root.maxPreferredWidth)

    Flickable {
        id: styleFlick
        anchors.fill: parent
        clip: true

        contentWidth: styleRow.implicitWidth
        contentHeight: root.pillHeight

        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width

        Row {
            id: styleRow
            spacing: root.pillSpacing
            height: root.pillHeight

            Repeater {
                model: root.styleOptions

                delegate: Rectangle {
                    id: styleButton

                    required property var modelData

                    readonly property string optionValue: String(modelData.value ?? "default")
                    readonly property bool optionEnabled: modelData.enabled !== false
                    readonly property bool selected: root.currentValue === optionValue
                    readonly property bool hovered: hoverHandler.hovered
                    readonly property bool pressed: tapHandler.pressed

                    height: root.pillHeight
                    implicitWidth: buttonLayout.implicitWidth + Appearance.rounding.normal
                    radius: Appearance.rounding.small
                    opacity: optionEnabled ? 1 : 0.5
                    color: !optionEnabled ? Appearance.colors.colLayer2
                        : selected ? Appearance.colors.colPrimaryContainer
                        : pressed ? Appearance.colors.colLayer2Active
                        : hovered ? Appearance.colors.colLayer2Hover
                        : Appearance.colors.colLayer2
                    scale: root.performanceMode ? 1 : (pressed ? 0.96 : (hovered ? 1.01 : 1))

                    Behavior on color {
                        enabled: !root.performanceMode
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(styleButton)
                    }

                    Behavior on scale {
                        enabled: !root.performanceMode
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(styleButton)
                    }

                    RowLayout {
                        id: buttonLayout
                        anchors.centerIn: parent
                        spacing: Appearance.rounding.unsharpenmore

                        MaterialSymbol {
                            visible: modelData.icon !== undefined && modelData.icon !== ""
                            text: modelData.icon ?? ""
                            iconSize: Appearance.font.pixelSize.small
                            color: styleButton.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            text: modelData.displayName ?? modelData.value ?? ""
                            color: styleButton.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                        cursorShape: styleButton.optionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    TapHandler {
                        id: tapHandler
                        enabled: styleButton.optionEnabled
                        onTapped: root.selected(styleButton.optionValue)
                    }
                }
            }
        }
    }
}
