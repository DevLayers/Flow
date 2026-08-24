import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * A settings row that opens a sub-page, showing the value it would take you to change.
 *
 * The codebase's existing trick for this is a ConfigSwitch pinned to `checked: true` with
 * `subPageOnly`, which leaves a switch on screen that does nothing. A row whose whole job is
 * "tap to go deeper" should look like one, so this is that row: a value on the right and a
 * chevron instead of a switch. Rounding and grouping come from RippleButton's own
 * `useDynamicRadius`, so it sits in a stack of settings rows like any other.
 */
RippleButton {
    id: root

    property string buttonIcon: ""
    // `text` is AbstractButton's own and is FINAL, so declaring one here makes the whole type
    // fail to load. The inherited one is used instead; the row draws it itself.
    /// Shown on the right, before the chevron. The current setting, in words.
    property string value: ""
    property url configPage: ""

    signal openSubPage

    Layout.fillWidth: true
    implicitHeight: contentLayout.implicitHeight + 20
    useDynamicRadius: true

    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colRipple: Appearance.colors.colLayer2Active

    onClicked: {
        root.openSubPage();
        if (root.configPage.toString() === "") return;
        // The host that owns the slide-in overlay is somewhere up the parent chain; the page
        // this row lives on does not know it exists.
        let node = root.parent;
        while (node) {
            if (typeof node.activeSubPage !== "undefined") {
                node.activeSubPage = root.configPage;
                return;
            }
            node = node.parent;
        }
    }

    HighlightOverlay {
        id: highlightOverlay
        anchors.fill: parent
        radius: root.buttonEffectiveRadius
        color: Appearance.colors.colSecondaryContainer
    }

    ScrollAnimate {}

    contentItem: Item {
        anchors.fill: parent

        RowLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 12

            Loader {
                active: root.buttonIcon.length > 0
                visible: active
                Layout.alignment: Qt.AlignVCenter
                opacity: root.enabled ? 1 : 0.4

                sourceComponent: MaterialShapeWrappedMaterialSymbol {
                    text: root.buttonIcon
                    shape: MaterialShape.Shape.Circle
                    iconSize: 18
                    padding: 6
                    fill: 0
                    color: Appearance.colors.colLayer3
                    colSymbol: Appearance.colors.colOnLayer3
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.text
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer2
                opacity: root.enabled ? 1 : 0.4
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 220
                visible: root.value.length > 0
                text: root.value
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                opacity: root.enabled ? 1 : 0.4
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "chevron_right"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colSubtext
                opacity: root.enabled ? 1 : 0.4
            }
        }
    }
}
