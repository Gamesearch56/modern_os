pragma Singleton

import Quickshell
import QtQuick

// The Mediaplayer's only door to the disk: scripts/player-io.sh, one job
// at a time and in order (JsonJobs). Playback reads the file through Qt
// Multimedia, never through here.
Singleton {
    id: root

    readonly property bool busy: jobs.busy

    function run(args: var, done: var) {
        jobs.run(args, null, done);
    }

    JsonJobs {
        id: jobs
        script: "player-io.sh"
        tag: "PlayerIo"
    }
}
