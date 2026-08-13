import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter

Item {
    id: root

    Component.onCompleted: ScreenShader.refresh()

    WPanelPageColumn {
        anchors.fill: parent

        BodyRectangle {
            implicitHeight: 400
            implicitWidth: 50

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                HeaderRow {
                    id: headerRow
                    Layout.fillWidth: true
                    title: Translation.tr("Screen filter")
                }

                StyledFlickable {
                    id: flickable
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    contentHeight: contentLayout.implicitHeight
                    contentWidth: width
                    clip: true

                    bottomMargin: 12

                    ShaderOptions {
                        id: contentLayout
                        width: flickable.width
                    }
                }
            }
        }

        WPanelSeparator {}

        FooterRectangle {}
    }

    component ShaderOptions: ColumnLayout {
        spacing: 10

        ToggleItem {
            name: Translation.tr("Enable")
            description: ScreenShader.active ? Translation.tr("Using %1").arg(ScreenShader.displayName(ScreenShader.activeName)) : Translation.tr("No filter over the screen")
            iconName: "dark-theme"
            checked: ScreenShader.active
            onCheckedChanged: {
                if (checked === ScreenShader.active)
                    return;
                ScreenShader.toggle();
            }
        }

        SectionText {
            text: Translation.tr("Filter")
        }

        WChoiceButton {
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            text: Translation.tr("Off")
            icon.name: "eye-off"
            checked: !ScreenShader.active
            onClicked: ScreenShader.clear()
        }

        Repeater {
            model: ScreenShader.shaders

            delegate: WChoiceButton {
                required property var modelData
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                text: ScreenShader.displayName(modelData.name)
                checked: ScreenShader.activeName === modelData.name
                onClicked: ScreenShader.apply(modelData.name)
            }
        }

        WText {
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.fillWidth: true
            visible: ScreenShader.errorMessage.length > 0
            wrapMode: Text.Wrap
            text: ScreenShader.errorMessage
        }

        WText {
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 4
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Looks.colors.subfg
            text: Translation.tr("Filters come from hyprshade — install it for the built-in set. Your own .glsl files in ~/.config/hypr/shaders show up here too.")
        }
    }
}
