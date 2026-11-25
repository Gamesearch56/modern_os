import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root

    signal addClicked()
    signal editClicked(var grp)
    signal removeClicked(var grp)

    readonly property var rows: Passwd.localGroups || []
    readonly property bool busy: Passwd.running
    readonly property bool manage: Passwd.canManage

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.users.groupsAll"
            styleName: "titleSmall"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MText {
            visible: root.rows.length > 0
            value: String(root.rows.length)
            styleName: "labelLarge"
            color: Colors.color.onSurfaceVariant
        }
        MButton {
            visible: root.manage
            kind: "filled"
            key: "settings.users.addGroup"
            enabled: !root.busy && root.manage
            onClicked: root.addClicked()
        }
    }

    Repeater {
        model: root.rows.length
        GroupRow {
            required property int index
            grp: root.rows[index]
            busy: root.busy
            onEditClicked: (g) => root.editClicked(g)
            onRemoveClicked: (g) => root.removeClicked(g)
        }
    }

    MEmptyState {
        visible: root.rows.length === 0 && !root.busy
        Layout.fillWidth: true
        Layout.preferredHeight: Tokens.spacing.xxl * 4
        iconName: "system-users-symbolic"
        titleKey: "settings.users.emptyGroups"
        hintKey: root.manage ? "settings.users.emptyGroupsHint" : "settings.users.adminOnlyHint"
    }
}