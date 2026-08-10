pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQml.Models

import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    Layout.fillWidth: true

    // Use view contentHeight for accurate dynamic row heights
    implicitHeight: view.contentHeight + componentSelectRow.height + 30

    color: "transparent"
    radius: Appearance.rounding.large

    property int barSection // 0: left, 1: center, 2: right
    property var listModel
    property int selectedCompIndex

    property bool dragging: false

    // Compute available components from registry based on what's already used
    readonly property var usedIds: {
        let ids = [];
        let allLists = [Config.options.bar.layouts.left, Config.options.bar.layouts.center, Config.options.bar.layouts.right];
        for (let list of allLists) {
            for (let item of list) {
                ids.push(item.id);
            }
        }
        return ids;
    }
    readonly property var availableComps: BarComponentRegistry.getAvailableComponents(usedIds)

    signal updated(var newList)

    Component.onCompleted: {
        initilizateLayout(listModel);
    }

    /*
     * We have to initilize the layout because we don't define the default values in Config.qml file
    */
    function initilizateLayout(list) {
        const source = list || [];
        const initializedLayout = source.map(comp => initilizateComponent(comp));

        // Config layouts are already normalized in the normal case. Avoid
        // assigning a fresh list back to Config during page construction:
        // list<var> emits a change even when the values are equivalent, which
        // otherwise retriggers all bar layout consumers and schedules a disk
        // write for each of the three editors.
        let needsNormalization = source.length !== initializedLayout.length;
        if (!needsNormalization) {
            for (let i = 0; i < source.length; ++i) {
                const original = source[i];
                const normalized = initializedLayout[i];
                const keys = original ? Object.keys(original) : [];
                const hasOnlyLayoutFields = keys.length === 3 &&
                        keys.indexOf("id") !== -1 &&
                        keys.indexOf("centered") !== -1 &&
                        keys.indexOf("visible") !== -1;
                if (!original || !hasOnlyLayoutFields || original.id !== normalized.id ||
                        original.centered !== normalized.centered ||
                        original.visible !== normalized.visible) {
                    needsNormalization = true;
                    break;
                }
            }
        }

        if (needsNormalization)
            root.updated(initializedLayout);
    }

    function initilizateComponent(comp) {
        return {
            id: comp.id,
            centered: comp.centered !== undefined ? comp.centered : false,
            visible: comp.visible !== undefined ? comp.visible : true
        };
    }

    function toggleCenter(idx, currentList) {
        if (currentList[idx].centered) {
            currentList[idx].centered = false;
            root.updated(currentList);
            return;
        }
        // Islands background style does not support centered widgets — they
        // must follow the island layout, not their own positioning.
        if (Config.options.bar.barBackgroundStyle === 3) {
            return;
        }

        for (let i = 0; i < currentList.length; i++) {
            currentList[i].centered = (i === idx);
        }

        root.updated(currentList);
    }

    DelegateModel {
        id: visualModel

        model: {
            values: root.listModel;
        }
        delegate: ConfigListViewEntry {
            barSection: root.barSection
        }
    }

    StyledListView {
        id: view

        interactive: false
        anchors {
            fill: parent
            margins: 10
        }

        add: null

        model: visualModel

        spacing: 4
        cacheBuffer: 50
    }

    RowLayout {
        id: componentSelectRow
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 10
        }

        spacing: 4

        StyledComboBox {
            id: componentSelector

            topRightRadius: Appearance.rounding.verysmall
            bottomRightRadius: Appearance.rounding.verysmall

            buttonIcon: "box"
            textRole: "title"
            model: root.availableComps
            enabled: root.availableComps.length >= 1

            onActivated: index => {
                root.selectedCompIndex = index;
            }
        }

        RippleButton {
            id: addComponentButton
            implicitHeight: componentSelector.implicitHeight

            topLeftRadius: Appearance.rounding.verysmall
            bottomLeftRadius: Appearance.rounding.verysmall
            topRightRadius: Appearance.rounding.full
            bottomRightRadius: Appearance.rounding.full

            buttonText: Translation.tr("Add component")
            enabled: root.availableComps.length >= 1

            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            rippleColor: Appearance.colors.colSecondaryContainerActive

            onClicked: {
                let available = root.availableComps;
                if (available[root.selectedCompIndex] == null)
                    return;
                let newComp = initilizateComponent(available[root.selectedCompIndex]);
                // Create a NEW array reference so the binding in BarConfig.qml
                // actually triggers QML property change notification to update
                // the bar's Repeater models.
                root.updated(listModel.concat([newComp]));
            }
        }
    }
}
