.pragma library

// Arithmetic only. Letters, calls and assignments are refused, so a
// query cannot become JavaScript.
function offer(text, prefix) {
    const p = prefix === undefined || prefix === null ? "=" : String(prefix);
    let body = String(text || "");
    let explicit = false;
    if (p.length && body.startsWith(p)) {
        explicit = true;
        body = body.slice(p.length);
    }
    body = body.trim();
    if (!body.length || body.length > 200)
        return null;
    if (!explicit && !/[+\-*/%]/.test(body))
        return null;
    const value = _eval(body);
    return value === null ? null : _format(value);
}

function _format(n) {
    if (!Number.isFinite(n))
        return null;
    const rounded = Math.round(n * 1e12) / 1e12;
    if (!Number.isFinite(rounded))
        return null;
    return String(rounded);
}

function _eval(src) {
    let i = 0;
    function peek() { return src[i] || ""; }
    function eat(c) {
        while (peek() === " ")
            i++;
        if (c && peek() === c) {
            i++;
            return true;
        }
        return !c;
    }
    function expr() {
        let left = term();
        if (left === null)
            return null;
        while (eat() && (peek() === "+" || peek() === "-")) {
            const op = src[i++];
            const right = term();
            if (right === null)
                return null;
            left = op === "+" ? left + right : left - right;
        }
        return left;
    }
    function term() {
        let left = factor();
        if (left === null)
            return null;
        while (eat() && (peek() === "*" || peek() === "/" || peek() === "%")) {
            const op = src[i++];
            const right = factor();
            if (right === null || (right === 0 && op !== "*"))
                return null;
            if (op === "*")
                left *= right;
            else if (op === "/")
                left /= right;
            else
                left %= right;
        }
        return left;
    }
    function factor() {
        eat();
        if (peek() === "-") {
            i++;
            const v = factor();
            return v === null ? null : -v;
        }
        if (peek() === "(") {
            i++;
            const v = expr();
            if (v === null || !eat(")"))
                return null;
            return v;
        }
        return number();
    }
    function number() {
        eat();
        const start = i;
        while (peek() >= "0" && peek() <= "9")
            i++;
        if (peek() === ".") {
            i++;
            while (peek() >= "0" && peek() <= "9")
                i++;
        }
        if (i === start || src[i - 1] === ".")
            return null;
        const n = Number(src.slice(start, i));
        return Number.isFinite(n) ? n : null;
    }
    const out = expr();
    eat();
    if (out === null || i !== src.length || !Number.isFinite(out))
        return null;
    return out;
}
