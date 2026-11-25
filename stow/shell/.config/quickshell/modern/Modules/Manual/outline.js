.pragma library

// Heading offsets in the rendered chapter. The search walks the plain
// text in order, so two headings with the same words stay distinct.

function marks(plain, heads, yAt) {
    const text = String(plain || "");
    const list = heads || [];
    let from = 0;
    const ys = [];
    for (let i = 0; i < list.length; i++) {
        const label = String((list[i] && list[i].text) || "");
        const at = label.length ? text.indexOf(label, from) : -1;
        if (at < 0) {
            ys.push(ys.length ? ys[ys.length - 1] : 0);
            continue;
        }
        from = at + label.length;
        ys.push(yAt(at));
    }
    return ys;
}

function current(ys, y) {
    if (!ys || !ys.length)
        return -1;
    let at = 0;
    for (let i = 0; i < ys.length; i++) {
        if (ys[i] <= y)
            at = i;
    }
    return at;
}
