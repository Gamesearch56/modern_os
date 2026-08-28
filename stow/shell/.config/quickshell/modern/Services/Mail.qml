// Opens Proton Mail. Modules must not call execDetached (layer rule).
pragma Singleton

import Quickshell

Singleton {
    id: root

    function openMail() {
        Quickshell.execDetached(["xdg-open", "https://mail.proton.me"]);
    }
}
