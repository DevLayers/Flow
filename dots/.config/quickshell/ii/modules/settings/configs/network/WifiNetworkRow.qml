import QtQuick
import QtQuick.Layouts
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * One scanned access point, with its actions folded away until the row is
 * opened. Connecting, entering a secret, forgetting and autoconnect all happen
 * in place — this page is the dialog, so there is nowhere else to send them.
 */
Rectangle {
    id: root

    required property WifiAccessPoint accessPoint
    property bool isFirst: false
    property bool isLast: false
    property bool expanded: false

    readonly property string ssid: root.accessPoint?.ssid ?? ""
    readonly property int strength: root.accessPoint?.strength ?? 0
    readonly property bool isActive: root.accessPoint?.active ?? false
    readonly property bool secure: root.accessPoint?.isSecure ?? false
    readonly property bool enterprise: root.accessPoint?.enterprise ?? false
    readonly property bool isConnecting: Network.wifiConnectTarget === root.accessPoint
    readonly property bool hasError: Network.lastWifiExitCode !== 0
        && Network.wifiErrorTarget === root.accessPoint
    readonly property bool askingPassword: root.accessPoint?.askingPassword ?? false

    readonly property string profileName: Network.savedProfileFor(root.ssid)
    readonly property var savedProfile: Network.savedConnections
        .find(entry => entry.name === root.profileName) ?? null
    readonly property bool isSaved: (root.accessPoint?.known ?? false) || root.profileName.length > 0
    // A secured network with nothing stored can only be joined with a secret,
    // so the row opens on its fields rather than failing first and then asking.
    readonly property bool needsSecret: root.secure && !root.isSaved

    readonly property real outerRadius: Appearance.rounding.normal
    readonly property real innerRadius: Appearance.rounding.verysmall

    function submit(): void {
        if (!root.needsSecret && !root.askingPassword) {
            Network.connectToWifiNetwork(root.accessPoint);
            return;
        }
        root.expanded = true;
        if (root.enterprise && identityField.text.length === 0) {
            identityField.forceActiveFocus();
            return;
        }
        if (passwordField.text.length === 0) {
            passwordField.forceActiveFocus();
            return;
        }
        Network.connectWithPassword(root.ssid, passwordField.text, root.enterprise ? identityField.text : "");
    }

    onAskingPasswordChanged: if (root.askingPassword) root.expanded = true

    Layout.fillWidth: true
    implicitHeight: rowContent.implicitHeight
    topLeftRadius: root.isFirst ? root.outerRadius : root.innerRadius
    topRightRadius: root.isFirst ? root.outerRadius : root.innerRadius
    bottomLeftRadius: root.isLast ? root.outerRadius : root.innerRadius
    bottomRightRadius: root.isLast ? root.outerRadius : root.innerRadius
    color: root.isActive ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
    clip: true

    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    ColumnLayout {
        id: rowContent
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Item {
            Layout.fillWidth: true
            implicitHeight: 58

            MouseArea {
                id: headerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }

            Rectangle {
                anchors.fill: parent
                color: headerArea.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                opacity: root.isActive ? 0.4 : 1
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 12

                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "wifi"
                        iconSize: 24
                        opacity: 0.25
                        color: Appearance.colors.colOnLayer1
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.strength > 80 ? "android_wifi_4_bar"
                            : root.strength > 60 ? "android_wifi_3_bar"
                            : root.strength > 40 ? "wifi_2_bar"
                            : root.strength > 20 ? "wifi_1_bar" : "signal_wifi_0_bar"
                        fill: 1
                        iconSize: 24
                        color: root.isActive ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.colors.colOnLayer1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: root.ssid.length > 0 ? root.ssid : Translation.tr("Hidden network")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: root.isActive ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: {
                            const parts = [];
                            if (root.isActive)
                                parts.push(Translation.tr("Connected"));
                            else if (root.isConnecting)
                                parts.push(Translation.tr("Connecting…"));
                            else if (root.isSaved)
                                parts.push(Translation.tr("Saved"));
                            parts.push(root.secure ? (root.accessPoint?.security ?? "")
                                : Translation.tr("Open"));
                            const band = root.accessPoint?.bandLabel ?? "";
                            if (band.length > 0)
                                parts.push(band);
                            parts.push(`${root.strength}%`);
                            return parts.filter(part => part.length > 0).join("  •  ");
                        }
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                MaterialSymbol {
                    visible: root.secure && !root.isConnecting
                    text: root.enterprise ? "badge" : "lock"
                    fill: 1
                    iconSize: Appearance.font.pixelSize.normal
                    color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.35)
                }

                MaterialLoadingIndicator {
                    visible: root.isConnecting
                    loading: root.isConnecting
                    implicitSize: 20
                }

                MaterialSymbol {
                    text: "keyboard_arrow_down"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    opacity: headerArea.containsMouse ? 1 : 0.6
                    rotation: root.expanded ? 0 : -90

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: root.expanded ? actions.implicitHeight + 16 : 0
            clip: true

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            ColumnLayout {
                id: actions
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                opacity: root.expanded ? 1 : 0
                spacing: 8

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                    }
                }

                MaterialTextField {
                    id: identityField
                    Layout.fillWidth: true
                    visible: root.enterprise && (root.needsSecret || root.askingPassword)
                    placeholderText: Translation.tr("Identity (username)")
                    onAccepted: root.submit()
                }

                MaterialTextField {
                    id: passwordField
                    Layout.fillWidth: true
                    visible: root.needsSecret || root.askingPassword
                    echoMode: revealSecret.checked ? TextInput.Normal : TextInput.Password
                    placeholderText: Translation.tr("Password")
                    error: root.hasError
                    onAccepted: root.submit()
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: passwordField.visible
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Show password")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }

                    StyledSwitch {
                        id: revealSecret
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.hasError && Network.lastWifiError.length > 0
                    wrapMode: Text.Wrap
                    text: Network.lastWifiError
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.m3colors.m3error
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !root.isActive && (root.accessPoint?.bssid ?? "").length > 0
                    elide: Text.ElideRight
                    text: Translation.tr("Access point %1").arg(root.accessPoint?.bssid ?? "")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButtonWithIcon {
                        visible: !root.isActive
                        materialIcon: "link"
                        mainText: root.needsSecret || root.askingPassword
                            ? Translation.tr("Join") : Translation.tr("Connect")
                        colBackground: Appearance.colors.colPrimary
                        colText: Appearance.colors.colOnPrimary
                        onClicked: root.submit()
                    }

                    RippleButtonWithIcon {
                        visible: root.isActive
                        materialIcon: "link_off"
                        mainText: Translation.tr("Disconnect")
                        onClicked: Network.disconnectWifiNetwork()
                    }

                    RippleButtonWithIcon {
                        visible: root.isSaved
                        materialIcon: "delete"
                        mainText: Translation.tr("Forget")
                        onClicked: Network.forgetWifiNetwork(root.ssid)
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        visible: root.savedProfile !== null
                        text: Translation.tr("Connect automatically")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }

                    StyledSwitch {
                        visible: root.savedProfile !== null
                        checked: root.savedProfile?.autoconnect ?? false
                        onToggled: {
                            NetworkCommands.setAutoconnect(root.profileName, checked,
                                () => Network.refreshSaved());
                            checked = Qt.binding(() => root.savedProfile?.autoconnect ?? false);
                        }
                    }
                }
            }
        }
    }
}
