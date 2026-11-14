import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

// Pick a provider, follow its steps, Connect. Nothing is saved until the
// calendar has actually loaded (Calendar.check).
ColumnLayout {
    id: root

    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    // "" | proton | google | apple (Apple ID) | appleLink (shared link)
    property string draft: ""

    readonly property bool connected: CalendarAccount.connected

    onDraftChanged: Calendar.clearError()

    readonly property string _connectedKey: {
        const p = CalendarAccount.provider;
        if (p === "google")
            return "calendar.connectedGoogle";
        if (p === "apple")
            return "calendar.connectedApple";
        if (p === "proton")
            return "calendar.connectedProton";
        return "calendar.connectedIcs";
    }

    MText {
        key: "calendar.connectTitle"
        styleName: "titleSmall"
        Layout.fillWidth: true
    }

    ColumnLayout {
        visible: !root.connected && root.draft.length === 0
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs
        MHint {
            key: "calendar.chooseProvider"
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.xs
        }
        Repeater {
            model: [
                { id: "proton", key: "calendar.providerProton" },
                { id: "google", key: "calendar.providerGoogle" },
                { id: "apple", key: "calendar.providerApple" }
            ]
            MButton {
                required property var modelData
                kind: "tonal"
                iconName: modelData.id === "google" ? "google-agenda" : (modelData.id === "apple" ? "icloud" : "")
                iconSource: modelData.id === "proton" ? Qt.resolvedUrl("proton-calendar.svg") : ""
                iconTint: false
                key: modelData.key
                fillWidth: true
                onClicked: root.draft = modelData.id
            }
        }
    }

    CalendarLinkForm {
        id: linkForm
        visible: !root.connected && (root.draft === "proton" || root.draft === "google" || root.draft === "appleLink")
        provider: root.draft === "appleLink" ? "apple" : root.draft
        onBack: root.draft = ""
        onUseAppleId: root.draft = "apple"
    }

    CalendarAppleForm {
        id: appleForm
        visible: !root.connected && root.draft === "apple"
        onBack: root.draft = ""
        onUseLink: root.draft = "appleLink"
    }

    ColumnLayout {
        visible: root.connected
        Layout.fillWidth: true
        spacing: Tokens.spacing.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.sm
            MText {
                key: root._connectedKey
                styleName: "bodyMedium"
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
            MButton {
                kind: "text"
                iconName: "view-refresh-symbolic"
                key: "calendar.refresh"
                busy: Calendar.busy
                onClicked: Calendar.refresh()
            }
            MButton {
                kind: "text"
                key: "calendar.disconnect"
                onClicked: {
                    CalendarAccount.disconnect();
                    Calendar.refresh();
                    root.draft = "";
                }
            }
        }
        MHint {
            visible: CalendarAccount.usesAppleId && CalendarAccount.account.length > 0
            value: CalendarAccount.account
            Layout.fillWidth: true
        }
        MHint {
            key: Calendar.errorKey.length > 0 ? Calendar.errorKey : "calendar.connectedHint"
            color: Calendar.errorKey.length > 0 ? Colors.color.error : Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
    }

    Connections {
        target: Calendar
        function onChecked(ok) {
            if (!ok)
                return;
            linkForm.clear();
            appleForm.clear();
            root.draft = "";
        }
    }
}
