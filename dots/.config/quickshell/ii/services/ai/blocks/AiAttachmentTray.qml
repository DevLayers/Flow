pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell

/**
 * What is going out with the next message.
 *
 * One row of chips above the composer, one per file, each with a thumbnail if
 * there is one to show and a way to take it back off. A file that was turned
 * away says why, in the same place, rather than not appearing and leaving the
 * drop looking like it never registered.
 */
Item {
    id: root

    readonly property var files: Ai.attachments
    readonly property string notice: Ai.attachmentNotice
    /** Set while a drag is over the composer, to say what dropping would do. */
    property string dragHint: ""

    readonly property bool hasContent: root.files.length > 0 || root.notice.length > 0 || root.dragHint.length > 0

    implicitHeight: root.hasContent ? contentColumnLayout.implicitHeight : 0
    visible: implicitHeight > 0
    clip: true

    Behavior on implicitHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    function symbolFor(kind: string): string {
        if (kind === "image")
            return "image";
        if (kind === "pdf")
            return "picture_as_pdf";
        if (kind === "audio")
            return "music_note";
        if (kind === "video")
            return "movie";
        if (kind === "text")
            return "description";
        return "file_present";
    }

    ColumnLayout {
        id: contentColumnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 4

        StyledFlickable {
            Layout.fillWidth: true
            implicitHeight: root.files.length > 0 ? chipsRowLayout.implicitHeight : 0
            visible: root.files.length > 0
            contentWidth: chipsRowLayout.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            clip: true

            RowLayout {
                id: chipsRowLayout
                height: parent.height
                spacing: 4

                Repeater {
                    model: ScriptModel {
                        values: root.files
                    }

                    delegate: Rectangle {
                        id: fileChip
                        required property var modelData
                        required property int index

                        implicitWidth: chipRowLayout.implicitWidth + 8 * 2
                        implicitHeight: 40
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2

                        RowLayout {
                            id: chipRowLayout
                            anchors.centerIn: parent
                            spacing: 8

                            Loader {
                                // A picture says what it is faster than its
                                // name does; everything else gets an icon.
                                active: fileChip.modelData.kind === "image"
                                visible: active
                                sourceComponent: Rectangle {
                                    id: thumbnail
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: Appearance.rounding.verysmall
                                    color: Appearance.colors.colLayer1

                                    StyledImage {
                                        anchors.fill: parent
                                        source: Qt.resolvedUrl(fileChip.modelData.path)
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 56
                                        sourceSize.height: 56
                                        asynchronous: true

                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: thumbnail.width
                                                height: thumbnail.height
                                                radius: thumbnail.radius
                                            }
                                        }
                                    }
                                }
                            }

                            MaterialSymbol {
                                visible: fileChip.modelData.kind !== "image"
                                text: root.symbolFor(fileChip.modelData.kind)
                                iconSize: Appearance.font.pixelSize.hugeass
                                color: Appearance.colors.colOnLayer2
                            }

                            ColumnLayout {
                                spacing: 0

                                StyledText {
                                    Layout.maximumWidth: 140
                                    text: fileChip.modelData.name
                                    elide: Text.ElideMiddle
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer2
                                }

                                StyledText {
                                    text: Ai.humanSize(fileChip.modelData.bytes)
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            RippleButton {
                                implicitWidth: 24
                                implicitHeight: 24
                                buttonRadius: Appearance.rounding.full
                                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active
                                onClicked: Ai.removeAttachment(fileChip.index)

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "close"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer2
                                }

                                StyledToolTip {
                                    text: Translation.tr("Remove")
                                }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.dragHint.length > 0
            visible: active
            sourceComponent: Rectangle {
                implicitHeight: 32
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "attach_file"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.m3colors.m3onSecondaryContainer
                    }

                    StyledText {
                        text: root.dragHint
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSecondaryContainer
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.notice.length > 0
            visible: active
            sourceComponent: RowLayout {
                spacing: 6

                MaterialSymbol {
                    Layout.alignment: Qt.AlignTop
                    text: "error"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.m3colors.m3error
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.notice
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.m3colors.m3error
                }

                RippleButton {
                    implicitWidth: 24
                    implicitHeight: 24
                    buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: Ai.attachmentNotice = ""

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3error
                    }
                }
            }
        }
    }
}
