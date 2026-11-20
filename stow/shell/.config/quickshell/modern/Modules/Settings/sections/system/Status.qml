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
    // The release card below already shows the version. This line sits
    // beside the search button, so it only names that a release is waiting.
    function _desktopShown(): bool {
        const list = Update.pending || [];
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (String(p && p.kind || "") === "desktop" && String(p && p.to || "").length > 0)
                return true;
        }
        return false;
    }

    titleKey: {
        if (Update.restarting)
            return "settings.update.restarting";
        if (Update.checking && Update.pending.length === 0)
            return "settings.update.checking";
        if (root._desktopShown())
            return "settings.update.desktopBanner";
        if (Update.pending.length === 1)
            return "settings.update.availableOne";
        if (Update.pending.length > 0)
            return "settings.update.available";
        return "settings.update.upToDate";
    }
    titleParams: ({ n: String(Update.pending.length) })

    trailing: MButton {
        kind: "tonal"
        key: "settings.update.search"
        iconName: "view-refresh"
        iconAfter: true
        busy: Update.checking
        enabled: Passwd.canManage && !Update.running && !Update.mirrorsRunning && !Update.restarting
        onClicked: Update.refresh()
    }

    MLinearProgress {
        visible: Update.checking || Update.restarting
        Layout.fillWidth: true
        indeterminate: true
    }
}
