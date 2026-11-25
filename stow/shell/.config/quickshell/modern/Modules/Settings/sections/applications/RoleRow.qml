import QtQuick
import QtQuick.Layouts
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MListItem {
    id: root

    property string role: ""
    property bool allowEmpty: false

    signal pick()

    readonly property string appId: String((Config.apps.defaults && Config.apps.defaults[root.role]) || "")
    readonly property string appName: Apps.displayName(root.role)
    readonly property string _fallback: {
        if (root.role === "browser")
            return "web-browser";
        if (root.role === "calendar")
            return "office-calendar";
        if (root.role === "mail")
            return "mail-message";
        if (root.role === "communication")
            return "user-available";
        if (root.role === "fileManager")
            return "folder";
        if (root.role === "videoPlayer")
            return "video-x-generic";
        if (root.role === "imageViewer")
            return "image-x-generic";
        if (root.role === "textEditor")
            return "text-x-generic";
        if (root.role === "terminal")
            return "utilities-terminal";
        return "application-x-executable";
    }

    Layout.fillWidth: true
    tintIcon: root.appId.length === 0
    preferSymbolic: root.appId.length === 0
    iconName: root.appId.length > 0 ? Apps.iconForId(root.appId) : root._fallback
    titleKey: "settings.fields." + root.role
    subtitleValue: root.appName.length > 0 ? root.appName : (root.allowEmpty ? I18n.t("settings.selectNone") : "")
    onClicked: root.pick()

    MIcon {
        name: "go-next-symbolic"
        size: Tokens.icon.sm
        color: Colors.color.onSurfaceVariant
    }
}
