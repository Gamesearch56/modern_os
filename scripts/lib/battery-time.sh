#!/usr/bin/env bash
# UPower often prints "time to empty: unknown" while the kernel still
# has time_to_empty_now, or energy_now and power_now to divide.
# Sourced by battery-read.sh. Prints the text with those lines replaced.

battery_read_i() {
    local f="$1" n
    [ -f "$f" ] || { printf '0\n'; return 0; }
    n="$(tr -d '[:space:]' <"$f")"
    n="${n#-}"
    case "$n" in
        ''|*[!0-9]*) printf '0\n' ;;
        *) printf '%s\n' "$n" ;;
    esac
}

battery_apply_kernel_time() {
    local pack="$1" root="$2" text="$3"
    local native empty full status now rate efull enow cap_s
    if [ -z "$pack" ]; then
        native="$(printf '%s\n' "$text" | sed -n 's/^[[:space:]]*native-path:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"
        if [ -n "$native" ] && [ -d "$root/$native" ]; then
            pack="$root/$native"
        fi
    fi
    if [ -z "$pack" ] || [ ! -d "$pack" ]; then
        printf '%s\n' "$text"
        return 0
    fi
    empty="$(battery_read_i "$pack/time_to_empty_now")"
    full="$(battery_read_i "$pack/time_to_full_now")"
    status="$(tr -d '[:space:]' <"$pack/status" 2>/dev/null || true)"
    # Charge current is not a discharge rate. Only estimate while emptying.
    if [ "$empty" -le 0 ] && [ "$status" = Discharging ]; then
        now="$(battery_read_i "$pack/energy_now")"
        rate="$(battery_read_i "$pack/power_now")"
        if [ "$now" -le 0 ] || [ "$rate" -le 0 ]; then
            now="$(battery_read_i "$pack/charge_now")"
            rate="$(battery_read_i "$pack/current_now")"
        fi
        if [ "$now" -gt 0 ] && [ "$rate" -gt 0 ]; then
            empty=$(( now * 3600 / rate ))
        fi
    fi
    if [ "$full" -le 0 ] && [ "$status" = Charging ]; then
        efull="$(battery_read_i "$pack/energy_full")"
        enow="$(battery_read_i "$pack/energy_now")"
        rate="$(battery_read_i "$pack/power_now")"
        if [ "$efull" -le 0 ] || [ "$rate" -le 0 ]; then
            efull="$(battery_read_i "$pack/charge_full")"
            enow="$(battery_read_i "$pack/charge_now")"
            rate="$(battery_read_i "$pack/current_now")"
        fi
        if [ "$rate" -gt 0 ] && [ "$efull" -gt "$enow" ]; then
            full=$(( (efull - enow) * 3600 / rate ))
        fi
    fi
    cap_s=$((36 * 3600))
    [ "$empty" -gt "$cap_s" ] && empty=0
    [ "$full" -gt "$cap_s" ] && full=0
    if [ "$empty" -gt 0 ]; then
        text="$(printf '%s\n' "$text" | grep -Fiv 'time to empty:' || true)"
        text="${text}"$'\n'"time to empty:       ${empty} seconds"
    fi
    if [ "$full" -gt 0 ]; then
        text="$(printf '%s\n' "$text" | grep -Fiv 'time to full:' || true)"
        text="${text}"$'\n'"time to full:       ${full} seconds"
    fi
    printf '%s\n' "$text"
}
