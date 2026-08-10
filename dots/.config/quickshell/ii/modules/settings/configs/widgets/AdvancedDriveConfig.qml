import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentPage {
    id: page

    property bool showBackButton: false
    signal goBack()

    forceWidth: false

    RowLayout {
        visible: page.showBackButton
        spacing: 12

        RippleButton {
            implicitWidth: implicitHeight
            implicitHeight: 40
            topLeftRadius: Appearance.rounding.full
            topRightRadius: Appearance.rounding.full
            bottomLeftRadius: Appearance.rounding.full
            bottomRightRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive
            onClicked: page.goBack()

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        StyledText {
            text: Translation.tr("Advanced Drive Settings")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        Layout.fillWidth: true
        icon: "drive_file_move"
        title: Translation.tr("Drive Destination")

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("Backups are grouped inside one Drive folder. The automatic name combines this username and Linux distribution.")
        }

        ConfigTextField {
            Layout.fillWidth: true
            icon: "folder_managed"
            text: Translation.tr("Remote backup folder")
            placeholderText: GoogleDriveService.defaultDriveBasePath
            inputText: GoogleDriveService.effectiveDriveBasePath
            tooltip: Translation.tr("Use letters, numbers, dots, underscores, dashes or nested folders. Leave empty to restore the automatic name.")
            textField.onEditingFinished: {
                const value = textField.text.trim();
                if (value === "") {
                    Config.options.googleDrive.driveBasePath = "";
                    return;
                }
                if (/^[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(value) && !value.includes(".."))
                    Config.options.googleDrive.driveBasePath = value;
            }
        }
    }

    ContentSection {
        Layout.fillWidth: true
        icon: "speed"
        title: Translation.tr("Transfer & Network")

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("These options are useful for slower connections or automatic backups triggered by network changes.")
        }

        ConfigSlider {
            Layout.fillWidth: true
            buttonIcon: "speed"
            text: Translation.tr("Bandwidth limit (KB/s)")
            from: 0
            to: 10000
            stepSize: 100
            value: Config.options.googleDrive.bandwidthLimitKbps
            usePercentTooltip: false
            tooltipContent: Config.options.googleDrive.bandwidthLimitKbps === 0
                ? Translation.tr("Unlimited")
                : String(Config.options.googleDrive.bandwidthLimitKbps) + " KB/s"
            onValueChanged: {
                if (value !== Config.options.googleDrive.bandwidthLimitKbps)
                    Config.options.googleDrive.bandwidthLimitKbps = Math.round(value);
            }
        }

        ConfigSwitch {
            buttonIcon: "signal_cellular_alt"
            text: Translation.tr("Pause on metered connections")
            checked: Config.options.googleDrive.pauseOnMeteredConnection
            onCheckedChanged: {
                if (checked !== Config.options.googleDrive.pauseOnMeteredConnection)
                    Config.options.googleDrive.pauseOnMeteredConnection = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "wifi_find"
            text: Translation.tr("Sync when network connects")
            checked: Config.options.googleDrive.syncOnNetworkChange
            onCheckedChanged: {
                if (checked !== Config.options.googleDrive.syncOnNetworkChange)
                    Config.options.googleDrive.syncOnNetworkChange = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "update"
            text: Translation.tr("Backup only files modified since last backup")
            checked: Config.options.googleDrive.onlyModifiedSinceLastSync
            onCheckedChanged: {
                if (checked !== Config.options.googleDrive.onlyModifiedSinceLastSync)
                    Config.options.googleDrive.onlyModifiedSinceLastSync = checked;
            }
        }
    }

    ContentSection {
        Layout.fillWidth: true
        icon: "history"
        title: Translation.tr("Retention & Cleanup")

        NoticeBox {
            Layout.fillWidth: true
            text: Translation.tr("Retention controls affect how many historical copies remain and how remote files are handled when local folders change.")
        }

        ConfigSpinBox {
            icon: "history"
            text: Translation.tr("Versions to keep")
            from: 1
            to: 10
            value: Config.options.googleDrive.keepVersions
            onValueChanged: {
                if (value !== Config.options.googleDrive.keepVersions)
                    Config.options.googleDrive.keepVersions = value;
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Orphan policy")
            color: Appearance.colors.colSubtext
        }

        ConfigSelectionArray {
            Layout.fillWidth: true
            currentValue: Config.options.googleDrive.deleteRemoteOrphans ? "delete" : "keep"
            options: [
                { displayName: Translation.tr("Keep on Drive"), value: "keep", icon: "cloud" },
                { displayName: Translation.tr("Delete from Drive"), value: "delete", icon: "delete_sweep" }
            ]
            onSelected: value => Config.options.googleDrive.deleteRemoteOrphans = value === "delete"
        }
    }

    ContentSection {
        Layout.fillWidth: true
        icon: "notifications"
        title: Translation.tr("Notifications")

        ConfigSwitch {
            buttonIcon: "cloud_done"
            text: Translation.tr("Notify on backup complete")
            checked: Config.options.googleDrive.notifyOnComplete
            onCheckedChanged: {
                if (checked !== Config.options.googleDrive.notifyOnComplete)
                    Config.options.googleDrive.notifyOnComplete = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "error"
            text: Translation.tr("Notify on errors")
            checked: Config.options.googleDrive.notifyOnError
            onCheckedChanged: {
                if (checked !== Config.options.googleDrive.notifyOnError)
                    Config.options.googleDrive.notifyOnError = checked;
            }
        }
    }
}
