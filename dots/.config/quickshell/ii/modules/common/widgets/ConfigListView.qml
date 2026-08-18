pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQml.Models

import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    Layout.fillWidth: true

    property real entryHeight: 48
    property real listSpacing: 4
    property real contentMargins: 10
    property real sectionSpacing: 10

    readonly property int itemCount: root.listModel?.length ?? 0
    readonly property real entriesHeight: root.itemCount <= 0
        ? 0
        : root.itemCount * root.entryHeight + (root.itemCount - 1) * root.listSpacing

    // Deterministic geometry: independent of view.contentHeight
    implicitHeight: root.entriesHeight + componentSelectRow.implicitHeight + root.contentMargins * 2 + root.sectionSpacing

    color: "transparent"
    radius: Appearance.rounding.large

    property int barSection // 0: left, 1: center, 2: right
    property var listModel
    property var availableComponents: []
    property int selectedCompIndex: 0

    property bool dragging: false

    signal updated(var newList)

    Component.onCompleted: {
        initilizateLayout(listModel);
    }

    /*
     * We have to initialize the layout because we don't define the default values in Config.qml file
    */
    function initilizateLayout(list) {
        const source = list || [];
        let needsNormalization = false;
        const initializedLayout = source.map(comp => {
            if (comp.centered === undefined || comp.visible === undefined)
                needsNormalization = true;
            return initilizateComponent(comp);
        });
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
            entryHeight: root.entryHeight
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.contentMargins
        spacing: root.sectionSpacing

        StyledListView {
            id: view

            Layout.fillWidth: true
            Layout.preferredHeight: root.entriesHeight
            Layout.minimumHeight: root.entriesHeight
            Layout.maximumHeight: root.entriesHeight

            interactive: false
            spacing: root.listSpacing
            cacheBuffer: 0
            model: visualModel

            animatePopulate: false
            animateAppearance: !Config.options?.appearance?.settingsPerformanceMode
            animateMovement: !Config.options?.appearance?.settingsPerformanceMode
        }

        RowLayout {
            id: componentSelectRow
            Layout.fillWidth: true
            spacing: 4

            StyledComboBox {
                id: componentSelector

                // Let the selector yield width to the action button on narrow
                // Settings windows instead of pushing the row past its clip.
                Layout.minimumWidth: 0

                topRightRadius: Appearance.rounding.verysmall
                bottomRightRadius: Appearance.rounding.verysmall

                buttonIcon: "box"
                textRole: "title"
                model: root.availableComponents
                enabled: root.availableComponents.length >= 1

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
                enabled: root.availableComponents.length >= 1

                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                rippleColor: Appearance.colors.colSecondaryContainerActive

                onClicked: {
                    let available = root.availableComponents;
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
}
