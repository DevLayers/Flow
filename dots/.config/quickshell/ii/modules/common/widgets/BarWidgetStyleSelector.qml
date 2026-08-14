import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Compact style picker used by each Bar settings row. It deliberately avoids
// the generic grouped-button stack so a row only owns one virtualized view and
// each style option has local feedback without sibling relayout.
Item {
    id: root

    property string styleConfigKey: ""
    property list<var> styleOptions: []
    property string currentValue: "default"
    readonly property bool performanceMode: Config.options?.appearance?.settingsPerformanceMode ?? false

    signal selected(var newValue)

    // Prefer the complete option row. If the parent row is narrower, its
    // Layout.minimumWidth: 0 lets the ListView become a horizontal viewport
    // instead of clipping the last style pill at an arbitrary fixed width.
    implicitWidth: Math.max(styleList.contentWidth,
        Appearance.font.pixelSize.small * 4 + Appearance.rounding.normal)
    // Horizontal ListView.contentHeight is not a reliable delegate metric
    // while its viewport is being polished. Use the actual delegate bounds
    // so the rounded style pills get their full vertical viewport.
    implicitHeight: Math.max(styleList.contentItem.childrenRect.height,
        Appearance.font.pixelSize.small + Appearance.rounding.small)

    ListView {
        id: styleList
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: Appearance.rounding.unsharpenmore
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        cacheBuffer: 0
        model: root.styleOptions

        delegate: Rectangle {
            id: styleButton

            required property var modelData

            readonly property string optionValue: String(modelData.value ?? "default")
            readonly property bool optionEnabled: modelData.enabled !== false
            readonly property bool selected: root.currentValue === optionValue
            readonly property bool hovered: hoverHandler.hovered
            readonly property bool pressed: tapHandler.pressed

            implicitWidth: buttonLayout.implicitWidth + Appearance.rounding.normal
            implicitHeight: buttonLayout.implicitHeight + Appearance.rounding.small
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
