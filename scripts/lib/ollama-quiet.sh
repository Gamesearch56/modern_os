# shellcheck shell=bash
# Download a model without pinning the desktop. Idle disk priority and a
# low CPU priority keep a small laptop answering while the file arrives.
# The progress helper turns cursor redraws into one line per percent.

ollama_quiet_pull() {
    local bin="$1" name="$2" progress="$3"
    local -a runner=()
    if command -v ionice >/dev/null 2>&1; then
        runner+=(ionice -c 3)
    fi
    if command -v nice >/dev/null 2>&1; then
        runner+=(nice -n 19)
    fi
    if command -v stdbuf >/dev/null 2>&1; then
        runner+=(stdbuf -oL -eL "$bin")
    else
        runner+=("$bin")
    fi
    "${runner[@]}" pull "$name" 2>&1 | python3 -u "$progress"
}
