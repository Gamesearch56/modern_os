import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MStatusCard {
    id: root

    iconName: "system-software-update"
    preferSymbolic: false
    iconColor: Colors.color.primary
    titleKey: {
        if (Update.checking && Update.pending.length === 0)
            return "settings.update.checking";
        if (Update.desktop && Update.desktop.pending === true && String(Update.desktop.to || "").length)
            return "settings.update.desktopAvailable";
        if (Update.pending.length === 1)
            return "settings.update.availableOne";
        if (Update.pending.length > 0)
            return "settings.update.available";
        return "settings.update.upToDate";
    }
    titleParams: ({ n: String(Update.pending.length), v: String((Update.desktop && Update.desktop.to) || "") })

    trailing: MButton {
        kind: "tonal"
        key: "settings.update.search"
        iconName: "view-refresh"
        iconAfter: true
        busy: Update.checking
        enabled: Passwd.canManage && !Update.running && !Update.mirrorsRunning
        onClicked: Update.refresh()
    }

    MLinearProgress {
        visible: Update.checking
        Layout.fillWidth: true
        indeterminate: true
    }
}
