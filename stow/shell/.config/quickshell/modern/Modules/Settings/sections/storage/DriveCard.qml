import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MCard {
    id: root

    property var drive: ({})

    readonly property bool _ejectable: !!(drive && drive.external)
    readonly property bool _busy: Storage.ejecting === (drive.name || "")
    readonly property real _frac: {
        const fs = Number(drive.fsSize) || 0;
        if (fs <= 0)
            return 0;
        return Math.max(0, Math.min(1, (Number(drive.used) || 0) / fs));
    }

    Layout.fillWidth: true
    level: 1
    implicitHeight: body.implicitHeight + Tokens.spacing.md * 2

    readonly property string tranKey: {
        const t = String(drive.tran || "");
        if (t === "usb")
            return "settings.storage.usb";
        if (t === "nvme")
            return "settings.storage.nvme";
        if (t === "sata" || t === "ata")
            return "settings.storage.sata";
        return "";
    }

    function _speedLabel(): string {
        void I18n._gen;
        const raw = String(drive.speedRaw || "");
        if (raw.indexOf("GT/s") !== -1) {
            const gt = parseFloat(raw);
            const lanes = raw.split("|")[1] || "";
            let gen = "1.0";
            if (gt >= 64)
                gen = "6.0";
            else if (gt >= 32)
                gen = "5.0";
            else if (gt >= 16)
                gen = "4.0";
            else if (gt >= 8)
                gen = "3.0";
            else if (gt >= 5)
                gen = "2.0";
            return I18n.t("settings.storage.pcie", ({ gen: gen, n: lanes }));
        }
        if (/^\d+(\.\d+)?$/.test(raw)) {
            const mbps = Number(raw);
            if (mbps >= 1000)
                return I18n.t("settings.storage.gbps", ({ n: mbps % 1000 === 0 ? String(mbps / 1000) : (mbps / 1000).toFixed(1) }));
            if (mbps > 0)
                return I18n.t("settings.storage.mbps", ({ n: String(Math.round(mbps)) }));
        }
        return "";
    }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: Tokens.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.lg

            MIcon {
                name: drive.iconName || "drive-harddisk"
                size: Tokens.spacing.xxl * 2
                color: Colors.color.onSurface
                tint: true
                preferSymbolic: true
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.xs
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.md
                    MText {
                        value: drive.title || drive.name || ""
                        styleName: "titleLarge"
                        Layout.fillWidth: true
                    }
                    MButton {
                        visible: root._ejectable
                        kind: "destructive"
                        key: "settings.storage.eject"
                        enabled: !root._busy
                        onClicked: Storage.eject(drive.name)
                    }
                }
                MText {
                    visible: root.tranKey.length > 0
                    key: root.tranKey
                    styleName: "bodyMedium"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
                MLinearProgress {
                    visible: (Number(drive.fsSize) || 0) > 0
                    Layout.fillWidth: true
                    value: root._frac
                }
                MText {
                    visible: (Number(drive.size) || 0) > 0
                    key: "settings.storage.space"
                    params: ({
                        used: Storage.formatBytes(drive.used),
                        total: Storage.formatBytes(drive.fsSize || drive.size),
                        free: Storage.formatBytes(drive.avail)
                    })
                    styleName: "bodySmall"
                    color: Colors.color.onSurfaceVariant
                    Layout.fillWidth: true
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs

            Repeater {
                model: {
                    void I18n._gen;
                    const out = [];
                    const kind = drive.rota ? "settings.storage.hdd" : "settings.storage.ssd";
                    out.push(I18n.t(kind));
                    const spd = root._speedLabel();
                    if (spd.length)
                        out.push(spd);
                    if (drive.fstype)
                        out.push(String(drive.fstype));
                    if (drive.mount)
                        out.push(drive.mount);
                    if (drive.serial)
                        out.push(drive.serial);
                    if (!(Number(drive.fsSize) || 0) && (Number(drive.size) || 0))
                        out.push(Storage.formatBytes(drive.size));
                    return out;
                }
                Rectangle {
                    required property var modelData
                    implicitHeight: Tokens.spacing.xl
                    implicitWidth: chipLab.implicitWidth + Tokens.spacing.md * 2
                    radius: Tokens.radius.full
                    color: Colors.color.surfaceContainerHighest
                    MText {
                        id: chipLab
                        anchors.centerIn: parent
                        value: modelData
                        styleName: "labelLarge"
                    }
                }
            }
        }
    }
}
