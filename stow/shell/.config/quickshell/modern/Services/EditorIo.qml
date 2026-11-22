pragma Singleton

import Quickshell
import QtQuick

// The Texteditor's only door to the disk: scripts/editor-io.sh, one job
// at a time and in order (JsonJobs).
Singleton {
    id: root

    readonly property bool busy: jobs.busy

    function run(args: var, input: var, done: var) {
        jobs.run(args, input, done);
    }

    JsonJobs {
        id: jobs
        script: "editor-io.sh"
        tag: "EditorIo"
    }
}
