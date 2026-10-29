import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.xs
    Layout.fillWidth: true

    readonly property bool pruneOn: Config.backup.pruneEnabled !== false
    readonly property int keepCount: {
        const n = Number(Config.backup.keepCount);
        if (n >= 3 && n <= 20)
            return Math.round(n);
        return 8;
    }
    readonly property var keepChoices: {
        const out = [];
        for (let n = 3; n <= 20; n++)
            out.push({ value: n, titleValue: String(n) });
        return out;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.backupPrune"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: root.pruneOn
            onToggled: (v) => {
                ConfigWrite.set("backup.pruneEnabled", v);
                if (v)
                    Snapshots.prune(root.keepCount);
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.md
        spacing: Tokens.spacing.md
        MText {
            key: "settings.fields.backupKeep"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSelect {
            Layout.preferredWidth: Tokens.spacing.xxl * 5
            enabled: root.pruneOn
            model: root.keepChoices
            value: root.keepCount
            onSelected: (v) => {
                const n = Number(v);
                ConfigWrite.set("backup.keepCount", n);
                Snapshots.prune(n);
            }
        }
    }
    MHint {
        key: "settings.hints.backupPrune"
        params: ({ n: root.keepCount })
        Layout.fillWidth: true
    }
}
