.pragma library

// A program plus arguments. No shell, so ; | & $ ` < > and quotes cannot
// change what runs. The name is a PATH command or one absolute path.
const META = /[\u0000-\u001f\u007f;&|`$<>(){}\\!*?~#'"]/;
const NAME = /^[A-Za-z0-9][A-Za-z0-9._+-]*$/;
const SHELLS = {
    sh: true, bash: true, dash: true, zsh: true, fish: true, ksh: true,
    csh: true, tcsh: true, env: true, sudo: true, pkexec: true, doas: true,
    su: true, script: true
};

function offer(text, prefix) {
    const p = prefix === undefined || prefix === null ? ">" : String(prefix);
    if (!p.length)
        return null;
    const raw = String(text || "");
    if (!raw.startsWith(p))
        return null;
    return argv(raw.slice(p.length));
}

function argv(text) {
    const body = String(text || "").trim();
    if (!body.length || body.length > 2000)
        return null;
    const parts = body.split(/\s+/);
    if (parts.length > 32)
        return null;
    for (let i = 0; i < parts.length; i++) {
        const token = parts[i];
        if (!token.length || token.length > 256 || META.test(token))
            return null;
    }
    const cmd = parts[0];
    if (cmd.indexOf("/") !== -1) {
        if (cmd.charAt(0) !== "/" || cmd.indexOf("..") !== -1)
            return null;
    } else if (!NAME.test(cmd) || SHELLS[cmd]) {
        return null;
    }
    return parts;
}

function ok(list) {
    const parts = list || [];
    if (!parts.length)
        return false;
    return argv(parts.join(" ")) !== null
        && argv(parts.join(" ")).join("\0") === parts.join("\0");
}
