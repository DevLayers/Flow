import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage
    property int loadStage: 0

    Component.onCompleted: Qt.callLater(() => root.loadStage = 1)

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        // Fade the parent content while the KDE Connect sub-page slides in so
        // its switches cannot remain visible behind the loaded page.
        opacity: subPageOverlay.slideProgress
        visible: opacity > 0

    ContentSection {
        icon: "smartphone"
        title: Translation.tr("Phone & scrcpy Integration")
        visible: Config.options.policies.phone !== 0

        ContentSubsectionLabel { text: Translation.tr("Display") }

        ConfigSwitch {
            buttonIcon: "view_in_ar"
            text: Translation.tr("Show Mirror / Webcam / Microphone cards")
            checked: Config.options.phone.showPeripheralCards
            onCheckedChanged: {
                Config.options.phone.showPeripheralCards = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "sync"
            text: Translation.tr("Enable KDE Connect Service")
            checked: Config.options.phone.kdeconnectEnabled
            configPage: Qt.resolvedUrl("widgets/KdeConnectConfig.qml")
            onCheckedChanged: {
                Config.options.phone.kdeconnectEnabled = checked;
            }
        }

        ContentSubsectionLabel { text: Translation.tr("Contacts") }

        ConfigSwitch {
            buttonIcon: "contacts"
            text: Translation.tr("Sync contacts from phone")
            checked: Config.options.phone.contacts.enabled
            onCheckedChanged: {
                Config.options.phone.contacts.enabled = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "filter_alt"
            text: Translation.tr("Hide contacts without a name")
            checked: Config.options.phone.contacts.hideUnnamed
            enabled: Config.options.phone.contacts.enabled
            onCheckedChanged: {
                Config.options.phone.contacts.hideUnnamed = checked;
            }
            StyledToolTip {
                text: Translation.tr("Your phone exports every number known to any app, including spam lists and SIM imports. These arrive with no name and show up as bare numbers. Favorites are never hidden.")
            }
        }
    }

    ProgressiveSectionLoader {
        source: Qt.resolvedUrl("sections/PhoneBluetoothImagesSection.qml")
        active: root.loadStage >= 1
        estimatedHeight: 620
        showSkeleton: true
        sectionTitle: Translation.tr("Bluetooth Device Images")
        prioritizeOnViewport: true
        prioritizeOnSearch: true
    }

    ContentSection {
        icon: "share"
        title: Translation.tr("LocalSend")

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Auto-start")
            checked: Config.options.localsend.autoStart
            enabled: LocalSend.available
            onCheckedChanged: {
                Config.options.localsend.autoStart = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "notifications"
            text: Translation.tr("Show notifications")
            checked: Config.options.localsend.showNotifications
            enabled: LocalSend.available
            onCheckedChanged: {
                Config.options.localsend.showNotifications = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "branding_watermark"
            text: Translation.tr("Prefer popup over notification")
            checked: Config.options.localsend.preferPopupOverNotification
            enabled: LocalSend.available
            onCheckedChanged: {
                Config.options.localsend.preferPopupOverNotification = checked;
            }
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Download path")
            text: Config.options.localsend.downloadPath
            wrapMode: TextEdit.Wrap
            enabled: LocalSend.available
            onTextChanged: {
                Config.options.localsend.downloadPath = text;
            }
        }
    }

    }

    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }

}
