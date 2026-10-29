// Session user identity for PowerMenu and Settings → Users.
// Face from ~/.face or ~/.face.icon; display name from GECOS / $USER.
// Never a hardcoded username.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property string loginName: Quickshell.env("USER") || ""
    property string displayName: root.loginName
    property url faceUrl: ""

    readonly property string home: Quickshell.env("HOME")

    FileView {
        id: faceFile
        path: root.home + "/.face"
        watchChanges: true
        printErrors: false
        onFileChanged: root._refreshFace()
        onLoaded: root._refreshFace()
        onLoadFailed: root._refreshFace()
    }

    FileView {
        id: passwdFile
        path: "/etc/passwd"
        watchChanges: true
        printErrors: false
        onLoaded: root._parsePasswd(text())
        onLoadFailed: root.displayName = root.loginName
        onFileChanged: reload()
    }

    function _refreshFace() {
        const face = root.home + "/.face";
        const icon = root.home + "/.face.icon";
        if (faceFile.loaded)
            root.faceUrl = "file://" + face;
        else
            root.faceUrl = "file://" + icon;
    }

    function _parsePasswd(raw: string) {
        const user = root.loginName;
        const lines = (raw || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split(":");
            if (parts[0] !== user)
                continue;
            const gecos = (parts[4] || "").split(",")[0].trim();
            root.displayName = gecos.length > 0 ? gecos : user;
            return;
        }
        root.displayName = user;
    }
}
