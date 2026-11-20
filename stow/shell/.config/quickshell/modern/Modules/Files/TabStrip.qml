import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Item {
    id: root

    property int _over: 0

    visible: FilesTabs.paths.length > 1
    height: visible ? Tokens.spacing.xxl + Tokens.spacing.sm : 0

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: (drag) => { FilesDrag.offer(drag); FilesDrag.cover(); root._over += 1; }
        onExited: { root._over = Math.max(0, root._over - 1); FilesDrag.uncover(); }
    }

    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: Tokens.spacing.xs

        Repeater {
            model: FilesTabs.paths
            delegate: Item {
                id: tab
                required property string modelData
                required property int index
                readonly property bool _land: FilesDrag.active && FilesDrag.drop === tab.modelData
                width: Math.min(label.implicitWidth + Tokens.spacing.xxl + Tokens.spacing.lg, Tokens.spacing.xxl * 7)
                height: Tokens.spacing.xxl + Tokens.spacing.sm

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius.small
                    color: tab._land ? Colors.color.primaryContainer
                        : tab.index === FilesTabs.index ? Chrome.navSelected.bg : Colors.color.onSurface
                    opacity: tab._land || tab.index === FilesTabs.index ? 1 : (hover.hovered ? Tokens.interaction.hover : 0)
                    border.width: tab._land ? Tokens.stroke.focus : 0
                    border.color: Colors.color.primary
                }

                HoverHandler { id: hover }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing.sm
                    anchors.rightMargin: Tokens.spacing.xs
                    spacing: Tokens.spacing.xs

                    MText {
                        id: label
                        Layout.fillWidth: true
                        styleName: "bodyMedium"
                        color: tab._land ? Colors.color.onPrimaryContainer
                            : tab.index === FilesTabs.index ? Chrome.navSelected.fg : Colors.color.onSurface
                        elide: Text.ElideRight
                        text: root.labelOf(tab.modelData)
                    }
                    MIconButton {
                        iconName: "window-close"
                        key: "files.tabs.close"
                        size: Tokens.spacing.xl
                        iconSize: Tokens.icon.sm
                        glyphColor: tab._land ? Colors.color.onPrimaryContainer
                            : tab.index === FilesTabs.index ? Chrome.navSelected.fg : Colors.color.onSurface
                        onClicked: {
                            FilesTabs.closeAt(tab.index);
                            const next = FilesTabs.paths[FilesTabs.index];
                            if (next && Files.path !== next)
                                Files.go(next, false);
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: Tokens.spacing.xl + Tokens.spacing.sm
                    onClicked: {
                        FilesTabs.pick(tab.index);
                        const next = FilesTabs.paths[tab.index];
                        if (next && Files.path !== next)
                            Files.go(next, false);
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onEntered: (drag) => {
                            FilesDrag.offer(drag);
                            FilesDrag.cover();
                            root._over += 1;
                            FilesDrag.drop = tab.modelData;
                        }
                        onExited: {
                            root._over = Math.max(0, root._over - 1);
                            if (FilesDrag.drop === tab.modelData)
                                FilesDrag.drop = "";
                            FilesDrag.uncover();
                        }
                        onDropped: (drag) => {
                            FilesDrag.offer(drag);
                            if (!FilesDrag.active)
                                return;
                            FilesDrag.drop = tab.modelData;
                            drag.accept(Qt.MoveAction);
                            FilesDrag.land();
                        }
                    }
                }
            }
        }
    }

    function labelOf(path: string): string {
        if (path === "/")
            return I18n.t("files.path.root");
        const parts = String(path || "").split("/");
        return parts.length ? parts[parts.length - 1] : path;
    }
}
