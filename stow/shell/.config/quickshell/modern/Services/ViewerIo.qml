pragma Singleton

import Quickshell
import QtQuick

// The Imageviewer's only door to the disk: scripts/viewer-io.sh, one job
// at a time and in order (JsonJobs).
Singleton {
    id: root

    readonly property bool busy: jobs.busy

    function run(args: var, done: var) {
        jobs.run(args, null, done);
    }

    JsonJobs {
        id: jobs
        script: "viewer-io.sh"
        tag: "ViewerIo"
    }
}
