import QtQuick
import Quickshell

import qs.modules.common

Scope {
    id: root

    Variants {
        id: screenVariants
        model: Quickshell.screens

        delegate: Scope {
            id: screenScope
            required property ShellScreen modelData

            // Hyprland only blurs behind a layer surface whose namespace carries the `blur`
            // layer rule, and a namespace can never change after the surface exists. Config
            // also loads asynchronously, so binding the namespace to the transparency setting
            // silently produced a no-blur surface at every startup. Instead the window is only
            // built once Config is readable, from whichever of the two Components matches the
            // setting — flipping it destroys the surface and maps a fresh one.
            readonly property bool wantsBlur: Config.options?.appearance?.transparency?.enable ?? false

            Loader {
                id: shadeWindowLoader
                active: Config.ready
                sourceComponent: screenScope.wantsBlur ? blurredShadeComponent : opaqueShadeComponent
            }

            Component {
                id: blurredShadeComponent
                TabletShadeWindow {
                    screen: screenScope.modelData
                    shellNamespace: "quickshell:tabletShade"
                    blurBacked: true
                }
            }

            Component {
                id: opaqueShadeComponent
                TabletShadeWindow {
                    screen: screenScope.modelData
                    shellNamespace: "quickshell:tabletShadeOpaque"
                    blurBacked: false
                }
            }
        }
    }
}
