import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

/**
 * Edit Mode's catalogue: the panel that slides in from the right of the card.
 *
 * Three sections. Widgets lists every desktop widget the registry knows - a
 * row is a click to add or remove, or a drag whose release places the widget
 * where the pointer is. Bar lists the bar components not already on the bar
 * and adds one to the picked bucket. Dock lists the apps the dock knows and
 * pins or unpins them.
 *
 * The drawer reports gestures and writes nothing: the surface that owns the
 * geometry turns a release into a canvas point, and every store write is made
 * there so the drawer can be laid out and reasoned about without one.
 */
Item {
    id: root

    property string screenName: ""
    // Where the drag ghost lives: an ancestor that is not clipped by the
    // drawer's reveal, so the ghost can follow the pointer out over the card.
    property Item ghostParent: null

    signal addRequested(string widgetId, real dropX, real dropY)
    signal toggleRequested(string widgetId)
    signal barAddRequested(string componentId, string bucket)
    signal dockToggleRequested(string appId)

    property string section: "widgets"
    property string barBucket: "right"
    property var dragMetadata: null

    // A desktop widget carried back over this drawer: the release removes it.
    readonly property bool dropWouldRemove: root.screenName !== ""
        && GlobalStates.editDrawerDropScreen === root.screenName

    readonly property var activeWidgets: Config.options.background.activeWidgets ?? []
    readonly property var usedBarIds: {
        const layouts = Config.options.bar.layouts;
        const ids = [];
        for (const bucket of ["left", "center", "right"])
            for (const entry of (layouts[bucket] ?? []))
                if (entry && entry.id) ids.push(entry.id);
        return ids;
    }
    readonly property var barOffer: BarComponentRegistry.getAvailableComponents(root.usedBarIds)

    function widgetOnDesktop(widgetId) {
        return root.activeWidgets.some(entry => entry && entry.widgetId === widgetId);
    }

    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Appearance.sizes.editModeDrawerWidth
        color: Appearance.m3colors.m3surfaceContainer
        radius: Appearance.rounding.verylarge
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        // The remove tint: lit while a desktop widget is carried over the panel.
        Rectangle {
            anchors.fill: parent
            radius: panel.radius
            color: root.dropWouldRemove ? Appearance.colors.colLayer1Active : "transparent"
            Behavior on color {
                enabled: !Appearance.reducedMotion
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            // The contents arrive after the panel: faded on the drawer's own scalar.
            opacity: Math.max(0, Math.min(1, (GlobalStates.editDrawerProgress - 0.4) / 0.6))

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                spacing: 10

                MaterialSymbol {
                    text: "add_circle"
                    iconSize: 22
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Add")
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurface
                }
            }

            ButtonGroup {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6

                SelectionGroupButton {
                    leftmost: true
                    buttonText: Translation.tr("Widgets")
                    toggled: root.section === "widgets"
                    onClicked: root.section = "widgets"
                }
                SelectionGroupButton {
                    buttonText: Translation.tr("Bar")
                    toggled: root.section === "bar"
                    onClicked: root.section = "bar"
                }
                SelectionGroupButton {
                    rightmost: true
                    buttonText: Translation.tr("Dock")
                    toggled: root.section === "dock"
                    onClicked: root.section = "dock"
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                text: root.section === "widgets"
                    ? Translation.tr("Drag a widget onto the desktop to place it, or click to add or remove it. Drag a desktop widget here to remove it.")
                    : root.section === "bar"
                        ? Translation.tr("Click a widget to add it to the picked bar section.")
                        : Translation.tr("Click an app to pin or unpin it on the dock.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
                wrapMode: Text.Wrap
            }

            // ── Widgets ──────────────────────────────────────────────────────
            ListView {
                id: widgetList
                visible: root.section === "widgets"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.section === "widgets" ? WidgetsRegistry.allWidgets : []

                delegate: MouseArea {
                    id: entry
                    required property var modelData
                    readonly property bool onDesktop: root.widgetOnDesktop(entry.modelData.widgetId)

                    width: widgetList.width
                    height: 60
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true

                    property real pressX: 0
                    property real pressY: 0
                    property bool dragActive: false

                    onPressed: mouse => {
                        entry.pressX = mouse.x;
                        entry.pressY = mouse.y;
                        entry.dragActive = false;
                    }
                    onPositionChanged: mouse => {
                        if (!entry.pressed)
                            return;
                        if (!entry.dragActive
                                && Math.abs(mouse.x - entry.pressX) < drag.threshold
                                && Math.abs(mouse.y - entry.pressY) < drag.threshold)
                            return;
                        entry.dragActive = true;
                        root.dragMetadata = entry.modelData;
                        const point = entry.mapToItem(root.ghostParent ?? root, mouse.x, mouse.y);
                        ghost.x = point.x - ghost.width / 2;
                        ghost.y = point.y - ghost.height / 2;
                    }
                    onReleased: mouse => {
                        const wasDrag = entry.dragActive;
                        entry.dragActive = false;
                        root.dragMetadata = null;
                        if (wasDrag) {
                            const point = entry.mapToItem(root.ghostParent ?? root, mouse.x, mouse.y);
                            root.addRequested(entry.modelData.widgetId, point.x, point.y);
                        } else {
                            root.toggleRequested(entry.modelData.widgetId);
                        }
                    }
                    onCanceled: {
                        entry.dragActive = false;
                        root.dragMetadata = null;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: entry.pressed ? Appearance.colors.colLayer1Active
                            : entry.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"
                        Behavior on color {
                            enabled: !Appearance.reducedMotion
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }

                    CatalogueRow {
                        anchors.fill: parent
                        symbol: entry.modelData.icon ?? "widgets"
                        title: entry.modelData.name ?? entry.modelData.widgetId
                        subtitle: entry.modelData.description ?? ""
                        checked: entry.onDesktop
                    }
                }
            }

            // ── Bar ──────────────────────────────────────────────────────────
            ButtonGroup {
                visible: root.section === "bar"
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6

                SelectionGroupButton {
                    leftmost: true
                    buttonText: Translation.tr("Left")
                    toggled: root.barBucket === "left"
                    onClicked: root.barBucket = "left"
                }
                SelectionGroupButton {
                    buttonText: Translation.tr("Center")
                    toggled: root.barBucket === "center"
                    onClicked: root.barBucket = "center"
                }
                SelectionGroupButton {
                    rightmost: true
                    buttonText: Translation.tr("Right")
                    toggled: root.barBucket === "right"
                    onClicked: root.barBucket = "right"
                }
            }

            ListView {
                id: barList
                visible: root.section === "bar"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.section === "bar" ? root.barOffer : []

                delegate: CatalogueButton {
                    required property var modelData
                    width: barList.width
                    rowSymbol: modelData.icon ?? "widgets"
                    rowTitle: modelData.title ?? modelData.id
                    onClicked: root.barAddRequested(modelData.id, root.barBucket)
                }
            }

            // ── Dock ─────────────────────────────────────────────────────────
            ListView {
                id: appList
                visible: root.section === "dock"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.section === "dock" ? TaskbarApps.apps : []

                delegate: CatalogueButton {
                    id: appRow
                    required property var modelData
                    readonly property string appId: modelData.appId ?? ""
                    width: appList.width
                    rowIcon: Quickshell.iconPath(AppSearch.guessIcon(appRow.appId), "image-missing")
                    rowTitle: DesktopEntries.heuristicLookup(appRow.appId)?.name ?? appRow.appId
                    rowChecked: modelData.pinned === true
                    onClicked: root.dockToggleRequested(appRow.appId)
                }
            }
        }
    }

    // The drag ghost: the row's name carried under the pointer, parented
    // outside the reveal so it is not clipped at the drawer's edge.
    Rectangle {
        id: ghost
        parent: root.ghostParent ?? root
        visible: root.dragMetadata !== null
        z: 100
        width: ghostRow.implicitWidth + 24
        height: 40
        radius: Appearance.rounding.full
        color: Appearance.m3colors.m3surfaceContainer
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        RowLayout {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 8
            MaterialSymbol {
                text: root.dragMetadata?.icon ?? "widgets"
                iconSize: 20
                color: Appearance.colors.colOnSurface
            }
            StyledText {
                text: root.dragMetadata?.name ?? ""
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurface
            }
        }
    }

    // A catalogue row's face: symbol or app icon, title, optional subtitle,
    // and the trailing added/add mark.
    component CatalogueRow: RowLayout {
        id: face
        property string symbol: ""
        property string iconSource: ""
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Loader {
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: face.iconSource !== "" ? appIconFace : symbolFace
        }
        Component {
            id: symbolFace
            MaterialSymbol {
                text: face.symbol
                iconSize: 24
                color: Appearance.colors.colOnSurface
            }
        }
        Component {
            id: appIconFace
            IconImage {
                implicitSize: 26
                source: face.iconSource
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                Layout.fillWidth: true
                text: face.title
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurface
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: face.subtitle !== ""
                text: face.subtitle
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: face.checked ? "check_circle" : "add"
            iconSize: 22
            color: face.checked ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
        }
    }

    // A click-only catalogue row (bar components, dock apps).
    component CatalogueButton: RippleButton {
        id: button
        property string rowSymbol: ""
        property string rowIcon: ""
        property string rowTitle: ""
        property bool rowChecked: false
        implicitHeight: 52
        buttonRadius: Appearance.rounding.large
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colRipple: Appearance.colors.colLayer1Active
        contentItem: CatalogueRow {
            anchors.fill: parent
            symbol: button.rowSymbol
            iconSource: button.rowIcon
            title: button.rowTitle
            checked: button.rowChecked
        }
    }
}
