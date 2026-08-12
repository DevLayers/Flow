import qs.services
import QtQuick
import qs.modules.ii.onScreenDisplay
import qs.modules.common.widgets
import qs.modules.common

Loader {
    sourceComponent: Config.options.osd.material.enable ? materialOsdComp : minimalOsdComp

    Component {
        id: minimalOsdComp
        OsdValueIndicator {
            id: osdValues
            value: MprisController.activePlayer?.volume ?? 0
            icon: "music_note"
            name: Translation.tr("Music")
            shape: MaterialShape.Shape.Cookie4Sided
        }
    }

    Component {
        id: materialOsdComp
        OsdMaterialValueIndicator {
            id: osdValues
            value: MprisController.activePlayer?.volume ?? 0
            icon: "music_note"
            shape: MaterialShape.Shape.Cookie4Sided
        }
    }
}
