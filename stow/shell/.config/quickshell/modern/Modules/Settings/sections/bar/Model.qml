import QtQuick
import "../../../../Commons"

QtObject {
    id: root

    readonly property string layoutText: JSON.stringify({
        left: Config.bar.left,
        center: Config.bar.center,
        right: Config.bar.right
    })

    // Settings-list icons. Clock and workspaces stay text-only on the bar.
    readonly property var icons: ({
        launcher: "view-app-grid-symbolic",
        ai: "applications-science-symbolic",
        workspaces: "virtual-desktops",
        media: "media-playback-start-symbolic",
        taskbar: "focus-windows-symbolic",
        clock: "preferences-system-time-symbolic",
        weather: "weather-few-clouds",
        connectivity: "network-wireless-symbolic",
        audio: "audio-volume-high-symbolic",
        battery: "battery-good-symbolic",
        settings: "org.gnome.Settings-symbolic",
        power: "system-shutdown-symbolic"
    })

    function icon(id: string): string {
        return root.icons[id] || "";
    }

    function key(id: string): string {
        if (id === "ai")
            return "ai.title";
        return "bar." + id;
    }
}
