pragma Singleton

// The Ko-fi page for this desktop. Settings cannot open a URL itself.
import Quickshell

Singleton {
    id: root

    function openKoFi() {
        Quickshell.execDetached(["xdg-open", "https://ko-fi.com/gamesearch56"]);
    }
}
