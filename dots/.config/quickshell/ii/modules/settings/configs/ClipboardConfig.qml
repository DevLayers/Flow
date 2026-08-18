import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentPage {
    id: page

    forceWidth: false

    ContentSection {
        icon: "content_paste"
        title: Translation.tr("Content detectors")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Detected content types get their own colour and preview in the launcher's clipboard mode.")
            color: Appearance.colors.colOnLayer1
            opacity: 0.75
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.Wrap
        }

        GridLayout {
            id: detectorsGrid
            Layout.fillWidth: true
            columns: width >= Appearance.font.pixelSize.hugeass * 24 ? 3 : (width >= Appearance.font.pixelSize.hugeass * 16 ? 2 : 1)
            columnSpacing: 8
            rowSpacing: 8

            // 1. Color
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 46
                buttonRadius: Appearance.rounding.normal
                property bool active: Config.options.search.clipboard.detectors.hexColor
                colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                onClicked: Config.options.search.clipboard.detectors.hexColor = !active

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "palette"
                        iconSize: 20
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Color")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: parent.parent.active
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                }
            }

            // 2. URL
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 46
                buttonRadius: Appearance.rounding.normal
                property bool active: Config.options.search.clipboard.detectors.url
                colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                onClicked: Config.options.search.clipboard.detectors.url = !active

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "link"
                        iconSize: 20
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("URL")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: parent.parent.active
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                }
            }

            // 3. Email
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 46
                buttonRadius: Appearance.rounding.normal
                property bool active: Config.options.search.clipboard.detectors.email
                colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                onClicked: Config.options.search.clipboard.detectors.email = !active

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "alternate_email"
                        iconSize: 20
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Email")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: parent.parent.active
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                }
            }

            // 4. Phone
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 46
                buttonRadius: Appearance.rounding.normal
                property bool active: Config.options.search.clipboard.detectors.phone
                colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                onClicked: Config.options.search.clipboard.detectors.phone = !active

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "phone"
                        iconSize: 20
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Phone")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: parent.parent.active
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                }
            }

            // 5. JSON
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 46
                buttonRadius: Appearance.rounding.normal
                property bool active: Config.options.search.clipboard.detectors.json
                colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                onClicked: Config.options.search.clipboard.detectors.json = !active

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "data_object"
                        iconSize: 20
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("JSON")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: parent.parent.active
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                }
            }

            // 6. Multiline / Lines
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 46
                buttonRadius: Appearance.rounding.normal
                property bool active: Config.options.search.clipboard.detectors.multiline
                colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                onClicked: Config.options.search.clipboard.detectors.multiline = !active

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "notes"
                        iconSize: 20
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Lines")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: parent.parent.active
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                }
            }

            // 7. Number
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 46
                buttonRadius: Appearance.rounding.normal
                property bool active: Config.options.search.clipboard.detectors.number
                colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                onClicked: Config.options.search.clipboard.detectors.number = !active

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "tag"
                        iconSize: 20
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Number")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: parent.parent.active
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                }
            }

            // 8. Markdown
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 46
                buttonRadius: Appearance.rounding.normal
                property bool active: Config.options.search.clipboard.detectors.markdown
                colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                onClicked: Config.options.search.clipboard.detectors.markdown = !active

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "markdown"
                        iconSize: 20
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Markdown")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: parent.parent.active
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                }
            }

            // 9. File Path
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 46
                buttonRadius: Appearance.rounding.normal
                property bool active: Config.options.search.clipboard.detectors.filePath
                colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                onClicked: Config.options.search.clipboard.detectors.filePath = !active

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    MaterialSymbol {
                        text: "folder_open"
                        iconSize: 20
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("File Path")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: parent.parent.active
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                    }

                    MaterialSymbol {
                        text: parent.parent.active ? "check_circle" : "radio_button_unchecked"
                        iconSize: 18
                        fill: parent.parent.active ? 1 : 0
                        color: parent.parent.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "dashboard"
        title: Translation.tr("Panel layout")

        ConfigSlider {
            buttonIcon: "width"
            text: Translation.tr("Panel width (px)")
            value: Config.options.search.clipboard.panelWidth
            from: 600
            to: 1200
            stepSize: 10
            usePercentTooltip: false
            onValueChanged: Config.options.search.clipboard.panelWidth = value
        }

        ConfigSlider {
            buttonIcon: "vertical_split"
            text: Translation.tr("List column ratio")
            value: Config.options.search.clipboard.listColumnRatio * 100
            from: 25
            to: 60
            stepSize: 5
            usePercentTooltip: true
            onValueChanged: Config.options.search.clipboard.listColumnRatio = value / 100
        }

        ConfigSlider {
            buttonIcon: "image_aspect_ratio"
            text: Translation.tr("Image preview height (px)")
            value: Config.options.search.clipboard.imageHeight
            from: 100
            to: 400
            stepSize: 10
            usePercentTooltip: false
            onValueChanged: Config.options.search.clipboard.imageHeight = value
        }

        ConfigSlider {
            buttonIcon: "format_size"
            text: Translation.tr("Text preview font size (pt)")
            value: Config.options.search.clipboard.previewFontSize
            from: 9
            to: 20
            stepSize: 1
            usePercentTooltip: false
            onValueChanged: Config.options.search.clipboard.previewFontSize = value
        }

        ConfigSwitch {
            buttonIcon: "info"
            text: Translation.tr("Show metadata panel")
            checked: Config.options.search.clipboard.showMetadata
            onCheckedChanged: Config.options.search.clipboard.showMetadata = checked
        }

        ConfigSwitch {
            buttonIcon: "travel_explore"
            text: Translation.tr("Fuzzy search for clipboard")
            checked: Config.options.search.clipboard.enableSloppySearch
            onCheckedChanged: Config.options.search.clipboard.enableSloppySearch = checked
        }
    }

    ContentSection {
        icon: "link"
        title: Translation.tr("Related settings")

        Flow {
            Layout.fillWidth: true
            spacing: 8

            RelatedChip {
                pageId: "privacy"
                label: Translation.tr("Hide clipboard images")
                sectionHighlight: Translation.tr("Work Safety & Policies")
            }
        }
    }
}
