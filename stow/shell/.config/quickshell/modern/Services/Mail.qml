// Opens Proton Mail in the browser when no desktop mail app is set.
// Prefer Apps.launch("mail") from Modules so fallbacks apply.
pragma Singleton

import Quickshell

Singleton {
    id: root

    function openMail() {
        Quickshell.execDetached(["xdg-open", "https://mail.proton.me"]);
    }
}
