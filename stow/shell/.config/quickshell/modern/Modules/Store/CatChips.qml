import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Widgets"
import "../../Services"

Flow {
    id: root

    readonly property var chips: {
        void Store.categories;
        const all = Store.categories || [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const c = all[i] || ({});
            const id = String(c.id || "");
            if (id === "discover" || id === "installed")
                continue;
            if (!(c.packages && c.packages.length))
                continue;
            out.push(c);
        }
        return out;
    }

    visible: root.chips.length > 0
    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    Repeater {
        model: root.chips.length

        MChip {
            required property int index
            readonly property var rowData: root.chips[index] || ({})
            key: "store.categories." + (rowData.id || "")
            onClicked: Store.setCategory(rowData.id)
        }
    }
}
