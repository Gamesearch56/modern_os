import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

Item {
    id: root

    property var pendingUser: null
    property var pendingGroup: null

    implicitHeight: col.implicitHeight

    Component.onCompleted: Passwd.watching = true
    Component.onDestruction: Passwd.watching = false

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Tokens.spacing.lg

        SessionCard {
            Layout.fillWidth: true
            onFaceClicked: faceDlg.open = true
            onEditClicked: {
                userDlg.load(Passwd.sessionUser);
                userDlg.open = true;
            }
        }

        MLinearProgress {
            visible: Passwd.running || Autologin.running
            Layout.fillWidth: true
            indeterminate: true
        }
        MText {
            visible: Passwd.lastError.length > 0 && !Passwd.running
            value: Passwd.lastError
            styleName: "bodySmall"
            color: Colors.color.error
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Accessible.role: Accessible.AlertMessage
            Accessible.name: Passwd.lastError
        }
        MHint {
            visible: !Passwd.canManage
            key: "settings.users.adminOnlyHint"
            Layout.fillWidth: true
        }

        UserList {
            onAddClicked: {
                if (!Passwd.canManage)
                    return;
                userDlg.reset();
                userDlg.open = true;
            }
            onEditClicked: (p) => {
                if (!Passwd.canManage)
                    return;
                userDlg.load(p);
                userDlg.open = true;
            }
            onRemoveClicked: (p) => root.askDeleteUser(p)
        }

        GroupList {
            Layout.topMargin: Tokens.spacing.xxl
            onAddClicked: {
                if (!Passwd.canManage)
                    return;
                groupDlg.reset();
                groupDlg.open = true;
            }
            onEditClicked: (g) => {
                if (!Passwd.canManage)
                    return;
                groupDlg.load(g);
                groupDlg.open = true;
            }
            onRemoveClicked: (g) => root.askDeleteGroup(g)
        }
    }

    function askDeleteUser(person) {
        if (!Passwd.canManage)
            return;
        root.pendingUser = person || null;
        if (!root.pendingUser)
            return;
        delUser.open = true;
    }

    function askDeleteGroup(grp) {
        if (!Passwd.canManage)
            return;
        root.pendingGroup = grp || null;
        if (!root.pendingGroup)
            return;
        delGroup.open = true;
    }

    function closeOverlays() {
        if (delUser.open) {
            delUser.open = false;
            root.pendingUser = null;
            return true;
        }
        if (delGroup.open) {
            delGroup.open = false;
            root.pendingGroup = null;
            return true;
        }
        if (userDlg.open) {
            userDlg.open = false;
            return true;
        }
        if (groupDlg.open) {
            groupDlg.open = false;
            return true;
        }
        if (faceDlg.open) {
            faceDlg.open = false;
            return true;
        }
        return false;
    }

    Connections {
        target: Autologin
        function onApplied(on) {
            ConfigWrite.set("general.autologin", on);
        }
    }

    FaceDialog {
        id: faceDlg
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        enabled: faceDlg.open
    }

    UserDialog {
        id: userDlg
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        enabled: userDlg.open
    }

    GroupDialog {
        id: groupDlg
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        enabled: groupDlg.open
    }

    MDialog {
        id: delUser
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        z: 200
        titleKey: "settings.users.deleteUserTitle"
        titleParams: ({ user: root.pendingUser ? (root.pendingUser.login || "") : "" })
        bodyKey: "settings.users.deleteUserBody"
        bodyParams: ({ user: root.pendingUser ? (root.pendingUser.login || "") : "" })
        confirmKey: "settings.users.deleteUser"
        cancelKey: "settings.cancel"
        destructive: true
        onConfirmed: {
            if (root.pendingUser)
                Passwd.deleteUser(root.pendingUser.login || "", true);
            delUser.open = false;
            root.pendingUser = null;
        }
        onCancelled: {
            delUser.open = false;
            root.pendingUser = null;
        }
    }

    MDialog {
        id: delGroup
        parent: Window.window ? Window.window.contentItem : root
        anchors.fill: parent
        z: 200
        titleKey: "settings.users.deleteGroupTitle"
        titleParams: ({ group: root.pendingGroup ? (root.pendingGroup.name || "") : "" })
        bodyKey: "settings.users.deleteGroupBody"
        bodyParams: ({ group: root.pendingGroup ? (root.pendingGroup.name || "") : "" })
        confirmKey: "settings.users.deleteGroup"
        cancelKey: "settings.cancel"
        destructive: true
        onConfirmed: {
            if (root.pendingGroup)
                Passwd.deleteGroup(root.pendingGroup.name || "");
            delGroup.open = false;
            root.pendingGroup = null;
        }
        onCancelled: {
            delGroup.open = false;
            root.pendingGroup = null;
        }
    }
}