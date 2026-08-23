import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root
    anchors.fill: parent
    property bool showBackButton: false
    signal goBack()
    property string aliasDraft: ""
    property string urlDraft: ""

    function addLink() {
        const alias = root.aliasDraft.trim();
        const url = root.urlDraft.trim();
        if (alias.length === 0 || !/^https?:\/\//.test(url))
            return;
        const links = Array.from(Config.options.search.modules.quicklinks.links ?? []).filter(link => String(link?.alias ?? "") !== alias);
        links.push({ alias: alias, name: alias, url: url, icon: "link", openWith: "default" });
        Config.options.search.modules.quicklinks.links = links;
        root.aliasDraft = "";
        root.urlDraft = "";
    }

    ContentPage {
        anchors.fill: parent
        forceWidth: false
        RowLayout {
            visible: root.showBackButton
            spacing: Appearance.sizes.elevationMargin
            RippleButton { implicitWidth: Appearance.sizes.elevationMargin * 4; implicitHeight: implicitWidth; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colSecondaryContainer; colBackgroundHover: Appearance.colors.colSecondaryContainerHover; colRipple: Appearance.colors.colSecondaryContainerActive; onClicked: root.goBack(); MaterialSymbol { anchors.centerIn: parent; text: "arrow_back"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnSecondaryContainer } }
            StyledText { text: Translation.tr("Quicklinks"); font.pixelSize: Appearance.font.pixelSize.large; font.family: Appearance.font.family.title; color: Appearance.colors.colOnLayer0 }
        }
        ContentSection {
            icon: "link"
            title: Translation.tr("Quicklinks")
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2
                ConfigSwitch { buttonIcon: "link"; text: Translation.tr("Enable quicklinks"); checked: Config.options.search.modules.quicklinks.enable; onCheckedChanged: Config.options.search.modules.quicklinks.enable = checked }
                ConfigSwitch { buttonIcon: "content_copy"; text: Translation.tr("Copy instead of open on Enter"); checked: Config.options.search.modules.quicklinks.copyOnEnter; onCheckedChanged: Config.options.search.modules.quicklinks.copyOnEnter = checked }
                ConfigTextField { text: Translation.tr("Alias"); icon: "alternate_email"; inputText: root.aliasDraft; textField.onTextChanged: root.aliasDraft = textField.text }
                ConfigTextField { text: Translation.tr("URL"); icon: "link"; inputText: root.urlDraft; textField.onTextChanged: root.urlDraft = textField.text }
                RippleButton {
                    implicitWidth: addLabel.implicitWidth + Appearance.sizes.elevationMargin * 2
                    implicitHeight: addLabel.implicitHeight + Appearance.sizes.elevationMargin
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    onClicked: root.addLink()
                    StyledText { id: addLabel; anchors.centerIn: parent; text: Translation.tr("Add quicklink"); color: Appearance.colors.colOnPrimaryContainer }
                }
            }
        }
        ContentSection {
            icon: "format_list_bulleted"
            title: Translation.tr("Saved links")
            Repeater {
                model: Config.options.search.modules.quicklinks.links
                delegate: ConfigSwitch {
                    required property int index
                    required property var modelData
                    buttonIcon: "link"
                    text: String(modelData.alias ?? modelData.name ?? "") + " · " + String(modelData.url ?? "")
                    checked: true
                    onCheckedChanged: if (!checked) {
                        const links = Array.from(Config.options.search.modules.quicklinks.links ?? []);
                        links.splice(index, 1);
                        Config.options.search.modules.quicklinks.links = links;
                    }
                }
            }
        }
    }
}
