import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

ColumnLayout {
    id: root

    required property var rule
    property bool busy: false

    signal removeClicked(var rule)
    signal editClicked(var rule)

    readonly property real fromWidth: Tokens.spacing.xxl * 7
    readonly property real actionWidth: Tokens.spacing.xxl * 2 + Tokens.spacing.sm

    readonly property string _port: {
        void I18n._gen;
        const p = String(rule.port || "").trim();
        if (p.length)
            return p;
        const t = String(rule.to || "").replace(/\/(tcp|udp)$/i, "").trim();
        return t.length ? t : I18n.t("settings.firewall.anywhere");
    }

    readonly property string _from: {
        void I18n._gen;
        const f = String(rule.from || "").trim();
        if (!f.length || /^anywhere$/i.test(f))
            return I18n.t("settings.firewall.anywhere");
        return f;
    }

    readonly property var _chips: {
        void I18n._gen;
        const out = [];
        const proto = String(rule.proto || "");
        if (proto === "tcp")
            out.push(I18n.t("settings.firewall.protoTcp"));
        else if (proto === "udp")
            out.push(I18n.t("settings.firewall.protoUdp"));
        else
            out.push(I18n.t("settings.firewall.protoAny"));
        out.push(I18n.t(rule.direction === "out" ? "settings.firewall.dirOut" : "settings.firewall.dirIn"));
        if (rule.v6)
            out.push(I18n.t("settings.firewall.ipv6"));
        return out;
    }

    spacing: Tokens.spacing.sm
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.xs
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.sm
                MText {
                    value: root._port
                    styleName: "bodyLarge"
                    Layout.alignment: Qt.AlignVCenter
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Tokens.spacing.xs
                    Repeater {
                        model: root._chips
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
            MText {
                visible: String(rule.comment || "").length > 0
                value: String(rule.comment || "")
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
        }

        MText {
            value: root._from
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            elide: Text.ElideRight
            Layout.preferredWidth: root.fromWidth
            Layout.maximumWidth: root.fromWidth
            Layout.alignment: Qt.AlignVCenter
        }

        RowLayout {
            Layout.preferredWidth: root.actionWidth
            Layout.maximumWidth: root.actionWidth
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.spacing.xs
            Item { Layout.fillWidth: true }
            MIconButton {
                iconName: "document-edit-symbolic"
                key: "settings.firewall.edit"
                iconSize: Tokens.icon.md
                enabled: !root.busy
                onClicked: root.editClicked(root.rule)
            }
            MIconButton {
                iconName: "edit-delete-symbolic"
                key: "settings.firewall.delete"
                iconSize: Tokens.icon.md
                enabled: !root.busy
                onClicked: root.removeClicked(root.rule)
            }
        }
    }

    MDivider {
        Layout.fillWidth: true
    }
}
