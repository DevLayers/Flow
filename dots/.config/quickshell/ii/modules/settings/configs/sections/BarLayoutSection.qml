pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentSection {
    id: barLayoutSection

    icon: "view_stream"
    title: Translation.tr("Layout")

    readonly property var usedIds: {
        const ids = [];
        const lists = [
            Config.options.bar.layouts.left,
            Config.options.bar.layouts.center,
            Config.options.bar.layouts.right
        ];
        for (const list of lists) {
            for (const item of list) {
                ids.push(item.id);
            }
        }
        return ids;
    }

    readonly property var availableComponents: BarComponentRegistry.getAvailableComponents(usedIds)

    ContentSubsection {
        title: Translation.tr("Left layout widgets")
        icon: "align_horizontal_left"
        tooltip: Translation.tr("Top layout in vertical mode")

        ConfigListView {
            barSection: 0
            listModel: Config.options.bar.layouts.left
            availableComponents: barLayoutSection.availableComponents
            onUpdated: (newList) => {
                Config.options.bar.layouts.left = newList;
            }
        }
    }

    ContentSubsection {
        title: Translation.tr("Center layout widgets")
        icon: "align_horizontal_center"
        tooltip: Translation.tr("Center the component with the button")

        NoticeBox {
            Layout.fillWidth: true
            visible: Config.options.bar.barBackgroundStyle === 3
            materialIcon: "grid_view"
            text: Translation.tr("Widget centering is disabled when Islands bar background is active. All center widgets follow the island layout automatically.")
        }

        NoticeBox {
            Layout.fillWidth: true
            visible: ShellModePolicy.barPositionLocked
            materialIcon: "lock"
            text: Translation.tr("Center widgets are locked while 'Dynamic Island in bar center' is active. The Dynamic Island occupies the center of the bar — adding visible widgets here would conflict with it.")
        }

        ConfigListView {
            barSection: 1
            listModel: Config.options.bar.layouts.center
            availableComponents: barLayoutSection.availableComponents
            enabled: !ShellModePolicy.barPositionLocked
            opacity: ShellModePolicy.barPositionLocked ? 0.4 : 1
            onUpdated: (newList) => {
                Config.options.bar.layouts.center = newList;
            }
        }
    }

    ContentSubsection {
        title: Translation.tr("Right layout widgets")
        icon: "align_horizontal_right"
        tooltip: Translation.tr("Bottom layout in vertical mode")

        ConfigListView {
            barSection: 2
            listModel: Config.options.bar.layouts.right
            availableComponents: barLayoutSection.availableComponents
            onUpdated: (newList) => {
                Config.options.bar.layouts.right = newList;
            }
        }
    }
}
