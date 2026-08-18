import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar as Bar
import qs.modules.ii.bar.shared
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.ii.sidebarDashboard.quickToggles
import qs.modules.ii.sidebarDashboard.quickToggles.classicStyle
import Quickshell
import Qt5Compat.GraphicalEffects

Item {
    id: systemButtonRowRoot
    implicitHeight: Math.max(uptimeContainer.implicitHeight, systemButtonsRow.implicitHeight)
    property int entranceTrigger: -1
    property bool editMode: false
    signal editModeToggled(bool newEditMode)

    // Entrance animation properties
    property real _leftTranslateX: -30
    property real _rightTranslateX: 30
    property real _entranceTranslateY: -15
    property real _entranceOpacity: 0
    property bool _entranceDone: false
    readonly property bool _animationsDisabled: (Config.options?.appearance?.animationMultiplier ?? 1.0) <= 0.25

    onEntranceTriggerChanged: {
        if (_animationsDisabled) {
            _entranceDone = true;
            _entranceOpacity = 1;
            _leftTranslateX = 0;
            _rightTranslateX = 0;
            _entranceTranslateY = 0;
            return;
        }
        _entranceDone = false;
        _entranceOpacity = 0;
        _leftTranslateX = -30;
        _rightTranslateX = 30;
        _entranceTranslateY = -15;
        Qt.callLater(function() {
            entranceAnim.start();
        });
    }

    Component.onCompleted: {
        if (_animationsDisabled) {
            _entranceDone = true;
            _entranceOpacity = 1;
            _leftTranslateX = 0;
            _rightTranslateX = 0;
            _entranceTranslateY = 0;
            return;
        }
        _entranceDone = false;
        _entranceOpacity = 0;
        _leftTranslateX = -30;
        _rightTranslateX = 30;
        _entranceTranslateY = -15;
        Qt.callLater(function() {
            entranceAnim.start();
        });
    }

    SequentialAnimation {
        id: entranceAnim
        ParallelAnimation {
            NumberAnimation { target: systemButtonRowRoot; property: "_entranceOpacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: systemButtonRowRoot; property: "_leftTranslateX"; from: -30; to: 0; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: systemButtonRowRoot; property: "_rightTranslateX"; from: 30; to: 0; duration: 340; easing.type: Easing.OutCubic }
            NumberAnimation { target: systemButtonRowRoot; property: "_entranceTranslateY"; from: -15; to: 0; duration: 300; easing.type: Easing.OutCubic }
        }
        PropertyAction { target: systemButtonRowRoot; property: "_entranceDone"; value: true }
    }

    Rectangle {
        id: uptimeContainer
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        color: Appearance.colors.colLayer1
        readonly property int fullRadius: Config.options.appearance.sharpMode ? Appearance.rounding.full : height / 2
        radius: fullRadius

        visible: Config.options.sidebar.dashboardHeader.profileImageType !== "none" || Config.options.sidebar.dashboardHeader.textMode !== "none"

        opacity: systemButtonRowRoot._entranceDone ? 1.0 : systemButtonRowRoot._entranceOpacity
        transform: Translate {
            x: systemButtonRowRoot._entranceDone ? 0 : systemButtonRowRoot._leftTranslateX
            y: systemButtonRowRoot._entranceDone ? 0 : systemButtonRowRoot._entranceTranslateY
        }

        property int rowLeftMargin: Config.options.sidebar.dashboardHeader.profileImageType === "user_profile" ? 6 : 14
        readonly property bool _hasText: Config.options.sidebar.dashboardHeader.textMode !== "none"
        readonly property int rowRightMargin: _hasText ? 14 : rowLeftMargin

        implicitWidth: uptimeRow.implicitWidth + rowLeftMargin + rowRightMargin
        implicitHeight: Math.max(32, uptimeRow.implicitHeight + (Config.options.sidebar.dashboardHeader.profileImageType === "user_profile" ? 4 : 12))

        Row {
            id: uptimeRow
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: uptimeContainer.rowLeftMargin
            }
            spacing: 8

            // PROFILE PICTURE
            Item {
                id: profilePicContainer
                anchors.verticalCenter: parent.verticalCenter
                width: Config.options.sidebar.dashboardHeader.profileImageType === "distro" ? 24 : 40
                height: width
                visible: Config.options.sidebar.dashboardHeader.profileImageType !== "none"

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimaryContainer
                    visible: Config.options.sidebar.dashboardHeader.profileImageType === "user_profile"

                    MultiEffect {
                        anchors.fill: parent
                        source: profileImage
                        maskEnabled: true
                        maskSource: profileMask
                    }

                    Item {
                        id: profileMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.full
                            color: "black"
                        }
                    }

                    Image {
                        id: profileImage
                        anchors.fill: parent
                        source: Directories.userAvatarPathAccountsService ?? ""
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                }

                CustomIcon {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: SystemInfo.distroIcon
                    colorize: true
                    color: Appearance.colors.colOnLayer1
                    visible: Config.options.sidebar.dashboardHeader.profileImageType === "distro"
                }
            }

            // TEXT CONTENT
            Column {
                anchors.verticalCenter: parent.verticalCenter
                visible: uptimeContainer._hasText

                StyledText {
                    id: headerPrimaryText
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: 600
                    color: Appearance.colors.colOnLayer1
                    text: {
                        switch (Config.options.sidebar.dashboardHeader.textMode) {
                        case "username":
                            return SystemInfo.username ?? "";
                        case "hostname":
                            return SystemInfo.hostname ?? "";
                        case "uptime":
                            return SystemInfo.uptime ?? "";
                        default:
                            return "";
                        }
                    }
                }

                StyledText {
                    id: headerSecondaryText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    visible: text !== ""
                    text: Config.options.sidebar.dashboardHeader.textMode === "username" ? (SystemInfo.hostname ?? "") : ""
                }
            }
        }
    }

    // SYSTEM BUTTONS (Edit, Reload, Settings, Power)
    Rectangle {
        id: systemButtonsRow
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.full
        implicitHeight: 44
        implicitWidth: buttonsInnerRow.implicitWidth + 8

        opacity: systemButtonRowRoot._entranceDone ? 1.0 : systemButtonRowRoot._entranceOpacity
        transform: Translate {
            x: systemButtonRowRoot._entranceDone ? 0 : systemButtonRowRoot._rightTranslateX
            y: systemButtonRowRoot._entranceDone ? 0 : systemButtonRowRoot._entranceTranslateY
        }

        Row {
            id: buttonsInnerRow
            anchors.centerIn: parent
            spacing: 4

            QuickToggleButton {
                id: editButton
                toggled: systemButtonRowRoot.editMode
                visible: Config.options.sidebar.quickToggles.style === "android"
                buttonIcon: "edit"
                onClicked: {
                    systemButtonRowRoot.editMode = !systemButtonRowRoot.editMode;
                    systemButtonRowRoot.editModeToggled(systemButtonRowRoot.editMode);
                }
                StyledToolTip {
                    text: Translation.tr("Edit quick toggles")
                }
            }

            QuickToggleButton {
                id: reloadButton
                toggled: false
                buttonIcon: "restart_alt"
                onClicked: {
                    Quickshell.execDetached(["hyprctl", "reload"]);
                    Quickshell.reload(true);
                }
                StyledToolTip {
                    text: Translation.tr("Reload Hyprland & Quickshell")
                }
            }

            QuickToggleButton {
                id: settingsButton
                toggled: false
                buttonIcon: "settings"
                onClicked: {
                    GlobalStates.dashboardPanelOpen = false;
                    GlobalStates.toggleSettings();
                }
                StyledToolTip {
                    text: Translation.tr("Settings")
                }
            }

            QuickToggleButton {
                id: powerButton
                toggled: false
                buttonIcon: "power_settings_new"
                onClicked: {
                    GlobalStates.sessionOpen = true;
                }
                StyledToolTip {
                    text: Translation.tr("Session")
                }
            }
        }
    }
}
