import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root

    signal addClicked()
    signal editClicked(var person)
    signal removeClicked(var person)

    readonly property var people: Passwd.others || []
    readonly property bool busy: Passwd.running
    readonly property bool manage: Passwd.canManage

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.users.others"
            styleName: "titleSmall"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MText {
            visible: root.people.length > 0
            value: String(root.people.length)
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }
        MButton {
            visible: root.manage
            kind: "filled"
            key: "settings.users.addUser"
            enabled: !root.busy && root.manage
            onClicked: root.addClicked()
        }
    }

    Repeater {
        model: root.people.length
        UserRow {
            required property int index
            person: root.people[index]
            busy: root.busy
            onEditClicked: (p) => root.editClicked(p)
            onRemoveClicked: (p) => root.removeClicked(p)
        }
    }

    MEmptyState {
        visible: root.people.length === 0 && !root.busy
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 5
        iconName: "user-identity"
        titleKey: "settings.users.empty"
        hintKey: root.manage ? "settings.users.emptyHint" : "settings.users.adminOnlyHint"
    }
}