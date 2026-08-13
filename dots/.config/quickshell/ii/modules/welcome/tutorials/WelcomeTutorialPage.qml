import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.welcome

Item {
    id: root

    property var tutorial: null
    readonly property var content: WelcomeTutorialContent.contentFor(root.tutorial ? root.tutorial.contentId : "")
    readonly property var integrationState: WelcomeTutorialRegistry.stateFor(root.tutorial)

    signal backRequested()
    signal openSettingsPage(string pageId)

    ContentPage {
        anchors.fill: parent
        bottomContentPadding: 28

        RippleButtonWithIcon {
            Layout.fillWidth: true
            materialIcon: "arrow_back"
            mainText: Translation.tr("Back to tutorials")
            onClicked: root.backRequested()
        }

        ContentSection {
            Layout.fillWidth: true
            icon: root.tutorial ? root.tutorial.icon : "school"
            title: root.tutorial ? Translation.tr(root.tutorial.titleKey) : Translation.tr("Tutorial")

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: root.integrationState.checking
                    ? "sync"
                    : (root.integrationState.error ? "error" : (root.integrationState.usable ? "check_circle" : "info"))
                text: root.tutorial
                    ? Translation.tr(root.content.intro) + "\n\n" + WelcomeTutorialRegistry.statusTextFor(root.tutorial)
                    : Translation.tr("Choose a tutorial from the catalog.")
            }
        }

        ContentSection {
            Layout.fillWidth: true
            visible: root.content.prerequisites && root.content.prerequisites.length > 0
            icon: "checklist"
            title: Translation.tr("Before you start")

            Repeater {
                model: root.content.prerequisites
                delegate: StyledText {
                    required property string modelData
                    Layout.fillWidth: true
                    text: "• " + Translation.tr(modelData)
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            visible: root.content.steps && root.content.steps.length > 0
            icon: "format_list_numbered"
            title: Translation.tr("Set it up")

            Repeater {
                model: root.content.steps
                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialShapeWrappedMaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            text: (["looks_one", "looks_two", "looks_3", "looks_4"][index] || "looks_one")
                            shape: MaterialShape.Shape.Cookie4Sided
                            iconSize: Appearance.font.pixelSize.normal
                            padding: 8
                            color: Appearance.colors.colPrimary
                            colSymbol: Appearance.colors.colOnPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr(modelData.title)
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr(modelData.body)
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.small
                                wrapMode: Text.WordWrap
                            }

                            RippleButtonWithIcon {
                                Layout.alignment: Qt.AlignLeft
                                visible: modelData.actionPage && modelData.actionPage.length > 0
                                materialIcon: "settings"
                                mainText: modelData.actionLabel ? Translation.tr(modelData.actionLabel) : Translation.tr("Open Settings")
                                onClicked: root.openSettingsPage(modelData.actionPage)
                            }

                            HelperCodeBox {
                                Layout.fillWidth: true
                                visible: modelData.command && modelData.command.length > 0
                                title: Translation.tr("Run when ready")
                                text: Translation.tr("This command is shown for reference; Welcome does not execute it.")
                                icon: "terminal"
                                codeSnippet: modelData.command || ""
                            }
                        }
                    }
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            visible: root.content.verification && root.content.verification.length > 0
            icon: "verified"
            title: Translation.tr("Verify the result")

            Repeater {
                model: root.content.verification
                delegate: StyledText {
                    required property string modelData
                    Layout.fillWidth: true
                    text: "• " + Translation.tr(modelData)
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "help"
            title: Translation.tr("Need help?")

            HelperLinkBox {
                Layout.fillWidth: true
                title: Translation.tr("Troubleshooting")
                text: Translation.tr("Common checks for this integration")

                Repeater {
                    model: root.content.troubleshooting
                    delegate: StyledText {
                        required property string modelData
                        Layout.fillWidth: true
                        text: "• " + Translation.tr(modelData)
                        color: Appearance.colors.colOnSecondaryContainer
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "ondemand_video"
            title: Translation.tr("Watch later")

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: root.tutorial && root.tutorial.videoUrl && root.tutorial.videoUrl.length > 0
                    ? "play_circle"
                    : "video_library"
                text: root.tutorial && root.tutorial.videoUrl && root.tutorial.videoUrl.length > 0
                    ? Translation.tr("A video guide is available when you want a visual walkthrough.")
                    : Translation.tr("Video guide coming soon. The written steps above are ready now.")

                RippleButtonWithIcon {
                    visible: root.tutorial && root.tutorial.videoUrl && root.tutorial.videoUrl.length > 0
                    materialIcon: "open_in_new"
                    mainText: Translation.tr("Open video")
                    onClicked: Qt.openUrlExternally(root.tutorial.videoUrl)
                }
            }
        }
    }
}
