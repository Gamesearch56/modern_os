// Open-Meteo current + 7-day forecast. Fetch: scripts/weather-fetch.sh.
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
    property real precip: 0
    property real pressure: 0
    property real tMax: 0
    property real tMin: 0
    property real uv: 0
    property string sunrise: ""
    property string sunset: ""
    property var daily: []
    property var hourly: []
    property string display: ""
    property string iconName: "weather-none"
    property string conditionKey: "weather.unavailable"
    property bool watching: false
    property int weatherCode: -1
    property bool isDay: true
    property bool _fromUser: false
    property bool busy: false

    readonly property bool imperial: (Config.widgets?.weather?.units || "metric") === "imperial"

    readonly property string windText: root.formatWind(root.windSpeed)

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
        root.busy = true;
        proc.running = false;
        proc.command = [root.script];
        proc.running = true;
    }

    function formatWind(speed: real): string {
        const p = {};
        p.speed = Math.round(speed);
        return I18n.t(root.imperial ? "weather.windMph" : "weather.windKmh", p);
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
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
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

    function _days(j: var): var {
        const d = j?.daily;
        if (!d || !d.time)
            return [];
        const out = [];
        const n = Math.min(7, d.time.length);
        for (let i = 0; i < n; i++) {
            const code = Number(d.weather_code?.[i] ?? -1);
            out.push({
                iso: String(d.time[i] || ""),
                code: code,
                tMax: Number(d.temperature_2m_max?.[i] ?? 0),
                tMin: Number(d.temperature_2m_min?.[i] ?? 0),
                precip: Number(d.precipitation_probability_max?.[i] ?? 0),
                wind: Number(d.wind_speed_10m_max?.[i] ?? 0),
                uv: Number(d.uv_index_max?.[i] ?? 0),
                sunrise: String(d.sunrise?.[i] || ""),
                sunset: String(d.sunset?.[i] || ""),
                icon: root._iconFor(code, true),
                conditionKey: root._conditionKey(code)
            });
        }
        return out;
    }

    function _hours(j: var): var {
        const h = j?.hourly;
        if (!h || !h.time)
            return [];
        const today = String(j?.daily?.time?.[0] || "").slice(0, 10);
        const out = [];
        for (let i = 0; i < h.time.length; i++) {
            const iso = String(h.time[i] || "");
            if (today.length && iso.slice(0, 10) !== today)
                continue;
            const code = Number(h.weather_code?.[i] ?? -1);
            const day = Number(h.is_day?.[i] ?? 1) !== 0;
            out.push({
                iso: iso,
                temp: Number(h.temperature_2m?.[i] ?? 0),
                precip: Number(h.precipitation_probability?.[i] ?? 0),
                wind: Number(h.wind_speed_10m?.[i] ?? 0),
                icon: root._iconFor(code, day),
                conditionKey: root._conditionKey(code)
            });
        }
        return out;
    }

    function _clear() {
        root.available = false;
        root.display = "";
        root.daily = [];
        root.hourly = [];
        root.iconName = "weather-none";
        root.conditionKey = "weather.unavailable";
    }

    function _parse(text: string) {
        try {
            const j = JSON.parse(text);
            const t = j?.current?.temperature_2m;
            if (typeof t !== "number") {
                root._clear();
                if (root._fromUser)
                    Logger.error("Weather", I18n.t("weather.unavailable"));
                root._fromUser = false;
                root.busy = false;
                return;
            }
            const days = root._days(j);
            const today = days[0] || null;
            root.tempC = t;
            root.humidity = Number(j.current.relative_humidity_2m ?? 0);
            root.windSpeed = Number(j.current.wind_speed_10m ?? 0);
            root.feelsLike = Number(j.current.apparent_temperature ?? t);
            root.precip = Number(j.current.precipitation ?? 0);
            root.pressure = Number(j.current.pressure_msl ?? 0);
            root.weatherCode = Number(j.current.weather_code ?? -1);
            root.isDay = Number(j.current.is_day ?? 1) !== 0;
            root.tMax = today ? today.tMax : t;
            root.tMin = today ? today.tMin : t;
            root.uv = today ? today.uv : 0;
            root.sunrise = today ? today.sunrise : "";
            root.sunset = today ? today.sunset : "";
            root.daily = days;
            root.hourly = root._hours(j);
            root.available = true;
            root.display = `${Math.round(t)}°`;
            root.iconName = root._iconFor(root.weatherCode, root.isDay);
            root.conditionKey = root._conditionKey(root.weatherCode);
            root._fromUser = false;
            root.busy = false;
        } catch (e) {
            root._clear();
            if (root._fromUser)
                Logger.error("Weather", I18n.t("weather.unavailable"));
            else
                Logger.warn("Weather", "parse failed: " + e);
            root._fromUser = false;
            root.busy = false;
        }
    }
}
