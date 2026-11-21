// Builds the searchable cheatsheet rows from Config.keybinds — the
// same table Settings > Keyboard lists — plus static mouse gestures
// that are not remappable and must not go in keybinds.
pragma Singleton

import Quickshell
import QtQuick
import "../Commons"

Singleton {
    id: root

    readonly property var categoryOf: ({
        launcher: "applications",
        terminal: "applications", browser: "applications",
        browserIncognito: "applications",
        fileManager: "applications", spotify: "applications",
        filePreview: "applications",
        settings: "system", wallpaperPicker: "system",
        taskbar: "system", overview: "system", aiChat: "system",
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
        screenshotFull: "screenshots",
        colorPicker: "system", bugReport: "system",
        cheatsheet: "system", powerMenu: "system", controlCenter: "system",
        lockScreen: "system", exitSession: "system"
    })

    // Binds added after a config.json was first written. The live keybinds
    // object replaces the defaults wholesale, so a missing key would
    // otherwise never appear on the sheet. A saved combo still wins.
    readonly property var shipped: ({
        bugReport: "SUPER + #"
    })

    // Not in keybinds: the emergency terminal, hardware keys, and mouse
    // gestures. Clipboard history has no bind, so it stays off the sheet.
    readonly property var fixedBinds: [
        { action: "emergencyTerminal", combo: "SUPER + RETURN", category: "applications" },
        { action: "volumeUp", combo: "VOL +", category: "media" },
        { action: "volumeDown", combo: "VOL -", category: "media" },
        { action: "volumeMute", combo: "MUTE", category: "media" },
        { action: "micMute", combo: "MIC", category: "media" },
        { action: "mediaPlay", combo: "PLAY", category: "media" },
        { action: "mediaPause", combo: "PAUSE", category: "media" },
        { action: "mediaNext", combo: "NEXT", category: "media" },
        { action: "mediaPrev", combo: "PREV", category: "media" },
        { action: "brightnessUp", combo: "BRI +", category: "media" },
        { action: "brightnessDown", combo: "BRI -", category: "media" },
        { action: "mouseMoveSuper", combo: "SUPER + LMB", category: "mouse" },
        { action: "mouseResizeSuper", combo: "SUPER + RMB", category: "mouse" },
        { action: "mouseResizeBorder", combo: "BORDER + LMB", category: "mouse" },
        { action: "mouseMoveSide", combo: "MB4 + DRAG", category: "mouse", side: true },
        { action: "mouseResizeSide", combo: "MB5 + DRAG", category: "mouse", side: true },
        { action: "mouseCloseSide", combo: "MB4 + MB5", category: "mouse", side: true },
        { action: "mouseFloatSide", combo: "MB4 + MMB", category: "mouse", side: true },
        { action: "mouseFullscreenSide", combo: "MB5 + MMB", category: "mouse", side: true },
        { action: "mouseCloseApp", combo: "MMB", category: "mouse" }
    ]

    function _rowMatches(action: string, combo: string, category: string, needle: string): bool {
        if (!needle.length)
            return true;
        const label = I18n.t("cheatsheet.action." + action).toLowerCase();
        const catLabel = I18n.t("cheatsheet.category." + category).toLowerCase();
        return label.indexOf(needle) !== -1
            || combo.toLowerCase().indexOf(needle) !== -1
            || catLabel.indexOf(needle) !== -1
            || category.toLowerCase().indexOf(needle) !== -1;
    }

    function _labelOf(action: string): string {
        return I18n.t("cheatsheet.action." + action);
    }

    // Launcher stays first under Anwendungen; everything else A→Z by label.
    function _sortItems(items: var): var {
        items.sort((a, b) => {
            if (a.action === "launcher")
                return -1;
            if (b.action === "launcher")
                return 1;
            return root._labelOf(a.action).localeCompare(root._labelOf(b.action));
        });
        return items;
    }

    function _binds(): var {
        const live = Config.keybinds || ({});
        const out = {};
        const extra = root.shipped;
        for (const action in extra)
            out[action] = extra[action];
        for (const action in live) {
            const combo = live[action];
            if (typeof combo === "string" && combo.length)
                out[action] = combo;
        }
        return out;
    }

    function rows(filter: string): var {
        const binds = root._binds();
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
            if (!root._rowMatches(action, combo, cat, needle))
                continue;
            out.push({
                action: action,
                category: cat,
                combo: combo,
                caps: combo.split(" + ")
            });
        }
        const fixed = root.fixedBinds;
        const side = Config.input.mouseSideButtons !== false;
        for (let i = 0; i < fixed.length; i++) {
            const g = fixed[i];
            if ((g.side && !side) || !root._rowMatches(g.action, g.combo, g.category, needle))
                continue;
            out.push({
                action: g.action,
                category: g.category,
                combo: g.combo,
                caps: g.combo.split(" + ")
            });
        }
        out.sort((a, b) => a.category.localeCompare(b.category) || a.action.localeCompare(b.action));
        return out;
    }

    function grouped(filter: string): var {
        const all = root.rows(filter);
        return {
            left: root._pack(all, ["applications", "system", "screenshots", "media"]),
            right: root._pack(all, ["windowManagement", "workspaces", "mouse"])
        };
    }

    function categoryIds(): var {
        return ["applications", "system", "screenshots", "media", "windowManagement", "workspaces", "mouse"];
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
        return root._sortItems(out);
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
            root._sortItems(items);
            if (items.length)
                cats.push({ id: id, items: items });
        }
        return cats;
    }
}
