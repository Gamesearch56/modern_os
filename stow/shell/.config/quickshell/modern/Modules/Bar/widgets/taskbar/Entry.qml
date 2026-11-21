import QtQuick
import QtQuick.Window
import "../../../../Commons"
import "../../../../Widgets"
import "../../../../Services"

MListItem {
    id: item

    property int index: 0
    property var host: null

    readonly property var entry: host ? host.entryAt(index) : null
    readonly property string address: String(item.entry?.address || "")
    readonly property int wsId: Number(item.entry?.wsId || 0)
    readonly property string cls: String(item.entry?.cls || "application-x-executable")
    readonly property bool background: !!(item.entry?.background)
    readonly property bool headless: item.entry?.kind === "tray" || item.entry?.kind === "process"
    readonly property bool tray: item.entry?.kind === "tray"

    tabFocus: false
    iconName: item.tray ? "" : String(item.entry?.icon || item.cls)
    imageSource: item.tray ? String(item.entry?.iconUrl || "") : ""
    tintIcon: false
    preferSymbolic: false
    titleValue: String(item.entry?.title || item.cls)
    subtitleValue: {
        if (item.background)
            return I18n.t("bar.taskbarBackground");
        if (item.wsId > 0 && host)
            return host.workspaceLabel(item.wsId);
        return "";
    }
    selected: !!(host && (host.currentIndex === item.index || host.menuIndex === item.index))

    function clickClose(): bool {
        if (!closeBtn.visible)
            return false;
        closeBtn.clicked();
        return true;
    }

    onClicked: {
        if (!host)
            return;
        host.currentIndex = item.index;
        host.activateCurrent();
    }
    onMiddleClicked: item.clickClose()
    onRightClicked: {
        if (!host)
            return;
        if (host.menuIndex === item.index) {
            host.closeMenu();
            return;
        }
        const win = Window.window ? Window.window.contentItem : host;
        const p = item.mapToItem(win, 0, 0);
        host.currentIndex = item.index;
        host.menuRowY = p.y;
        host.menuRowH = item.height;
        host.menuAddress = item.address;
        host.menuBackground = item.background;
        host.menuKind = item.headless ? (item.tray ? "tray" : "process") : "window";
        host.menuEntry = item.entry;
        host.menuIndex = item.index;
    }

    MIconButton {
        id: closeBtn
        z: 3
        close: true
        tabFocus: false
        escapeClicks: false
        iconName: "window-close-symbolic"
        key: "bar.close"
        size: Tokens.spacing.xl
        iconSize: Tokens.icon.xs
        highlighted: !!(host && host.closeFocus && host.currentIndex === item.index)
        onClicked: {
            if (host)
                host.closeAt(item.index);
            else
                Taskbar.close(item.entry);
        }
    }
}
