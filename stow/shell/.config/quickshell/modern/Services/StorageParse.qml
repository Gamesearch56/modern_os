// lsblk JSON → drive rows. Host is the Storage singleton.
import QtQuick

QtObject {
    id: root

    function skip(d: var): bool {
        const n = String(d.name || "");
        const t = String(d.type || "");
        if (t !== "disk")
            return true;
        if (n.indexOf("loop") === 0 || n.indexOf("zram") === 0 || n.indexOf("ram") === 0)
            return true;
        if ((Number(d.size) || 0) <= 0)
            return true;
        return false;
    }

    function isExternal(d: var): bool {
        const t = String(d.tran || "").toLowerCase();
        if (t === "usb" || t === "ieee1394" || t === "sbp2" || t === "firewire")
            return true;
        return d.rm === true || d.rm === "1";
    }

    function mountsOf(node: var): var {
        const out = [];
        const many = node.mountpoints;
        if (Array.isArray(many)) {
            for (let i = 0; i < many.length; i++) {
                const m = String(many[i] || "");
                if (m.length && out.indexOf(m) === -1)
                    out.push(m);
            }
        }
        const one = String(node.mountpoint || "");
        if (one.length && out.indexOf(one) === -1)
            out.push(one);
        return out;
    }

    function pickMount(mounts: var): string {
        const list = mounts || [];
        if (list.indexOf("/") !== -1)
            return "/";
        if (list.indexOf("/home") !== -1)
            return "/home";
        return list.length ? String(list[0]) : "";
    }

    function walkUsage(node: var, acc: var) {
        const kids = node.children || [];
        const mps = root.mountsOf(node);
        for (let i = 0; i < mps.length; i++)
            acc.mounts.push(mps[i]);
        if (kids.length) {
            for (let j = 0; j < kids.length; j++)
                root.walkUsage(kids[j], acc);
            return;
        }
        const fs = Number(node.fssize);
        if (fs > 0) {
            const key = String(node.label || node.path || fs);
            if (!acc.seen[key]) {
                acc.seen[key] = true;
                acc.fsSize += fs;
                acc.used += Number(node.fsused) || 0;
                acc.avail += Number(node.fsavail) || 0;
                if (fs >= acc.bestFs && node.fstype) {
                    acc.bestFs = fs;
                    acc.fstype = String(node.fstype);
                }
            }
        } else if (node.fstype && !acc.fstype) {
            acc.fstype = String(node.fstype);
        }
    }

    function normalize(d: var, speeds: var): var {
        const acc = { seen: ({}), fsSize: 0, used: 0, avail: 0, fstype: "", mounts: [], bestFs: 0 };
        root.walkUsage(d, acc);
        const external = root.isExternal(d);
        const name = String(d.name || "");
        const mounts = acc.mounts;
        return {
            name: name,
            title: String(d.model || name).trim(),
            serial: String(d.serial || "").trim(),
            tran: String(d.tran || "").toLowerCase(),
            external: external,
            system: mounts.indexOf("/") !== -1,
            rota: d.rota === true || d.rota === "1",
            size: Number(d.size) || 0,
            fsSize: acc.fsSize,
            used: acc.used,
            avail: acc.avail,
            fstype: acc.fstype,
            mount: root.pickMount(mounts),
            speedRaw: (speeds && speeds[name]) || "",
            iconName: external ? "drive-removable-media" : "drive-harddisk"
        };
    }
}
