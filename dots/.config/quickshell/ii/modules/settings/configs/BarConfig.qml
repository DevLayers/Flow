pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// Root Item wraps the scrollable page + the slide-in sub-page overlay.
// The `contentY` alias lets settings.qml search-scroll still work.
Item {
    id: barConfigRoot

    property alias contentY: page.contentY
    // ── Active sub-page URL ("" = none) ───────────────────────────────────
    property alias activeSubPage: subPageOverlay.activeSubPage
    property int loadStage: 0

    function advanceStage(nextStage) {
        if (barConfigRoot.loadStage >= nextStage)
            return;
        Qt.callLater(() => {
            if (barConfigRoot.loadStage < nextStage)
                barConfigRoot.loadStage = nextStage;
        });
    }

    Component.onCompleted: Qt.callLater(() => barConfigRoot.loadStage = 1)

    function openWidgetPage(componentId) {
        page.openWidgetPage(componentId);
    }

    // ── Main content page ─────────────────────────────────────────────────
    ContentPage {
        id: page

        function openWidgetPage(componentId) {
            const compInfo = BarComponentRegistry.getComponent(componentId);
            if (compInfo) {
                if (typeof compInfo.pageId !== "undefined") {
                    var win = barConfigRoot.QsWindow.window;
                    if (win && win.pageIndexById !== undefined) {
                        if (compInfo.sectionTitle)
                            win.pendingSectionHighlight = Translation.tr(compInfo.sectionTitle);

                        win.currentPage = win.pageIndexById(compInfo.pageId);
                    }
                } else if (compInfo.configPage) {
                    barConfigRoot.activeSubPage = Qt.resolvedUrl("widgets/" + compInfo.configPage);
                }
            }
        }

        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress
        visible: opacity > 0

        // ── Shell mode ────────────────────────────────────────────────────
        ContentSection {
            icon: "phone_android"
            title: Translation.tr("Shell mode")

            ContentSubsection {
                title: Translation.tr("Style")
                icon: "style"
                Layout.fillWidth: true

                // Locked to Default when centerInBar active
                NoticeBox {
                    Layout.fillWidth: true
                    visible: ShellModePolicy.barPositionLocked
                    materialIcon: "lock"
                    text: Translation.tr("Shell mode is locked to Default while 'Dynamic Island in bar center' is active. The search runs independently of the Dynamic Island in this mode.")
                }

                ConfigSelectionArray {
                    id: shellStyleSelector

                    currentValue: Config.options.sidebar.sidebarStyle
                    onSelected: (newValue) => {
                        ShellModePolicy.setMode(newValue);
                    }
                    options: {
                        var opts = [{
                            "displayName": Translation.tr("Default"),
                            "icon": "view_sidebar",
                            "value": "default"
                        }, {
                            "displayName": Translation.tr("Connect"),
                            "icon": "phone_android",
                            "value": "connect",
                            "enabled": ShellModePolicy.canSelectConnect
                        }];
                        opts[0].enabled = ShellModePolicy.canSelectDefault;

                        return opts;
                    }
                }

            }

            NoticeBox {
                Layout.fillWidth: true
                visible: ShellModePolicy.defaultBlockedReasonKey.length > 0
                materialIcon: "water_drop"
                text: Translation.tr(ShellModePolicy.defaultBlockedReasonKey)

                ShortcutBox {
                    targetPageId: "dynamicIsland"
                    targetSectionTitle: Translation.tr("Floating Dynamic Island")
                    materialIcon: "arrow_forward"
                    text: Translation.tr("Go to Dynamic Island settings")
                    linkText: Translation.tr("Go there")
                }

            }

            NoticeBox {
                Layout.fillWidth: true
                visible: Config.options.bar.autoHide.enable
                text: Translation.tr("Bar auto-hide is not supported by Search Connect Mode yet. Disable auto-hide to use the drop search.")
            }

        }

        // ── Position and Style ───────────────────────────────────────────
        ContentSection {
            icon: "palette"
            title: Translation.tr("Position and Style")

            ContentSubsection {
                title: Translation.tr("Bar position")
                icon: "dock"

                // Locked when centerInBar: must be Top
                NoticeBox {
                    Layout.fillWidth: true
                    visible: ShellModePolicy.barPositionLocked
                    materialIcon: "lock"
                    text: Translation.tr("Bar position is locked to Top while 'Dynamic Island in bar center' is active. Disable that feature first to change position.")
                }

                ConfigSelectionArray {
                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: (newValue) => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: {
                        const locked = ShellModePolicy.barPositionLocked;
                        return [{
                            "displayName": Translation.tr("Top"),
                            "icon": "arrow_upward",
                            "value": 0
                        }, {
                            "displayName": Translation.tr("Left"),
                            "icon": "arrow_back",
                            "value": 2,
                            "enabled": !locked
                        }, {
                            "displayName": Translation.tr("Bottom"),
                            "icon": "arrow_downward",
                            "value": 1,
                            "enabled": !locked
                        }, {
                            "displayName": Translation.tr("Right"),
                            "icon": "arrow_forward",
                            "value": 3,
                            "enabled": !locked
                        }];
                    }
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Bar dimensions")
                Layout.topMargin: 4
            }

            ConfigSpinBox {
                icon: "height"
                text: Translation.tr("Bar height")
                value: Config.options.bar.sizes.height
                from: 30
                to: 50
                stepSize: 1
                onValueChanged: {
                    Config.options.bar.sizes.height = value;
                }
            }

            ConfigSpinBox {
                visible: Config.options.bar.vertical
                icon: "width"
                text: Translation.tr("Bar width")
                value: Config.options.bar.sizes.width
                from: 30
                to: 50
                stepSize: 1
                onValueChanged: {
                    Config.options.bar.sizes.width = value;
                }
            }

            ContentSubsection {
                title: Translation.tr("Corner style")
                icon: "rounded_corner"

                NoticeBox {
                    Layout.fillWidth: true
                    visible: Config.options.bar.barBackgroundStyle === 3 && (Config.options.bar.cornerStyle === 2 || Config.options.bar.cornerStyle === 3)
                    materialIcon: "grid_view"
                    text: Translation.tr("Rect and Dynamic Island corner styles are incompatible with Islands background. Only Hug and Float are available while Islands is active.")
                }

                ConfigSelectionArray {
                    id: cornerStyleSelector

                    currentValue: Config.options.bar.cornerStyle
                    onSelected: (newValue) => {
                        Config.options.bar.cornerStyle = newValue;
                    }
                    options: {
                        var opts = [{
                            "displayName": Translation.tr("Hug"),
                            "icon": "line_curve",
                            "value": 0
                        }, {
                            "displayName": Translation.tr("Float"),
                            "icon": "page_header",
                            "value": 1
                        }, {
                            "displayName": Translation.tr("Rect"),
                            "icon": "toolbar",
                            "value": 2
                        }, {
                            "displayName": Translation.tr("Dynamic Island"),
                            "icon": "water_drop",
                            "value": 3
                        }];
                        if (Config.options.bar.barBackgroundStyle === 3) {
                            opts[2].enabled = false;
                            opts[3].enabled = false;
                        }
                        return opts;
                    }
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Dynamic Island behavior")
                visible: Config.options.bar.cornerStyle === 3
                Layout.topMargin: 4
            }

            ConfigSwitch {
                buttonIcon: "auto_fix"
                text: Translation.tr("Auto spacing")
                visible: Config.options.bar.cornerStyle === 3
                checked: Config.options.bar.dynamicIslandLoadBalance
                onCheckedChanged: {
                    Config.options.bar.dynamicIslandLoadBalance = checked;
                }
            }

            ConfigSlider {
                buttonIcon: "space_bar"
                text: Translation.tr("Dynamic Island spacing")
                visible: Config.options.bar.cornerStyle === 3 && !Config.options.bar.dynamicIslandLoadBalance
                usePercentTooltip: false
                from: Config.options.bar.vertical ? 16 : 48
                to: Config.options.bar.vertical ? 100 : 250
                stepSize: 1
                value: Config.options.bar.vertical ? Config.options.bar.dynamicIslandSpacingVertical : Config.options.bar.dynamicIslandSpacingHorizontal
                onValueChanged: {
                    if (Config.options.bar.vertical)
                        Config.options.bar.dynamicIslandSpacingVertical = value;
                    else
                        Config.options.bar.dynamicIslandSpacingHorizontal = value;
                }
            }

            ContentSubsection {
                title: Translation.tr("Group style")
                icon: "group_work"
                tooltip: Translation.tr("Island style makes the group background opaque when bar is transparent")

                ConfigSelectionArray {
                    currentValue: Config.options.bar.barGroupStyle
                    onSelected: (newValue) => {
                        Config.options.bar.barGroupStyle = newValue;
                    }
                    options: [{
                        "displayName": Translation.tr("Pills"),
                        "icon": "location_chip",
                        "value": 0
                    }, {
                        "displayName": Translation.tr("Island"),
                        "icon": "shadow",
                        "value": 1
                    }, {
                        "displayName": Translation.tr("Transparent"),
                        "icon": "opacity",
                        "value": 2
                    }]
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Group color")
                visible: Config.options.bar.barGroupStyle !== 2
                Layout.topMargin: 4
            }

            ConfigSwitch {
                buttonIcon: "colorize"
                text: Translation.tr("Expressive group color")
                checked: Config.options.bar.expressiveGroupColor
                visible: Config.options.bar.barGroupStyle !== 2
                onCheckedChanged: {
                    Config.options.bar.expressiveGroupColor = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Use primary container color for pill/island group backgrounds")
                }
            }

            ContentSubsection {
                title: Translation.tr("Bar background style")
                icon: "format_paint"
                tooltip: Translation.tr("Adaptive style makes the bar background transparent when there are no active windows")

                // Locked when centerInBar: only Transparent(0) or Islands(3) allowed
                NoticeBox {
                    Layout.fillWidth: true
                    visible: ShellModePolicy.barPositionLocked
                    materialIcon: "lock"
                    text: Translation.tr("Bar background is locked to Transparent or Islands while 'Dynamic Island in bar center' is active. Visible and Adaptive options are unavailable.")
                }

                ConfigSelectionArray {
                    currentValue: Config.options.bar.barBackgroundStyle
                    onSelected: (newValue) => {
                        Config.options.bar.barBackgroundStyle = newValue;
                        if (newValue === 3 && (Config.options.bar.cornerStyle === 2 || Config.options.bar.cornerStyle === 3))
                            Config.options.bar.cornerStyle = 0;

                        if (newValue === 3) {
                            let centerList = Config.options.bar.layouts.center;
                            let hasCentered = centerList.some((item) => {
                                return item.centered;
                            });
                            if (hasCentered)
                                Config.options.bar.layouts.center = centerList.map((item) => {
                                return ({
                                    "id": item.id,
                                    "centered": false,
                                    "visible": item.visible
                                });
                            });
                        }
                    }
                    options: {
                        const locked = ShellModePolicy.barPositionLocked;
                        return [{
                            "displayName": Translation.tr("Visible"),
                            "icon": "visibility",
                            "value": 1,
                            "enabled": !locked
                        }, {
                            "displayName": Translation.tr("Adaptive"),
                            "icon": "masked_transitions",
                            "value": 2,
                            "enabled": !locked
                        }, {
                            "displayName": Translation.tr("Transparent"),
                            "icon": "opacity",
                            "value": 0
                        }, {
                            "displayName": Translation.tr("Islands"),
                            "icon": "grid_view",
                            "value": 3
                        }];
                    }
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Bar effects")
                Layout.topMargin: 4
            }

            ConfigSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Transparent bar blur/dim")
                checked: Config.options.bar.transparentGlow
                visible: Config.options.bar.barBackgroundStyle === 0
                onCheckedChanged: {
                    Config.options.bar.transparentGlow = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Adds a soft blur and dim gradient under the transparent bar")
                }
            }

            ConfigSwitch {
                buttonIcon: "format_color_fill"
                text: Translation.tr("Expressive bar solid colors")
                checked: Config.options.bar.expressiveColors
                onCheckedChanged: {
                    Config.options.bar.expressiveColors = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Use expressive solid layer colors")
                }
            }

            ConfigSwitch {
                buttonIcon: "filter_drama"
                text: Translation.tr("Bar drop-shadow")
                checked: Config.options.bar.dropShadow
                onCheckedChanged: {
                    Config.options.bar.dropShadow = checked;
                }

                StyledToolTip {
                    text: Translation.tr("Shows a soft drop shadow underneath the status bar")
                }
            }

            ContentSubsection {
                title: Translation.tr("Expressive color theme")
                icon: "palette"
                visible: Config.options.bar.expressiveColors

                ConfigSelectionArray {
                    currentValue: Config.options.bar.expressiveColorTheme
                    onSelected: (newValue) => {
                        Config.options.bar.expressiveColorTheme = newValue;
                    }
                    options: [{
                        "displayName": Translation.tr("Content"),
                        "icon": "brush",
                        "value": "content"
                    }, {
                        "displayName": Translation.tr("Vibrant"),
                        "icon": "brush",
                        "value": "primary"
                    }, {
                        "displayName": Translation.tr("Secondary"),
                        "icon": "brush",
                        "value": "secondary"
                    }, {
                        "displayName": Translation.tr("Surface"),
                        "icon": "brush",
                        "value": "surface"
                    }]
                }
            }

            ContentSubsection {
                title: Translation.tr("Fake screen rounding")
                icon: "fullscreen_exit"
                Layout.fillWidth: true

                // Locked when centerInBar: Wrapped(3)/Edge(4) break the visual
                NoticeBox {
                    Layout.fillWidth: true
                    visible: ShellModePolicy.barPositionLocked
                    materialIcon: "lock"
                    text: Translation.tr("Wrapped Frame and Edge modes are locked while 'Dynamic Island in bar center' is active. They would render floating above the island, causing visual conflicts.")
                }

                ConfigSelectionArray {
                    currentValue: Config.options.appearance.fakeScreenRounding
                    onSelected: (newValue) => {
                        Config.options.appearance.fakeScreenRounding = newValue;
                    }
                    options: {
                        const locked = ShellModePolicy.barPositionLocked;
                        return [{
                            "displayName": Translation.tr("No"),
                            "icon": "close",
                            "value": 0
                        }, {
                            "displayName": Translation.tr("Yes"),
                            "icon": "check",
                            "value": 1
                        }, {
                            "displayName": Translation.tr("When not fullscreen"),
                            "icon": "fullscreen_exit",
                            "value": 2
                        }, {
                            "displayName": Translation.tr("Wrapped"),
                            "icon": "capture",
                            "value": 3,
                            "enabled": !locked
                        }, {
                            "displayName": Translation.tr("Edge"),
                            "icon": "border_bottom",
                            "value": 4,
                            "enabled": !locked
                        }];
                    }
                }
            }

            ConfigSpinBox {
                visible: Config.options.appearance.fakeScreenRounding === 3
                icon: "line_weight"
                text: Translation.tr("Wrapped frame thickness")
                value: Config.options.appearance.wrappedFrameThickness
                from: 5
                to: 25
                stepSize: 1
                onValueChanged: {
                    Config.options.appearance.wrappedFrameThickness = value;
                }
            }

            ContentSubsectionLabel {
                text: Translation.tr("Top Left Brand Icon")
                Layout.topMargin: 4
            }

            ConfigSwitch {
                buttonIcon: "text_fields"
                text: Translation.tr("Use Material Symbol for top-left icon")
                checked: Config.options.bar.useMaterialSymbolForTopLeftIcon
                onCheckedChanged: {
                    Config.options.bar.useMaterialSymbolForTopLeftIcon = checked;
                }
            }

            ConfigTextField {
                id: topLeftIconField

                text: Translation.tr("Top-left icon identifier")
                icon: "image"
                tooltip: Translation.tr("If not using Material Symbol, enter a preset SVG name (e.g. arch, fedora) or a Material Symbol name if the switch above is on.")
                placeholderText: Translation.tr("Identifier...")
                Component.onCompleted: {
                    inputText = Config.options.bar.topLeftIcon;
                }
                textField.onTextChanged: {
                    var val = textField.text.trim();
                    if (val !== "" && textField.activeFocus)
                        Config.options.bar.topLeftIcon = val;
                }

                Connections {
                    function onTopLeftIconChanged() {
                        topLeftIconField.textField.text = Config.options.bar.topLeftIcon;
                    }

                    target: Config.options.bar
                }
            }
        }

        ProgressiveSectionLoader {
            source: Qt.resolvedUrl("sections/BarLayoutSection.qml")
            active: barConfigRoot.loadStage >= 1
            estimatedHeight: 620
            sectionTitle: Translation.tr("Layout")
            prioritizeOnViewport: true
            prioritizeOnSearch: true
            onLoaded: barConfigRoot.advanceStage(2)
        }

        ProgressiveSectionLoader {
            source: Qt.resolvedUrl("sections/BarBehaviorSection.qml")
            active: barConfigRoot.loadStage >= 2
            estimatedHeight: 270
            sectionTitle: Translation.tr("Behavior")
            prioritizeOnViewport: true
            prioritizeOnSearch: true
            onLoaded: barConfigRoot.advanceStage(3)
        }

        ProgressiveSectionLoader {
            source: Qt.resolvedUrl("sections/BarMonitorsSection.qml")
            active: barConfigRoot.loadStage >= 3
            estimatedHeight: 210
            sectionTitle: Translation.tr("Monitors")
            prioritizeOnViewport: true
            prioritizeOnSearch: true
        }

        // ── Widgets & Waffle Sub-Page ─────────────────────────────────────────
        ContentSection {
            icon: "widgets"
            title: Translation.tr("Widgets & Waffle")

            ServiceCard {
                cardIcon: "widgets"
                cardHue: 210
                cardShape: "circle"
                title: Translation.tr("Widgets & Waffle Settings")
                description: Translation.tr("Configure individual bar widgets and Waffle panel tweaks")
                onOpenCard: {
                    barConfigRoot.activeSubPage = Qt.resolvedUrl("widgets/BarWidgetsWaffleConfig.qml");
                }
            }
        }

    }

    // ── Sub-page overlay (slides in from the right) ───────────────────────
    ConfigSubPageHost {
        id: subPageOverlay

        anchors.fill: parent
        z: 10
    }

}
