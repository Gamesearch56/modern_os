import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    readonly property bool _capsOn: password.capsOn
    readonly property bool _shutdown: Session.mode === "shutdown"

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    function focusPassword() {
        if (password.visible)
            password.focusInput();
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.lg

        MTextField {
            id: password
            visible: !root._shutdown
            Layout.fillWidth: true
            focus: true
            holdFocus: true
            placeholderKey: "session.password"
            echoMode: TextInput.Password
            onTextEdited: Session.password = text
            enabled: !Session.busy
            onAccepted: Session.authenticate(Session.password)
            Component.onCompleted: {
                if (Session.password.length)
                    text = Session.password;
                focusInput();
            }

            Connections {
                target: Session
                function onPasswordChanged() {
                    if (password.text !== Session.password)
                        password.text = Session.password;
                }
            }
        }

        MText {
            visible: password.visible && root._capsOn
            Layout.alignment: Qt.AlignHCenter
            key: "session.capsLock"
            styleName: "bodySmall"
            color: Colors.color.onSurfaceVariant
            Accessible.role: Accessible.Alert
            Accessible.name: I18n.t("session.capsLock")
        }

        MText {
            visible: Session.lastError.length > 0
            Layout.alignment: Qt.AlignHCenter
            key: "session.authFailed"
            styleName: "bodySmall"
            color: Colors.color.error
            Accessible.role: Accessible.Alert
            Accessible.name: I18n.t("session.authFailed")
        }

        MButton {
            visible: !root._shutdown
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.xl
            kind: "filled"
            key: Session.busy ? "session.starting" : "session.unlock"
            enabled: Session.password.length > 0 && !Session.busy
            onClicked: Session.authenticate(Session.password)
        }

        RowLayout {
            visible: root._shutdown
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.md

            MButton {
                kind: "text"
                key: "powerMenu.cancel"
                onClicked: Session.unlock()
            }

            MButton {
                kind: "filled"
                key: "powerMenu." + (Session.pendingAction === "reboot" ? "restart" : (Session.pendingAction || "poweroff"))
                onClicked: {
                    if (Session.pendingAction === "reboot")
                        Power.reboot();
                    else if (Session.pendingAction === "logout")
                        Power.logout();
                    else
                        Power.poweroff();
                }
            }
        }
    }
}
