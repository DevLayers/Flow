import QtQuick

/**
 * Base for one trigger of a mode or routine. A watcher instantiates one of
 * these per trigger entry and combines their `satisfied` flags.
 *
 * `params` is the normalized trigger object from the definition. `reason` is
 * a short human string for the UI ("23:00–07:00", "steam_app_123") so a
 * surprising start can be explained.
 */
QtObject {
    id: root
    property var params: ({})
    readonly property string type: root.params?.type ?? ""
    // False while the owning mode/routine cannot start automatically; a
    // condition with a standing cost (GPU polling) may idle then.
    property bool armed: true
    property bool satisfied: false
    property string reason: ""
}
