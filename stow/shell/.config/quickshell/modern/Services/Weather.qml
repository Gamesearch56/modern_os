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
    property real humidity: 0
    property real windSpeed: 0
    property real feelsLike: 0
    property string display: ""
    property string iconName: "weather-none"
    property string conditionKey: "weather.unavailable"
    property bool watching: false
    property int weatherCode: -1
    property bool isDay: true
    property bool _fromUser: false

    readonly property bool imperial: (Config.widgets?.weather?.units || "metric") === "imperial"

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: root.home + "/modern_dotfile/scripts/weather-fetch.sh"
    readonly property string manualLocation: Config.widgets?.weather?.manualLocation || ""
    readonly property string locationMode: Config.widgets?.weather?.locationMode || "auto"

    onManualLocationChanged: if (root.watching)
        root.refresh()
    onLocationModeChanged: if (root.watching)
        root.refresh()
    onImperialChanged: if (root.watching)
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
                if (t.length === 0)
                    return;
                if (root._fromUser)
                    Logger.error("Weather", t);
                else
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

    function refresh(fromUser: bool) {
        root._fromUser = !!fromUser;
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

    function _conditionKey(code: int): string {
        if (code < 0)
            return "weather.unavailable";
        if (code === 0)
            return "weather.clear";
        if (code <= 2)
            return "weather.partlyCloudy";
        if (code === 3)
            return "weather.overcast";
        if (code === 45 || code === 48)
            return "weather.fog";
        if (code >= 71 && code <= 86)
            return "weather.snow";
        if (code >= 95)
            return "weather.storm";
        if (code >= 51)
            return "weather.rain";
        return "weather.partlyCloudy";
    }

    function _parse(text: string) {
        try {
            const j = JSON.parse(text);
            const t = j?.current?.temperature_2m;
            if (typeof t !== "number") {
                root.available = false;
                root.display = "";
                root.iconName = "weather-none";
                root.conditionKey = "weather.unavailable";
                if (root._fromUser)
                    Logger.error("Weather", I18n.t("weather.unavailable"));
                root._fromUser = false;
                return;
            }
            root.tempC = t;
            root.humidity = Number(j.current.relative_humidity_2m ?? 0);
            root.windSpeed = Number(j.current.wind_speed_10m ?? 0);
            root.feelsLike = Number(j.current.apparent_temperature ?? t);
            root.weatherCode = Number(j.current.weather_code ?? -1);
            root.isDay = Number(j.current.is_day ?? 1) !== 0;
            root.available = true;
            root.display = `${Math.round(t)}°`;
            root.iconName = root._iconFor(root.weatherCode, root.isDay);
            root.conditionKey = root._conditionKey(root.weatherCode);
            root._fromUser = false;
        } catch (e) {
            root.available = false;
            root.display = "";
            root.iconName = "weather-none";
            root.conditionKey = "weather.unavailable";
            if (root._fromUser)
                Logger.error("Weather", I18n.t("weather.unavailable"));
            else
                Logger.warn("Weather", "parse failed: " + e);
            root._fromUser = false;
        }
    }
}
