// Open-Meteo current conditions. Location is IP-geolocated when
// widgets.weather.locationMode is auto, or widgets.weather.manualLocation
// (city name or "lat,lon"). Fetch lives in scripts/weather-fetch.sh.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../Commons"

Singleton {
    id: root

    property bool available: false
    property real tempC: 0
    property string display: ""
    property string iconName: "weather-none"
    property bool watching: false
    property int weatherCode: -1
    property bool isDay: true

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: root.home + "/modern_dotfile/scripts/weather-fetch.sh"
    readonly property string manualLocation: Config.widgets?.weather?.manualLocation || ""
    readonly property string locationMode: Config.widgets?.weather?.locationMode || "auto"

    onManualLocationChanged: if (root.watching)
        root.refresh()
    onLocationModeChanged: if (root.watching)
        root.refresh()

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t.length > 0)
                    Logger.warn("Weather", t);
            }
        }
    }

    Timer {
        interval: Config.widgets?.weather?.pollIntervalMs ?? 600000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        proc.running = false;
        proc.command = [root.script];
        proc.running = true;
    }

    function _iconFor(code: int, day: bool): string {
        if (code === 0)
            return day ? "weather-clear" : "weather-clear-night";
        if (code <= 2)
            return day ? "weather-few-clouds" : "weather-few-clouds-night";
        if (code === 3)
            return "weather-clouds";
        if (code === 45 || code === 48)
            return "weather-fog";
        if (code >= 71 && code <= 77)
            return "weather-snow";
        if (code === 85 || code === 86)
            return "weather-snow";
        if (code >= 95)
            return "weather-storm";
        if (code >= 51)
            return "weather-showers";
        return "weather-few-clouds";
    }

    function _parse(text: string) {
        try {
            const j = JSON.parse(text);
            const t = j?.current?.temperature_2m;
            if (typeof t !== "number") {
                root.available = false;
                root.display = "";
                root.iconName = "weather-none";
                return;
            }
            root.tempC = t;
            root.weatherCode = Number(j.current.weather_code ?? -1);
            root.isDay = Number(j.current.is_day ?? 1) !== 0;
            root.available = true;
            root.display = `${Math.round(t)}°`;
            root.iconName = root._iconFor(root.weatherCode, root.isDay);
        } catch (e) {
            root.available = false;
            root.display = "";
            root.iconName = "weather-none";
            Logger.warn("Weather", "parse failed: " + e);
        }
    }
}
