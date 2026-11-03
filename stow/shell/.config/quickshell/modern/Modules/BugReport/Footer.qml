// Back / Next / Send, then Save as file / Close once it is done.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

RowLayout {
    spacing: Tokens.spacing.sm

    readonly property bool done: BugReport.step === 3
    readonly property bool named: BugReport.title.trim().length > 0

    MButton {
        kind: "text"
        iconName: "go-previous"
        key: "bugReport.back"
        visible: BugReport.step > 0 && !parent.done
        onClicked: BugReport.goTo(BugReport.step - 1)
    }

    MHint {
        Layout.fillWidth: true
        visible: BugReport.step === 0 && !parent.named
        key: "bugReport.needSummary"
    }

    Item {
        Layout.fillWidth: true
        visible: BugReport.step !== 0 || parent.named
    }

    MButton {
        kind: "tonal"
        iconName: "document-save"
        key: "bugReport.export"
        visible: parent.done && BugReport.result !== "sent" && !BugReport.sending
        onClicked: BugReport.exportReport()
    }

    MButton {
        iconName: "go-next"
        iconAfter: true
        key: "bugReport.next"
        visible: BugReport.step < 2
        enabled: parent.named
        onClicked: BugReport.goTo(BugReport.step + 1)
    }

    MButton {
        iconName: "mail-send"
        key: "bugReport.send"
        visible: BugReport.step === 2 || (parent.done && (BugReport.result === "notSetUp" || BugReport.result === "failed" || BugReport.result === "refused"))
        enabled: BugReport.canSend
        busy: BugReport.sending
        onClicked: {
            BugReport.goTo(3);
            BugReport.send();
        }
    }

    MButton {
        key: "bugReport.close"
        visible: parent.done && !BugReport.sending
        onClicked: BugReport.hide()
    }
}
