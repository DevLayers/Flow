import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property bool nextButtonHovered: false

    readonly property var languageNames: ({
        "de_DE": "Deutsch",
        "en_US": "English (United States)",
        "es_MX": "Español (México)",
        "fr_FR": "Français",
        "he_HE": "עברית",
        "id_ID": "Bahasa Indonesia",
        "it_IT": "Italiano",
        "ja_JP": "日本語",
        "pt_BR": "Português (Brasil)",
        "ru_RU": "Русский",
        "tr_TR": "Türkçe",
        "uk_UA": "Українська",
        "vi_VN": "Tiếng Việt",
        "zh_CN": "简体中文"
    })

    readonly property var languageOptions: {
        const codes = Translation.allAvailableLanguages && Translation.allAvailableLanguages.length > 0
            ? Array.from(Translation.allAvailableLanguages)
            : ["en_US"];
        if (!codes.includes("en_US"))
            codes.unshift("en_US");
        codes.sort((a, b) => a === "en_US" ? -1 : b === "en_US" ? 1 : a.localeCompare(b));
        return codes.map(code => ({
            code: code,
            label: root.languageNames[code] || code
        }));
    }

    readonly property string configuredLanguage: Config.options.language.ui
    property string selectedLanguage: root.languageOptions.some(option => option.code === root.configuredLanguage)
        ? root.configuredLanguage
        : "en_US"

    function selectLanguage(code: string) {
        root.selectedLanguage = code;
        Config.options.language.ui = code;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.rounding.large
        anchors.rightMargin: Appearance.rounding.large
        anchors.topMargin: Appearance.rounding.small
        spacing: Appearance.rounding.small

        ListView {
            id: languageList
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Let the hover scale breathe past the list viewport. The
            // Welcome window remains the outer clipping boundary.
            clip: false
            spacing: Appearance.rounding.verysmall
            boundsBehavior: Flickable.StopAtBounds
            model: root.languageOptions

            delegate: RippleButton {
                id: languageButton
                required property var modelData
                width: languageList.width
                implicitHeight: Appearance.rounding.large * 2.5
                buttonRadius: Appearance.rounding.normal
                toggled: root.selectedLanguage === modelData.code
                colBackground: toggled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                colBackgroundHover: toggled ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                colBackgroundActive: toggled ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active
                colRipple: toggled ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active
                Accessible.name: modelData.label

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.rounding.normal
                    anchors.rightMargin: Appearance.rounding.normal
                    spacing: Appearance.rounding.small

                    StyledText {
                        Layout.fillWidth: true
                        text: languageButton.modelData.label
                        color: languageButton.toggled
                            ? Appearance.colors.colOnPrimary
                            : Appearance.colors.colOnLayer1
                        font.family: Appearance.font.family.title
                        font.variableAxes: Appearance.font.variableAxes.titleRounded
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: languageButton.toggled ? Font.Bold : Font.DemiBold
                    }

                    MaterialSymbol {
                        visible: languageButton.toggled
                        text: "check"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnPrimary
                    }
                }

                onClicked: root.selectLanguage(languageButton.modelData.code)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: noticeText.implicitHeight + Appearance.rounding.normal * 2
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            StyledText {
                id: noticeText
                anchors.fill: parent
                anchors.margins: Appearance.rounding.normal
                text: Translation.tr("More languages can be translated with AI later from Language settings.")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
