#!/usr/bin/env python3
"""MET Norway locationforecast/2.0 "complete" JSON -> the Open-Meteo shape
Services/Weather.qml parses. weather-fetch.sh falls back to it when
Open-Meteo fails, so a single provider outage does not blank the widget.

Usage: weather-metno.py FORECAST.json LAT LON metric|imperial

MET has no sunrise in the forecast (and the sunrise API is one request
per day), so sunrise/sunset come from the sunrise equation. Precipitation
probability exists only for the Nordics; elsewhere it reads 0.
Times are local to this machine, like Open-Meteo's timezone=auto.
"""
import json
import math
import sys
from datetime import date, datetime, timedelta, timezone

# Substring of MET's symbol_code -> WMO code, first match wins.
SYMBOLS = [
    ("thunder", 95),
    ("heavysnow", 75), ("lightsnow", 71), ("snow", 73),
    ("sleet", 68),
    ("heavyrainshowers", 82), ("lightrainshowers", 80), ("rainshowers", 81),
    ("heavyrain", 65), ("lightrain", 61), ("rain", 63),
    ("fog", 45),
    ("fair", 1), ("clearsky", 0),
]


def wmo(symbol):
    base = symbol.split("_")[0]
    if base == "cloudy":
        return 3
    if base == "partlycloudy":
        return 2
    for key, code in SYMBOLS:
        if key in base:
            return code
    return -1


def sun_times(day, lat, lon):
    """Sunrise and sunset (aware UTC datetimes) or (None, None) in polar day/night."""
    jd0 = (datetime(day.year, day.month, day.day, tzinfo=timezone.utc).timestamp() / 86400.0) + 2440587.5
    n = math.ceil(jd0 - 2451545.0 + 0.0008)
    j_star = n - lon / 360.0
    m = (357.5291 + 0.98560028 * j_star) % 360.0
    mr = math.radians(m)
    c = 1.9148 * math.sin(mr) + 0.02 * math.sin(2 * mr) + 0.0003 * math.sin(3 * mr)
    lam = math.radians((m + c + 180.0 + 102.9372) % 360.0)
    transit = 2451545.0 + j_star + 0.0053 * math.sin(mr) - 0.0069 * math.sin(2 * lam)
    decl = math.asin(math.sin(lam) * math.sin(math.radians(23.4397)))
    phi = math.radians(lat)
    cos_w = (math.sin(math.radians(-0.833)) - math.sin(phi) * math.sin(decl)) / (math.cos(phi) * math.cos(decl))
    if cos_w < -1 or cos_w > 1:
        return None, None
    w = math.degrees(math.acos(cos_w)) / 360.0

    def at(j):
        return datetime.fromtimestamp((j - 2440587.5) * 86400.0, tz=timezone.utc)

    return at(transit - w), at(transit + w)


def iso(dt):
    return dt.astimezone().strftime("%Y-%m-%dT%H:%M") if dt else ""


