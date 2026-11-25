// Step 4: sending, then what happened to the report.
import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.md

    readonly property var _look: ({
        sent: { icon: "emblem-ok-symbolic", key: "bugReport.sent" },
        queued: { icon: "network-offline", key: "bugReport.queued" },
        notSetUp: { icon: "dialog-information", key: "bugReport.notSetUpHint" },
        refused: { icon: "dialog-error", key: "bugReport.refused" },
        failed: { icon: "dialog-error", key: "bugReport.failed" },
        exported: { icon: "document-save", key: "bugReport.exported" }
    })
    readonly property string phase: BugReport.sending ? "sending" : BugReport.result
    readonly property var look: root._look[root.phase] || ({ icon: "mail-send", key: "bugReport.sending" })

    MLinearProgress {
        Layout.fillWidth: true
        visible: BugReport.sending
        indeterminate: true
    }

    MStatusCard {
        Layout.fillWidth: true
        iconName: root.look.icon
        iconColor: root.phase === "refused" || root.phase === "failed" ? Colors.color.error : Colors.color.primary
        titleKey: root.phase.length ? "bugReport.resultTitle." + root.phase : ""

        detail: MHint {
            Layout.fillWidth: true
            key: root.look.key
            params: ({ n: String(BugReport.issueNumber), path: BugReport.exportPath })
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
