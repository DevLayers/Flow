import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.configs.network

/**
 * Bluetooth tab of the Network page: the radio, the pairing conversation, and
 * every device the adapter knows about or can currently see.
 *
 * Scanning runs only while this tab is on screen. Discovery keeps the radio
 * busy and drains battery, so it starts when the tab loads and stops when it
 * goes away.
 */
ContentPage {
    id: root
    forceWidth: false

    readonly property var pairingRequest: BluetoothAgent.request
    readonly property var pairingDisplay: BluetoothAgent.display
    readonly property bool showPairing: root.pairingRequest !== null || root.pairingDisplay !== null

    // Wording and formatting live on the agent because the shell-wide prompt
    // asks the same questions with the same words when this page is not open.
    Component.onCompleted: {
        BluetoothStatus.startDiscovery();
        BluetoothAgent.claimInline();
    }

    Component.onDestruction: {
        BluetoothStatus.stopDiscovery();
        BluetoothAgent.releaseInline();
    }

    // The adapter may still have been powering on when the tab appeared, in
    // which case the scan above was refused and has to be started again.
    Connections {
        target: BluetoothStatus
        function onEnabledChanged() {
            if (BluetoothStatus.enabled)
                BluetoothStatus.startDiscovery();
        }
    }

    component InfoRow: RowLayout {
        id: infoRow
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        visible: infoRow.value.length > 0
        spacing: 12

        StyledText {
            Layout.preferredWidth: 150
            text: infoRow.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: infoRow.value
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }
    }

    ContentSection {
        icon: "bluetooth"
        title: Translation.tr("Bluetooth")

        NoticeBox {
            Layout.fillWidth: true
            visible: !BluetoothStatus.available
            materialIcon: "bluetooth_disabled"
            text: Translation.tr("No Bluetooth adapter is available. Either the machine has none, or its driver did not load.")
        }

        NoticeBox {
            Layout.fillWidth: true
            visible: BluetoothStatus.available && BluetoothStatus.hardBlocked
            materialIcon: "airplanemode_active"
            text: Translation.tr("Bluetooth is blocked in hardware — by a physical switch, a keyboard toggle, or airplane mode. Software cannot lift that block.")
        }

        NoticeBox {
            Layout.fillWidth: true
            visible: BluetoothStatus.available && BluetoothAgent.lastError.length > 0
            materialIcon: "key_off"
            text: Translation.tr("The pairing helper could not start, so devices that ask for a code cannot be paired here. %1").arg(BluetoothAgent.lastError)
        }

        NoticeBox {
            Layout.fillWidth: true
            visible: BluetoothAgent.ready && !BluetoothAgent.isDefaultAgent
            materialIcon: "info"
            text: Translation.tr("Another program is already handling pairing requests. Codes may be asked for there instead of here.")
        }

        ConfigSwitch {
            id: radioSwitch
            buttonIcon: "bluetooth"
            text: Translation.tr("Enable Bluetooth")
            enabled: BluetoothStatus.available && !BluetoothStatus.hardBlocked
            checked: BluetoothStatus.enabled
            // The adapter owns this state, so the switch has to be handed its
            // binding back after the click that broke it.
            onCheckedChanged: {
                if (checked === BluetoothStatus.enabled)
                    return;
                BluetoothStatus.setEnabled(checked);
                checked = Qt.binding(() => BluetoothStatus.enabled);
            }
        }

        ConfigSwitch {
            buttonIcon: "visibility"
            text: Translation.tr("Visible to other devices")
            enabled: BluetoothStatus.enabled
            checked: BluetoothStatus.adapter?.discoverable ?? false
            onCheckedChanged: {
                const adapter = BluetoothStatus.adapter;
                if (!adapter || checked === adapter.discoverable)
                    return;
                adapter.discoverable = checked;
                checked = Qt.binding(() => BluetoothStatus.adapter?.discoverable ?? false);
            }
        }

        InfoRow {
            label: Translation.tr("Adapter")
            value: {
                const id = BluetoothStatus.adapterId;
                const name = BluetoothStatus.adapterName;
                if (id.length === 0)
                    return name;
                return name.length > 0 ? `${name} (${id})` : id;
            }
        }

        InfoRow {
            label: Translation.tr("Hardware address")
            value: BluetoothStatus.adapterAddress
        }
    }

    ContentSection {
        icon: "key"
        title: Translation.tr("Pairing")
        visible: root.showPairing

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.pairingRequest !== null
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: BluetoothAgent.requestTitle(root.pairingRequest)
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.fillWidth: true
                visible: (root.pairingRequest?.address ?? "").length > 0
                text: root.pairingRequest?.address ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.pairingRequest?.type === "confirm"
                horizontalAlignment: Text.AlignHCenter
                text: BluetoothAgent.formatPasskey(root.pairingRequest?.passkey)
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Bold
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                visible: (root.pairingRequest?.uuid ?? "").length > 0
                wrapMode: Text.Wrap
                text: Translation.tr("Service %1").arg(root.pairingRequest?.uuid ?? "")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            MaterialTextField {
                id: secretField
                Layout.fillWidth: true
                visible: BluetoothAgent.needsValue
                placeholderText: root.pairingRequest?.type === "pincode"
                    ? Translation.tr("PIN") : Translation.tr("Passkey")
                onAccepted: BluetoothAgent.accept(secretField.text)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButtonWithIcon {
                    materialIcon: "check"
                    mainText: BluetoothAgent.needsValue ? Translation.tr("Send")
                        : Translation.tr("Accept")
                    colBackground: Appearance.colors.colPrimary
                    colText: Appearance.colors.colOnPrimary
                    onClicked: {
                        if (BluetoothAgent.needsValue)
                            BluetoothAgent.accept(secretField.text);
                        else
                            BluetoothAgent.accept();
                        secretField.text = "";
                    }
                }

                RippleButtonWithIcon {
                    materialIcon: "close"
                    mainText: Translation.tr("Reject")
                    onClicked: {
                        BluetoothAgent.reject();
                        secretField.text = "";
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.pairingDisplay !== null
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Translation.tr("Enter this code on %1").arg(BluetoothAgent.requestName(root.pairingDisplay))
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.pairingDisplay?.type === "pincode" ? (root.pairingDisplay?.pin ?? "")
                    : BluetoothAgent.formatPasskey(root.pairingDisplay?.passkey)
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Bold
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colPrimary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButtonWithIcon {
                    materialIcon: "done"
                    mainText: Translation.tr("Dismiss")
                    onClicked: BluetoothAgent.dismissDisplay()
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }

    ContentSection {
        icon: "devices"
        title: Translation.tr("Paired devices")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                id: pairedRepeater
                model: ScriptModel {
                    values: BluetoothStatus.connectedDevices
                        .concat(BluetoothStatus.pairedButNotConnectedDevices)
                }

                delegate: BluetoothDeviceRow {
                    required property BluetoothDevice modelData
                    required property int index

                    device: modelData
                    isFirst: index === 0
                    isLast: index === pairedRepeater.count - 1
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: pairedRepeater.count === 0
            text: Translation.tr("No devices are paired yet.")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }

    ContentSection {
        icon: "bluetooth_searching"
        title: Translation.tr("Nearby devices")

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: BluetoothStatus.discovering ? Translation.tr("Scanning…")
                    : Translation.tr("%1 devices in range").arg(nearbyRepeater.count)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            RippleButtonWithIcon {
                enabled: BluetoothStatus.enabled
                materialIcon: BluetoothStatus.discovering ? "stop" : "refresh"
                mainText: BluetoothStatus.discovering ? Translation.tr("Stop")
                    : Translation.tr("Scan")
                onClicked: {
                    if (BluetoothStatus.discovering)
                        BluetoothStatus.stopDiscovery();
                    else
                        BluetoothStatus.startDiscovery();
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: BluetoothStatus.enabled
            spacing: 4

            Repeater {
                id: nearbyRepeater
                model: ScriptModel {
                    values: BluetoothStatus.unpairedDevices
                }

                delegate: BluetoothDeviceRow {
                    required property BluetoothDevice modelData
                    required property int index

                    device: modelData
                    isFirst: index === 0
                    isLast: index === nearbyRepeater.count - 1
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 8
            horizontalAlignment: Text.AlignHCenter
            visible: BluetoothStatus.enabled && nearbyRepeater.count === 0
            text: Translation.tr("Nothing new found yet. Put the other device in pairing mode.")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }
}
