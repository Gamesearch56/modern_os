// Match / parse helpers for Brightness.qml (line-cap split).
import QtQuick

QtObject {
    id: root

    function matchFor(list: var, description: string): var {
        const desc = String(description || "").toLowerCase();
        const rows = list || [];
        let backlight = null;
        let ddcCount = 0;
        for (let i = 0; i < rows.length; i++) {
            const d = rows[i];
            if (!d)
                continue;
            if (String(d.backend) === "brightnessctl") {
                backlight = d;
                continue;
            }
            if (String(d.backend) !== "ddcutil")
                continue;
            ddcCount++;
            const serial = String(d.serial || "").toLowerCase();
            const model = String(d.model || "").toLowerCase();
            const connector = String(d.connector || "").toLowerCase();
            if (serial.length > 0 && desc.indexOf(serial) !== -1)
                return d;
            if (model.length > 0 && desc.indexOf(model) !== -1)
                return d;
            if (connector.length > 0 && desc.indexOf(connector) !== -1)
                return d;
        }
        if (desc.length === 0)
            return backlight;
        if (backlight && ddcCount === 0)
            return backlight;
        return null;
    }

    function canControl(list: var, description: string): bool {
        return root.matchFor(list, description) !== null;
    }

    function canAdjust(list: var, description: string): bool {
        const d = root.matchFor(list, description);
        return !!(d && d.ok !== false);
    }

    function percentFor(list: var, description: string, fallback: int): int {
        const d = root.matchFor(list, description);
        if (d && typeof d.percent === "number" && d.percent > 0)
            return d.percent;
        return fallback;
    }

    function parseList(text: string): var {
        try {
            const j = JSON.parse(text);
            return j?.displays || [];
        } catch (e) {
            return null;
        }
    }

    function parseGet(text: string): var {
        const raw = String(text || "").trim();
        if (!raw.length || raw.charAt(0) !== "{")
            return null;
        try {
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    function anyOk(list: var): bool {
        const rows = list || [];
        for (let i = 0; i < rows.length; i++) {
            if (rows[i] && rows[i].ok !== false)
                return true;
        }
        return false;
    }
}
