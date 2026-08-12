import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Flow {
    id: root
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4

    ScrollAnimate {}

    property int clickIndex: -1
    property real calculatedWidth: 0

    function updateWidth() {
        if (!repeater) return;
        let w = 0;
        for (let i = 0; i < repeater.count; ++i) {
            let child = repeater.itemAt(i);
            if (child && child.visible) {
                w += child.implicitWidth + root.spacing;
            }
        }
        root.calculatedWidth = Math.max(0, w - root.spacing);
    }

    function scheduleWidthUpdate() {
        root.updateWidth();
    }

    Layout.preferredWidth: calculatedWidth

    property color colBackground: Appearance.colors.colSecondaryContainer
    property color colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    property color colBackgroundActive: Appearance.colors.colSecondaryContainerActive

    spacing: 2
    property list<var> options: [
        {
            "displayName": "Option 1",
            "icon": "check",
            "shape": "Arch", // Optional (for material shape)
            "symbol": "google-gemini-symbolic", // Optional (for custom icons)
            "color": "red", // Optional (for custom shape color)
            "value": 1
        },
        {
            "displayName": "Option 2",
            "icon": "close",
            "shape": "Circle", // Optional (for material shape)
            "symbol": "mistral-symbolic", // Optional (for custom icons)
            "color": "blue", // Optional (for custom shape color)
            "value": 2
        },
    ]
    property var currentValue: null

    signal selected(var newValue)

    Repeater {
        id: repeater
        model: root.options
        delegate: SelectionGroupButton {
            id: paletteButton
            required property var modelData
            required property int index
            
            readonly property bool isOptionEnabled: modelData.enabled !== undefined ? modelData.enabled : true
            opacity: isOptionEnabled ? 1.0 : 0.5
            mouseArea.cursorShape: isOptionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            
            onImplicitWidthChanged: root.scheduleWidthUpdate()
            Component.onCompleted: root.scheduleWidthUpdate()
            Component.onDestruction: root.scheduleWidthUpdate()
            
            color: isOptionEnabled ? (toggled ? 
                (down ? colBackgroundToggledActive : 
                    hovered ? colBackgroundToggledHover : 
                    colBackgroundToggled) :
                (down ? colBackgroundActive : 
                    hovered ? colBackgroundHover : 
                    colBackground)) : colBackground

            onYChanged: {
                if (index === 0) {
                    paletteButton.leftmost = true
                } else {
                    for (var i = index - 1; i >= 0; i--) {
                        var prev = repeater.itemAt(i)
                        if (prev) {
                            var thisIsOnNewLine = prev.y !== paletteButton.y
                            paletteButton.leftmost = thisIsOnNewLine
                            prev.rightmost = thisIsOnNewLine
                            break
                        }
                    }
                }
            }
            leftmost: index === 0
            rightmost: index === root.options.length - 1
            buttonIcon: modelData.icon || ""
            buttonShape: modelData.shape || ""
            buttonSymbol: modelData.symbol || ""
            buttonColor: modelData.color || ""
            buttonText: modelData.displayName
            toggled: root.currentValue == modelData.value
            releaseAction: modelData.releaseAction || ""

            colBackground: root.colBackground
            colBackgroundHover: root.colBackgroundHover
            colBackgroundActive: root.colBackgroundActive

            onClicked: {
                if (isOptionEnabled) {
                    root.selected(modelData.value);
                }
            }

            // A tooltip watches its own parent's hover state, so it has to hang off the button
            // itself. Loading it through a Loader made the Loader its parent instead, and a Loader
            // has no hover state to read - which the tooltip took as "always hovered" and showed
            // itself the moment the page opened.
            StyledToolTip {
                extraVisibleCondition: paletteButton.modelData.tooltip !== undefined && paletteButton.modelData.tooltip !== ""
                text: paletteButton.modelData.tooltip ?? ""
            }
        }
    }
}
