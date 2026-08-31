import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"
import "."

ColumnLayout {
    id: root

    spacing: Tokens.spacing.md

    readonly property bool kdeOn: Config.kdeconnect.enabled
    onKdeOnChanged: KdeConnect.watching = root.kdeOn

    Component.onCompleted: {
        KdeConnect.watching = Config.kdeconnect.enabled;
        Qt.callLater(root._scrollToFeed);
    }

    MSectionHeader {
        key: "settings.privacy.notifications"
        topMargin: 0
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "notifications.dnd"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: Notifications.dnd
            onToggled: (v) => Notifications.dnd = v
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.privacy.quietHours"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.fillWidth: true
        }
        MSwitch {
            checked: !!(Config.general.dndSchedule.enabled)
            onToggled: (v) => ConfigWrite.set("general.dndSchedule.enabled", v)
        }
    }
    RowLayout {
        visible: !!(Config.general.dndSchedule.enabled)
        Layout.fillWidth: true
        spacing: Tokens.spacing.md

        MField {
            Layout.fillWidth: true
            labelKey: "settings.fields.dndFrom"
            MTextField {
                id: fromField
                text: Config.general.dndSchedule.from
                onAccepted: ConfigWrite.set("general.dndSchedule.from", text)
                onFocusedChanged: {
                    if (!fromField.focused)
                        ConfigWrite.set("general.dndSchedule.from", fromField.text);
                }
            }
        }
        MField {
            Layout.fillWidth: true
            labelKey: "settings.fields.dndTo"
            MTextField {
                id: toField
                text: Config.general.dndSchedule.to
                onAccepted: ConfigWrite.set("general.dndSchedule.to", text)
                onFocusedChanged: {
                    if (!toField.focused)
                        ConfigWrite.set("general.dndSchedule.to", toField.text);
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        MText {
            key: "settings.privacy.bannerDuration"
            styleName: "bodyMedium"
            color: Colors.color.onSurfaceVariant
            Layout.preferredWidth: Tokens.spacing.xxl * 8
        }
        MSlider {
            Layout.fillWidth: true
            from: 2
            to: 15
            value: (Config.general.notificationTimeoutMs ?? 6000) / 1000
            showValue: true
            onCommitted: (v) => ConfigWrite.set("general.notificationTimeoutMs", Math.round(v) * 1000)
        }
    }

    MSectionHeader {
        key: "settings.privacy.connectedServices"
        topMargin: Tokens.spacing.xxl
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.md
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MText {
                key: "settings.fields.kdeconnectEnabled"
                styleName: "bodyMedium"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
            MText {
                value: root.kdeOn && KdeConnect.connectedCount > 0
                    ? I18n.t("kdeconnect.connected", ({ count: KdeConnect.connectedCount }))
                    : I18n.t("kdeconnect.off")
                styleName: "bodySmall"
                color: Colors.color.onSurfaceVariant
                Layout.fillWidth: true
            }
        }
        MSwitch {
            checked: root.kdeOn
            onToggled: (v) => ConfigWrite.set("kdeconnect.enabled", v)
        }
    }

    MSectionHeader {
        id: calendarHeader
        key: "settings.privacy.calendar"
        topMargin: Tokens.spacing.xxl
    }
    CalendarFeed {
        id: calendarFeed
        Layout.fillWidth: true
    }

    function _flickable() {
        let p = root.parent;
        while (p) {
            if (p.flickableDirection !== undefined)
                return p;
            p = p.parent;
        }
        return null;
    }

    function _scrollToFeed() {
        if (Settings.subsectionId !== "calendar")
            return;
        if (calendarFeed.height <= 0 || calendarHeader.y <= 0)
            return;
        const flick = root._flickable();
        if (!flick)
            return;
        const pos = calendarHeader.mapToItem(flick.contentItem, 0, 0);
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        flick.contentY = Math.min(maxY, Math.max(0, pos.y - Tokens.spacing.md));
        Settings.subsectionId = "";
        calendarFeed.focusField();
    }

    Connections {
        target: Settings
        function onSubsectionIdChanged() { Qt.callLater(root._scrollToFeed); }
    }

    onImplicitHeightChanged: Qt.callLater(root._scrollToFeed)
}
