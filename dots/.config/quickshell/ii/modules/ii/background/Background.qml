pragma ComponentBehavior: Bound

import qs
import Quickshell
import qs.modules.ii.background.widgets
import qs.modules.ii.background.compositor

Scope {
    id: backgroundScope

    WidgetStateManager {
        id: widgetState
    }

    readonly property alias widgetSyncVersion: widgetState.syncVersion
    readonly property alias widgetStateManager: widgetState

    Variants {
        id: root
        model: Quickshell.screens

        BackgroundRoot {
            widgetStateManager: widgetState
        }
    }

    Variants {
        id: widgetsVariant
        model: Quickshell.screens

        BackgroundWidgetsWindow {
            widgetStateManager: widgetState
        }
    }

    // BlurOverlayWindow is only meaningful while zoom-out mirroring is enabled.
    // Skipping it for everyone else saves one PanelWindow + scenegraph per
    // monitor (and its blur layer in Hyprland).
    readonly property bool blurOverlayNeeded:
        Config.options.background.zoomOutEnabled
        && Config.options.background.zoomOutStyle === 1

    Variants {
        id: blurOverlayVariant
        model: backgroundScope.blurOverlayNeeded ? Quickshell.screens : []

        BlurOverlayWindow {}
    }
}
