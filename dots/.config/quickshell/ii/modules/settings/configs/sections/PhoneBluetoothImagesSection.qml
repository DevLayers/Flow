pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentSection {
    id: root

    icon: "bluetooth"
    title: Translation.tr("Bluetooth Device Images")

    property string pendingMac: ""
    readonly property string manageScript: Quickshell.shellPath("scripts/services/manage_device_image.sh")

    // Cache the two derived arrays once per source change. The previous
    // bindings rebuilt both lists for every visibility and Repeater binding.
    readonly property var deviceImages: {
        const images = Config.options.bluetoothDeviceImages || [];
        return Array.from(images);
    }
    readonly property var availableDevices: {
        const all = BluetoothStatus.friendlyDeviceList || [];
        const managed = root.deviceImages;
        const available = [];
        for (let i = 0; i < all.length; i++) {
            let isManaged = false;
            for (let j = 0; j < managed.length; j++) {
                if (all[i].address === managed[j].mac) {
                    isManaged = true;
                    break;
                }
            }
            if (!isManaged)
                available.push(all[i]);
        }
        return available;
    }

    function getDeviceName(mac) {
        const all = BluetoothStatus.friendlyDeviceList || [];
        for (let i = 0; i < all.length; i++) {
            if (all[i].address === mac)
                return all[i].name || "Unknown Device";
        }
        return "Unknown Device";
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 250
        visible: root.availableDevices.length === 0 && root.deviceImages.length === 0

        PagePlaceholder {
            anchors.fill: parent
            icon: "bluetooth_disabled"
            shape: MaterialShape.Shape.Circle
            title: Translation.tr("No Bluetooth devices")
            description: Translation.tr("Pair a Bluetooth device first to assign custom images.")
        }
    }

    Process {
        id: pickerProc
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0 && root.pendingMac !== "")
                    copyProc.exec([root.manageScript, "copy", path, root.pendingMac]);
            }
        }
    }

    Process {
        id: copyProc
        stdout: StdioCollector {
            onStreamFinished: {
                const filename = text.trim();
                if (filename.length === 0)
                    return;

                const list = Array.from(root.deviceImages);
                let idx = -1;
                for (let i = 0; i < list.length; i++) {
                    if (list[i].mac === root.pendingMac) {
                        idx = i;
                        break;
                    }
                }
                const entry = { mac: root.pendingMac, image: filename };
                if (idx !== -1)
                    list[idx] = entry;
                else
                    list.push(entry);
                Config.options.bluetoothDeviceImages = list;
                root.pendingMac = "";
            }
        }
    }

    ContentSubsection {
        title: Translation.tr("1. Select a Device")
        visible: root.availableDevices.length > 0
        isFirst: true

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.rounding.small

            Repeater {
                model: root.availableDevices

                delegate: Rectangle {
                    required property var modelData

                    width: 240
                    height: 76
                    radius: Appearance.rounding.normal
                    color: isSelected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer3

                    readonly property bool isSelected: root.pendingMac === (modelData ? modelData.address : "")

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.rounding.small
                        spacing: Appearance.rounding.small

                        Item {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42

                            MaterialShape {
                                anchors.centerIn: parent
                                implicitSize: 42
                                color: isSelected ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHighest

                                function rollShape() {
                                    const shapes = ["Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided", "Clover8Leaf", "SoftBurst", "Circle", "Sunny"];
                                    shapeString = shapes[Math.floor(Math.random() * shapes.length)];
                                }
                                Component.onCompleted: rollShape()
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "bluetooth"
                                iconSize: Appearance.font.pixelSize.larger
                                fill: 1
                                color: isSelected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.rounding.unsharpen

                            StyledText {
                                text: modelData && modelData.name ? modelData.name : "Unknown"
                                font.weight: Font.DemiBold
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: modelData && modelData.address ? modelData.address : ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                                opacity: isSelected ? 0.9 : 0.7
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (modelData) root.pendingMac = modelData.address
                    }
                }
            }
        }
    }

    ContentSubsection {
        title: Translation.tr("2. Assign Image")
        visible: root.pendingMac !== ""

        Rectangle {
            Layout.fillWidth: true
            height: 120
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer3

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Appearance.rounding.small

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Appearance.rounding.unsharpen

                    StyledText {
                        text: Translation.tr("Preparing to style: ") + root.getDeviceName(root.pendingMac)
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnSurface
                        Layout.alignment: Qt.AlignHCenter
                    }

                    StyledText {
                        text: root.pendingMac
                        font.family: Appearance.font.family.numbers
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOutline
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                RippleButtonWithIcon {
                    Layout.alignment: Qt.AlignHCenter
                    materialIcon: "add_photo_alternate"
                    mainText: Translation.tr("Upload Artwork")
                    onClicked: pickerProc.exec([root.manageScript, "pick"])
                }
            }
        }
    }

    ContentSubsection {
        title: Translation.tr("Managed Devices")
        visible: root.deviceImages.length > 0
        isLast: true

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.rounding.small

            Repeater {
                model: root.deviceImages

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: 180
                    height: 220
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer3

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.rounding.small
                        spacing: Appearance.rounding.small

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            color: Appearance.colors.colLayer1
                            radius: Appearance.rounding.normal
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: Appearance.rounding.small
                                source: modelData && modelData.image ? "file://" + Directories.shellConfig + "/bluetooth_images/" + modelData.image : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.rounding.unsharpen

                            StyledText {
                                text: modelData ? root.getDeviceName(modelData.mac) : ""
                                font.weight: Font.DemiBold
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurface
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: modelData ? modelData.mac : ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.family: Appearance.font.family.numbers
                                color: Appearance.colors.colOnSurfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }

                            IconToolbarButton {
                                text: "delete"
                                onClicked: {
                                    const list = Array.from(root.deviceImages);
                                    list.splice(index, 1);
                                    Config.options.bluetoothDeviceImages = list;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
