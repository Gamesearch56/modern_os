.pragma library

// Pure playback math for the Mediaplayer, tested with node
// (scripts/test-player.sh). Times are milliseconds, as Qt Multimedia's.

const speeds = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 3, 4];
const frameFallbackMs = 40;
const zoomStep = 1.25;
const maxZoom = 8;

// "1:05", "12:30", "1:02:03": hours only when there are any.
function clock(ms) {
    const total = Math.max(0, Math.floor((Number(ms) || 0) / 1000));
    const h = Math.floor(total / 3600);
    const m = Math.floor(total / 60) % 60;
    const s = total % 60;
    const ss = s < 10 ? "0" + s : String(s);
    if (h > 0)
        return h + ":" + (m < 10 ? "0" + m : m) + ":" + ss;
    return m + ":" + ss;
}

// The next speed up (steps > 0) or down along `speeds`; a rate between two
// steps snaps to the neighbour in that direction.
function stepSpeed(rate, steps) {
    const r = Number(rate) || 1;
    if (steps > 0) {
        for (let i = 0; i < speeds.length; i++) {
            if (speeds[i] > r + 1e-6)
                return speeds[i];
        }
        return speeds[speeds.length - 1];
    }
    for (let i = speeds.length - 1; i >= 0; i--) {
        if (speeds[i] < r - 1e-6)
            return speeds[i];
    }
    return speeds[0];
}

// "1.5" for the label: no trailing zeros.
function speedLabel(rate) {
    return String(Math.round((Number(rate) || 1) * 100) / 100);
}

// Where a seek by `delta` lands, kept inside the file. An unknown
// duration (0) only keeps it from going below zero.
function seekTarget(position, delta, duration) {
    const next = Math.max(0, (Number(position) || 0) + (Number(delta) || 0));
    return duration > 0 ? Math.min(next, Math.max(0, duration - 1)) : next;
}

// One frame in ms; streams that report no rate step by 25 fps.
function frameMs(fps) {
    const f = Number(fps);
    return f > 0 && isFinite(f) ? 1000 / f : frameFallbackMs;
}

// Slider volume (0..1) to output gain: the cube, as PipeWire scales its
// own volume, so the slider's middle sounds like half.
function gain(volume) {
    const v = Math.max(0, Math.min(1, Number(volume) || 0));
    return v * v * v;
}

function percent(volume) {
    return Math.round(Math.max(0, Math.min(1, Number(volume) || 0)) * 100);
}

// A track's label: its title, else its language, else "" (the caller
// says "Track n").
function trackLabel(title, language) {
    const t = String(title || "").trim();
    if (t.length)
        return t;
    const l = String(language || "").trim();
    return l.length && l !== "C" && l.toLowerCase() !== "und" ? l : "";
}

// The track after `current` among `count`, with -1 (off) in the cycle
// when `withOff` is set, like mpv's subtitle key.
function cycleTrack(current, count, withOff) {
    if (count <= 0)
        return -1;
    const next = current + 1;
    if (next < count)
        return next;
    return withOff ? -1 : 0;
}

// Wheel delta in notches: a mouse wheel sends 120 per notch, a touchpad
// sends pixels.
function notches(angleY, pixelY) {
    if (angleY)
        return angleY / 120;
    return (pixelY || 0) / 48;
}

// Zoom is a factor over the fitted picture: 1 fits, never smaller.
function clampZoom(z) {
    return Math.max(1, Math.min(maxZoom, Number(z) || 1));
}

function zoomed(z, steps) {
    return clampZoom(z * Math.pow(zoomStep, steps));
}

// The item offset after scaling it from z1 to z2 about its top-left corner
// that keeps the point under `at` (view coordinates) in place, on one axis.
function anchoredOffset(offset, at, z1, z2) {
    return z1 > 0 ? at - (at - offset) * z2 / z1 : offset;
}

// The offset that keeps a picture spanning [a, b] in the unscaled item
// from leaving a gap it could fill: centred while smaller than the view,
// edge to edge once larger.
function clampOffset(offset, z, view, a, b) {
    if (!(b > a))
        return 0;
    const lo = a * z;
    const hi = b * z;
    if (hi - lo <= view)
        return (view - lo - hi) / 2;
    return Math.max(view - hi, Math.min(-lo, offset));
}

// file:// URL that survives "#", "?", "%", and spaces in a name.
function fileUrl(path) {
    if (!path)
        return "";
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
}
