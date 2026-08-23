pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root

    property var hints: []
    property color surface: Appearance.colors.colSurfaceContainerHigh
    property color onSurface: Appearance.colors.colOnSurface

    spacing: 8

    Repeater {
        model: root.hints

        delegate: RowLayout {
            required property var modelData

            spacing: 4

            StyledText {
                text: modelData.label ?? ""
                color: root.onSurface
                font.pixelSize: Appearance.font.pixelSize.smallest
            }

            KeyHint {
                visible: (modelData.keys ?? []).length > 0
                keys: modelData.keys ?? []
                surface: root.surface
                onSurface: root.onSurface
            }
        }
    }
}
