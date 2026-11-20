import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    MTextField {
        id: location
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: Files.locationOpen
        text: Files.path
        placeholderKey: "files.toolbar.location"
        onAccepted: {
            Files.locationOpen = false;
            Files.show(location.text);
        }
        onEscaped: Files.locationOpen = false
        onActiveFocusChanged: Files.typing = focused
        onVisibleChanged: if (visible) forceActiveFocus()
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        visible: !Files.locationOpen
        clip: true
        contentWidth: trail.implicitWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id: trail
            height: scroller.height
            spacing: Tokens.spacing.sm

            Repeater {
                model: root._crumbs
                delegate: Row {
                    id: segment
                    required property var modelData
                    required property int index
                    height: trail.height
                    spacing: Tokens.spacing.sm

                    MIcon {
                        visible: segment.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        name: "go-next"
                        size: Tokens.icon.xs
                        color: Colors.color.onSurfaceVariant
                    }

                    Item {
                        id: crumb
                        width: label.implicitWidth + (modelData.root ? Tokens.icon.xs + Tokens.spacing.xs : 0) + Tokens.spacing.sm * 2
                        height: parent.height

                        HoverHandler {
                            id: hover
                            cursorShape: segment.index === root._crumbs.length - 1 ? Qt.ArrowCursor : Qt.PointingHandCursor
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius.full
                            color: Colors.color.onSurface
                            opacity: {
                                if (FilesDrag.active && FilesDrag.drop === String(segment.modelData.path || ""))
                                    return Tokens.interaction.focus;
                                if (segment.index === root._crumbs.length - 1)
                                    return Tokens.interaction.focus;
                                if (hover.hovered)
                                    return Tokens.interaction.hover;
                                return 0;
                            }
                            border.width: FilesDrag.active && FilesDrag.drop === String(segment.modelData.path || "") ? Tokens.stroke.focus : 0
                            border.color: Colors.color.primary
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.xs
                            MIcon {
                                visible: modelData.root
                                anchors.verticalCenter: parent.verticalCenter
                                name: "drive-harddisk"
                                size: Tokens.icon.xs
                                color: Colors.color.onSurface
                            }
                            MText {
                                id: label
                                anchors.verticalCenter: parent.verticalCenter
                                key: modelData.key
                                value: modelData.label
                                styleName: "bodyMedium"
                                color: segment.index === root._crumbs.length - 1 ? Colors.color.onSurface : Colors.color.onSurfaceVariant
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: segment.index === root._crumbs.length - 1 ? Qt.ArrowCursor : Qt.PointingHandCursor
                            focus: true
                            onPressed: forceActiveFocus()
                            onClicked: {
                                if (segment.index === root._crumbs.length - 1)
                                    return;
                                const dest = String(segment.modelData.path || "");
                                const child = root._child(dest);
                                Files.go(dest, true, child.length ? [child] : []);
                            }
                        }

                        DropArea {
                            anchors.fill: parent
                            enabled: String(segment.modelData.path || "").charAt(0) === "/"
                            keys: ["text/uri-list"]
                            onEntered: (drag) => {
                                FilesDrag.offer(drag);
                                FilesDrag.cover();
                                FilesDrag.drop = String(segment.modelData.path || "");
                            }
                            onExited: {
                                if (FilesDrag.drop === String(segment.modelData.path || ""))
                                    FilesDrag.drop = "";
                                FilesDrag.uncover();
                            }
                            onDropped: (drag) => {
                                const dest = String(segment.modelData.path || "");
                                FilesDrag.offer(drag);
                                if (!FilesDrag.active || dest.charAt(0) !== "/")
                                    return;
                                FilesDrag.drop = dest;
                                drag.accept(Qt.MoveAction);
                                FilesDrag.land();
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: Files
        function onPathChanged() {
            Qt.callLater(() => scroller.contentX = Math.max(0, scroller.contentWidth - scroller.width));
        }
    }

    readonly property bool _shown: !FilesSearch.active && (Files.place !== "recent" || Files.locationOpen)

    readonly property var _crumbs: {
        if (FilesSearch.active || Files.place === "recent")
            return [];
        if (Files.place === "favorites")
            return [{ key: "files.places.favorites", label: "", path: "", root: false }];
        if (Files.place === "network")
            return [{ key: "files.places.network", label: "", path: "", root: false }];
        const path = Files.path || "/";
        const parts = path.split("/").filter(part => part.length > 0);
        const rows = [{ key: "files.path.root", label: "", path: "/", root: true }];
        let acc = "";
        for (let i = 0; i < parts.length; i++) {
            acc += "/" + parts[i];
            rows.push({ key: "", label: parts[i], path: acc, root: false });
        }
        return rows;
    }

    function _child(dest: string): string {
        if (Files.place !== "folder")
            return "";
        const current = String(Files.path || "");
        if (current.charAt(0) !== "/" || dest.charAt(0) !== "/")
            return "";
        if (dest === "/") {
            const leaf = current.split("/").filter(part => part.length > 0)[0] || "";
            return leaf.length ? "/" + leaf : "";
        }
        const prefix = dest + "/";
        if (current.indexOf(prefix) !== 0)
            return "";
        const leaf = current.slice(prefix.length).split("/")[0];
        return leaf.length ? prefix + leaf : "";
    }
}
