import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root
    spacing: Tokens.spacing.lg

    Model { id: model }

    readonly property bool hdrDisplay: {
        void MonitorCaps.gen;
        void Hypr.monitors;
        const list = Hypr.monitors?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            const caps = MonitorCaps.capsFor(String(list[i].name || ""));
            if (caps.known && caps.hdr)
                return true;
        }
        return false;
    }

    Component.onCompleted: {
        MonitorCaps.refresh();
        GamesLibrary.refresh();
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Tokens.spacing.xs
        rowSpacing: Tokens.spacing.xs

        MPercentTile {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            showTrack: false
            titleKey: "settings.gaming.last"
            valueText: root._lastWhen()
            detailText: root._lastName()
        }
        MPercentTile { Layout.fillWidth: true; showTrack: false; titleKey: "settings.gaming.hours"; valueText: root._hours() }
        MPercentTile { Layout.fillWidth: true; showTrack: false; titleKey: "settings.gaming.installed"; valueText: root._count(GamesLibrary.installed) }
        MPercentTile { Layout.fillWidth: true; showTrack: false; titleKey: "settings.gaming.disk"; valueText: root._disk() }
        MPercentTile { Layout.fillWidth: true; showTrack: false; titleKey: "settings.gaming.running"; valueText: root._play() }
    }

    RowLayout {
        visible: GamesLibrary.playing.length > 0
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.gaming.now"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
        }
        MText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            value: GamesLibrary.playing
        }
    }

    MSectionHeader { key: "settings.gaming.play"; topMargin: Tokens.spacing.sm }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText { key: "settings.fields.gameMode"; styleName: "bodyMedium"; color: Colors.color.onSurfaceVariant; Layout.fillWidth: true }
        MSwitch { checked: model.mode; onToggled: (v) => ConfigWrite.set("gaming.mode", v) }
    }
    MHint { key: "settings.hints.gameMode"; Layout.fillWidth: true }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText { key: "settings.fields.gameFullscreen"; styleName: "bodyMedium"; color: Colors.color.onSurfaceVariant; Layout.fillWidth: true }
        MSwitch { checked: model.autoFullscreen; onToggled: (v) => ConfigWrite.set("gaming.autoFullscreen", v) }
    }
    MHint { key: "settings.hints.gameFullscreen"; Layout.fillWidth: true }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText { key: "settings.fields.gameHdr"; styleName: "bodyMedium"; color: Colors.color.onSurfaceVariant; Layout.fillWidth: true }
        MSwitch {
            enabled: root.hdrDisplay
            checked: model.hdrSession && root.hdrDisplay
            onToggled: (v) => ConfigWrite.set("gaming.hdrSession", v)
        }
    }
    MHint { visible: root.hdrDisplay; key: "settings.hints.gameHdr"; Layout.fillWidth: true }
    MHint { visible: !root.hdrDisplay; key: "settings.hints.gameHdrOff"; Layout.fillWidth: true }

    MSectionHeader { key: "settings.gaming.ease"; topMargin: Tokens.spacing.xl }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText { key: "settings.fields.easePc"; styleName: "bodyMedium"; color: Colors.color.onSurfaceVariant; Layout.fillWidth: true }
        MSwitch {
            checked: model.browserLight || model.autoOptimize
            onToggled: (v) => { ConfigWrite.set("gaming.browserLight", v); ConfigWrite.set("gaming.autoOptimize", v); }
        }
    }
    MHint { key: "settings.hints.easePc"; Layout.fillWidth: true }

    function _none(): string { return I18n.t("settings.gaming.none"); }
    function _hours(): string {
        if (!GamesLibrary.ready) return root._none();
        const h = GamesLibrary.hours;
        const n = h < 10 ? Math.round(h * 10) / 10 : Math.round(h);
        return I18n.t("settings.gaming.hoursValue", ({ n: n }));
    }
    function _count(n: int): string {
        if (!GamesLibrary.ready) return root._none();
        return I18n.t("settings.gaming.countValue", ({ n: n }));
    }
    function _disk(): string {
        if (!GamesLibrary.ready) return root._none();
        const gb = GamesLibrary.bytes / (1024 * 1024 * 1024);
        const n = gb >= 10 ? Math.round(gb) : Math.round(gb * 10) / 10;
        return I18n.t("settings.gaming.diskValue", ({ n: n }));
    }
    function _lastWhen(): string {
        if (!GamesLibrary.ready || !GamesLibrary.last) return root._none();
        return Qt.formatDateTime(new Date(GamesLibrary.last * 1000), "d MMM yyyy");
    }
    function _lastName(): string {
        if (!GamesLibrary.ready || !GamesLibrary.last) return "";
        return GamesLibrary.lastName || "";
    }
    function _play(): string {
        return GamesLibrary.playing.length ? GamesLibrary.playing : root._none();
    }
}
