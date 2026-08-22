import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false

        RowLayout {
            visible: subPageRoot.showBackButton
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
                onClicked: subPageRoot.goBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            StyledText {
                text: Translation.tr("Dock Live Preview")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            title: Translation.tr("Live Preview Widget")
            icon: "live_tv"

            ConfigSwitch {
                buttonIcon: "live_tv"
                text: Translation.tr("Enable Live Preview widget")
                checked: Config.options.dock.enableLivePreviewWidget ?? false
                onCheckedChanged: {
                    Config.options.dock.enableLivePreviewWidget = checked;
                }
            }

            ContentSubsection {
                visible: Config.options.dock.enableLivePreviewWidget ?? false
                title: Translation.tr("Target application")
                icon: "apps"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.dock.livePreviewAppId ?? ""
                    onSelected: newValue => {
                        DockLivePreviewService.selectApp(newValue);
                    }
                    options: {
                        const options = [{
                            displayName: Translation.tr("No application selected"),
                            icon: "block",
                            value: ""
                        }];
                        const selected = Config.options.dock.livePreviewAppId || "";
                        if (selected !== "") {
                            const entry = TaskbarApps.getCachedDesktopEntry(selected);
                            const name = (entry && entry.name) ? entry.name : selected;
                            options.push({
                                displayName: name,
                                icon: "live_tv",
                                value: selected
                            });
                        }
                        const appList = TaskbarApps.apps || [];
                        for (let i = 0; i < appList.length; ++i) {
                            const app = appList[i];
                            const appId = (app && app.appId) ? app.appId : "";
                            if (!appId || options.some(option => TaskbarApps.normalizeAppId(option.value) === TaskbarApps.normalizeAppId(appId)))
                                continue;
                            const appEntry = TaskbarApps.getCachedDesktopEntry(appId);
                            const appName = (appEntry && appEntry.name) ? appEntry.name : appId;
                            options.push({
                                displayName: appName,
                                icon: "apps",
                                value: appId
                            });
                        }
                        return options;
                    }
                }
            }

            ConfigSpinBox {
                visible: Config.options.dock.enableLivePreviewWidget ?? false
                Layout.fillWidth: true
                icon: "width"
                text: Translation.tr("Preview width (slots)")
                value: Config.options.dock.livePreviewSlots ?? 2
                from: 2
                to: 6
                stepSize: 1
                onValueChanged: Config.options.dock.livePreviewSlots = value
            }

            ContentSubsection {
                visible: Config.options.dock.enableLivePreviewWidget ?? false
                title: Translation.tr("Capture mode")
                icon: "videocam"
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.dock.livePreviewCaptureMode ?? "visible"
                    onSelected: newValue => Config.options.dock.livePreviewCaptureMode = newValue
                    options: [
                        {
                            displayName: Translation.tr("While visible"),
                            icon: "visibility",
                            value: "visible"
                        },
                        {
                            displayName: Translation.tr("While hovered"),
                            icon: "touch_app",
                            value: "hover"
                        }
                    ]
                }
            }

            ConfigSwitch {
                visible: Config.options.dock.enableLivePreviewWidget ?? false
                buttonIcon: "mouse"
                text: Translation.tr("Show captured cursor")
                checked: Config.options.dock.livePreviewPaintCursor ?? false
                onCheckedChanged: Config.options.dock.livePreviewPaintCursor = checked
            }

            ConfigSwitch {
                visible: Config.options.dock.enableLivePreviewWidget ?? false
                buttonIcon: "sync"
                text: Translation.tr("Follow active window")
                checked: Config.options.dock.livePreviewFollowActiveWindow ?? true
                onCheckedChanged: Config.options.dock.livePreviewFollowActiveWindow = checked
            }
        }
    }
}
