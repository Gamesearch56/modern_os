// Frosted login backdrop. Desktop MFrost cannot be imported here.
import Quickshell
import QtQuick

Item {
    id: root

    property var chrome: null
    property string username: ""
    property string source: "file:///var/lib/modern/session/wallpaper-blur.jpg"

    function _user() {
        return String(root.username || "").replace(/[^A-Za-z0-9._-]/g, "");
    }

    function _userBlur() {
        const u = root._user();
        return u.length ? "file:///var/lib/modern/session/wallpapers/" + u + "-blur.jpg" : "";
    }

    onUsernameChanged: {
        const next = root._userBlur();
        root.source = next.length ? next : "file:///var/lib/modern/session/wallpaper-blur.jpg";
    }

    Rectangle {
        anchors.fill: parent
        color: (root.chrome && root.chrome.color && root.chrome.color.surface)
            ? root.chrome.color.surface : "#141218"
    }

    Image {
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        Accessible.ignored: true
        onStatusChanged: {
            if (status !== Image.Error)
                return;
            const u = root._user();
            const userBlur = u.length ? "file:///var/lib/modern/session/wallpapers/" + u + "-blur.jpg" : "";
            const userJpg = u.length ? "file:///var/lib/modern/session/wallpapers/" + u + ".jpg" : "";
            const sharedBlur = "file:///var/lib/modern/session/wallpaper-blur.jpg";
            if (userBlur.length && root.source === userBlur)
                root.source = userJpg;
            else if (userJpg.length && root.source === userJpg)
                root.source = sharedBlur;
            else if (root.source === sharedBlur)
                root.source = "file:///var/lib/modern/session/wallpaper.jpg";
            else if (root.source.indexOf("default.jpg") < 0)
                root.source = "file://" + Quickshell.env("HOME") + "/.config/modern/wallpapers/default.jpg";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: (root.chrome && root.chrome.color && root.chrome.color.surface)
            ? root.chrome.color.surface : "#141218"
        opacity: root.chrome ? root.chrome.transparency : 0.85
        Accessible.ignored: true
    }

    Rectangle {
        anchors.fill: parent
        color: (root.chrome && root.chrome.color && root.chrome.color.scrim)
            ? root.chrome.color.scrim : "#000000"
        opacity: root.chrome ? root.chrome.overlayLock : 0.32
        Accessible.ignored: true
    }
}
