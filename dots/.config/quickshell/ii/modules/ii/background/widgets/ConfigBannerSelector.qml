import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: bannerSelectorRoot
    property string text: ""
    property string placeholderText: "Click to select banner image"
    property var nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.bmp)"]

    implicitWidth: 360
    implicitHeight: 220

    readonly property string defaultPreviewPath: `${Directories.assetsPath}/images/default_wallpaper.png`

    StyledImage {
        id: bannerPreview
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: Config.options.sidebar.bannerImage !== "" ? Config.options.sidebar.bannerImage : bannerSelectorRoot.defaultPreviewPath
        cache: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: bannerPreview.width
                height: bannerPreview.height
                radius: Appearance.rounding.normal
            }
        }
    }

    StyledImage {
        id: bannerPreviewFallback
        anchors.fill: parent
        visible: bannerPreview.status === Image.Error
        source: bannerSelectorRoot.defaultPreviewPath
        fillMode: Image.PreserveAspectCrop
        cache: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: bannerPreviewFallback.width
                height: bannerPreviewFallback.height
                radius: Appearance.rounding.normal
            }
        }
    }

    RippleButton {
        anchors.fill: parent
        colBackground: "transparent"
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colOnPrimary, 0.85)
        colRipple: ColorUtils.transparentize(Appearance.colors.colOnPrimary, 0.5)
        onClicked: fileDialog.open()
    }

    FileDialog {
        id: fileDialog
        title: bannerSelectorRoot.text !== "" ? bannerSelectorRoot.text : "Select banner image"
        nameFilters: bannerSelectorRoot.nameFilters
        fileMode: FileDialog.OpenFile
        onAccepted: {
            const path = selectedFile.toString().replace(/^file:\/\//, "");
            Config.options.sidebar.bannerImage = path;
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: 10
        }

        implicitWidth: Math.min(fileNameLabel.implicitWidth + 20, parent.width - 20)
        implicitHeight: fileNameLabel.implicitHeight + 5
        color: Appearance.colors.colPrimary
        radius: Appearance.rounding.full

        StyledText {
            id: fileNameLabel
            anchors.centerIn: parent
            property string fileName: {
                const path = Config.options.sidebar.bannerImage;
                if (path === "") return bannerSelectorRoot.placeholderText;
                const parts = path.split("/");
                return parts[parts.length - 1];
            }
            text: fileName.length > 30 ? fileName.slice(0, 27) + "..." : fileName
            color: Appearance.colors.colOnPrimary
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }
}
