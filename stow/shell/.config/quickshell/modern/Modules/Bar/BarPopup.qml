import QtQuick
import "../../Widgets"
import "../../Services"

MPopup {
    id: root

    onOpenChanged: {
        if (root.open)
            Popups.opened();
        else
            Popups.closed();
    }

    Connections {
        target: Popups
        function onCloseRequested() {
            root.open = false;
        }
    }
}
