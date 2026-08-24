pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property string searchQuery: ""
    property int selectedIndex: 0
    property bool subscribed: false

    readonly property var rows: root.filteredGames()
    readonly property var selectedGame: root.selectedIndex >= 0 && root.selectedIndex < root.rows.length ? root.rows[root.selectedIndex] : null
    readonly property string statusText: root.selectedGame
        ? String(root.selectedGame.name ?? "") + " · " + String(root.selectedGame.status ?? "")
        : (SportsService.searchLoading ? Translation.tr("Loading today’s games…") : Translation.tr("%1 games today").arg(String(root.rows.length)))

    implicitWidth: 720
    implicitHeight: scaffold.implicitHeight

    function filteredGames() {
        const query = root.searchQuery.trim().toLocaleLowerCase();
        const today = SportsService.dayKey(DateTime.clock.date);
        const leagues = Array.from(Config.options.search.modules.sports.leagues ?? []);
        return Array.from(SportsService.searchGames ?? []).filter(game => {
            if (SportsService.dayKey(game?.date) !== today)
                return false;
            if (leagues.length > 0 && !leagues.includes(String(game?.leagueId ?? game?.league ?? "")))
                return false;
            if (query.length === 0)
                return true;
            return [game?.name, game?.league, game?.home?.name, game?.away?.name, game?.status].join(" ").toLocaleLowerCase().includes(query);
        }).sort((left, right) => new Date(left?.date) - new Date(right?.date));
    }

    function clampSelection() {
        root.selectedIndex = root.rows.length === 0 ? -1 : Math.max(0, Math.min(root.selectedIndex, root.rows.length - 1));
    }

    function navigateUp(): bool {
        if (root.selectedIndex <= 0)
            return false;
        root.selectedIndex--;
        gamesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function navigateDown(): bool {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.rows.length - 1)
            return false;
        root.selectedIndex++;
        gamesList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        return true;
    }

    function activateSelected(): bool {
        if (!root.selectedGame)
            return false;
        const index = Array.from(SportsService.allGames ?? []).findIndex(game => String(game?.id ?? "") === String(root.selectedGame.id ?? ""));
        if (index >= 0) {
            SportsService.currentGameIndex = index;
            SportsService.currentGame = SportsService.allGames[index];
        } else {
            SportsService.currentGame = root.selectedGame;
        }
        return true;
    }

    function createFromQuery(): bool {
        if (!root.selectedGame?.date)
            return false;
        const seconds = Math.floor((new Date(root.selectedGame.date).getTime() - Date.now()) / 1000) - 600;
        if (seconds <= 0)
            return false;
        TimerService.addCountdown(Math.max(1, Math.ceil(seconds / 60)), String(root.selectedGame.name ?? Translation.tr("Game")));
        return true;
    }

    function focusInput(): bool { return false; }

    onRowsChanged: root.clampSelection()
    onSearchQueryChanged: root.selectedIndex = 0

    Component.onCompleted: {
        SportsService.acquireSearchSubscriber();
        root.subscribed = true;
    }

    Component.onDestruction: {
        if (root.subscribed)
            SportsService.releaseSearchSubscriber();
    }

    SearchPanelScaffold {
        id: scaffold
        anchors.fill: parent
        title: Translation.tr("Today’s games")
        icon: "sports_soccer"
        accent: true
        statusText: root.statusText
        showStatus: true
        primaryHint: ({ label: Translation.tr("Select"), keys: ["↵"] })
        hints: [{ label: Translation.tr("Remind"), keys: ["Ctrl", "N"] }]

        ListView {
            id: gamesList
            width: parent.width
            height: parent.height
            clip: true
            spacing: Appearance.sizes.elevationMargin / 2
            model: root.rows

            delegate: RippleButton {
                required property int index
                required property var modelData
                width: gamesList.width
                implicitHeight: gameContent.implicitHeight + Appearance.sizes.elevationMargin * 2
                buttonRadius: Appearance.rounding.normal
                colBackground: root.selectedIndex === index ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh
                colBackgroundHover: root.selectedIndex === index ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colSurfaceContainerHighHover
                colRipple: root.selectedIndex === index ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colSurfaceContainerHighActive
                onClicked: { root.selectedIndex = index; root.activateSelected(); }

                RowLayout {
                    id: gameContent
                    anchors.fill: parent
                    anchors.margins: Appearance.sizes.elevationMargin
                    spacing: Appearance.sizes.elevationMargin

                    MaterialSymbol {
                        text: modelData.state === "in" ? "sensors" : "sports_soccer"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.selectedIndex === index ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: String(modelData.home?.name ?? "") + " " + String(modelData.home?.score ?? "") + " × " + String(modelData.away?.score ?? "") + " " + String(modelData.away?.name ?? "")
                            elide: Text.ElideRight
                            color: root.selectedIndex === index ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: String(modelData.league ?? "") + " · " + String(modelData.status ?? "")
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.selectedIndex === index ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.rows.length === 0
                text: SportsService.searchLoading
                    ? Translation.tr("Loading today’s games…")
                    : (SportsService.searchError.length > 0
                        ? SportsService.searchError
                        : Translation.tr("No games today"))
                color: Appearance.colors.colSubtext
            }
        }
    }
}
