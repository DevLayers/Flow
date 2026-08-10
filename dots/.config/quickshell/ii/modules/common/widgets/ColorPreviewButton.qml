import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root
    readonly property string builtInThemeDirectory: Directories.defaultThemes
    readonly property string customThemeDirectory: Directories.customThemes

    property string colorScheme: "scheme-auto"
    property string colorSchemeDisplayName: ""

    property bool builtInTheme: false
    readonly property string builtInThemeFilePath: builtInThemeDirectory + "/" + colorScheme + ".json"
    readonly property string builtInThemeCommand: `jq -r '.primary, .primary_container, .secondary' ${builtInThemeFilePath}`

    property bool customTheme: false
    readonly property string customThemeFilePath: customThemeDirectory + "/" + colorScheme + ".json"
    readonly property string customThemeCommand: `jq -r '.primary, .primary_container, .secondary' ${customThemeFilePath}`

    readonly property string wallpaperPath: (Config.options && Config.options.background && Config.options.background.wallpaperPath) ? Config.options.background.wallpaperPath : ""
    readonly property string activeWallpaperPath: {
        if (Config.options && Config.options.background && Config.options.background.useWallpaperEngine) {
            return "/tmp/wpe_screenshot.png";
        }
        return wallpaperPath;
    }
    readonly property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/generate_colors_material.py`)

    readonly property string resolvedScheme: root.colorScheme === "scheme-auto" ? "scheme-tonal-spot" : root.colorScheme
    property string fullCommand: root.activeWallpaperPath !== "" ? `${root.scriptPath} --path ${root.activeWallpaperPath} --scheme ${root.resolvedScheme} --all-previews ${Directories.wallpaperPreviewColorsPath}` : ""

    // Primary/secondary/tertiary colors
    property color previewPrimary: "transparent"
    property color previewSecondary: "transparent"
    property color previewTertiary: "transparent"
    property bool usePreviewColors: false

    property color primaryColor: usePreviewColors ? previewPrimary : "transparent"
    property color secondaryColor: usePreviewColors ? previewSecondary : "transparent"
    property color tertiaryColor: usePreviewColors ? previewTertiary : "transparent"

    property bool loaded: usePreviewColors
    property bool shouldLoad: false

    property bool isWidgetScheme: false
    property bool widgetSchemeToggled: false
    readonly property bool toggled: isWidgetScheme ? widgetSchemeToggled : (
                                                         Config.options.appearance.palette.type
                                                         === root.colorScheme)
    readonly property bool sharpMode: Config.options.appearance.sharpMode

    colBackground: toggled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
    colBackgroundHover: toggled ? Appearance.colors.colPrimaryContainerHover :
                                  Appearance.colors.colLayer2Hover
    colRipple: toggled ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active

    buttonRadius: Appearance.rounding.small

    Layout.fillWidth: true
    implicitHeight: 64

    onClicked: {
        if (isWidgetScheme) {
            return;
        }
        if (customTheme) {
            Config.options.appearance.palette.type = root.colorScheme;
            const themePath = FileUtils.trimFileProtocol(root.customThemeFilePath);
            const targetPath = FileUtils.trimFileProtocol(Directories.generatedMaterialThemePath);
            const script = FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/recolor_icons.py`);
            Quickshell.execDetached(["bash", "-c", `cp "${themePath}" "${targetPath}" && python3 "${script}"`]);
        } else if (builtInTheme) {
            Config.options.appearance.palette.type = root.colorScheme;
            const themePath = FileUtils.trimFileProtocol(root.builtInThemeFilePath);
            const targetPath = FileUtils.trimFileProtocol(Directories.generatedMaterialThemePath);
            const script = FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/recolor_icons.py`);
            Quickshell.execDetached(["bash", "-c", `cp "${themePath}" "${targetPath}" && python3 "${script}"`]);
        } else {
            Config.options.appearance.palette.type = root.colorScheme;
            Quickshell.execDetached(["bash", "-c", `env -u LD_LIBRARY_PATH -u PYTHONHOME -u PYTHONPATH PATH=$HOME/.local/bin:$HOME/.cargo/bin:$PATH ${Directories.wallpaperSwitchScriptPath} --type ${root.colorScheme} --noswitch > /tmp/switchwall_button.log 2>&1`]);
        }
    }

    // Widget scheme buttons already receive all three preview colors from the
    // caller. Do not create a watcher/read cycle for the shared wallpaper
    // cache in that mode; doing so duplicated the same JSON parse per button.
    readonly property bool cacheIoEnabled: !root.usePreviewColors
                                          && !root.customTheme
                                          && !root.builtInTheme

    readonly property string themePreviewPath: root.customTheme ? root.customThemeFilePath
                                            : root.builtInTheme ? root.builtInThemeFilePath : ""

    function applyCachedPreview() {
        if (!root.cacheIoEnabled)
            return false;
        const schemeData = WallpaperPreviewCache.get(root.colorScheme);
        if (!schemeData)
            return false;
        root.primaryColor = schemeData.primary || "transparent";
        root.secondaryColor = schemeData.primary_container || "transparent";
        root.tertiaryColor = schemeData.secondary || "transparent";
        root.loaded = true;
        return true;
    }

    function applyThemePreview() {
        if (!root.themePreviewPath)
            return false;
        const themeData = ThemePreviewCache.get(root.themePreviewPath);
        if (!themeData)
            return false;
        root.primaryColor = themeData.primary || "transparent";
        root.secondaryColor = themeData.secondary || "transparent";
        root.tertiaryColor = themeData.tertiary || "transparent";
        root.loaded = true;
        return true;
    }

    Connections {
        target: WallpaperPreviewCache
        function onCacheChanged() {
            if (root.shouldLoad)
                root.applyCachedPreview();
        }
    }

    Connections {
        target: ThemePreviewCache
        function onCacheChanged(path) {
            if (root.shouldLoad && path === root.themePreviewPath)
                root.applyThemePreview();
        }
    }

    function requestLoad() {
        if (root.usePreviewColors)
            return;

        if (root.customTheme || root.builtInTheme) {
            if (!root.applyThemePreview())
                ThemePreviewCache.request(root.themePreviewPath);
            return;
        }

        WallpaperPreviewCache.ensureActive();
        if (root.applyCachedPreview()) {
            return;
        }

        if (root.fullCommand !== "") {
            WallpaperPreviewCache.requestGeneration(root.fullCommand, root.colorScheme);
        }
    }

    onShouldLoadChanged: {
        if (shouldLoad && !loaded) {
            root.requestLoad();
        }
    }

    onWallpaperPathChanged: {
        if (shouldLoad && root.cacheIoEnabled) {
            root.loaded = false;
            WallpaperPreviewCache.invalidateForWallpaperChange();
        }
    }

    readonly property string wpeId: (Config.options && Config.options.background)
                                    ? Config.options.background.wallpaperEngineId : ""
    onWpeIdChanged: {
        if (shouldLoad && root.cacheIoEnabled) {
            root.loaded = false;
            WallpaperPreviewCache.invalidateForWallpaperChange();
        }
    }

    property bool useWpe: (Config.options && Config.options.background)
                          ? Config.options.background.useWallpaperEngine : false
    onUseWpeChanged: {
        if (shouldLoad && root.cacheIoEnabled) {
            root.loaded = false;
            WallpaperPreviewCache.invalidateForWallpaperChange();
        }
    }

    StyledToolTip {
        text: root.colorSchemeDisplayName
    }

    Item {
        anchors.fill: parent

        StyledText {
            anchors.fill: parent
            visible: !root.loaded
            elide: Text.ElideRight
            text: root.colorSchemeDisplayName
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colOnPrimaryContainer
            font.pixelSize: Appearance.font.pixelSize.small
        }

        Item {
            id: colorCircleContainer
            anchors.centerIn: parent
            width: root.implicitHeight - 16
            height: root.implicitHeight - 16
            visible: root.loaded

            // Sharp mode (Square)
            Item {
                anchors.fill: parent
                visible: root.sharpMode

                // Top half: primaryColor
                Rectangle {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: parent.height / 2
                    color: root.primaryColor
                }

                // Bottom-left quadrant: tertiaryColor
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                    }
                    width: parent.width / 2
                    height: parent.height / 2
                    color: root.tertiaryColor
                }

                // Bottom-right quadrant: secondaryColor
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                    }
                    width: parent.width / 2
                    height: parent.height / 2
                    color: root.secondaryColor
                }
            }

            // Circle mode (GPU-accelerated Shape with anti-aliased arcs)
                Shape {
                id: circleShape
                anchors.fill: parent
                visible: !root.sharpMode
                layer.enabled: root.loaded && !root.sharpMode
                layer.samples: 4

                // Top half semi-circle (primary)
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.primaryColor
                    startX: circleShape.width / 2
                    startY: circleShape.height / 2
                    PathAngleArc {
                        centerX: circleShape.width / 2
                        centerY: circleShape.height / 2
                        radiusX: circleShape.width / 2
                        radiusY: circleShape.height / 2
                        startAngle: 180
                        sweepAngle: 180
                    }
                    PathLine {
                        x: circleShape.width / 2
                        y: circleShape.height / 2
                    }
                }

                // Bottom-right quarter circle (secondary)
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.secondaryColor
                    startX: circleShape.width / 2
                    startY: circleShape.height / 2
                    PathAngleArc {
                        centerX: circleShape.width / 2
                        centerY: circleShape.height / 2
                        radiusX: circleShape.width / 2
                        radiusY: circleShape.height / 2
                        startAngle: 0
                        sweepAngle: 90
                    }
                    PathLine {
                        x: circleShape.width / 2
                        y: circleShape.height / 2
                    }
                }

                // Bottom-left quarter circle (tertiary)
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.tertiaryColor
                    startX: circleShape.width / 2
                    startY: circleShape.height / 2
                    PathAngleArc {
                        centerX: circleShape.width / 2
                        centerY: circleShape.height / 2
                        radiusX: circleShape.width / 2
                        radiusY: circleShape.height / 2
                        startAngle: 90
                        sweepAngle: 90
                    }
                    PathLine {
                        x: circleShape.width / 2
                        y: circleShape.height / 2
                    }
                }
            }
        }
    }
}
