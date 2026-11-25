import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg
    Layout.fillWidth: true

    property var previews: []

    Component.onCompleted: {
        Wallpaper.refresh();
        if ((Wallpaper.images || []).length > 0)
            root._reshuffle();
    }

    Connections {
        target: Wallpaper
        function onImagesChanged() {
            if (root.previews.length === 0)
                root._reshuffle();
        }
    }

    function _reshuffle() {
        const cur = Wallpaper.currentPath;
        const pool = (Wallpaper.images || []).filter(p => p && p !== cur);
        for (let i = pool.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const t = pool[i];
            pool[i] = pool[j];
            pool[j] = t;
        }
        root.previews = pool.slice(0, 9);
    }

    function _pick(index: int) {
        const path = String(root.previews[index] || "");
        if (!path.length)
            return;
        const prev = Wallpaper.currentPath;
        Wallpaper.setWallpaper(path);
        const next = root.previews.slice();
        if (prev && prev.length > 0 && prev !== path)
            next[index] = prev;
        else
            next.splice(index, 1);
        root.previews = next;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        MImageTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 2
            Layout.preferredHeight: Tokens.spacing.xxl * 7
            source: {
                void Wallpaper.thumbsRev;
                return Wallpaper.currentPath.length > 0
                    ? Wallpaper.tileSource(Wallpaper.currentPath)
                    : "";
            }
            selected: Wallpaper.currentPath.length > 0
        }

        GridLayout {
            visible: root.previews.length > 0
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: Tokens.spacing.xxl * 7
            columns: 3
            rowSpacing: Tokens.spacing.xs
            columnSpacing: Tokens.spacing.xs

            Repeater {
                model: root.previews.length
                MImageTile {
                    required property int index
                    readonly property string path: String(root.previews[index] || "")
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    source: {
                        void Wallpaper.thumbsRev;
                        return path.length > 0 ? Wallpaper.tileSource(path) : "";
                    }
                    onClicked: root._pick(index)
                    tabFocus: true
                }
            }
        }
    }

    MButton {
        kind: "tonal"
        key: "wallpaper.browse"
        onClicked: Wallpaper.pick()
    }
}
