pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/** Official project destinations used by Welcome cards.
 * The fork documentation URL stays empty until the project publishes it.
 */
QtObject {
    readonly property string repositoryUrl: "https://github.com/P3DROVFX/ii-p3drovfx"
    readonly property string documentationUrl: ""
    readonly property bool documentationAvailable: documentationUrl.length > 0
}
