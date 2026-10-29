import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    property string draft: ""

    readonly property bool connected: CalendarAccount.connected
    readonly property string setup: root.connected ? "" : root.draft

    function _connectIcs(provider: string) {
        const u = String(linkField.text || "").trim();
        if (!u.length)
            return;
        ConfigWrite.set("widgets.clock.calendarProvider", provider);
        Calendar.commitUrl(u);
        root.draft = "";
    }

    function _connectApple() {
        const user = String(appleUser.text || "").trim();
        const pwd = String(applePass.text || "").trim();
        if (!user.length || !pwd.length)
            return;
        CalendarAccount.saveApple(user, pwd);
        ConfigWrite.set("widgets.clock.calendarProvider", "apple");
        Calendar.connectNow();
        root.draft = "";
        applePass.text = "";
    }

    MText {
        key: "calendar.connectTitle"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    ColumnLayout {
        visible: !root.connected && root.setup.length === 0
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
        MButton {
            kind: "tonal"
            key: "calendar.providerProton"
            fillWidth: true
            onClicked: root.draft = "proton"
        }
        MButton {
            kind: "tonal"
            key: "calendar.providerGoogle"
            fillWidth: true
            onClicked: root.draft = "google"
        }
        MButton {
            kind: "tonal"
            key: "calendar.providerApple"
            fillWidth: true
            onClicked: root.draft = "apple"
        }
    }

    ColumnLayout {
        visible: !root.connected && (root.setup === "proton" || root.setup === "google")
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm
        MHint {
            key: root.setup === "google" ? "calendar.googleHint" : "calendar.protonHint"
            Layout.fillWidth: true
        }
        MButton {
            kind: "outlined"
            key: root.setup === "google" ? "calendar.openGoogle" : "calendar.openProton"
            fillWidth: true
            onClicked: root.setup === "google" ? CalendarAccount.openGoogle() : CalendarAccount.openProton()
        }
        MField {
            labelKey: "calendar.privateLink"
            MTextField {
                id: linkField
                placeholderKey: "calendar.linkPlaceholder"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm
            MButton {
                kind: "text"
                key: "calendar.chooseAnother"
                onClicked: root.draft = ""
            }
            Item { Layout.fillWidth: true }
            MButton {
                kind: "filled"
                key: "calendar.connect"
                onClicked: root._connectIcs(root.setup)
            }
        }
    }

    ColumnLayout {
        visible: !root.connected && root.setup === "apple"
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm
        MHint {
            key: "calendar.appleHint"
            Layout.fillWidth: true
        }
        MButton {
            kind: "outlined"
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
            }
        }
        MField {
            labelKey: "calendar.appPassword"
            MTextField {
                id: applePass
                echoMode: TextInput.Password
                placeholderKey: "calendar.appPasswordPlaceholder"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm
            MButton {
                kind: "text"
                key: "calendar.chooseAnother"
                onClicked: root.draft = ""
            }
            Item { Layout.fillWidth: true }
            MButton {
                kind: "filled"
                key: "calendar.connect"
                onClicked: root._connectApple()
            }
        }
    }

    RowLayout {
        visible: root.connected
        Layout.fillWidth: true
        spacing: Tokens.spacing.sm
        MText {
            value: {
                const p = CalendarAccount.provider;
                if (p === "google")
                    return I18n.t("calendar.connectedGoogle");
                if (p === "apple")
                    return I18n.t("calendar.connectedApple");
                if (p === "proton")
                    return I18n.t("calendar.connectedProton");
                return I18n.t("calendar.connectedIcs");
            }
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
        MButton {
            kind: "text"
            key: "calendar.disconnect"
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            onClicked: {
                CalendarAccount.disconnect();
                Calendar.refresh();
                root.draft = "";
            }
        }
    }

    Connections {
        target: Calendar
        function onLoadFailed() {
            Notifications.toast(I18n.t("calendar.icsFailed"), "");
        }
    }
}
