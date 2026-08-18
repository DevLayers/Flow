import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Toolbar {
    id: actionToolbar

    property bool expanded: false
    property real expandedProgress: expanded ? 1.0 : 0.0

    padding: 6
    spacing: 6 * expandedProgress
    colBackground: Appearance.m3colors.m3surfaceContainerLow

    Behavior on expandedProgress {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(actionToolbar)
    }

    component ActionButton: IconToolbarButton {
        implicitWidth: height

        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colBackgroundActive: Appearance.colors.colLayer2Active
        colBackgroundToggled: Appearance.colors.colPrimary
        colBackgroundToggledHover: Appearance.colors.colPrimaryHover
        colBackgroundToggledActive: Appearance.colors.colPrimaryActive
        colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        colRipple: Appearance.colors.colLayer2Active
        colRippleToggled: Appearance.colors.colPrimaryActive
    }

    component ActionSlot: Item {
        id: actionSlot

        default property alias slotData: slot.data

        implicitWidth: 0
        implicitHeight: 0
        clip: true
        opacity: actionToolbar.expandedProgress
        enabled: actionToolbar.expandedProgress > 0.5

        Layout.fillHeight: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: Math.max(0, (actionToolbar.height - actionToolbar.padding * 2) * actionToolbar.expandedProgress)
        Layout.maximumWidth: Math.max(0, (actionToolbar.height - actionToolbar.padding * 2) * actionToolbar.expandedProgress)

        Behavior on Layout.preferredWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(actionSlot)
        }

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(actionSlot)
        }

        Item {
            id: slot
            anchors.fill: parent
        }
    }

    ActionSlot {
        ActionButton {
            id: openFileButton
            anchors.fill: parent

            onClicked: {
                Wallpapers.openFallbackPicker(wallpaperSelectorContent.useDarkMode);
                GlobalStates.wallpaperSelectorOpen = false;
            }
            altAction: () => {
                Wallpapers.openFallbackPicker(wallpaperSelectorContent.useDarkMode);
                GlobalStates.wallpaperSelectorOpen = false;
                Config.options.wallpaperSelector.useSystemFileDialog = true;
            }
            text: "open_in_new"

            StyledToolTip {
                text: Translation.tr("Use the system file picker instead\nRight-click to make this the default behavior")
            }
        }
    }

    ActionSlot {
        ActionButton {
            id: randomButton
            anchors.fill: parent

            onClicked: {
                if (wallpaperSelectorContent.browserMode) {
                    if (wallpaperSelectorContent.apiImages.length > 0) {
                        const randomImg = wallpaperSelectorContent.apiImages[Math.floor(Math.random() * wallpaperSelectorContent.apiImages.length)];
                        wallpaperSelectorContent.selectWallpaperPath(randomImg.actualPath || randomImg.filePath);
                    }
                } else if (wallpaperSelectorContent.favMode) {
                    const favs = Persistent.states.wallpaper.favourites;
                    if (favs.length > 0) {
                        const randomPath = favs[Math.floor(Math.random() * favs.length)];
                        wallpaperSelectorContent.selectWallpaperPath(randomPath);
                    }
                } else {
                    Wallpapers.randomFromCurrentFolder();
                }
            }
            text: "ifl"

            StyledToolTip {
                text: Translation.tr("Pick random from this folder")
            }
        }
    }

    ActionSlot {
        ActionButton {
            id: refreshButton
            anchors.fill: parent

            onClicked: wallpaperSelectorContent.updateThumbnails(true)
            text: "refresh"

            StyledToolTip {
                text: Translation.tr("Reload thumbnails (for high resolution displays)")
            }
        }
    }

    ActionSlot {
        ActionButton {
            id: colorFilterButton
            anchors.fill: parent

            toggled: wallpaperSelectorContent.colorFilterVisible
            onClicked: wallpaperSelectorContent.toggleColorFilter()
            text: "palette"

            StyledToolTip {
                text: wallpaperSelectorContent.colorCacheUpdating ? Translation.tr("Updating color cache...") : Translation.tr("Filter by color")
            }
        }
    }

    ActionButton {
        id: expandButton
        implicitWidth: height
        toggled: actionToolbar.expanded
        text: "arrow_back_ios_new"

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            iconSize: expandButton.iconSize
            text: expandButton.text
            fill: expandButton.iconFill ? 1 : 0
            color: expandButton.colText
            rotation: actionToolbar.expanded ? 180 : 0
            animateChange: true

            Behavior on rotation {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        onClicked: actionToolbar.expanded = !actionToolbar.expanded

        StyledToolTip {
            text: actionToolbar.expanded ? Translation.tr("Collapse wallpaper actions") : Translation.tr("Expand wallpaper actions")
        }
    }
}