def main():
    path, lat, lon, units = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
    with open(path, encoding="utf-8") as f:
        series = json.load(f)["properties"]["timeseries"]
    imperial = units == "imperial"

    def temp(c):
        return round(c * 9 / 5 + 32, 1) if imperial else round(c, 1)

    def wind(ms):
        return round(ms * (2.236936 if imperial else 3.6), 1)

    def rain(mm):
        return round(mm / 25.4, 2) if imperial else round(mm, 1)

    suns = {}

    def sun(day):
        if day not in suns:
            suns[day] = sun_times(day, lat, lon)
        return suns[day]

    def is_day(symbol, when):
        if symbol.endswith("_night"):
            return 0
        if symbol.endswith("_day") or symbol.endswith("_polartwilight"):
            return 1
        rise, set_ = sun(when.astimezone().date())
        if rise is None:
            # Polar day in the hemisphere's summer, polar night otherwise.
            return 1 if (lat > 0) == (4 <= when.month <= 9) else 0
        return 1 if rise <= when <= set_ else 0

    def symbol_of(data, *keys):
        for k in keys:
            s = data.get(k, {}).get("summary", {}).get("symbol_code")
            if s:
                return s
        return ""

    rows = []
    for entry in series:
        when = datetime.fromisoformat(entry["time"].replace("Z", "+00:00"))
        data = entry.get("data", {})
        inst = data.get("instant", {}).get("details", {})
        if "air_temperature" not in inst:
            continue
        rows.append((when, data, inst))
    if not rows:
        raise SystemExit("weather-metno: empty forecast")

    when, data, inst = rows[0]
    sym = symbol_of(data, "next_1_hours", "next_6_hours", "next_12_hours")
    current = {
        "temperature_2m": temp(inst["air_temperature"]),
        "apparent_temperature": temp(inst.get("apparent_air_temperature", inst["air_temperature"])),
        "relative_humidity_2m": inst.get("relative_humidity", 0),
        "wind_speed_10m": wind(inst.get("wind_speed", 0)),
        "pressure_msl": inst.get("air_pressure_at_sea_level", 0),
        "cloud_cover": inst.get("cloud_area_fraction", 0),
        "precipitation": rain(data.get("next_1_hours", {}).get("details", {}).get("precipitation_amount", 0)),
        "weather_code": wmo(sym),
        "is_day": is_day(sym, when),
    }

    hourly = {k: [] for k in ("time", "temperature_2m", "weather_code", "precipitation_probability", "wind_speed_10m", "is_day")}
    days = {}
    for when, data, inst in rows:
        local = when.astimezone()
        one = data.get("next_1_hours")
        if one:
            s = symbol_of(data, "next_1_hours")
            hourly["time"].append(iso(when))
            hourly["temperature_2m"].append(temp(inst["air_temperature"]))
            hourly["weather_code"].append(wmo(s))
            hourly["precipitation_probability"].append(one.get("details", {}).get("probability_of_precipitation", 0))
            hourly["wind_speed_10m"].append(wind(inst.get("wind_speed", 0)))
            hourly["is_day"].append(is_day(s, when))
        d = days.setdefault(local.date(), {"t": [], "wind": [], "uv": [], "pop": [], "noon": None})
        d["t"].append(inst["air_temperature"])
        six = data.get("next_6_hours", {}).get("details", {})
        for k in ("air_temperature_max", "air_temperature_min"):
            if k in six:
                d["t"].append(six[k])
        d["wind"].append(inst.get("wind_speed", 0))
        d["uv"].append(inst.get("ultraviolet_index_clear_sky", 0))
        for k in ("next_1_hours", "next_6_hours"):
            p = data.get(k, {}).get("details", {}).get("probability_of_precipitation")
            if p is not None:
                d["pop"].append(p)
        s = symbol_of(data, "next_6_hours", "next_1_hours", "next_12_hours")
        gap = abs(local.hour - 12)
        if s and (d["noon"] is None or gap < d["noon"][0]):
            d["noon"] = (gap, s)

    daily = {k: [] for k in ("time", "weather_code", "temperature_2m_max", "temperature_2m_min", "precipitation_probability_max", "wind_speed_10m_max", "uv_index_max", "sunrise", "sunset")}
    for day in sorted(days)[:7]:
        d = days[day]
        rise, set_ = sun(day)
        daily["time"].append(day.isoformat())
        daily["weather_code"].append(wmo(d["noon"][1]) if d["noon"] else -1)
        daily["temperature_2m_max"].append(temp(max(d["t"])))
        daily["temperature_2m_min"].append(temp(min(d["t"])))
        daily["precipitation_probability_max"].append(max(d["pop"]) if d["pop"] else 0)
        daily["wind_speed_10m_max"].append(wind(max(d["wind"])))
        daily["uv_index_max"].append(max(d["uv"]))
        daily["sunrise"].append(iso(rise))
        daily["sunset"].append(iso(set_))

    json.dump({"current": current, "hourly": hourly, "daily": daily}, sys.stdout)


if __name__ == "__main__":
    main()
