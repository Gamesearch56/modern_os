import QtQuick
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
            uid: Number(modelData.uid) || 0
            summary: modelData.summary || modelData.appName || ""
            body: modelData.body || ""
            image: modelData.image || ""
            appIcon: modelData.appIcon || ""
            expireTimeout: {
                const v = modelData.expireTimeout;
                if (v === undefined || v === null)
                    return Notifications.timeoutMs;
                const n = Number(v);
                return n === n ? n : 0;
            }
            shownAt: Number(modelData.shownAt) || 0
            notification: modelData
        }
    }
}
