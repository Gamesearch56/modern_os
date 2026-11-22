// One scripts/bug-report.sh step for Services/BugReport. Logs its stderr
// and an unexpected exit, so a broken step leaves a trace in the shell
// log instead of only an empty screenshot or file list.
import Quickshell.Io
import QtQuick
import "../Commons"

Process {
    id: proc

    // Exit codes the caller handles as answers, not failures.
    property var expectedCodes: [0]
    readonly property string step: String((proc.command || [])[1] || "bug-report")

    stderr: StdioCollector {
        onStreamFinished: {
            const text = String(this.text || "").trim();
            if (text.length)
                Logger.warn("BugReport", proc.step + ": " + text.slice(-800));
        }
    }

    onExited: (code) => {
        if (proc.expectedCodes.indexOf(code) < 0)
            Logger.warn("BugReport", proc.step + " exited " + code);
    }
}
