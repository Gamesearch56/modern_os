#!/usr/bin/env bash
# The launcher calculates arithmetic and starts a program without a shell.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
err() { printf 'test-launcher-input: FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'test-launcher-input: ok %s\n' "$*"; }

calc_ok() {
    grep -v '^\.pragma' "$ROOT/stow/shell/.config/quickshell/modern/Services/calc.js" | node -e '
        let src = ""; process.stdin.on("data", d => src += d);
        process.stdin.on("end", () => { eval(src);
            function check(cond, what) { if (!cond) { console.error(what); process.exit(1); } }
            check(offer("2+2", "=") === "4", "sum");
            check(offer("(3-1)*4", "=") === "8", "parentheses");
            check(offer("=2", "=") === "2", "prefixed number");
            check(offer("2", "=") === null, "a bare number stays a search");
            check(offer("2+2;rm", "=") === null, "trailing text is refused");
            check(offer("alert(1)", "=") === null, "a call is refused");
            check(offer("constructor", "=") === null, "a name is refused");
            check(offer("1/0", "=") === null, "division by zero is refused");
            check(offer("10%3", "=") === "1", "remainder");
        });'
}
cmd_ok() {
    grep -v '^\.pragma' "$ROOT/stow/shell/.config/quickshell/modern/Services/command.js" | node -e '
        let src = ""; process.stdin.on("data", d => src += d);
        process.stdin.on("end", () => { eval(src);
            function check(cond, what) { if (!cond) { console.error(what); process.exit(1); } }
            const ls = offer(">notify-send hello", ">");
            check(ls && ls[0] === "notify-send" && ls[1] === "hello", "a program and an argument");
            check(offer("notify-send hello", ">") === null, "a command needs the prefix");
            check(offer(">sh -c rm", ">") === null, "a shell is refused");
            check(offer(">sudo reboot", ">") === null, "sudo is refused");
            check(offer(">ls;rm", ">") === null, "a semicolon is refused");
            check(offer(">echo " + String.fromCharCode(36) + "(id)", ">") === null, "a substitution is refused");
            check(offer(">/tmp/../etc/passwd", ">") === null, "a parent path is refused");
            check(offer(">/usr/bin/true", ">") !== null, "an absolute program is allowed");
            check(ok(["notify-send", "hello"]) === true, "the service accepts the same list");
            check(ok(["sh", "-c", "id"]) === false, "the service refuses a shell list");
        });'
}
if calc_ok && cmd_ok; then
    ok "arithmetic and commands stay inside their rules"
else
    err "the launcher accepted a calculation or a command it should refuse"
fi

MOD="$ROOT/stow/shell/.config/quickshell/modern/Modules/Launcher/Module.qml"
SVC="$ROOT/stow/shell/.config/quickshell/modern/Services/Launcher.qml"
if grep -Fq 'Calc.offer' "$MOD" && grep -Fq 'Command.offer' "$MOD" \
    && grep -Fq 'kind === "calc"' "$MOD" && grep -Fq 'kind === "command"' "$MOD" \
    && grep -Fq 'function runCommand' "$SVC" && grep -Fq 'Command.ok' "$SVC" \
    && ! grep -Fq 'sh -c' "$SVC"; then
    ok "the field offers a result and a direct program"
else
    err "the launcher field does not calculate or run a program"
fi

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
printf 'test-launcher-input: ok\n'
