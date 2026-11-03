// Boot snapshot and machine identity for Settings > Overview.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool watching: false
    property string cpu: ""
    property string gpu: ""
    property string memory: ""
    property string board: ""
    property string disk: ""
    // Release tag the desktop checkout sits on (updates check out tags);
    // a clone between tags shows its commit instead.
    property string version: ""
    property string commit: ""
    readonly property string os: root.version.length
        ? I18n.t("settings.overview.osNameVersion", { version: root.version })
        : (root.commit.length
            ? I18n.t("settings.overview.osNameDev", { commit: root.commit })
            : I18n.t("settings.overview.osName"))
    property string kernel: ""
    property string wm: ""
    property string shell: ""
    property real bootTotal: 0
    property var bootStages: []

    function refresh() {
        bootProc.running = true;
        hwProc.running = true;
        swProc.running = true;
    }

    onWatchingChanged: {
        if (root.watching)
            root.refresh();
    }

    function formatSeconds(n: real): string {
        return I18n.t("settings.overview.seconds", { n: Number(n || 0).toFixed(1) });
    }

    function _bytes(n: real): string {
        const v = Number(n) || 0;
        if (v >= 0.95 * 1e12) {
            const tb = v / 1e12;
            const label = Math.abs(tb - Math.round(tb)) < 0.08 ? String(Math.round(tb)) : tb.toFixed(1);
            return I18n.t("units.tb", { n: label });
        }
        if (v >= 1e9)
            return I18n.t("units.gb", { n: (v / 1e9).toFixed(0) });
        if (v >= 1e6)
            return I18n.t("units.mb", { n: (v / 1e6).toFixed(0) });
        return I18n.t("units.gb", { n: "0" });
    }

    function _installedRam(bytesStr: string): string {
        const bytes = Number(bytesStr);
        if (!(bytes > 0))
            return "";
        const gib = bytes / 1024 / 1024 / 1024;
        const sizes = [8, 16, 24, 32, 48, 64, 96, 128, 192, 256];
        let n = Math.max(1, Math.round(gib));
        for (let i = 0; i < sizes.length; i++) {
            if (Math.abs(gib - sizes[i]) / sizes[i] < 0.1) {
                n = sizes[i];
                break;
            }
        }
        return I18n.t("units.gb", { n: String(n) });
    }

    function _facts(text: string): var {
        const map = ({});
        const lines = (text || "").trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const tab = lines[i].indexOf("\t");
            if (tab < 0)
                continue;
            map[lines[i].slice(0, tab)] = lines[i].slice(tab + 1).trim();
        }
        return map;
    }

    function _parseHw(text: string) {
        const m = root._facts(text);
        root.cpu = m.cpu || "";
        root.gpu = m.gpu || "";
        root.memory = root._installedRam(m.memoryBytes || "");
        root.board = m.board || "";
        const disk = (m.disk || "").split(/\s+/);
        const used = root._bytes(Number(disk[0] || 0));
        const total = root._bytes(Number(disk[1] || 0));
        root.disk = Number(disk[1] || 0) > 0
            ? I18n.t("settings.overview.diskUsed", { used: used, total: total })
            : "";
    }

    function _parseSw(text: string) {
        const m = root._facts(text);
        root.kernel = m.kernel || "";
        root.wm = m.wm || "";
        root.version = m.version || "";
        root.commit = m.commit || "";
        const shell = (m.shell || "").trim();
        root.shell = (shell.length > 0 && shell.length <= 80) ? shell : "Quickshell";
    }

    function _parseBoot(text: string) {
        const src = (text || "").trim();
        if (src.length === 0)
            return;
        const total = src.match(/=\s*([0-9.]+)s/);
        if (total)
            root.bootTotal = Number(total[1]);
        const stages = [];
        const re = /([0-9.]+)s\s*\((\w+)\)/g;
        let m = re.exec(src);
        while (m !== null) {
            const id = m[2];
            if (id === "firmware" || id === "loader" || id === "kernel" || id === "initrd" || id === "userspace")
                stages.push({ id: id, seconds: Number(m[1]) });
            m = re.exec(src);
        }
        if (stages.length > 0)
            root.bootStages = stages;
        if (!total && stages.length === 0 && root.bootTotal === 0) {
            const first = src.match(/([0-9.]+)s/);
            if (first)
                root.bootTotal = Number(first[1]);
        }
    }

    Process {
        id: bootProc
        command: ["systemd-analyze"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseBoot(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: root._parseBoot(this.text)
        }
    }

    Process {
        id: hwProc
        command: ["sh", "-c", "awk -F: '/^model name/{sub(/^[ \\t]+/,\"\",$2); print \"cpu\\t\"$2; exit}' /proc/cpuinfo; gpu=$(glxinfo -B 2>/dev/null | awk -F': ' '/Device:/{gsub(/ \\(.*\\)/,\"\",$2); print $2; exit}'); [ -n \"$gpu\" ] || gpu=$(rocminfo 2>/dev/null | awk -F': *' '$1 ~ /^[ \\t]+Name$/ {n=$2} $1 ~ /Marketing Name/ {if (n ~ /^gfx/) {gsub(/[ \\t]+$/,\"\",$2); print $2; exit}}'); [ -n \"$gpu\" ] || gpu=$(lspci 2>/dev/null | awk -F': ' '/VGA compatible controller|3D controller|Display controller/{gsub(/ \\(rev [^)]*\\)/,\"\",$NF); print $NF; exit}'); printf 'gpu\\t%s\\n' \"$gpu\"; bs=$(printf '%d' \"0x$(cat /sys/devices/system/memory/block_size_bytes 2>/dev/null)\"); n=$(grep -l '^online$' /sys/devices/system/memory/memory*/state 2>/dev/null | wc -l); n=$((n + 0)); if [ \"$bs\" -gt 0 ] 2>/dev/null && [ \"$n\" -gt 0 ]; then printf 'memoryBytes\\t%s\\n' $((n * bs)); else awk '/MemTotal/{print \"memoryBytes\\t\"$2*1024; exit}' /proc/meminfo; fi; name=$(cat /sys/class/dmi/id/board_name 2>/dev/null | tr -d '\\r'); vendor=$(cat /sys/class/dmi/id/board_vendor 2>/dev/null | tr -d '\\r'); product=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr -d '\\r'); case \"$name\" in MS-*|\"\") printf 'board\\t%s%s\\n' \"${vendor:+$vendor }\" \"${product:-$name}\" ;; *) printf 'board\\t%s\\n' \"$name\" ;; esac; src=$(findmnt -nro SOURCE / | sed 's/\\[.*//'); pk=$(lsblk -no PKNAME \"$src\" 2>/dev/null | head -1); [ -n \"$pk\" ] || pk=$(lsblk -dno NAME \"$src\" 2>/dev/null | head -1); used=$(df -P -B1 / | awk 'NR==2{print $3}'); size=$(lsblk -bdno SIZE \"/dev/$pk\" 2>/dev/null); printf 'disk\\t%s %s\\n' \"$used\" \"$size\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseHw(this.text)
        }
    }

    Process {
        id: swProc
        environment: ({ MODERN_REPO: Paths.repo })
        command: ["sh", "-c", "printf 'version\\t%s\\n' \"$(git -C \"$MODERN_REPO\" describe --tags --exact-match 2>/dev/null)\"; printf 'commit\\t%s\\n' \"$(git -C \"$MODERN_REPO\" rev-parse --short HEAD 2>/dev/null)\"; printf 'kernel\\t%s\\n' \"$(uname -r)\"; printf 'wm\\t%s\\n' \"$(hyprland --version 2>/dev/null | head -1 | sed 's/ built from.*//')\"; shell=$(qs --version 2>/dev/null | head -1 | sed 's/ (.*//'); [ -n \"$shell\" ] || shell=$(quickshell --version 2>/dev/null | head -1 | sed 's/ (.*//'); [ -n \"$shell\" ] || shell=Quickshell; printf 'shell\\t%s\\n' \"$shell\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseSw(this.text)
        }
    }
}
