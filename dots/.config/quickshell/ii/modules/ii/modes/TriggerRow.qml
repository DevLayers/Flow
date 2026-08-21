pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../services/modes/ModeSchema.js" as ModeSchema

/**
 * One condition of a mode: its summary, whether it holds right now, and —
 * unfolded — the form for its parameters. Each change is written back as
 * a whole trigger object; the engine normalizes it.
 */
Rectangle {
    id: root

    required property var trigger
    property var watcher: null
    property int triggerIndex: 0
    property bool expanded: false

    readonly property string type: root.trigger?.type ?? ""
    readonly property var condition: root.watcher?.conditionAt(root.triggerIndex) ?? null
    readonly property bool supported: root.condition?.supported ?? true
    readonly property bool negated: root.trigger?.not === true
    readonly property bool holds: (root.condition?.item?.satisfied ?? false) !== root.negated
    readonly property string liveReason: root.condition?.item?.reason ?? ""

    onExpandedChanged: formLoader.sync()

    signal changed(var trigger)
    signal removeRequested()

    function set(changes) {
        root.changed(Object.assign({}, ModeSchema.clone(root.trigger), changes));
    }

    implicitHeight: column.implicitHeight + 16
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2
    clip: true

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: 8
            leftMargin: 14
            rightMargin: 8
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialSymbol {
                text: ModeUi.triggerTypeIcon(root.type)
                iconSize: 22
                color: Appearance.colors.colOnLayer2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: ModeUi.triggerText(root.trigger)
                    elide: Text.ElideRight
                    color: Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    text: ModeUi.triggerTypeLabel(root.type)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            // Live verdict, so a mode that "should have started" is
            // diagnosable from its own row.
            Rectangle {
                visible: root.watcher !== null
                implicitWidth: verdictRow.implicitWidth + 16
                implicitHeight: 24
                radius: Appearance.rounding.full
                color: !root.supported ? Appearance.colors.colErrorContainer
                    : (root.holds ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3)

                MouseArea {
                    id: verdictArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                StyledToolTip {
                    extraVisibleCondition: verdictArea.containsMouse && root.liveReason.length > 0
                    text: root.liveReason
                }

                RowLayout {
                    id: verdictRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        text: !root.supported ? "error" : (root.holds ? "check" : "remove")
                        iconSize: 14
                        color: !root.supported ? Appearance.colors.colOnErrorContainer
                            : (root.holds ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext)
                    }

                    StyledText {
                        text: !root.supported ? Translation.tr("Unsupported")
                            : (root.holds ? Translation.tr("Holds now") : Translation.tr("Not now"))
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: !root.supported ? Appearance.colors.colOnErrorContainer
                            : (root.holds ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext)
                    }
                }
            }

            FormIconButton {
                buttonIcon: root.expanded ? "expand_less" : "expand_more"
                onClicked: root.expanded = !root.expanded
            }

            FormIconButton {
                buttonIcon: "close"
                onClicked: root.removeRequested()
            }
        }

        // The parameter form lives in forms/Trigger<Editor>.qml and gets this
        // row as `row`; it is created on unfold and torn down on fold.
        Loader {
            id: formLoader
            Layout.fillWidth: true
            Layout.leftMargin: 34
            Layout.rightMargin: 6
            visible: status === Loader.Ready && item !== null
            readonly property string formUrl: ModeUi.triggerFormUrl(root.type)
            onFormUrlChanged: formLoader.sync()

            function sync() {
                if (!root.expanded || !formLoader.formUrl.length) {
                    formLoader.source = "";
                    return;
                }
                formLoader.setSource(formLoader.formUrl, { row: root });
            }
        }

        // Every condition can be read the other way round: "Zoom is not
        // running" is how "when Zoom closes" is said.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 34
            Layout.rightMargin: 6
            Layout.bottomMargin: 4
            visible: root.expanded
            spacing: 10

            StyledSwitch {
                checked: root.negated
                onClicked: root.set({ not: checked })
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                FormLabel {
                    text: Translation.tr("Invert")
                }

                FormHint {
                    text: root.negated ? Translation.tr("Holds while the above is not the case")
                        : Translation.tr("Hold when the above is not the case instead")
                }
            }
        }
    }
}
