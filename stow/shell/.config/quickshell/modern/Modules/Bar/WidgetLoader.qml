// Resolves a widget id from config.json to widgets/<id>/Widget.qml.
// Unknown ids log and collapse rather than crashing the bar.
// `modelData` is required so Qt 6 Repeaters actually instantiate us
// (a required `widgetId` is never filled from a string-list model).
import QtQuick
import "../../Commons"

Loader {
    id: root

    required property var modelData
    property var barScreen: null
    readonly property string widgetId: String(root.modelData ?? "")

    active: root.widgetId.length > 0
    visible: !root.item || root.item.visible
    // A layout that assigns width deletes this binding and leaves the
    // slot at 0, so the chip paints under the next buttons. The island
    // uses a positioner, which keeps the binding.
    readonly property real _slotW: (root.item && root.visible) ? root.item.implicitWidth : 0
    readonly property real _slotH: (root.item && root.visible) ? root.item.implicitHeight : 0
    width: _slotW
    height: _slotH
    source: Qt.resolvedUrl("widgets/" + root.widgetId + "/Widget.qml")
    onLoaded: {
        if (root.item && root.item.barScreen !== undefined)
            root.item.barScreen = Qt.binding(() => root.barScreen);
    }
    onStatusChanged: {
        if (root.status === Loader.Error)
            Logger.warn("Bar", "missing widget '" + root.widgetId + "'");
    }
}
