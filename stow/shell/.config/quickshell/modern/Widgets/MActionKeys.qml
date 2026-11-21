import QtQuick
import "actions.js" as ActionList

// A Shortcut for every key in actions.js the text field does not already
// handle. Dialogs switch them off so Ctrl+S cannot save under a prompt.
Item {
    id: root

    property var actions: null
    property bool armed: true

    Repeater {
        model: ActionList.bindable()
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
