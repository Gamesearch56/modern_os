import QtQuick

// A window Shortcut for every key of every command in `model`
// ([{ id, keys: ["Ctrl+S", ...] }]). Pressing one calls actions.run(id).
// Dialogs switch `armed` off so a shortcut cannot act under a prompt.
Item {
    id: root

    property var model: []
    property var actions: null
    property bool armed: true

    Repeater {
        model: root.model
        delegate: Item {
            id: slot
            required property var modelData

            Repeater {
                model: slot.modelData.keys
                delegate: Item {
                    id: key
                    required property string modelData

                    Shortcut {
                        sequence: key.modelData
                        context: Qt.WindowShortcut
                        enabled: root.armed && !!root.actions
                        onActivated: root.actions.run(slot.modelData.id)
                    }
                }
            }
        }
    }
}
