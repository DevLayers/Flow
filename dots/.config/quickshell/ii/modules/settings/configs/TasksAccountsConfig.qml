import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.usage

Item {
    id: root

    property alias contentY: page.contentY
    property alias activeSubPage: subPageOverlay.activeSubPage


    // Temp state before saving
    property string tempClientId: ""
    property string tempClientSecret: ""
    property string tempAccessToken: ""
    
    // Auth process state
    property bool authRunning: false
    property string authErrorMsg: ""
    property string driveUiError: ""
    property string excludePatternDraft: ""
    property string excludePatternError: ""
    property int activityGranularityIndex: 0
    property int activityMetricIndex: 0

    readonly property var driveOptions: Config.options.googleDrive
    readonly property list<var> activityGranularities: [
        { key: "day", value: "day", displayName: Translation.tr("Day"), icon: "today" },
        { key: "week", value: "week", displayName: Translation.tr("Week"), icon: "date_range" },
        { key: "month", value: "month", displayName: Translation.tr("Month"), icon: "calendar_month" }
    ]
    readonly property list<var> activityMetrics: [
        { key: "data", value: "data", displayName: Translation.tr("Data transferred"), icon: "data_usage" },
        { key: "transfers", value: "transfers", displayName: Translation.tr("Backups completed"), icon: "cloud_done" }
    ]
    readonly property string activityGranularity: root.activityGranularities[root.activityGranularityIndex].key
    readonly property list<var> activityBuckets: root.buildActivityBuckets(root.activityGranularity)
    readonly property list<real> activityDataValues: root.activityBuckets.map(bucket => bucket.dataMb)
    readonly property list<real> activityTransferValues: root.activityBuckets.map(bucket => bucket.runs)
    readonly property list<string> activityLabels: root.activityBuckets.map(bucket => bucket.label)
    readonly property list<string> activityTooltipLabels: root.activityBuckets.map(bucket => bucket.tooltip)
    readonly property list<var> activityTableRows: root.activityBuckets
        .filter(bucket => bucket.runs > 0 || bucket.files > 0 || bucket.dataMb > 0 || bucket.errors > 0)
        .slice()
        .reverse()
    readonly property real activitySelectedTotal: {
        const values = root.activityMetricIndex === 0 ? root.activityDataValues : root.activityTransferValues;
        return values.reduce((total, value) => total + Number(value || 0), 0);
    }
    readonly property string activityWindowLabel: root.activityGranularity === "day"
        ? Translation.tr("Last 7 days")
        : root.activityGranularity === "week"
            ? Translation.tr("Last 8 weeks")
            : Translation.tr("Last 12 months")
    readonly property bool hasActivity: {
        const entries = GoogleDriveService.syncHistory || [];
        for (const entry of entries) {
            if (entry && entry.time)
                return true;
        }
        return false;
    }
    readonly property int activityFilesTotal: root.activityBuckets.reduce((total, bucket) => total + Number(bucket.files || 0), 0)
    readonly property int activityErrors: root.activityBuckets.reduce((total, bucket) => total + Number(bucket.errors || 0), 0)

    function rcloneInstallFamilyFor(value: string): string {
        const distro = String(value || "").toLowerCase();
        if (["fedora", "rhel", "centos", "rocky", "almalinux"].indexOf(distro) >= 0)
            return "Fedora / RHEL";
        if (["arch", "artix", "manjaro", "endeavouros", "cachyos"].indexOf(distro) >= 0)
            return "Arch Linux";
        if (["debian", "ubuntu", "linuxmint", "pop", "popos", "zorin", "elementary", "kali", "raspbian"].indexOf(distro) >= 0)
            return "Debian / Ubuntu";
        if (distro === "nixos")
            return "NixOS";
        if (["opensuse", "opensuse-leap", "opensuse-tumbleweed", "sles"].indexOf(distro) >= 0)
            return "openSUSE";
        if (distro === "alpine")
            return "Alpine Linux";
        if (["gentoo", "funtoo"].indexOf(distro) >= 0)
            return "Gentoo";
        if (distro === "void")
            return "Void Linux";
        if (distro === "solus")
            return "Solus";
        return SystemInfo.distroName && SystemInfo.distroName !== "Unknown"
            ? SystemInfo.distroName
            : "Linux";
    }

    function rcloneInstallCommandFor(value: string): string {
        const distro = String(value || "").toLowerCase();
        if (["fedora", "rhel", "centos", "rocky", "almalinux"].indexOf(distro) >= 0)
            return "sudo dnf install -y rclone";
        if (["arch", "artix", "manjaro", "endeavouros", "cachyos"].indexOf(distro) >= 0)
            return "sudo pacman -S --needed rclone";
        if (["debian", "ubuntu", "linuxmint", "pop", "popos", "zorin", "elementary", "kali", "raspbian"].indexOf(distro) >= 0)
            return "sudo apt update && sudo apt install -y rclone";
        if (distro === "nixos")
            return "nix profile install nixpkgs#rclone";
        if (["opensuse", "opensuse-leap", "opensuse-tumbleweed", "sles"].indexOf(distro) >= 0)
            return "sudo zypper install rclone";
        if (distro === "alpine")
            return "sudo apk add rclone";
        if (["gentoo", "funtoo"].indexOf(distro) >= 0)
            return "sudo emerge --ask app-portage/rclone";
        if (distro === "void")
            return "sudo xbps-install -S rclone";
        if (distro === "solus")
            return "sudo eopkg install rclone";
        return "curl https://rclone.org/install.sh | sudo bash";
    }

    readonly property string rcloneInstallFamily: root.rcloneInstallFamilyFor(SystemInfo.distroId)
    readonly property string rcloneInstallCommand: root.rcloneInstallCommandFor(SystemInfo.distroId)

    function updateDriveList(key: string, transform): void {
        const current = (driveOptions[key] || []).slice();
        transform(current);
        driveOptions[key] = current;
    }

    function addBackupFolder(path: string): void {
        const cleanPath = String(path || "").trim();
        if (!cleanPath || driveOptions.backupFolders.indexOf(cleanPath) >= 0)
            return;
        root.updateDriveList("backupFolders", values => values.push(cleanPath));
    }

    function removeBackupFolder(index: int): void {
        root.updateDriveList("backupFolders", values => values.splice(index, 1));
    }

    function removeExcludePattern(index: int): void {
        root.updateDriveList("excludePatterns", values => values.splice(index, 1));
    }

    function addExcludePattern(pattern: string): void {
        const cleanPattern = String(pattern || "").trim();
        root.excludePatternError = "";
        if (!cleanPattern) {
            root.excludePatternError = Translation.tr("Enter a pattern before adding it.");
            return;
        }
        if (cleanPattern.length > 256 || /[\r\n]/.test(cleanPattern) || cleanPattern.startsWith("--")) {
            root.excludePatternError = Translation.tr("Use one rclone glob pattern (up to 256 characters) without line breaks.");
            return;
        }
        if (driveOptions.excludePatterns.indexOf(cleanPattern) >= 0) {
            root.excludePatternError = Translation.tr("That pattern is already excluded.");
            return;
        }
        root.updateDriveList("excludePatterns", values => values.push(cleanPattern));
        root.excludePatternDraft = "";
    }

    function dateKey(date): string {
        return String(date.getFullYear()) + "-"
            + String(date.getMonth() + 1).padStart(2, "0") + "-"
            + String(date.getDate()).padStart(2, "0");
    }

    function activityBucketKey(value: string, granularity: string): string {
        const date = new Date(value || "");
        if (!isFinite(date.getTime()))
            return "";
        if (granularity === "month")
            return String(date.getFullYear()) + "-" + String(date.getMonth() + 1).padStart(2, "0");
        if (granularity === "week") {
            const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate());
            const offset = (monday.getDay() + 6) % 7;
            monday.setDate(monday.getDate() - offset);
            return root.dateKey(monday);
        }
        return root.dateKey(date);
    }

    function activityBucketLabel(key: string, granularity: string): string {
        if (granularity === "month") {
            const parts = key.split("-");
            return parts[1] + "/" + parts[0];
        }
        const parts = key.split("-");
        return parts[2] + "/" + parts[1];
    }

    function activityBucketTooltip(date, granularity: string): string {
        if (granularity === "month")
            return date.toLocaleDateString(Qt.locale(), "MMMM yyyy");
        if (granularity === "week") {
            const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 6);
            return date.toLocaleDateString(Qt.locale(), "dd MMM")
                + " – " + end.toLocaleDateString(Qt.locale(), "dd MMM yyyy");
        }
        return date.toLocaleDateString(Qt.locale(), "dd MMM yyyy");
    }

    function buildActivityBuckets(granularity: string): list<var> {
        const grouped = ({ });
        const orderedKeys = [];
        const now = new Date();
        const bucketCount = granularity === "day" ? 7 : granularity === "week" ? 8 : 12;

        for (let offset = bucketCount - 1; offset >= 0; --offset) {
            let bucketDate;
            if (granularity === "month") {
                bucketDate = new Date(now.getFullYear(), now.getMonth() - offset, 1, 12);
            } else if (granularity === "week") {
                bucketDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12);
                const weekdayOffset = (bucketDate.getDay() + 6) % 7;
                bucketDate.setDate(bucketDate.getDate() - weekdayOffset - offset * 7);
            } else {
                bucketDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - offset, 12);
            }

            const key = root.activityBucketKey(bucketDate.toISOString(), granularity);
            orderedKeys.push(key);
            grouped[key] = {
                key: key,
                runs: 0,
                files: 0,
                dataMb: 0,
                errors: 0,
                label: root.activityBucketLabel(key, granularity),
                tooltip: root.activityBucketTooltip(bucketDate, granularity)
            };
        }

        const entries = GoogleDriveService.syncHistory || [];
        for (const entry of entries) {
            if (!entry || !entry.time)
                continue;
            const key = root.activityBucketKey(String(entry.time), granularity);
            if (!key)
                continue;
            if (!grouped[key])
                continue;
            const bucket = grouped[key];
            bucket.runs += Math.max(1, Number(entry.transferCount || 1));
            bucket.files += Math.max(0, Number(entry.fileCount || 0));
            bucket.dataMb += Math.max(0, Number(entry.sizeMb || 0));
            if (entry.status === "error")
                bucket.errors += 1;
        }
        return orderedKeys.map(key => grouped[key]);
    }

    function formatMegabytes(value: real): string {
        const amount = Number(value || 0);
        if (amount >= 1024)
            return (amount / 1024).toFixed(1) + " GB";
        return amount.toFixed(1) + " MB";
    }

    function formatTransferSize(value: real): string {
        const bytes = Math.max(0, Number(value || 0));
        if (bytes < 1024)
            return Math.round(bytes) + " B";
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KiB";
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MiB";
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GiB";
    }

    function syncProgressSummary(): string {
        const details = [];
        if (GoogleDriveService.currentFolderTotalFiles > 0)
            details.push(String(GoogleDriveService.currentFolderFiles) + " / " + String(GoogleDriveService.currentFolderTotalFiles) + " files");
        if (GoogleDriveService.currentFolderTotalBytes > 0)
            details.push(root.formatTransferSize(GoogleDriveService.currentFolderBytes) + " / " + root.formatTransferSize(GoogleDriveService.currentFolderTotalBytes));
        if (details.length === 0)
            return Translation.tr("Preparing transfer…");
        return details.join(" · ");
    }

    function lastSyncSummary(): string {
        if (GoogleDriveService.syncing)
            return Translation.tr("Sync in progress…");
        if (driveOptions.lastSyncStatus === "running")
            return Translation.tr("Previous sync interrupted · run again");
        if (driveOptions.lastSyncStatus === "success"
                && Number(driveOptions.lastSyncFileCount || 0) === 0
                && Number(driveOptions.lastSyncSizeMb || 0) === 0)
            return Translation.tr("Last sync: Up to date · no new files");
        return Translation.tr("Last sync: %1 · %2 files · %3")
            .arg(root.relativeTime(driveOptions.lastSyncTime))
            .arg(String(driveOptions.lastSyncFileCount || 0))
            .arg(root.formatMegabytes(driveOptions.lastSyncSizeMb));
    }

    function formatDuration(seconds: int): string {
        const elapsed = Math.max(0, Number(seconds || 0));
        const minutes = Math.floor(elapsed / 60);
        const remainingSeconds = elapsed % 60;
        return String(minutes).padStart(2, "0") + ":" + String(remainingSeconds).padStart(2, "0");
    }

    function relativeTime(value: string): string {
        if (!value)
            return Translation.tr("Never");
        const timestamp = new Date(value).getTime();
        if (!isFinite(timestamp))
            return Translation.tr("Never");
        const elapsed = Math.max(0, Date.now() - timestamp);
        if (elapsed < 60000)
            return Translation.tr("Just now");
        if (elapsed < 3600000)
            return Math.floor(elapsed / 60000) + "m ago";
        if (elapsed < 86400000)
            return Math.floor(elapsed / 3600000) + "h ago";
        return Math.floor(elapsed / 86400000) + "d ago";
    }

    function openFolderPicker(): void {
        root.driveUiError = "";
        folderPickerProc.running = false;
        folderPickerProc.running = true;
    }

    Component.onCompleted: {
        loadTempData();
    }

    function loadTempData() {
        tempClientId = TickTickService.clientId;
        tempClientSecret = TickTickService.clientSecret;
        tempAccessToken = TickTickService.accessToken;
    }


    ContentPage {
        id: page

        anchors.fill: parent
        forceWidth: false
        opacity: subPageOverlay.slideProgress
        visible: opacity > 0

    WarningBox {
        Layout.fillWidth: true
        visible: authErrorMsg !== ""
        text: authErrorMsg
    }

    ContentSection {
        icon: "cloud_sync"
        title: Translation.tr("TickTick Credentials")

        HelperLinkBox {
            Layout.fillWidth: true
            title: Translation.tr("TickTick Developer Center")
            text: Translation.tr("Register your application to get Client ID and Client Secret.")
            isFirst: true

            RippleButtonWithIcon {
                mainText: Translation.tr("Open Website")
                materialIcon: "open_in_new"
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                colBackground: Appearance.colors.colLayer0
                colBackgroundHover: Appearance.colors.colLayer0Hover
                colRipple: Appearance.colors.colLayer0Active
                downAction: () => {
                    Qt.openUrlExternally("https://developer.ticktick.com/manage")
                }
            }
        }

        ConfigTextField {
            text: Translation.tr("Client ID")
            icon: "key"
            placeholderText: Translation.tr("Enter your TickTick Client ID")
            inputText: root.tempClientId
            textField.onTextChanged: root.tempClientId = textField.text.trim()
        }

        ConfigTextField {
            text: Translation.tr("Client Secret")
            icon: "vpn_key"
            placeholderText: Translation.tr("Enter your TickTick Client Secret")
            inputText: root.tempClientSecret
            textField.echoMode: TextInput.Password
            textField.onTextChanged: root.tempClientSecret = textField.text.trim()
        }

        ConfigTextField {
            text: Translation.tr("Access Token")
            icon: "token"
            placeholderText: Translation.tr("Enter or generate an Access Token")
            inputText: root.tempAccessToken
            textField.echoMode: TextInput.Password
            textField.onTextChanged: root.tempAccessToken = textField.text.trim()
        }
    }

    ContentSection {
        icon: "sync_saved_locally"
        title: Translation.tr("Actions")

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 48
                buttonRadius: Appearance.rounding.normal
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                enabled: !root.authRunning && root.tempClientId.length > 0 && root.tempClientSecret.length > 0

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    MaterialSymbol {
                        id: authIcon
                        text: "vpn_key"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnPrimaryContainer

                        RotationAnimation on rotation {
                            running: root.authRunning
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }
                    StyledText {
                        text: root.authRunning ? Translation.tr("Authorizing in browser...") : Translation.tr("Authorize & Generate Token")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.bold: true
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                onClicked: {
                    root.authRunning = true;
                    root.authErrorMsg = "";
                    authTokenProc.command = ["python3", Quickshell.shellPath("scripts/ticktick/get_token.py"), root.tempClientId, root.tempClientSecret];
                    authTokenProc.running = false;
                    authTokenProc.running = true;
                }
            }

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 48
                buttonRadius: Appearance.rounding.normal
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    MaterialSymbol {
                        text: "save"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: Translation.tr("Save Credentials")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.bold: true
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }

                onClicked: {
                    saveCredentials();
                }
            }
        }
    }

    function saveCredentials() {
        // Save to Gnome Keyring via KeyringStorage
        KeyringStorage.setNestedField(["apiKeys", "ticktick_client_id"], root.tempClientId);
        KeyringStorage.setNestedField(["apiKeys", "ticktick_client_secret"], root.tempClientSecret);
        KeyringStorage.setNestedField(["apiKeys", "ticktick_access_token"], root.tempAccessToken);

        // Backup to .env
        backupEnvProc.command = ["python3", Quickshell.shellPath("scripts/ticktick/backup_env.py"), root.tempClientId, root.tempClientSecret, root.tempAccessToken];
        backupEnvProc.running = false;
        backupEnvProc.running = true;

        // Apply changes immediately to the service
        TickTickService.clientId = root.tempClientId;
        TickTickService.clientSecret = root.tempClientSecret;
        TickTickService.accessToken = root.tempAccessToken;
        TickTickService.refresh();

        console.log("[TickTickConfig] Credentials saved and applied.");
    }

    Process {
        id: authTokenProc
        stdout: StdioCollector {
            onStreamFinished: {
                let token = text.trim();
                if (token.length > 0 && !token.startsWith("ERROR")) {
                    root.tempAccessToken = token;
                    root.authRunning = false;
                    // Auto save credentials after successful authorization
                    Qt.callLater(() => {
                        saveCredentials();
                    });
                } else {
                    root.authErrorMsg = Translation.tr("Failed to get token: ") + token;
                    root.authRunning = false;
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.authRunning = false;
                if (root.authErrorMsg === "") {
                    root.authErrorMsg = Translation.tr("Authorization process exited with code ") + code;
                }
            }
        }
    }

    Process {
        id: backupEnvProc
    }

    NoticeBox {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        topLeftRadius: Appearance.rounding.large
        topRightRadius: Appearance.rounding.large
        bottomLeftRadius: Appearance.rounding.large
        bottomRightRadius: Appearance.rounding.large
        text: Translation.tr("Gmail credentials are set in ii/.env. Sports (ESPN) options live in the Sports bar widget page.")
    }

    WarningBox {
        Layout.fillWidth: true
        Layout.topMargin: 8
        topLeftRadius: Appearance.rounding.large
        topRightRadius: Appearance.rounding.large
        bottomLeftRadius: Appearance.rounding.large
        bottomRightRadius: Appearance.rounding.large
        visible: root.driveUiError !== "" || GoogleDriveService.errorMessage !== "" || GoogleDriveService.warningMessage !== ""
        text: root.driveUiError !== ""
            ? root.driveUiError
            : GoogleDriveService.errorMessage !== ""
                ? GoogleDriveService.errorMessage
                : GoogleDriveService.warningMessage
    }

    HelperCodeBox {
        Layout.fillWidth: true
        Layout.topMargin: 8
        visible: !GoogleDriveService.checking && !GoogleDriveService.rcloneInstalled
        topLeftRadius: Appearance.rounding.large
        topRightRadius: Appearance.rounding.large
        bottomLeftRadius: Appearance.rounding.large
        bottomRightRadius: Appearance.rounding.large
        icon: "terminal"
        title: Translation.tr("Install rclone · %1").arg(root.rcloneInstallFamily)
        text: Translation.tr("rclone is required for Google Drive backups. Copy the command for your system, run it in a terminal, then return here to authorize Google Drive.")
        codeSnippet: root.rcloneInstallCommand
        snippetWrapMode: Text.Wrap
    }

    // ── Google Drive — status hero ──────────────────────────────────────────
    ContentSection {
        Layout.fillWidth: true
        icon: "cloud_sync"
        title: Translation.tr("Google Drive Backup")

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: heroLayout.implicitHeight + 32
            radius: Appearance.rounding.large
            color: Appearance.colors.colSecondaryContainer

            ColumnLayout {
                id: heroLayout
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 52
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colPrimary

                        Image {
                            anchors.centerIn: parent
                            width: 34
                            height: 34
                            source: "file://" + Quickshell.shellPath("assets/icons/google_drive.png")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Google Drive Backup")
                            color: Appearance.colors.colOnSecondaryContainer
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.bold: true
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.lastSyncSummary()
                            color: Appearance.colors.colOnSecondaryContainer
                            opacity: 0.82
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: statusText.implicitWidth + 24
                        implicitHeight: statusText.implicitHeight + 12
                        radius: Appearance.rounding.full
                        color: GoogleDriveService.errorMessage !== ""
                            ? Appearance.colors.colErrorContainer
                            : GoogleDriveService.syncing
                                ? Appearance.colors.colPrimaryContainer
                                : GoogleDriveService.configured
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colTertiaryContainer

                        StyledText {
                            id: statusText
                            anchors.centerIn: parent
                            text: GoogleDriveService.errorMessage !== ""
                                ? Translation.tr("Action required")
                                : GoogleDriveService.syncing
                                    ? Translation.tr("Syncing")
                                    : GoogleDriveService.configured
                                        ? Translation.tr("Connected")
                                        : Translation.tr("Setup required")
                            color: GoogleDriveService.errorMessage !== ""
                                ? Appearance.colors.colOnErrorContainer
                                : GoogleDriveService.syncing
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : GoogleDriveService.configured
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colOnTertiaryContainer
                            font.bold: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    StyledProgressBar {
                        Layout.fillWidth: true
                        valueBarHeight: 8
                        value: GoogleDriveService.driveQuotaMb > 0
                            ? GoogleDriveService.driveUsedMb / GoogleDriveService.driveQuotaMb
                            : 0
                        highlightColor: Appearance.colors.colPrimary
                        trackColor: Appearance.colors.colLayer3
                    }

                    StyledText {
                        text: GoogleDriveService.driveQuotaMb > 0
                            ? root.formatMegabytes(GoogleDriveService.driveUsedMb) + " / " + root.formatMegabytes(GoogleDriveService.driveQuotaMb)
                            : GoogleDriveService.driveBackupUsageMb > 0
                                ? Translation.tr("Backup: %1").arg(root.formatMegabytes(GoogleDriveService.driveBackupUsageMb))
                                : Translation.tr("Drive usage unavailable")
                        color: Appearance.colors.colOnSecondaryContainer
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: GoogleDriveService.syncing
                    implicitHeight: syncProgressLayout.implicitHeight + 24
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    ColumnLayout {
                        id: syncProgressLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            MaterialShapeWrappedMaterialSymbol {
                                text: "sync"
                                iconSize: Appearance.font.pixelSize.large
                                padding: 8
                                color: Appearance.colors.colPrimaryContainer
                                colSymbol: Appearance.colors.colOnPrimaryContainer
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: GoogleDriveService.finalizing
                                        ? Translation.tr("Finalizing backup")
                                        : GoogleDriveService.currentFolder !== ""
                                            ? Translation.tr("Backing up %1").arg(GoogleDriveService.currentFolder)
                                            : Translation.tr("Preparing backup…")
                                    color: Appearance.colors.colOnLayer1
                                    font.bold: true
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: GoogleDriveService.finalizing
                                        ? GoogleDriveService.statsLine
                                        : GoogleDriveService.currentFile !== ""
                                            ? GoogleDriveService.currentFile
                                            : GoogleDriveService.statsLine !== ""
                                                ? GoogleDriveService.statsLine
                                                : Translation.tr("Scanning folders…")
                                    color: Appearance.colors.colOnLayer2
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                }
                            }

                            StyledText {
                                text: GoogleDriveService.progress > 0
                                    ? Math.round(GoogleDriveService.progress * 100) + "%"
                                    : "—"
                                color: Appearance.colors.colOnLayer1
                                font.bold: true
                            }
                        }

                        StyledProgressBar {
                            Layout.fillWidth: true
                            valueBarHeight: 8
                            value: GoogleDriveService.progress > 0 ? GoogleDriveService.progress : 0.04
                            wavy: GoogleDriveService.progress <= 0
                            highlightColor: Appearance.colors.colPrimary
                            trackColor: Appearance.colors.colLayer3
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: root.syncProgressSummary()
                                color: Appearance.colors.colOnLayer2
                            }

                            StyledText {
                                text: root.formatDuration(GoogleDriveService.syncElapsedSeconds)
                                color: Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        implicitHeight: 54
                        buttonRadius: Appearance.rounding.large
                        mainText: GoogleDriveService.syncing ? Translation.tr("Syncing…") : Translation.tr("Sync now")
                        materialIcon: GoogleDriveService.syncing ? "sync" : "cloud_upload"
                        colText: Appearance.colors.colOnPrimary
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colRipple: Appearance.colors.colPrimaryActive
                        enabled: GoogleDriveService.configured
                        onClicked: GoogleDriveService.syncing ? GoogleDriveService.cancelSync() : GoogleDriveService.startSync()

                        StyledToolTip {
                            text: GoogleDriveService.syncing ? Translation.tr("Cancel sync") : Translation.tr("Sync now")
                        }
                    }

                    RippleButtonWithIcon {
                        id: heroRefreshButton
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 54
                        implicitWidth: 54
                        implicitHeight: 54
                        buttonRadius: Appearance.rounding.full
                        mainText: ""
                        materialIcon: "refresh"
                        colText: Appearance.colors.colOnSecondaryContainer
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        enabled: GoogleDriveService.configured && !GoogleDriveService.setupRunning
                        onClicked: GoogleDriveService.fetchDriveInfo()

                        StyledToolTip {
                            text: Translation.tr("Refresh Drive usage")
                        }
                    }
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "cloud_done"
            text: Translation.tr("Enable Google Drive backups")
            checked: driveOptions.enabled
            onCheckedChanged: {
                if (checked !== driveOptions.enabled)
                    driveOptions.enabled = checked;
            }
        }
    }

    // ── Google Drive — authorization ────────────────────────────────────────
    ContentSection {
        Layout.fillWidth: true
        icon: "vpn_key"
        title: Translation.tr("Google Drive Authorization")

        HelperLinkBox {
            Layout.fillWidth: true
            title: Translation.tr("Google Cloud Console")
            text: Translation.tr("Enable the Google Drive API in the same Google Cloud project used by Gmail.")

            RippleButtonWithIcon {
                Layout.preferredHeight: 44
                implicitHeight: 44
                buttonRadius: Appearance.rounding.large
                mainText: Translation.tr("Open Console")
                materialIcon: "open_in_new"
                colText: Appearance.colors.colOnSecondaryContainer
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: Qt.openUrlExternally("https://console.cloud.google.com/apis/library/drive.googleapis.com")
            }
        }

        NoticeBox {
            Layout.fillWidth: true
            materialIcon: "security"
            text: Translation.tr("OAuth uses the existing Gmail client credentials from ii/.env. The access token is stored by rclone in its normal user configuration.")
        }
    }

    // This is a page-level action, intentionally kept outside the authorization section.
    RippleButtonWithIcon {
        Layout.fillWidth: true
        Layout.preferredHeight: 54
        implicitHeight: 54
        buttonRadius: Appearance.rounding.large
        mainText: GoogleDriveService.checking
            ? Translation.tr("Checking rclone…")
            : GoogleDriveService.setupRunning
                ? Translation.tr("Opening browser…")
                : GoogleDriveService.configured
                    ? Translation.tr("Re-authorize Google Drive")
                    : Translation.tr("Authorize Google Drive")
        materialIcon: GoogleDriveService.checking || GoogleDriveService.setupRunning ? "sync" : "vpn_key"
        colText: GoogleDriveService.configured ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimary
        colBackground: GoogleDriveService.configured ? Appearance.colors.colErrorContainer : Appearance.colors.colPrimary
        colBackgroundHover: GoogleDriveService.configured ? Appearance.colors.colErrorContainerHover : Appearance.colors.colPrimaryHover
        colRipple: GoogleDriveService.configured ? Appearance.colors.colErrorContainerActive : Appearance.colors.colPrimaryActive
        enabled: !GoogleDriveService.checking && !GoogleDriveService.setupRunning && !GoogleDriveService.setupPendingCheck
        onClicked: GoogleDriveService.setupRclone()
    }

    // ── Google Drive — activity ─────────────────────────────────────────────
    ContentSection {
        Layout.fillWidth: true
        icon: "monitoring"
        title: Translation.tr("Sync Activity")

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Backup trends")
                    color: Appearance.colors.colOnLayer1
                    font.bold: true
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Transfers grouped by calendar period")
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }
            }

            ConfigSelectionArray {
                Layout.alignment: Qt.AlignVCenter
                currentValue: root.activityGranularity
                options: root.activityGranularities
                onSelected: value => {
                    const index = root.activityGranularities.findIndex(option => option.key === value);
                    if (index >= 0)
                        root.activityGranularityIndex = index;
                }
            }

            ConfigSelectionArray {
                Layout.alignment: Qt.AlignVCenter
                currentValue: root.activityMetrics[root.activityMetricIndex].value
                options: root.activityMetrics
                onSelected: value => {
                    const index = root.activityMetrics.findIndex(option => option.key === value);
                    if (index >= 0)
                        root.activityMetricIndex = index;
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: root.hasActivity ? 258 : 156
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1

            PagePlaceholder {
                anchors.fill: parent
                anchors.margins: 8
                visible: !root.hasActivity
                shown: visible
                icon: "monitoring"
                title: Translation.tr("No sync activity yet")
                description: Translation.tr("Completed backups will appear here.")
                shape: MaterialShape.Shape.Cookie9Sided
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                visible: root.hasActivity
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: root.activityMetrics[root.activityMetricIndex].displayName
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: root.activityMetricIndex === 0
                                ? root.formatMegabytes(root.activitySelectedTotal)
                                : String(Math.round(root.activitySelectedTotal))
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.bold: true
                        }
                    }

                    Rectangle {
                        implicitWidth: activityWindowText.implicitWidth + 24
                        implicitHeight: activityWindowText.implicitHeight + 12
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSecondaryContainer

                        StyledText {
                            id: activityWindowText
                            anchors.centerIn: parent
                            text: root.activityWindowLabel
                            color: Appearance.colors.colOnSecondaryContainer
                            font.bold: true
                        }
                    }
                }

                UsageBarChart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.hasActivity
                    values: root.activityMetricIndex === 0 ? root.activityDataValues : root.activityTransferValues
                    labels: root.activityLabels
                    tooltipLabels: root.activityTooltipLabels
                    barColor: root.activityMetricIndex === 0 ? Appearance.colors.colPrimary : Appearance.colors.colTertiary
                    emptyColor: Appearance.colors.colLayer2
                    labelStride: Math.max(1, Math.ceil(root.activityLabels.length / 6))
                    labelAnchorEnd: true
                    formatValue: value => root.activityMetricIndex === 0
                        ? root.formatMegabytes(value)
                        : String(Math.round(value)) + " " + Translation.tr("backups")
                    formatTick: value => root.activityMetricIndex === 0
                        ? root.formatMegabytes(value)
                        : String(Math.round(value))
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.hasActivity
            implicitHeight: activityDetailsLayout.implicitHeight + 24
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1

            ColumnLayout {
                id: activityDetailsLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.bottomMargin: 4
                    spacing: 10

                    MaterialSymbol {
                        text: "table_rows"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Period details")
                        color: Appearance.colors.colOnLayer1
                        font.bold: true
                    }

                    StyledText {
                        text: String(root.activityTableRows.length) + " " + Translation.tr("periods")
                        color: Appearance.colors.colSubtext
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        StyledText { Layout.fillWidth: true; text: Translation.tr("Period"); color: Appearance.colors.colSubtext; font.bold: true }
                        StyledText { Layout.preferredWidth: 76; text: Translation.tr("Backups"); color: Appearance.colors.colSubtext; font.bold: true; horizontalAlignment: Text.AlignRight }
                        StyledText { Layout.preferredWidth: 76; text: Translation.tr("Files"); color: Appearance.colors.colSubtext; font.bold: true; horizontalAlignment: Text.AlignRight }
                        StyledText { Layout.preferredWidth: 88; text: Translation.tr("Data"); color: Appearance.colors.colSubtext; font.bold: true; horizontalAlignment: Text.AlignRight }
                    }
                }

                Repeater {
                    model: root.activityTableRows

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 42
                        radius: Appearance.rounding.small
                        color: index % 2 === 0
                            ? ColorUtils.transparentize(Appearance.colors.colLayer1, 1)
                            : Appearance.colors.colLayer1Hover

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            StyledText { Layout.fillWidth: true; text: modelData.label; color: Appearance.colors.colOnLayer1; font.bold: true }
                            StyledText { Layout.preferredWidth: 76; text: String(modelData.runs); color: Appearance.colors.colOnLayer1; horizontalAlignment: Text.AlignRight }
                            StyledText { Layout.preferredWidth: 76; text: String(modelData.files); color: Appearance.colors.colOnLayer1; horizontalAlignment: Text.AlignRight }
                            StyledText { Layout.preferredWidth: 88; text: root.formatMegabytes(modelData.dataMb); color: Appearance.colors.colOnLayer1; horizontalAlignment: Text.AlignRight }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Layout.topMargin: root.hasActivity ? 8 : 0

            Repeater {
                model: [
                    { label: Translation.tr("Files"), value: String(root.activityFilesTotal), icon: "description" },
                    { label: Translation.tr("Data"), value: root.formatMegabytes(root.activityDataValues.reduce((total, value) => total + Number(value || 0), 0)), icon: "data_usage" },
                    { label: Translation.tr("Errors"), value: String(root.activityErrors), icon: "error" }
                ]

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: metricColumn.implicitHeight + 24
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    ColumnLayout {
                        id: metricColumn
                        anchors.centerIn: parent
                        spacing: 2

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.value
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.bold: true
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }

    // ── Google Drive — folders ──────────────────────────────────────────────
    ContentSection {
        Layout.fillWidth: true
        icon: "folder_copy"
        title: Translation.tr("Backup Folders")

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Choose the local folders that should be copied to Drive.")
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            RippleButtonWithIcon {
                mainText: Translation.tr("Add folder")
                materialIcon: "create_new_folder"
                colText: Appearance.colors.colOnPrimaryContainer
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                onClicked: root.openFolderPicker()
            }
        }

        Item {
            Layout.fillWidth: true
            visible: driveOptions.backupFolders.length === 0
            implicitHeight: visible ? 140 : 0

            PagePlaceholder {
                anchors.fill: parent
                shown: parent.visible
                icon: "folder_off"
                title: Translation.tr("No folders configured")
                description: Translation.tr("Add a folder to start backing up.")
                shape: MaterialShape.Shape.Cookie9Sided
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: driveOptions.backupFolders

                delegate: Rectangle {
                    id: folderRow
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 56
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: folderRowLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            text: folderRow.modelData.toLowerCase().includes("picture") ? "image" : folderRow.modelData.includes(".config") ? "settings" : "folder"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: folderRow.modelData
                            color: Appearance.colors.colOnLayer2
                            elide: Text.ElideMiddle
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: Translation.tr("Local")
                            color: Appearance.colors.colSubtext
                        }

                        RippleButtonWithIcon {
                            mainText: ""
                            materialIcon: "close"
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            colText: Appearance.colors.colOnLayer2
                            colBackground: Appearance.colors.colLayer3
                            colBackgroundHover: Appearance.colors.colLayer3Hover
                            colRipple: Appearance.colors.colLayer3Active
                            onClicked: root.removeBackupFolder(folderRow.index)
                        }
                    }
                }
            }
        }
    }

    // ── Google Drive — schedule ─────────────────────────────────────────────
    ContentSection {
        Layout.fillWidth: true
        icon: "schedule"
        title: Translation.tr("Sync Schedule")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Choose how often the backup service should run.")
            color: Appearance.colors.colSubtext
        }

        ConfigSelectionArray {
            Layout.fillWidth: true
            currentValue: driveOptions.syncInterval
            options: [
                { displayName: Translation.tr("1 hour"), value: "1h", icon: "hourglass_top" },
                { displayName: Translation.tr("4 hours"), value: "4h", icon: "schedule" },
                { displayName: Translation.tr("1 day"), value: "1d", icon: "today" },
                { displayName: Translation.tr("2 days"), value: "2d", icon: "date_range" },
                { displayName: Translation.tr("3 days"), value: "3d", icon: "calendar_month" }
            ]
            onSelected: value => driveOptions.syncInterval = value
        }

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Sync on boot")
            checked: driveOptions.syncOnBoot
            onCheckedChanged: {
                if (checked !== driveOptions.syncOnBoot)
                    driveOptions.syncOnBoot = checked;
            }
        }
    }

    // ── Google Drive — advanced settings entry ──────────────────────────────
    ContentSection {
        Layout.fillWidth: true
        icon: "tune"
        title: Translation.tr("Advanced Drive Settings")

        RippleButton {
            id: advancedDriveButton
            Layout.fillWidth: true
            implicitHeight: advancedDriveRow.implicitHeight + 32
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colTertiaryContainer
            colBackgroundHover: Appearance.colors.colTertiaryContainerHover
            colRipple: Appearance.colors.colTertiaryContainerActive
            onClicked: root.activeSubPage = Qt.resolvedUrl("widgets/AdvancedDriveConfig.qml")

            contentItem: RowLayout {
                id: advancedDriveRow
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                MaterialShapeWrappedMaterialSymbol {
                    text: "tune"
                    shape: MaterialShape.Shape.Circle
                    iconSize: Appearance.font.pixelSize.large
                    padding: 8
                    color: Appearance.colors.colTertiary
                    colSymbol: Appearance.colors.colOnTertiary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Advanced Drive Settings")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnTertiaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Transfer limits, retention, network triggers and notifications")
                        color: Appearance.colors.colOnTertiaryContainer
                        opacity: 0.82
                        wrapMode: Text.WordWrap
                    }
                }

                MaterialSymbol {
                    text: "arrow_forward"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnTertiaryContainer
                }
            }
        }
    }

    // ── Google Drive — exclusion patterns ───────────────────────────────────
    ContentSection {
        Layout.fillWidth: true
        icon: "block"
        title: Translation.tr("Exclude Patterns")

        ConfigTextField {
            Layout.fillWidth: true
            text: Translation.tr("New pattern")
            icon: "filter_alt"
            tooltip: Translation.tr("Use rclone globs such as *.tmp, cache/ or **/*.log. A trailing / targets a directory; one pattern is added per entry.")
            placeholderText: Translation.tr("e.g. *.cache or build/")
            inputText: root.excludePatternDraft
            textField.onTextChanged: root.excludePatternDraft = textField.text
        }

        WarningBox {
            Layout.fillWidth: true
            visible: root.excludePatternError !== ""
            text: root.excludePatternError
        }

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Glob patterns ignored by rclone during each backup.")
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            RippleButtonWithIcon {
                mainText: Translation.tr("Add pattern")
                materialIcon: "add"
                colText: Appearance.colors.colOnPrimaryContainer
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                onClicked: root.addExcludePattern(root.excludePatternDraft)
            }
        }

        NoticeBox {
            Layout.fillWidth: true
            materialIcon: "help"
            text: Translation.tr("Examples: *.cache matches files with that suffix, .git/ excludes a directory, and **/*.log matches logs in any subfolder. Patterns are passed directly to rclone.")
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: excludeFlow.height

            Flow {
                id: excludeFlow
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 6

                Repeater {
                    model: driveOptions.excludePatterns

                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: patternContent.implicitWidth + 24
                        height: 36
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSecondaryContainer

                        RowLayout {
                            id: patternContent
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 5

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignVCenter
                                text: "filter_alt"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData
                                color: Appearance.colors.colOnSecondaryContainer
                                font.pixelSize: Appearance.font.pixelSize.small
                            }

                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24

                                RippleButton {
                                    anchors.fill: parent
                                    padding: 0
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: Appearance.colors.colSecondaryContainer
                                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                                    colRipple: Appearance.colors.colSecondaryContainerActive
                                    onClicked: root.removeExcludePattern(index)

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "close"
                                        iconSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: folderPickerProc
        command: ["bash", "-c", "if command -v zenity >/dev/null 2>&1; then zenity --file-selection --directory; elif command -v kdialog >/dev/null 2>&1; then kdialog --getexistingdirectory \"$PWD\"; else exit 127; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const selectedPath = text.trim();
                if (selectedPath)
                    root.addBackupFolder(selectedPath);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 127)
                root.driveUiError = Translation.tr("Install zenity or kdialog to choose a backup folder.");
        }
    }
    }

    ConfigSubPageHost {
        id: subPageOverlay

        anchors.fill: parent
        z: 10
    }
}
