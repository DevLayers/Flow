import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0
import Qt5Compat.GraphicalEffects

// ─────────────────────────────────────────────────────────────────────────────
// Flow SDDM greeter — the hyprlock design, as a login screen.
// Blurred live wallpaper (synced world-readable by the wallpaper scripts),
// a light 12-hour Inter clock in the upper third, and a frosted translucent
// password pill in the lower third. Colors come from matugen via theme.conf
// (symlinked to /var/tmp/sddm-dotfiles/theme.conf), so the greeter tracks the
// wallpaper palette exactly like the lock screen and the shell.
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.stringValue("backgroundFill") || "#131314"

    readonly property string fontUi: config.stringValue("font") || "Inter"
    readonly property color accent: config.stringValue("accentColor") || "#c0c7d5"
    readonly property color errorColor: config.stringValue("errorColor") || "#ffb4ab"

    property int currentUsersIndex: userModel.lastIndex
    property int currentSessionsIndex: sessionModel.lastIndex
    readonly property int usernameRole: Qt.UserRole + 1
    readonly property string currentUsername:
        userModel.data(userModel.index(currentUsersIndex, 0), usernameRole) || ""
    property bool authFailed: false

    // ── Wallpaper, blurred + dimmed like hyprlock's live blur ────────────────
    Image {
        id: wall
        anchors.fill: parent
        source: config.stringValue("background")
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
    }
    FastBlur {
        anchors.fill: wall
        source: wall
        radius: config.intValue("blurRadius") || 48
        visible: wall.status === Image.Ready
    }
    Rectangle {   // dim so the light text + glass read cleanly (hyprlock brightness 0.55)
        anchors.fill: parent
        color: "#000000"
        opacity: 0.42
    }

    // ── Upper third: time + date (12-hour, matching hyprlock) ────────────────
    // 12-hour is computed manually — Qt.formatTime("h:mm") follows the system
    // locale, and the sddm greeter runs under C/POSIX where "h" renders 0-23.
    function fmt12(d) {
        var h = d.getHours() % 12; if (h === 0) h = 12;
        var m = d.getMinutes();
        return h + ":" + (m < 10 ? "0" + m : m);
    }
    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -300
        color: "#ffffff"
        font.family: root.fontUi
        font.pixelSize: 116
        font.weight: Font.DemiBold
        text: root.fmt12(new Date())
        layer.enabled: true
        layer.effect: DropShadow { radius: 16; samples: 25; color: "#66000000"; verticalOffset: 2 }
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: {
                var now = new Date();
                clock.text = root.fmt12(now);
                dateLabel.text = Qt.formatDate(now, "dddd, MMMM d");
            }
        }
    }
    Text {
        id: dateLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clock.bottom
        anchors.topMargin: 4
        color: "#ccffffff"
        font.family: root.fontUi
        font.pixelSize: 20
        font.weight: Font.Medium
        text: Qt.formatDate(new Date(), "dddd, MMMM d")
        layer.enabled: true
        layer.effect: DropShadow { radius: 10; samples: 17; color: "#55000000"; verticalOffset: 1 }
    }

    // ── Lower third: unlock cluster ──────────────────────────────────────────
    // User identity, macOS-style. Defaults to the LAST logged-in user
    // (userModel.lastIndex). The name is always clickable: tap it and it turns
    // into a small edit field where ANY username can be typed (like macOS's
    // "Other…"), Enter/Escape confirms/cancels. With multiple accounts a
    // chevron also reveals the other users as frosted chips.
    readonly property bool multiUser: userModel.count > 1
    property bool userPickerOpen: false
    property bool userEditing: false
    property string customUser: ""     // non-empty → overrides the model user
    readonly property string loginUsername: customUser !== "" ? customUser : currentUsername

    Item {
        id: userRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 172
        width: root.userEditing ? 220 : nameRow.implicitWidth + 44
        height: 38
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // Frosted pill behind the name — always visible, same glass language as
        // the password pill; brightens on hover to signal it's interactive.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.userEditing ? "#1fffffff"
                 : userMouse.containsMouse ? "#2effffff" : "#1fffffff"
            border.width: 1
            border.color: root.userEditing ? "#40ffffff" : "#30ffffff"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Display state — the name (+ chevron when there are more accounts).
        Row {
            id: nameRow
            visible: !root.userEditing
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: userMouse.containsMouse ? "#ffffffff" : "#eeffffff"
                font.family: root.fontUi
                font.pixelSize: 16
                font.weight: Font.Medium
                text: root.loginUsername
            }
            Text {   // chevron — only when there is actually a list to open
                visible: root.multiUser
                anchors.verticalCenter: parent.verticalCenter
                color: "#99ffffff"
                font.pixelSize: 11
                text: root.userPickerOpen ? "▴" : "▾"
            }
        }
        MouseArea {
            id: userMouse
            visible: !root.userEditing
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.multiUser) {
                    root.userPickerOpen = !root.userPickerOpen;
                } else {
                    // Single account: clicking the name switches to type-a-user.
                    root.userEditing = true;
                    userField.text = root.loginUsername;
                    userField.selectAll();
                    userField.forceActiveFocus();
                }
            }
            onPressAndHold: {   // long-press always offers manual entry
                root.userPickerOpen = false;
                root.userEditing = true;
                userField.text = root.loginUsername;
                userField.selectAll();
                userField.forceActiveFocus();
            }
        }

        // Edit state — type any username inside the same pill.
        TextInput {
            id: userField
            visible: root.userEditing
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            color: "#ffffff"
            font.family: root.fontUi
            font.pixelSize: 16
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            onAccepted: {
                var typed = text.trim();
                if (typed !== "") {
                    // If it matches a known account, select it; else custom.
                    var matched = -1;
                    for (var i = 0; i < userModel.count; i++) {
                        if (userModel.data(userModel.index(i, 0), root.usernameRole) === typed) { matched = i; break; }
                    }
                    if (matched >= 0) { root.currentUsersIndex = matched; root.customUser = ""; }
                    else root.customUser = typed;
                }
                root.userEditing = false;
                passwordInput.text = "";
                passwordInput.forceActiveFocus();
            }
            Keys.onEscapePressed: {
                root.userEditing = false;
                passwordInput.forceActiveFocus();
            }
        }
    }

    // Frosted user picker — the other accounts, as tappable glass chips.
    Row {
        visible: root.userPickerOpen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: userRow.top
        anchors.bottomMargin: 14
        spacing: 10

        Repeater {
            model: userModel
            delegate: Rectangle {
                required property int index
                required property string name
                visible: index !== root.currentUsersIndex
                width: chipText.implicitWidth + 32
                height: 38
                radius: height / 2
                color: chipMouse.containsMouse ? "#33ffffff" : "#1fffffff"
                border.width: 1
                border.color: "#30ffffff"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    color: "#eeffffff"
                    font.family: root.fontUi
                    font.pixelSize: 15
                    text: name
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentUsersIndex = index;
                        root.customUser = "";
                        root.userPickerOpen = false;
                        passwordInput.text = "";
                        passwordInput.forceActiveFocus();
                    }
                }
            }
        }
    }

    // Frosted password pill — translucent fill + hairline ring, like hyprlock.
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 240
        width: 320; height: 54
        radius: height / 2
        color: "#1fffffff"                       // frosted glass fill (~12% white)
        border.width: 2
        border.color: root.authFailed ? root.errorColor
                     : passwordInput.activeFocus ? "#50ffffff" : "#30ffffff"
        Behavior on border.color { ColorAnimation { duration: 250 } }

        TextInput {
            id: passwordInput
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            echoMode: TextInput.Password
            passwordCharacter: "●"
            color: "#ffffff"
            font.family: root.fontUi
            font.pixelSize: 15
            font.letterSpacing: 2
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            focus: true
            onTextEdited: root.authFailed = false
            onAccepted: {
                if (text !== "")
                    sddm.login(root.loginUsername, text, root.currentSessionsIndex);
            }
        }
        Text {   // placeholder
            anchors.centerIn: parent
            visible: passwordInput.text.length === 0 && !root.authFailed
            text: "Enter Password"
            color: "#aaffffff"
            font.family: root.fontUi
            font.pixelSize: 15
        }
    }

    // Failure feedback — quiet line under the pill, pill ring keyed to error.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: pill.bottom
        anchors.topMargin: 14
        visible: root.authFailed
        text: "Incorrect password"
        color: root.errorColor
        font.family: root.fontUi
        font.pixelSize: 14
    }

    // Session picker — a whisper in the bottom-right corner, cycled with F3.
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        color: "#88ffffff"
        font.family: root.fontUi
        font.pixelSize: 13
        text: sessionModel.data(sessionModel.index(root.currentSessionsIndex, 0), Qt.UserRole + 1) || ""
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.authFailed = true;
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F3) {   // cycle sessions
            root.currentSessionsIndex = (root.currentSessionsIndex + 1) % sessionModel.rowCount();
            event.accepted = true;
        } else if (event.key === Qt.Key_F2) {   // cycle users (clears typed name)
            root.currentUsersIndex = (root.currentUsersIndex + 1) % userModel.count;
            root.customUser = "";
            event.accepted = true;
        }
    }
    Component.onCompleted: passwordInput.forceActiveFocus()
}
