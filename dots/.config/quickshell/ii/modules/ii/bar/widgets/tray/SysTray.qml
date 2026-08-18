import qs.modules.ii.bar.shared
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: sysTrayRoot
    implicitWidth: hasItems ? gridLayout.implicitWidth : 0
    implicitHeight: hasItems ? gridLayout.implicitHeight : 0
    property bool vertical: false
    property bool invertSide: false
    property bool trayOverflowOpen: false
    property bool showSeparator: true
    property bool showOverflowMenu: true
    property bool circleItems: false
    property var activeMenu: null

    property var pinnedItems: TrayService.pinnedItems
    property var unpinnedItems: TrayService.unpinnedItems
    readonly property bool hasItems: pinnedItems.length > 0 || unpinnedItems.length > 0
    visible: hasItems

    onUnpinnedItemsChanged: {
        if (unpinnedItems.length === 0)
            closeOverflowMenu();
    }

    readonly property var overflowWindow: trayOverflowLayout.QsWindow ? trayOverflowLayout.QsWindow.window : null

    function grabFocus() {
        focusGrab.wanted = true;
    }

    function closeActiveMenu() {
        if (!sysTrayRoot.activeMenu)
            return;
        if (typeof sysTrayRoot.activeMenu.close === "function")
            sysTrayRoot.activeMenu.close();
        sysTrayRoot.activeMenu = null;
    }

    function setExtraWindowAndGrabFocus(window) {
        if (sysTrayRoot.activeMenu && sysTrayRoot.activeMenu !== window)
            sysTrayRoot.closeActiveMenu();
        sysTrayRoot.activeMenu = window;
        sysTrayRoot.grabFocus();
    }

    function releaseFocus() {
        focusGrab.wanted = false;
    }

    function closeOverflowMenu() {
        focusGrab.wanted = false;
    }

    onTrayOverflowOpenChanged: {
        if (sysTrayRoot.trayOverflowOpen) {
            sysTrayRoot.grabFocus();
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        property bool wanted: false

        // The popup window only exists a moment after trayOverflowOpen flips, so grabbing
        // eagerly would start a grab with no windows in it — Hyprland clears those
        // immediately and the popup would snap shut before it finished opening.
        active: wanted && (sysTrayRoot.overflowWindow !== null || sysTrayRoot.activeMenu !== null)
        windows: [sysTrayRoot.overflowWindow, sysTrayRoot.activeMenu]
        onCleared: {
            // Close the menu before collapsing the overflow popup: the menu window is
            // anchored to an item living inside that popup, so tearing the popup down
            // first leaves the anchor pointing into a destroyed window.
            sysTrayRoot.closeActiveMenu();
            sysTrayRoot.trayOverflowOpen = false;
        }
    }

    GridLayout {
        id: gridLayout
        columns: sysTrayRoot.vertical ? 1 : -1
        anchors.fill: parent
        rowSpacing: sysTrayRoot.circleItems ? 4 : 8
        columnSpacing: sysTrayRoot.circleItems ? 4 : 15

        RippleButton {
            id: trayOverflowButton
            visible: sysTrayRoot.showOverflowMenu && sysTrayRoot.unpinnedItems.length > 0
            toggled: sysTrayRoot.trayOverflowOpen
            property bool containsMouse: hovered

            downAction: () => sysTrayRoot.trayOverflowOpen = !sysTrayRoot.trayOverflowOpen

            Layout.fillHeight: !sysTrayRoot.vertical
            Layout.fillWidth: sysTrayRoot.vertical
            background.implicitWidth: 24
            background.implicitHeight: 24
            background.anchors.centerIn: this
            colBackgroundToggled: Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
            colRippleToggled: Appearance.colors.colSecondaryContainerActive

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                iconSize: Appearance.font.pixelSize.larger
                text: "expand_more"
                horizontalAlignment: Text.AlignHCenter
                color: sysTrayRoot.trayOverflowOpen ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                rotation: (sysTrayRoot.trayOverflowOpen ? 180 : 0) - (90 * sysTrayRoot.vertical) + (180 * sysTrayRoot.invertSide)
                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            StyledPopup {
                id: overflowPopup
                hoverTarget: trayOverflowButton
                forceClick: true
                // We run our own focus grab below, which also has to cover the tray menu
                // window. A second grab from the popup would clear ours and snap it shut.
                selfDismiss: false
                active: sysTrayRoot.trayOverflowOpen && sysTrayRoot.unpinnedItems.length > 0

                GridLayout {
                    id: trayOverflowLayout
                    anchors.centerIn: parent
                    columns: Math.ceil(Math.sqrt(sysTrayRoot.unpinnedItems.length))
                    columnSpacing: 10
                    rowSpacing: 10

                    readonly property bool startAnim: overflowPopup.opened && overflowPopup.popupOpenProgress > 0.6

                    onStartAnimChanged: {
                        if (startAnim) {
                            trayOverflowLayout.opacity = 0.0;
                            trayOverflowLayout.scale = 0.85;
                            trayOverflowTransform.y = 25;
                            Qt.callLater(function() {
                                trayOverflowAnim.start();
                            });
                        }
                    }

                    Connections {
                        target: overflowPopup
                        function onPopupOpenProgressChanged() {
                            if (overflowPopup.popupOpenProgress === 0.0) {
                                trayOverflowAnim.stop();
                                trayOverflowLayout.opacity = 0.0;
                                trayOverflowLayout.scale = 0.85;
                                trayOverflowTransform.y = 25;
                            }
                        }
                    }

                    opacity: 0.0
                    scale: 0.85
                    transform: Translate {
                        id: trayOverflowTransform
                        y: 25
                    }

                    SequentialAnimation {
                        id: trayOverflowAnim
                        PauseAnimation { duration: 40 }
                        ParallelAnimation {
                            NumberAnimation { target: trayOverflowLayout; property: "opacity"; to: 1.0; duration: 300 }
                            NumberAnimation { target: trayOverflowLayout; property: "scale"; to: 1.0; duration: 380; easing.type: Easing.OutBack }
                            NumberAnimation { target: trayOverflowTransform; property: "y"; to: 0; duration: 380; easing.type: Easing.OutCubic }
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            values: sysTrayRoot.unpinnedItems
                        }

                        delegate: SysTrayItem {
                            required property SystemTrayItem modelData
                            item: modelData
                            Layout.fillHeight: !sysTrayRoot.vertical
                            Layout.fillWidth: sysTrayRoot.vertical
                            onMenuClosed: sysTrayRoot.releaseFocus()
                            onMenuOpened: qsWindow => sysTrayRoot.setExtraWindowAndGrabFocus(qsWindow)
                        }
                    }
                }
            }
        }

        Repeater {
            model: ScriptModel {
                values: sysTrayRoot.pinnedItems
            }

            delegate: Item {
                id: circleDelegate
                required property SystemTrayItem modelData
                property bool useCircle: sysTrayRoot.circleItems
                Layout.fillHeight: !sysTrayRoot.vertical && !useCircle
                Layout.fillWidth: sysTrayRoot.vertical && !useCircle
                implicitWidth: useCircle ? 26 : trayItem.implicitWidth
                implicitHeight: useCircle ? 26 : trayItem.implicitHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimaryContainer
                    visible: circleDelegate.useCircle
                }

                SysTrayItem {
                    id: trayItem
                    anchors.centerIn: parent
                    item: circleDelegate.modelData
                    onMenuClosed: sysTrayRoot.releaseFocus()
                    onMenuOpened: qsWindow => {
                        sysTrayRoot.setExtraWindowAndGrabFocus(qsWindow);
                    }
                }
            }
        }
    }
}
