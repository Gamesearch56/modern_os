import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

// Apple ID with an app-specific password: every iCloud calendar.
ColumnLayout {
    id: root

    signal back()
    signal useLink()

    readonly property string _user: String(appleUser.text || "").trim()
    readonly property string _pwd: String(applePass.text || "")
    readonly property bool _userOk: root._user.indexOf("@") > 0
    readonly property bool _pwdOk: CalendarAccount.appPasswordLooksRight(root._pwd)
    readonly property string _problem: root._user.length > 0 && !root._userOk
        ? "calendar.appleIdFormat"
        : (root._pwd.length > 0 && !root._pwdOk ? "calendar.applePasswordFormat" : "")

    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    function _connect() {
        if (root._userOk && root._pwdOk && !Calendar.checking)
            Calendar.check("apple", "", root._user, root._pwd);
    }

    function clear() {
        applePass.text = "";
    }

    CalendarSteps {
        keys: ["calendar.appleStep1", "calendar.appleStep2", "calendar.appleStep3"]
    }

    MButton {
        kind: "outlined"
        iconName: "icloud"
        iconTint: false
        key: "calendar.openApple"
        fillWidth: true
        onClicked: CalendarAccount.openAppleId()
    }

    MField {
        labelKey: "calendar.appleId"
        MTextField {
            id: appleUser
            text: CalendarAccount.account
            placeholderKey: "calendar.appleIdPlaceholder"
            onAccepted: applePass.editor.forceActiveFocus()
        }
    }
    MField {
        labelKey: "calendar.appPassword"
        MTextField {
            id: applePass
            echoMode: TextInput.Password
            placeholderKey: "calendar.appPasswordPlaceholder"
            onAccepted: root._connect()
        }
    }

    MHint {
        visible: root._problem.length > 0 || Calendar.errorKey.length > 0
        key: root._problem.length > 0 ? root._problem : Calendar.errorKey
        color: Colors.color.error
        Layout.fillWidth: true
    }

    MButton {
        kind: "text"
        key: "calendar.appleUseLink"
        onClicked: root.useLink()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm
        MButton {
            kind: "text"
            key: "calendar.chooseAnother"
            onClicked: root.back()
        }
        Item { Layout.fillWidth: true }
        MButton {
            kind: "filled"
            key: Calendar.checking ? "calendar.checking" : "calendar.connect"
            busy: Calendar.checking
            enabled: root._userOk && root._pwdOk
            onClicked: root._connect()
        }
    }
}
