import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    implicitWidth: parent ? parent.width : 400
    implicitHeight: mainLayout.implicitHeight + 28
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2

    readonly property var diag: NetworkDisplayService.diagnostics
    property bool isTesting: false
    property bool hasTested: false

    readonly property bool bridgeOk: NetworkDisplayService.bridgeAvailable
    readonly property bool backendOk: Boolean(diag && diag.backend && diag.backend.daemonBinary)
    readonly property bool portalOk: Boolean(diag && diag.portal && diag.portal.screenCast)
    readonly property bool pipewireOk: Boolean(diag && diag.pipewire && diag.pipewire.available)
    readonly property bool wifiP2pOk: Boolean(diag && diag.networkManager && diag.networkManager.p2pDevice)
    readonly property bool h264Ok: Boolean(diag && diag.codecs && diag.codecs.h264 && diag.codecs.h264.length > 0)
    readonly property bool aacOk: Boolean(diag && diag.codecs && diag.codecs.aac && diag.codecs.aac.length > 0)

    readonly property int totalChecks: 7
    readonly property int passedChecks: (bridgeOk ? 1 : 0) + (backendOk ? 1 : 0) + (portalOk ? 1 : 0) + (pipewireOk ? 1 : 0) + (wifiP2pOk ? 1 : 0) + (h264Ok ? 1 : 0) + (aacOk ? 1 : 0)
    readonly property int criticalErrors: (!bridgeOk ? 1 : 0) + (!backendOk ? 1 : 0) + (!portalOk ? 1 : 0) + (!pipewireOk ? 1 : 0) + (!h264Ok ? 1 : 0)

    Timer {
        id: testTimer
        interval: 1000
        repeat: false
        onTriggered: {
            root.isTesting = false;
            root.hasTested = true;
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShape {
                Layout.alignment: Qt.AlignVCenter
                implicitSize: 42
                shapeString: "Cookie9Sided"
                color: Appearance.colors.colPrimaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "network_check"
                    iconSize: 22
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Wireless Casting Capabilities")
                    font.weight: Font.Bold
                    font.pixelSize: Appearance.font.pixelSize.body
                    color: Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Status of backend daemon, portal streaming, media encoders and Rust bridge")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            RippleButtonWithIcon {
                Layout.alignment: Qt.AlignVCenter
                materialIcon: {
                    if (root.isTesting)
                        return "sync";
                    if (root.hasTested) {
                        return root.criticalErrors === 0 ? "check_circle" : "error";
                    }
                    return "refresh";
                }
                mainText: {
                    if (root.isTesting)
                        return Translation.tr("Testing…");
                    if (root.hasTested) {
                        return root.criticalErrors === 0
                            ? Translation.tr("All passed (%1/%2)").arg(String(root.passedChecks)).arg(String(root.totalChecks))
                            : Translation.tr("%1 issue(s) found").arg(String(root.criticalErrors));
                    }
                    return Translation.tr("Run diagnostics");
                }
                buttonRadius: Appearance.rounding.small
                colBackground: {
                    if (root.hasTested && root.criticalErrors === 0)
                        return Qt.alpha(Appearance.colors.colPrimary, 0.15);
                    if (root.hasTested && root.criticalErrors > 0)
                        return Qt.alpha(Appearance.m3colors.m3error, 0.15);
                    return Appearance.colors.colLayer3;
                }
                colBackgroundHover: Appearance.colors.colLayer3Hover
                colRipple: Appearance.colors.colLayer3Active
                onClicked: {
                    root.isTesting = true;
                    NetworkDisplayService.runDiagnostics();
                    testTimer.restart();
                }
            }
        }

        // Diagnostic Rows (compact, grouped with dynamic radius)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Rust Bridge Binary Status Row
            NetworkDisplayDiagnosticRow {
                Layout.fillWidth: true
                icon: "build"
                label: Translation.tr("Rust Helper Bridge (network_display_bridge)")
                detail: root.bridgeOk
                    ? Directories.networkDisplayBridgePath
                    : Translation.tr("Binary not found. Compile using cargo below.")
                ready: root.bridgeOk
                isFirst: true
            }

            NetworkDisplayDiagnosticRow {
                Layout.fillWidth: true
                icon: "dns"
                label: Translation.tr("GNOME Network Displays Backend")
                detail: (root.diag && root.diag.backend && root.diag.backend.daemonPath) ? root.diag.backend.daemonPath : Translation.tr("gnome-network-displays binary / flatpak")
                ready: root.backendOk
            }

            NetworkDisplayDiagnosticRow {
                Layout.fillWidth: true
                icon: "screen_share"
                label: Translation.tr("XDG ScreenCast Portal")
                detail: (root.diag && root.diag.portal && root.diag.portal.desktopPortal) ? Translation.tr("org.freedesktop.portal.ScreenCast active") : Translation.tr("Desktop portal not responding")
                ready: root.portalOk
            }

            NetworkDisplayDiagnosticRow {
                Layout.fillWidth: true
                icon: "volume_up"
                label: Translation.tr("PipeWire Audio/Video Server")
                detail: (root.diag && root.diag.pipewire && root.diag.pipewire.socketExists) ? Translation.tr("PipeWire socket active") : Translation.tr("PipeWire daemon status")
                ready: root.pipewireOk
            }

            NetworkDisplayDiagnosticRow {
                Layout.fillWidth: true
                icon: "wifi"
                label: Translation.tr("NetworkManager Wi-Fi Direct (P2P)")
                detail: (root.diag && root.diag.networkManager && root.diag.networkManager.p2pDevice) ? Translation.tr("Wi-Fi Direct P2P interface detected") : Translation.tr("P2P optional (Network casting & Chromecast still work)")
                ready: root.wifiP2pOk
                isWarning: !root.wifiP2pOk
            }

            NetworkDisplayDiagnosticRow {
                Layout.fillWidth: true
                icon: "movie"
                label: Translation.tr("H.264 Video Encoder")
                detail: (root.diag && root.diag.codecs && root.diag.codecs.h264 && root.diag.codecs.h264.length > 0) ? root.diag.codecs.h264.join(", ") : Translation.tr("No H.264 encoder found in GStreamer")
                ready: root.h264Ok
            }

            NetworkDisplayDiagnosticRow {
                Layout.fillWidth: true
                icon: "audiotrack"
                label: Translation.tr("AAC Audio Encoder")
                detail: (root.diag && root.diag.codecs && root.diag.codecs.aac && root.diag.codecs.aac.length > 0) ? root.diag.codecs.aac.join(", ") : Translation.tr("No AAC encoder found in GStreamer")
                ready: root.aacOk
                isWarning: !root.aacOk
                isLast: true
            }
        }

        // Action bar for binary management
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                visible: root.bridgeOk
                materialIcon: "delete"
                mainText: Translation.tr("Delete compiled binary")
                buttonRadius: Appearance.rounding.small
                colBackground: Qt.alpha(Appearance.m3colors.m3error, 0.14)
                colBackgroundHover: Qt.alpha(Appearance.m3colors.m3error, 0.24)
                colRipple: Qt.alpha(Appearance.m3colors.m3error, 0.35)
                onClicked: {
                    NetworkDisplayService.deleteBridge();
                }
            }

            RippleButtonWithIcon {
                visible: !root.bridgeOk
                materialIcon: "build"
                mainText: NetworkDisplayService.isCompiling ? Translation.tr("Compiling binary…") : Translation.tr("Compile binary")
                buttonRadius: Appearance.rounding.small
                colBackground: Qt.alpha(Appearance.colors.colPrimary, 0.15)
                colBackgroundHover: Qt.alpha(Appearance.colors.colPrimary, 0.25)
                colRipple: Qt.alpha(Appearance.colors.colPrimary, 0.35)
                onClicked: {
                    NetworkDisplayService.compileBridge();
                }
            }
        }
    }
}
