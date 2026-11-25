.pragma library

// Signal as 0–4 bars, the unit lists sort and draw by. Coarse on purpose:
// readings drift a few points between scans, and sorting on the raw value
// would reshuffle a list while it is being read.

// NetworkManager reports 0–1 through Quickshell, nmcli 0–100.
function wifi(strength) {
    let s = Number(strength);
    if (!isFinite(s) || s <= 0)
        return 0;
    if (s > 1)
        s = s / 100;
    if (s >= 0.75)
        return 4;
    if (s >= 0.5)
        return 3;
    if (s >= 0.3)
        return 2;
    return 1;
}

// BlueZ RSSI in dBm. -1 when the device was not heard in the last search.
function bluetooth(rssi) {
    if (rssi === undefined || rssi === null)
        return -1;
    const r = Number(rssi);
    if (!isFinite(r))
        return -1;
    if (r >= -60)
        return 4;
    if (r >= -70)
        return 3;
    if (r >= -80)
        return 2;
    return 1;
}

// Connected first, then saved, then the rest; within a tier the stronger
// signal first, then by name so equal bars keep a fixed order.
function sortWifi(raw, keyOf) {
    const list = [];
    for (let i = 0; i < raw.length; i++)
        list.push(raw[i]);
    const tier = n => n?.connected ? 0 : (n && (n.known || (n.nmSettings && n.nmSettings.length)) ? 1 : 2);
    list.sort((a, b) => {
        const t = tier(a) - tier(b);
        if (t !== 0)
            return t;
        const s = wifi(b?.signalStrength) - wifi(a?.signalStrength);
        if (s !== 0)
            return s;
        const an = keyOf(a).toLowerCase();
        const bn = keyOf(b).toLowerCase();
        return an < bn ? -1 : (an > bn ? 1 : 0);
    });
    return list;
}
