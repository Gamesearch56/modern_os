// Builds the searchable cheatsheet rows from Config.keybinds — the
// same table Settings > Keyboard edits. No second list to drift.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property var categoryOf: ({
        launcher: "applications", terminal: "applications", browser: "applications",
        browserIncognito: "applications",
        fileManager: "applications", settings: "applications", wallpaperPicker: "applications",
        taskbar: "applications",
        overview: "applications", spotify: "applications", aiChat: "applications",
        closeWindow: "windowManagement", fullscreen: "windowManagement",
        toggleFloating: "windowManagement", pseudoTile: "windowManagement",
        toggleSplit: "windowManagement",
        moveFocusLeft: "windowManagement", moveFocusRight: "windowManagement",
        moveFocusUp: "windowManagement", moveFocusDown: "windowManagement",
        moveWindowLeft: "windowManagement", moveWindowRight: "windowManagement",
        moveWindowUp: "windowManagement", moveWindowDown: "windowManagement",
        workspace1: "workspaces", workspace2: "workspaces", workspace3: "workspaces",
        workspace4: "workspaces", workspace5: "workspaces", workspace6: "workspaces",
        workspace7: "workspaces", workspace8: "workspaces", workspace9: "workspaces",
        workspace10: "workspaces",
        moveToWorkspace1: "workspaces", moveToWorkspace2: "workspaces",
        moveToWorkspace3: "workspaces", moveToWorkspace4: "workspaces",
        moveToWorkspace5: "workspaces", moveToWorkspace6: "workspaces",
        moveToWorkspace7: "workspaces", moveToWorkspace8: "workspaces",
        moveToWorkspace9: "workspaces", moveToWorkspace10: "workspaces",
        screenshotRegion: "screenshots", screenshotWindow: "screenshots",
        screenshotFull: "screenshots", colorPicker: "screenshots",
        cheatsheet: "system", powerMenu: "system", controlCenter: "system", lockScreen: "system", exitSession: "system",
        filePreview: "utilities", clipboardHistory: "utilities"
    })

    function rows(filter: string): var {
        const binds = Config.keybinds || ({});
        const needle = (filter || "").trim().toLowerCase();
        const out = [];
        for (const action in binds) {
            if (action.charAt(0) === "_")
                continue;
            if (action === "gameMode")
                continue;
            const combo = binds[action];
            if (typeof combo !== "string")
                continue;
            const cat = root.categoryOf[action];
            if (!cat)
                continue;
            const label = I18n.t("cheatsheet.action." + action);
            if (needle.length > 0 && label.toLowerCase().indexOf(needle) === -1 && combo.toLowerCase().indexOf(needle) === -1)
                continue;
            out.push({
                action: action,
                category: cat,
                combo: combo,
                caps: combo.split(" + ")
            });
        }
        out.sort((a, b) => a.category.localeCompare(b.category) || a.action.localeCompare(b.action));
        return out;
    }

    function grouped(filter: string): var {
        const all = root.rows(filter);
        return {
            left: root._pack(all, ["applications", "system", "utilities", "screenshots"]),
            right: root._pack(all, ["windowManagement", "workspaces"])
        };
    }

    function categoryIds(): var {
        return ["applications", "system", "utilities", "screenshots", "windowManagement", "workspaces"];
    }

    function categories(filter: string): var {
        return root._pack(root.rows(filter), root.categoryIds());
    }

    function itemsFor(category: string, filter: string): var {
        const all = root.rows(filter);
        const out = [];
        for (let i = 0; i < all.length; i++) {
            if (all[i].category === category)
                out.push(all[i]);
        }
        return out;
    }

    function _pack(all: var, ids: var): var {
        const cats = [];
        for (let i = 0; i < ids.length; i++) {
            const id = ids[i];
            const items = [];
            for (let j = 0; j < all.length; j++) {
                if (all[j].category === id)
                    items.push(all[j]);
            }
            if (items.length)
                cats.push({ id: id, items: items });
        }
        return cats;
    }
}
