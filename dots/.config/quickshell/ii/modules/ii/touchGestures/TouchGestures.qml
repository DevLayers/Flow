import QtQuick
import Quickshell
import qs
import qs.modules.common

Scope {
    id: root

    Variants {
        model: Quickshell.screens
        delegate: GestureFeedbackWindow {
            required property var modelData
            screen: modelData
        }
    }
}
