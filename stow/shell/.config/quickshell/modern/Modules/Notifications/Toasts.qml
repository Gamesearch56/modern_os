import QtQuick
import QtQuick.Layouts
import "../../Commons"
import "../../Services"

Column {
    id: root
    width: Tokens.spacing.xxl * 12
    spacing: Tokens.spacing.sm

    Repeater {
        model: Notifications.toasts

        delegate: ToastCard {
            required property var modelData
            width: root.width
            summary: modelData.summary || modelData.appName || ""
            body: modelData.body || ""
            image: modelData.image || ""
            appIcon: modelData.appIcon || ""
            expireTimeout: Number(modelData.expireTimeout) || 0
            shownAt: modelData.shownAt || 0
            notification: modelData
        }
    }
}
