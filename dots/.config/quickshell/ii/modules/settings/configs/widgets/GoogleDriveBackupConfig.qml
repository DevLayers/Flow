import QtQuick
import QtQuick.Layouts

// The Drive dashboard already owns its service state, charts, authorization
// flow, and folder editors in TasksAccountsConfig. Reuse that page in the
// sub-page so the refactor does not create a second source of truth.
Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    Loader {
        id: drivePageLoader
        anchors.fill: parent
        source: Qt.resolvedUrl("../TasksAccountsConfig.qml")

        onLoaded: {
            item.driveSubPageMode = true;
            item.showBackButton = subPageRoot.showBackButton;
            item.goBack.connect(function() {
                subPageRoot.goBack();
            });
        }
    }

    onShowBackButtonChanged: {
        if (drivePageLoader.item)
            drivePageLoader.item.showBackButton = showBackButton;
    }
}
