// A labelled row of single- or multi-select chips for the describe step.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"

MField {
    id: root

    spacing: Tokens.spacing.sm

    property var options: []
    property string keyPrefix: ""
    property var selected: []

    signal picked(string id)

    Flow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm

        Repeater {
            model: root.options

            MChip {
                required property string modelData
                key: root.keyPrefix + modelData
                checked: (root.selected || []).indexOf(modelData) !== -1
                onClicked: root.picked(modelData)
            }
        }
    }
}
