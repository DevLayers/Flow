import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.configs.widgets
import qs.services

Item {
    id: launcherRoot
    anchors.fill: parent

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress

        // ── Search Behavior & Positioning ────────────────────────────────────
        ContentSection {
            icon: "tune"
            title: Translation.tr("Search Behavior & Positioning")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ConfigSwitch {
                    buttonIcon: "trending_up"
                    text: Translation.tr("Frequency-based ranking")
                    checked: Config.options.search.frecency
                    onCheckedChanged: {
                        Config.options.search.frecency = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Sort apps by usage frequency and recency")
                    }
                }

                ConfigSwitch {
                    buttonIcon: "apps"
                    text: Translation.tr("Always list apps on empty query")
                    checked: Config.options.search.alwaysListApps
                    onCheckedChanged: {
                        Config.options.search.alwaysListApps = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Opens the app list immediately when search is opened with no query, bypassing the workspace overview")
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 8
                }

                LauncherPreview {
                    Layout.fillWidth: true
                    baseWidth: Config.options.search.baseWidth
                    maxHeight: Config.options.search.baseHeight ?? 500
                    centered: Config.options.search.positionStyle === "center"
                    verticalRatio: Config.options.search.centerVerticalRatio
                }

                ConfigSlider {
                    buttonIcon: "search"
                    text: Translation.tr("Search base width (px)")
                    value: Config.options.search.baseWidth
                    from: 360
                    to: 1000
                    stepSize: 10
                    usePercentTooltip: false
                    onValueChanged: Config.options.search.baseWidth = value
                }

                ConfigSlider {
                    buttonIcon: "height"
                    text: Translation.tr("Search max height (px)")
                    value: Config.options.search.baseHeight ?? 500
                    from: 300
                    to: 900
                    stepSize: 10
                    usePercentTooltip: false
                    onValueChanged: Config.options.search.baseHeight = value
                }

                ConfigSwitch {
                    buttonIcon: "center_focus_strong"
                    text: Translation.tr("Center Search on Screen")
                    checked: Config.options.search.positionStyle === "center"
                    onCheckedChanged: {
                        Config.options.search.positionStyle = checked ? "center" : "default";
                    }
                    StyledToolTip {
                        text: Translation.tr("Center disables overview and forces zoom animation to prevent bugs")
                    }
                }

                ConfigSlider {
                    enabled: Config.options.search.positionStyle === "center"
                    buttonIcon: "vertical_align_center"
                    text: Translation.tr("Vertical Center Position (%)")
                    value: Math.round(Config.options.search.centerVerticalRatio * 100)
                    from: 10
                    to: 90
                    stepSize: 1
                    usePercentTooltip: true
                    onValueChanged: Config.options.search.centerVerticalRatio = value / 100
                }

                NoticeBox {
                    visible: Config.options.search.positionStyle === "center"
                    text: Translation.tr("Note: In Center mode, the Overview workspace previews are disabled and the open animation is fixed to zoom.")
                    materialIcon: "info"
                }

                HelperCodeBox {
                    Layout.fillWidth: true
                    icon: "search"
                    title: Translation.tr("Open Search Only")
                    text: Translation.tr("To open search directly without launching the overview screen, add this keybind to your ~/.config/hypr/custom/keybinds.lua file:")
                    codeSnippet: 'hl.bind("CTRL + Space", hl.dsp.global("quickshell:searchOnlyToggle"), { description = "Shell: Open search only" })'
                    snippetWrapMode: Text.Wrap
                }
            }
        }

        // ── Search Features (Chips Grid) ─────────────────────────────────────
        ContentSection {
            icon: "extension"
            title: Translation.tr("Search Features & Previews")

            ContentSubsectionLabel {
                text: Translation.tr("Active search integrations")
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                // 1. System Controls
                RippleButton {
                    id: btnSystemControls
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.search.enableSystemControls
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.search.enableSystemControls = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "terminal"
                            iconSize: 20
                            fill: btnSystemControls.active ? 1 : 0
                            color: btnSystemControls.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("System Controls")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: btnSystemControls.active
                            color: btnSystemControls.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: btnSystemControls.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: btnSystemControls.active ? 1 : 0
                            color: btnSystemControls.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip {
                        text: Translation.tr("Allows running commands like :lock, :reboot, :poweroff, :suspend directly from search")
                    }
                }

                // 2. Math & Unit Converter
                RippleButton {
                    id: btnMathPreview
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.search.enableMathPreview
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.search.enableMathPreview = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "calculate"
                            iconSize: 20
                            fill: btnMathPreview.active ? 1 : 0
                            color: btnMathPreview.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Math & Units")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: btnMathPreview.active
                            color: btnMathPreview.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: btnMathPreview.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: btnMathPreview.active ? 1 : 0
                            color: btnMathPreview.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip {
                        text: Translation.tr("Displays real-time answers for math expressions and unit conversions in the result list")
                    }
                }

                // 3. Blur File Search Result Previews
                RippleButton {
                    id: btnBlurFilePreviews
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.search.blurFileSearchResultPreviews
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.search.blurFileSearchResultPreviews = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "blur_on"
                            iconSize: 20
                            fill: btnBlurFilePreviews.active ? 1 : 0
                            color: btnBlurFilePreviews.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Blur File Previews")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: btnBlurFilePreviews.active
                            color: btnBlurFilePreviews.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: btnBlurFilePreviews.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: btnBlurFilePreviews.active ? 1 : 0
                            color: btnBlurFilePreviews.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip {
                        text: Translation.tr("Blurs file search result previews to protect privacy")
                    }
                }

                // 4. Now Playing Media Bubble
                RippleButton {
                    id: btnNowPlaying
                    Layout.fillWidth: true
                    implicitHeight: 48
                    buttonRadius: Appearance.rounding.normal
                    property bool active: Config.options.search.showNowPlayingBubble
                    colBackground: active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    onClicked: Config.options.search.showNowPlayingBubble = !active

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialSymbol {
                            text: "music_note"
                            iconSize: 20
                            fill: btnNowPlaying.active ? 1 : 0
                            color: btnNowPlaying.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Now Playing")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.bold: btnNowPlaying.active
                            color: btnNowPlaying.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: btnNowPlaying.active ? "check_circle" : "radio_button_unchecked"
                            iconSize: 18
                            fill: btnNowPlaying.active ? 1 : 0
                            color: btnNowPlaying.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip {
                        text: Translation.tr("Shows a floating media player bubble in the search launcher when music or video is playing")
                    }
                }
            }

            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Non-app result delay (ms)")
                value: Config.options.search.nonAppResultDelay
                from: 0
                to: 500
                stepSize: 10
                onValueChanged: {
                    Config.options.search.nonAppResultDelay = value;
                }
                StyledToolTip {
                    text: Translation.tr("Delay in milliseconds before showing non-application search results to keep app launching snappy")
                }
            }
        }

        // ── AI Chat in Search ────────────────────────────────────────────────
        ContentSection {
            icon: "auto_awesome"
            title: Translation.tr("AI Chat in Search")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: Translation.tr("How search hands queries over to AI chat. The prefix trigger always works; the options below enable automatic triggers.")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                StyledComboBox {
                    id: aiTriggerSelector
                    buttonIcon: "auto_awesome"
                    textRole: "displayName"
                    model: [
                        {
                            displayName: Translation.tr("Prefix only"),
                            value: "prefix"
                        },
                        {
                            displayName: Translation.tr("Suggest \"Ask AI\" row"),
                            value: "suggest"
                        },
                        {
                            displayName: Translation.tr("Auto-open when nothing matches"),
                            value: "auto"
                        }
                    ]
                    currentIndex: {
                        const trigger = (Config.options.search.ai && Config.options.search.ai.trigger) ? Config.options.search.ai.trigger : "prefix";
                        const index = model.findIndex(item => item.value === trigger);
                        return index !== -1 ? index : 0;
                    }
                    onActivated: index => {
                        Config.options.search.ai.trigger = model[index].value;
                    }
                }
            }
        }

        // ── Advanced Subpages ────────────────────────────────────────────────
        ContentSection {
            icon: "settings_suggest"
            title: Translation.tr("Launcher Extensions & Tools")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ServiceCard {
                    cardIcon: "auto_awesome"
                    cardHue: 45
                    cardShape: "Cookie9Sided"
                    title: Translation.tr("Suggestions Panel")
                    description: Translation.tr("Configure empty-query suggestions (frecency, apps, commands, aliases)")
                    onOpenCard: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherSuggestionsConfig.qml"))
                }

                ServiceCard {
                    cardIcon: "tag"
                    cardHue: 200
                    cardShape: "Cookie12Sided"
                    title: Translation.tr("Search Prefixes")
                    description: Translation.tr("Customize query prefix triggers for apps, files, math, AI and web search")
                    onOpenCard: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherPrefixesConfig.qml"))
                }

                ServiceCard {
                    cardIcon: "label"
                    cardHue: 280
                    cardShape: "Clover4Leaf"
                    title: Translation.tr("App Aliases")
                    description: Translation.tr("Manage custom search keywords and shortcuts for apps, folders and commands")
                    onOpenCard: subPageOverlay.open(Qt.resolvedUrl("widgets/LauncherAliasesConfig.qml"))
                }
            }
        }

        // ── Target Directories ───────────────────────────────────────────────
        ContentSection {
            icon: "folder"
            title: Translation.tr("Directories & Targets")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                ContentSubsection {
                    title: Translation.tr("File search directory")
                    icon: "folder_open"
                    Layout.fillWidth: true

                    MaterialTextArea {
                        Layout.fillWidth: true
                        text: Config.options.search.fileSearchDirectory
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.search.fileSearchDirectory = text
                    }
                }
            }
        }

        // ── Related Settings ─────────────────────────────────────────────────
        ContentSection {
            icon: "link"
            title: Translation.tr("Related settings")

            Flow {
                Layout.fillWidth: true
                spacing: 8

                RelatedChip {
                    pageId: "mediaMusic"
                    label: Translation.tr("Media Downloader")
                    sectionHighlight: Translation.tr("Download")
                }

                RelatedChip {
                    pageId: "clipboard"
                    label: Translation.tr("Clipboard")
                    sectionHighlight: Translation.tr("General")
                }
            }
        }
    }

    // Sub-page overlay (slides in from the right)
    ConfigSubPageHost {
        id: subPageOverlay
        anchors.fill: parent
        z: 10
    }
}
