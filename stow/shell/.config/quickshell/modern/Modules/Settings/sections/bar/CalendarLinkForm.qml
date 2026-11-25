import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

// Proton, Google, or one shared Apple calendar: paste its iCal link.
ColumnLayout {
    id: root

    property string provider: "proton"

    signal back()
    signal useAppleId()

    readonly property string _link: String(linkField.text || "").trim()
    readonly property string _problem: CalendarAccount.linkProblem(root.provider, root._link)

    spacing: Tokens.spacing.md
    Layout.fillWidth: true

    function _connect() {
        if (root._link.length && !Calendar.checking)
            Calendar.check(root.provider, root._link, "", "");
    }

    function clear() {
        linkField.text = "";
    }

    CalendarSteps {
        keys: root.provider === "google"
            ? ["calendar.googleStep1", "calendar.googleStep2", "calendar.googleStep3"]
            : (root.provider === "apple"
                ? ["calendar.appleLinkStep1", "calendar.appleLinkStep2", "calendar.appleLinkStep3"]
                : ["calendar.protonStep1", "calendar.protonStep2", "calendar.protonStep3"])
    }

    MButton {
        visible: root.provider !== "apple"
        kind: "outlined"
        iconName: root.provider === "google" ? "google-agenda" : ""
        iconSource: root.provider === "google" ? "" : Qt.resolvedUrl("proton-calendar.svg")
        iconTint: false
        key: root.provider === "google" ? "calendar.openGoogle" : "calendar.openProton"
        fillWidth: true
        onClicked: root.provider === "google" ? CalendarAccount.openGoogle() : CalendarAccount.openProton()
    }

    MField {
        labelKey: "calendar.calendarLink"
        MTextField {
            id: linkField
            placeholderKey: "calendar.linkPlaceholder"
            onAccepted: root._connect()
        }
    }

    MHint {
        visible: root._problem.length > 0 || Calendar.errorKey.length > 0
        key: root._problem.length > 0 ? root._problem : Calendar.errorKey
        color: Colors.color.error
        Layout.fillWidth: true
    }
    MHint {
        visible: root.provider === "google"
        key: "calendar.googleWorkNote"
        Layout.fillWidth: true
    }

    MButton {
        visible: root.provider === "apple"
        kind: "text"
        key: "calendar.appleUseId"
        onClicked: root.useAppleId()
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
            enabled: root._link.length > 0 && root._problem.length === 0
            onClicked: root._connect()
        }
    }
}
