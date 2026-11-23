.pragma library

// Pure picture math for Stage.qml, tested with node (scripts/test-viewer.sh).
// A scale is screen pixels per image pixel.

// One mouse notch. Small enough that a few clicks walk in on a detail,
// and a touchpad's pixel deltas stay smaller still.
const step = 1.1;
const maxScale = 32;

// The largest scale at which the turned picture still fits the view.
function fitScale(viewW, viewH, boxW, boxH) {
    if (!(viewW > 0) || !(viewH > 0) || !(boxW > 0) || !(boxH > 0))
        return 1;
    return Math.min(viewW / boxW, viewH / boxH);
}

// "shrink" fits but never enlarges a small picture (imv's default).
function baseScale(mode, fit) {
    if (mode === "actual")
        return 1;
    if (mode === "fit")
        return fit;
    return Math.min(1, fit);
}

function minScale(base) {
    return Math.min(base, 1) / 8;
}

function clampScale(s, base) {
    return Math.max(minScale(base), Math.min(maxScale, s));
}

function zoomed(s, steps, base) {
    return clampScale(s * Math.pow(step, steps), base);
}

// Wheel delta in notches. A mouse sends 120 per detent and no pixels.
// A touchpad sends both; the pixel distance is the smaller movement,
// so the zoom follows the finger instead of jumping a whole detent.
function notches(angleY, pixelY) {
    const fromAngle = angleY ? angleY / 120 : 0;
    const fromPixel = pixelY ? pixelY / 48 : 0;
    if (fromPixel && (!fromAngle || Math.abs(fromPixel) < Math.abs(fromAngle)))
        return fromPixel;
    return fromAngle;
}

// The content offset after zooming from s1 to s2 that keeps the image
// point under `at` (view coordinates) in place, on one axis.
function anchored(offset, at, view, box, s1, s2) {
    const pad1 = Math.max(0, (view - box * s1) / 2);
    const pad2 = Math.max(0, (view - box * s2) / 2);
    const frac = box * s1 > 0 ? (offset + at - pad1) / (box * s1) : 0.5;
    const content = Math.max(view, box * s2);
    const next = pad2 + Math.max(0, Math.min(1, frac)) * box * s2 - at;
    return Math.max(0, Math.min(content - view, next));
}

function panned(offset, delta, view, content) {
    return Math.max(0, Math.min(Math.max(0, content - view), offset + delta));
}

// Bytes as a value and a unit key ("byte", "kb", ... under viewer.units).
function sizeParts(bytes) {
    const v = Number(bytes);
    if (!isFinite(v) || v < 0)
        return null;
    if (v < 1024)
        return { value: v, unit: "byte" };
    const units = ["kb", "mb", "gb", "tb"];
    let value = v / 1024;
    let at = 0;
    while (value >= 1024 && at < units.length - 1) {
        value /= 1024;
        at++;
    }
    return { value: value >= 10 ? Math.round(value) : Math.round(value * 10) / 10, unit: units[at] };
}

// "1795284061415438585" (ns, as viewer-io sends it) → a Date.
function mtimeDate(ns) {
    const s = String(ns || "");
    if (!/^\d+$/.test(s) || s.length < 7)
        return null;
    return new Date(Number(s.slice(0, -6)));
}

// file:// URL that survives "#", "?", "%", and spaces in a name. `rev`
// forces a reload after the file was rewritten.
function fileUrl(path, rev) {
    if (!path)
        return "";
    const url = "file://" + String(path).split("/").map(encodeURIComponent).join("/");
    return rev ? url + "#r" + rev : url;
}
