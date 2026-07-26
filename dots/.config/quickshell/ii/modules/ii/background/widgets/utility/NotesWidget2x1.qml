import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets
import qs.modules.ii.overlay.notes

AbstractBackgroundWidget {
    id: root

    configEntryName: "notes_widget_2x1"

    implicitWidth: 492
    implicitHeight: 240

    // Theme palette tokens from WidgetColorScheme
    readonly property color cardBgColor: WidgetColorScheme.cardBgColor
    readonly property color textColorOnBg: WidgetColorScheme.textColorOnBg
    readonly property color subtextColorOnBg: WidgetColorScheme.subtextColorOnBg
    readonly property color accentColor: WidgetColorScheme.accentColor
    readonly property color onAccentColor: WidgetColorScheme.onAccentColor
    readonly property color innerShapeColor: WidgetColorScheme.innerShapeColor

    property var notesData: []
    property bool ready: false
    property real initTimestamp: Date.now()
    property int missingFileGracePeriod: 2000
    property int missingFileRetryInterval: 1500

    property bool notesWindowOpen: false

    readonly property var defaultNotes: [
        {
            title: Translation.tr("Material Next"),
            content: Translation.tr("Material Next is Google's new design language for apps and system UI.")
        },
        {
            title: Translation.tr("Low-Knead Bread"),
            content: Translation.tr("- 400g bread flour\n- 300ml water\n- 7g instant yeast")
        }
    ]

    function openNotes(tabIdx) {
        if (tabIdx !== undefined && tabIdx >= 0) {
            Persistent.states.overlay.notes.tabIndex = tabIdx;
        }
        root.notesWindowOpen = true;
    }

    onNotesWindowOpenChanged: {
        if (!notesWindowOpen) {
            noteFile.reload();
            GlobalStates.notesOpen = false;
        }
    }

    Connections {
        target: GlobalStates
        function onNotesOpenChanged() {
            if (GlobalStates.notesOpen && !root.notesWindowOpen) {
                root.openNotes();
            }
        }
    }

    function loadNotesFromDisk() {
        try {
            const jsonText = noteFile.text();
            const parsed = JSON.parse(jsonText);
            if (parsed && parsed.tabs && Array.isArray(parsed.tabs) && parsed.tabs.length > 0) {
                root.notesData = parsed.tabs;
            } else {
                root.notesData = root.defaultNotes;
            }
        } catch (e) {
            root.notesData = root.defaultNotes;
        }
        root.ready = true;
    }

    function deleteNote(index) {
        if (index < 0 || index >= root.notesData.length) return;
        let newTabs = root.notesData.slice();
        newTabs.splice(index, 1);
        if (newTabs.length === 0) {
            newTabs = [{
                title: Translation.tr("Tab 1"),
                icon: "article",
                content: ""
            }];
        }
        let dataToSave = { tabs: newTabs };
        noteFile.setText(JSON.stringify(dataToSave, null, 2));
        root.notesData = newTabs;
        noteFile.reload();
    }

    Component.onCompleted: {
        noteFile.reload();
    }

    FileView {
        id: noteFile
        path: Qt.resolvedUrl(Directories.notesPath)
        atomicWrites: true
        watchChanges: true
        onAdapterUpdated: root.loadNotesFromDisk()
        onLoaded: root.loadNotesFromDisk()
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) return;
            if (Date.now() - root.initTimestamp > root.missingFileGracePeriod) {
                root.notesData = root.defaultNotes;
                root.ready = true;
            } else {
                missingFileRetryTimer.restart();
            }
        }
    }

    Timer {
        id: missingFileRetryTimer
        interval: root.missingFileRetryInterval
        repeat: false
        onTriggered: noteFile.reload()
    }

    StyledRectangularShadow {
        id: bgShadow
        target: bgRect
        visible: Config.options.background.widgets.enableShadows ?? false
    }

    // Outer card container
    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: root.cardBgColor
        radius: Appearance.rounding.windowRounding

        layer.enabled: Config.options.background.widgets.enableInnerShadow ?? false
        layer.effect: InnerShadow {
            color: Qt.rgba(0, 0, 0, 0.15)
            radius: 8.0
            samples: 16
            horizontalOffset: 0
            verticalOffset: 1
            spread: 0.0
        }

        // Inner mask container for rounded clipping
        Item {
            id: contentContainer
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: contentContainer.width
                    height: contentContainer.height
                    radius: bgRect.radius
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 12
                anchors.bottomMargin: 0
                spacing: 8

                // Header Row: Title "Notes" on left, Add Button "+" on top right
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Notes")
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                        color: root.textColorOnBg
                        elide: Text.ElideRight
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.small
                        colBackground: root.accentColor
                        colBackgroundHover: Qt.lighter(root.accentColor, 1.1)
                        colRipple: Qt.lighter(root.accentColor, 1.2)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "add"
                            iconSize: 18
                            color: root.onAccentColor
                        }

                        onClicked: {
                            root.openNotes();
                        }
                    }
                }

                // Scrollable list of notes
                ListView {
                    id: notesListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    snapMode: ListView.SnapToItem
                    model: root.notesData

                    delegate: Rectangle {
                        id: noteCard
                        required property var modelData
                        required property int index

                        width: notesListView.width
                        height: notesListView.height * 0.75
                        radius: Appearance.rounding.windowRounding
                        color: root.innerShapeColor

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.openNotes(noteCard.index);
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            // Note title row with delete action
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                StyledText {
                                    Layout.fillWidth: true
                                    text: noteCard.modelData.title || Translation.tr("Untitled Note")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.DemiBold
                                    color: root.textColorOnBg
                                    elide: Text.ElideRight
                                }

                                RippleButton {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: "transparent"
                                    colBackgroundHover: Qt.rgba(0, 0, 0, 0.1)

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        iconSize: 16
                                        color: root.subtextColorOnBg
                                    }

                                    onClicked: {
                                        root.deleteNote(noteCard.index);
                                    }
                                }
                            }

                            // Note body content
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentWidth: width
                                contentHeight: bodyColumn.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: false // Allows clicks to pass through to noteCard MouseArea

                                ColumnLayout {
                                    id: bodyColumn
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: (noteCard.modelData.content || "").split("\n").filter(line => line.trim().length > 0)

                                        delegate: RowLayout {
                                            required property string modelData
                                            required property int index

                                            Layout.fillWidth: true
                                            spacing: 6

                                            readonly property bool isCheckItem: modelData.trim().startsWith("- ")
                                            readonly property string lineText: isCheckItem ? modelData.trim().substring(2) : modelData

                                            MaterialSymbol {
                                                visible: isCheckItem
                                                text: "check_box_outline_blank"
                                                iconSize: 14
                                                color: root.subtextColorOnBg
                                                Layout.alignment: Qt.AlignTop
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: lineText
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: root.subtextColorOnBg
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Standalone direct Notes Window (no overlay module required)
    Scope {
        id: notesWindowScope

        LazyLoader {
            id: notesWindowLoader
            active: root.notesWindowOpen

            component: PanelWindow {
                id: notesWin
                color: Qt.rgba(0, 0, 0, 0.4)
                visible: true
                screen: Quickshell.screens.find(s => s.name === (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")) ?? Quickshell.screens[0] ?? null

                WlrLayershell.namespace: "quickshell:notesPopup2x1"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: 0

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                Component.onCompleted: {
                    Qt.callLater(() => {
                        notesContentComp.focusAtEnd();
                    });
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.notesWindowOpen = false;
                        event.accepted = true;
                    }
                }

                // Backdrop click to dismiss
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.notesWindowOpen = false
                }

                // Dialog card container
                Rectangle {
                    id: dialogCard
                    anchors.centerIn: parent
                    width: Math.min(680, parent.width * 0.9)
                    height: Math.min(560, parent.height * 0.85)
                    color: Appearance.colors.colSurfaceContainerHigh
                    radius: Appearance.rounding.windowRounding

                    // Stop click propagation to backdrop
                    MouseArea {
                        anchors.fill: parent
                        onClicked: mouse => mouse.accepted = true
                    }

                    StyledDropShadow {
                        target: dialogCard
                        visible: Config.options.background.widgets.enableShadows ?? true
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        // Window Header Bar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MaterialSymbol {
                                text: "note_stack"
                                iconSize: 22
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                text: Translation.tr("Notes")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                                Layout.fillWidth: true
                            }

                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colSurfaceContainerHighest

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 18
                                    color: Appearance.colors.colOnSurfaceVariant
                                }

                                onClicked: root.notesWindowOpen = false
                            }
                        }

                        // Embedded NotesContent Component
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            NotesContent {
                                id: notesContentComp
                                anchors.fill: parent
                                radius: Appearance.rounding.normal
                                isClickthrough: false
                            }
                        }
                    }
                }
            }
        }
    }
}
