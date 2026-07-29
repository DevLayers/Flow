pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import "ParticipantVisualState.js" as ParticipantVisualState

Item {
    id: root
    required property var participant
    property real avatarSize: 44
    property bool showName: false
    property bool horizontalLayout: false
    property bool nameOnLeft: false
    property real maxNameWidth: 88
    property string backgroundMode: "none"
    property real backgroundOpacity: 0.72
    property bool speaking: participant?.speaking === true
    property real transitionScale: 1
    property real transitionRotation: 0
    property bool componentReady: false
    property var displayedShape: MaterialShape.Shape.Circle
    readonly property var avatarShape: participant?.deaf
        ? MaterialShape.Shape.Boom
        : (participant?.mute
            ? MaterialShape.Shape.Cookie4Sided
            : MaterialShape.Shape.Circle)

    implicitWidth: root.horizontalLayout
        ? Math.max(176, root.avatarSize + root.maxNameWidth + 16)
        : (root.showName
            ? Math.max(root.avatarSize, root.maxNameWidth + 16)
            : root.avatarSize)
    implicitHeight: root.horizontalLayout ? root.avatarSize + 12
        : root.avatarSize + (root.showName ? nameText.implicitHeight + 16 : 12)

    function transitionToCurrentShape() {
        ParticipantVisualState.remember(root.participant?.id, root.avatarShape)
        if (root.displayedShape === root.avatarShape)
            return
        root.displayedShape = root.avatarShape
        stateTransition.restart()
    }

    onAvatarShapeChanged: if (componentReady) transitionToCurrentShape()
    Component.onCompleted: {
        const previousShape = ParticipantVisualState.previous(root.participant?.id, root.avatarShape)
        root.displayedShape = previousShape
        root.componentReady = true
        ParticipantVisualState.remember(root.participant?.id, root.avatarShape)
        if (previousShape !== root.avatarShape)
            Qt.callLater(root.transitionToCurrentShape)
    }

    SequentialAnimation {
        id: stateTransition
        ParallelAnimation {
            NumberAnimation { target: root; property: "transitionScale"; to: 0.82; duration: 90; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "transitionRotation"; to: -7; duration: 90; easing.type: Easing.InCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "transitionScale"; to: 1; duration: 280; easing.type: Easing.OutBack }
            NumberAnimation { target: root; property: "transitionRotation"; to: 0; duration: 280; easing.type: Easing.OutBack }
        }
    }

    Rectangle {
        visible: root.backgroundMode === "card"
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: ColorUtils.transparentize(Appearance.colors.colLayer2, 1 - root.backgroundOpacity)
        border.width: Appearance.borderWidth.standard
        border.color: Appearance.colors.colLayer0Border
    }

    MaterialShape {
        id: glowSource
        anchors.centerIn: ring
        width: ring.width
        height: ring.height
        shape: root.displayedShape
        color: Appearance.colors.colPrimary
        visible: false
    }
    Glow {
        anchors.fill: glowSource
        source: glowSource
        color: Appearance.colors.colPrimary
        radius: 18
        samples: 25
        spread: 0.35
        transparentBorder: true
        opacity: root.speaking ? 0.9 : 0
        scale: root.speaking ? 1.18 : 0.9
        Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on scale { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutBack } }
    }

    MaterialShape {
        id: ring
        x: root.horizontalLayout
            ? (root.nameOnLeft ? root.width - width - 6 : 6)
            : Math.round((root.width - width) / 2)
        y: root.horizontalLayout ? Math.round((root.height - height) / 2) : 8
        width: root.avatarSize
        height: root.avatarSize
        shape: root.displayedShape
        color: root.speaking ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
        scale: (root.speaking ? 1.1 : 1) * root.transitionScale
        rotation: root.transitionRotation

        Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

        Image {
            id: avatar
            anchors.fill: parent
            anchors.margins: root.speaking ? 4 : 2
            source: DiscordVoice.avatarUrl(root.participant, 128)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MaterialShape {
            id: avatarMask
            anchors.fill: avatar
            shape: root.displayedShape
            visible: false
        }
        OpacityMask {
            anchors.fill: avatar
            source: avatar
            maskSource: avatarMask
            visible: avatar.status === Image.Ready
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: avatar.status !== Image.Ready
            text: "person"
            iconSize: root.avatarSize * 0.52
            color: Appearance.colors.colOnLayer2
        }

        MaterialShapeWrappedMaterialSymbol {
            visible: root.participant?.mute || root.participant?.deaf
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitSize: 20
            shape: root.participant?.deaf
                ? MaterialShape.Shape.Boom : MaterialShape.Shape.Cookie4Sided
            color: Appearance.colors.colErrorContainer
            text: root.participant?.deaf ? "headset_off" : "mic_off"
            iconSize: 12
            padding: 2
            colSymbol: Appearance.colors.colOnErrorContainer
        }
    }

    StyledText {
        id: nameText
        z: 2
        visible: root.showName
        x: root.horizontalLayout
            ? (root.nameOnLeft
                ? ring.x - 8 - width
                : ring.x + root.avatarSize + 8)
            : Math.round((root.width - width) / 2)
        y: root.horizontalLayout
            ? Math.round((root.avatarSize - height) / 2)
            : ring.y + root.avatarSize + 4
        width: root.horizontalLayout
            ? Math.min(root.maxNameWidth, implicitWidth)
            : Math.min(root.width - 8, root.maxNameWidth)
        text: root.participant?.nick || root.participant?.username || "Unknown"
        elide: Text.ElideRight
        horizontalAlignment: root.horizontalLayout
            ? (root.nameOnLeft ? Text.AlignRight : Text.AlignLeft)
            : Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colOnLayer1
    }

    Rectangle {
        visible: root.showName && root.backgroundMode === "name"
        z: 1
        x: nameText.x - 8
        y: nameText.y - 3
        width: nameText.width + 16
        height: nameText.height + 6
        radius: Appearance.rounding.verysmall
        color: ColorUtils.transparentize(Appearance.colors.colLayer2, 1 - root.backgroundOpacity)
        border.width: Appearance.borderWidth.standard
        border.color: Appearance.colors.colLayer0Border
    }
}
