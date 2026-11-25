import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    property var shots: []

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    MText {
        key: "store.screenshots"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    ListView {
        visible: root.shots.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 6
        orientation: ListView.Horizontal
        spacing: Tokens.spacing.xs
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.shots.length
        delegate: MImageTile {
            required property int index
            width: Tokens.spacing.xxl * 10
            height: Tokens.spacing.xxl * 6
            hoverRing: true
            dimRest: false
            source: root.shots[index] || ""
            onClicked: Store.previewImage(root.shots[index] || "")
        }
    }

    MHint {
        visible: root.shots.length === 0
        key: "store.screenshotsEmpty"
        Layout.fillWidth: true
    }
}
