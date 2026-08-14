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
    signal openSettingsTarget(string pageId, string subPageId, string sectionId)

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RippleButton {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: implicitHeight
                implicitHeight: 44
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: root.backRequested()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.tutorial ? Translation.tr(root.tutorial.titleKey) : Translation.tr("Tutorial")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.tutorial
                        ? WelcomeTutorialRegistry.statusTextFor(root.tutorial)
                        : Translation.tr("Choose a tutorial from the catalog.")
                    color: root.integrationState.error
                        ? Appearance.colors.colOnErrorContainer
                        : Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.tutorial
                ? Translation.tr(root.content.intro)
                : Translation.tr("Choose a tutorial from the catalog.")
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.content.prerequisites && root.content.prerequisites.length > 0
            text: Translation.tr("What you need: ") + root.content.prerequisites.join(Translation.tr(" · "))
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Repeater {
                model: root.content.steps || []

                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 10

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignTop
                        text: (["looks_one", "looks_two", "looks_3", "looks_4"][index] || "looks_one")
                        shape: MaterialShape.Shape.Cookie4Sided
                        iconSize: Appearance.font.pixelSize.small
                        padding: 7
                        color: Appearance.colors.colSecondaryContainer
                        colSymbol: Appearance.colors.colOnSecondaryContainer
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr(modelData.title)
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr(modelData.body)
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RippleButtonWithIcon {
                Layout.alignment: Qt.AlignLeft
                visible: root.content.actionPage && root.content.actionPage.length > 0
                materialIcon: "open_in_new"
                mainText: root.content.actionLabel
                    ? Translation.tr(root.content.actionLabel)
                    : Translation.tr("Open guide")
                onClicked: root.openSettingsTarget(
                    root.content.actionPage || "",
                    root.content.actionSubPage || "",
                    root.content.actionSection || "")
            }
        }
    }
}
