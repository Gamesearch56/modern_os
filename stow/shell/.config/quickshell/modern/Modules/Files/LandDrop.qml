// The open folder is the landing place when the pointer is not on a subfolder.
import QtQuick
import "../../Commons"
import "../../Services"

DropArea {
    id: root

    keys: ["text/uri-list"]
    enabled: Files.place === "folder"

    onEntered: (drag) => {
        FilesDrag.offer(drag);
        FilesDrag.cover();
        if (FilesDrag.active)
            FilesDrag.drop = root._here();
    }
    onExited: FilesDrag.uncover()
    onDropped: (drag) => {
        FilesDrag.offer(drag);
        if (FilesDrag.active)
            FilesDrag.drop = root._here();
        if (!FilesDrag.active)
            return;
        drag.accept(Qt.MoveAction);
        FilesDrag.land();
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Tokens.radius.medium
        border.width: FilesDrag.active && FilesDrag.drop.length > 0 && FilesDrag.drop === root._here()
            ? Tokens.stroke.focus : 0
        border.color: Colors.color.primary
    }

    function _here(): string {
        const path = String(Files.path || "");
        return Files.place === "folder" && path.charAt(0) === "/" ? path : "";
    }
}
