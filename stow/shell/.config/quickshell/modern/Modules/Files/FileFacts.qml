import QtQuick
import "../../Commons"
import "../../Services"

QtObject {
    readonly property real colSize: Tokens.spacing.xxl * 3
    readonly property real colDate: Tokens.spacing.xxl * 5
    readonly property real colType: Tokens.spacing.xxl * 3

    function sizeText(entry) {
        if (!entry)
            return I18n.t("files.details.none");
        const v = Number(entry.size);
        if (!isFinite(v) || v < 0)
            return I18n.t("files.details.none");
        if (v < 1024)
            return v + " " + I18n.t("files.units.byte");
        const units = ["kb", "mb", "gb", "tb"];
        let value = v / 1024;
        let at = 0;
        while (value >= 1024 && at < units.length - 1) {
            value = value / 1024;
            at = at + 1;
        }
        const shown = value >= 10 ? Math.round(value) : Math.round(value * 10) / 10;
        return shown + " " + I18n.t("files.units." + units[at]);
    }

    function whenText(sec) {
        const n = Number(sec) || 0;
        if (!n)
            return I18n.t("files.details.none");
        return Qt.formatDateTime(new Date(n * 1000), Qt.locale().dateTimeFormat(Locale.ShortFormat));
    }

    function dateText(sec) {
        const n = Number(sec) || 0;
        if (!n)
            return I18n.t("files.details.none");
        return Qt.formatDate(new Date(n * 1000), Qt.locale().dateFormat(Locale.ShortFormat));
    }

    function kindText(entry) {
        if (!entry)
            return "";
        if (entry.dir)
            return I18n.t("files.details.folder");
        if (entry.kind === "link")
            return I18n.t("files.details.link");
        if (!entry.kind || entry.kind === "file")
            return I18n.t("files.details.file");
        return String(entry.kind);
    }

    function gridDates(entry) {
        if (entry && entry.share)
            return "";
        const parts = [];
        if (Files.showCreated)
            parts.push(I18n.t("files.details.created") + " " + dateText(entry && entry.created));
        if (Files.showModified)
            parts.push(I18n.t("files.details.changed") + " " + dateText(entry && entry.mtime));
        return parts.join("\n");
    }

    function gridMeta(entry) {
        if (entry && entry.share)
            return "";
        const parts = [];
        if (Files.showSize)
            parts.push(sizeText(entry));
        if (Files.showType)
            parts.push(kindText(entry));
        return parts.join(" · ");
    }
}
