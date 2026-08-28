// Resolves a widget id from config.json to Widgets/<id>/Widget.qml.
// Unknown ids log and collapse rather than crashing the bar.
import QtQuick
import "../../../Commons"

Loader {
    id: root

    required property string widgetId
    active: true
    source: Qt.resolvedUrl("widgets/" + root.widgetId + "/Widget.qml")
    onStatusChanged: {
        if (root.status === Loader.Error)
            Logger.warn("Bar", "missing widget '" + root.widgetId + "'");
    }
}
