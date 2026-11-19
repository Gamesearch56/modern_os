import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MCard {
    id: root

    Layout.fillWidth: true
    level: 0
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2

    readonly property var drive: Storage.systemDrive || ({})
    property string hoveredId: ""
    readonly property string _hot: StorageClean.open ? "" : root.hoveredId

    readonly property real _total: Number(drive.fsSize) || Number(drive.size) || 0
    readonly property real _used: Number(drive.used) || 0
    readonly property real _free: Number(drive.avail) || 0

    readonly property var rows: {
        void StorageUsage.games;
        void StorageUsage.files;
        void StorageUsage.apps;
        void StorageUsage.cache;
        void StorageUsage.backups;
        void StorageUsage.models;
        void Colors.color.primary;
        const cats = [
            { id: "games", bytes: StorageUsage.games, color: Colors.color.primary, key: "settings.storage.catGames" },
            { id: "files", bytes: StorageUsage.files, color: Colors.color.secondary, key: "settings.storage.catFiles" },
            { id: "apps", bytes: StorageUsage.apps, color: Colors.color.tertiary, key: "settings.storage.catApps" },
            { id: "models", bytes: StorageUsage.models, color: Colors.color.tertiaryContainer, key: "settings.storage.catModels" },
            { id: "cache", bytes: StorageUsage.cache, color: Colors.color.primaryContainer, key: "settings.storage.catCache" },
            { id: "backups", bytes: StorageUsage.backups, color: Colors.color.secondaryContainer, key: "settings.storage.catBackups" }
        ];
        let sum = 0;
        for (let i = 0; i < cats.length; i++)
            sum += Number(cats[i].bytes) || 0;
        cats.push({
            id: "other",
            bytes: Math.max(0, root._used - sum),
            color: Colors.color.outline,
            key: "settings.storage.catOther"
        });
        cats.push({
            id: "free",
            bytes: root._free,
            color: Colors.color.surfaceContainerHighest,
            key: "settings.storage.catFree"
        });
        const total = root._total > 0 ? root._total : (root._used + root._free);
        const out = [];
        for (let j = 0; j < cats.length; j++) {
            const n = Number(cats[j].bytes) || 0;
            // A new snapshot shares the live disk, so its own size is 0
            // until the system changes. Keep the row so that stays visible.
            if (n <= 0 && cats[j].id !== "free" && cats[j].id !== "backups")
                continue;
            out.push({
                id: cats[j].id,
                key: cats[j].key,
                color: cats[j].color,
                bytes: n,
                frac: total > 0 ? n / total : 0,
                size: Storage.formatBytes(n)
            });
        }
        return out;
    }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.md
            MText {
                key: "settings.storage.system"
                styleName: "titleSmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MIconButton {
                visible: StorageUsage.measured
                iconName: "view-refresh"
                key: "settings.refresh"
                iconSize: Tokens.icon.sm
                enabled: !StorageUsage.running
                onClicked: StorageUsage.refresh()
            }
        }
        MText {
            value: drive.title || drive.name || ""
            styleName: "titleLarge"
            Layout.fillWidth: true
        }
        MText {
            visible: root._total > 0
            value: Storage.formatBytes(root._free)
            styleName: "displaySmall"
            color: Colors.color.primary
            Layout.fillWidth: true
        }
        MText {
            visible: root._total > 0
            key: "settings.storage.usedOf"
            params: ({
                used: Storage.formatBytes(root._used),
                total: Storage.formatBytes(root._total)
            })
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MStackedBar {
            visible: root._total > 0
            Layout.fillWidth: true
            implicitHeight: Tokens.spacing.lg
            activeId: root._hot
            segments: {
                const segs = [];
                const list = root.rows;
                for (let i = 0; i < list.length; i++)
                    segs.push({
                        id: list[i].id,
                        frac: list[i].frac,
                        color: list[i].color
                    });
                return segs;
            }
            onHovered: (id) => root.hoveredId = id
        }
        MLinearProgress {
            visible: StorageUsage.running
            Layout.fillWidth: true
            indeterminate: true
        }
        Item {
            visible: !StorageUsage.measured
            Layout.fillWidth: true
            implicitHeight: Tokens.spacing.xxl * 4

            MButton {
                anchors.centerIn: parent
                kind: "filled"
                key: "settings.storage.measure"
                busy: StorageUsage.running
                enabled: !StorageUsage.running
                onClicked: StorageUsage.start()
            }
        }
        Repeater {
            model: StorageUsage.measured ? root.rows : []
            Item {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: catRow.implicitHeight
                opacity: !root._hot || root._hot === modelData.id ? 1 : 0.38

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.shortMs
                        easing.bezierCurve: Motion.easingStandard
                    }
                }

                RowLayout {
                    id: catRow
                    width: parent.width
                    spacing: Tokens.spacing.md
                    Rectangle {
                        Layout.preferredWidth: Tokens.spacing.md
                        Layout.preferredHeight: Tokens.spacing.md
                        radius: Tokens.radius.full
                        color: modelData.color
                        border.color: Colors.color.outlineVariant
                        border.width: Tokens.stroke.hairline
                    }
                    MText {
                        key: modelData.key
                        styleName: "bodyMedium"
                        Layout.fillWidth: true
                    }
                    MText {
                        value: modelData.size
                        styleName: "labelLarge"
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: !StorageClean.open
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        if (!StorageClean.open)
                            root.hoveredId = modelData.id;
                    }
                    onExited: {
                        if (root.hoveredId === modelData.id)
                            root.hoveredId = "";
                    }
                }
            }
        }
    }
}
