# Why this file exists: interactive shell conveniences for the modern
# desktop. Theme/toolkit variables are owned by matugen + config.json,
# not here — QT_QPA_PLATFORM=xcb and a hardcoded GTK_THEME would force
# XWayland and fight the token pipeline (docs/DECISIONS.md #5).
#
# Stow target: $HOME/.bashrc for the install user (never the live
# daily-driver account). Machine-local extras go in bashrc.local.

export EDITOR="${EDITOR:-nvim}"

_modern_local="${XDG_CONFIG_HOME:-$HOME/.config}/modern/bashrc.local"
if [ -f "$_modern_local" ]; then
    # shellcheck source=/dev/null
    . "$_modern_local"
fi
unset _modern_local

# Non-interactive shells (scp, ssh remote-cmd) should not grow aliases
# or print a fetch.
case $- in
    *i*) ;;
    *) return ;;
esac

alias vim=nvim
alias ls='ls -alh --color=auto'
alias ll='ls -alh --color=auto'
alias la='ls -A --color=auto'
# Recursive in `.` when stdin is a tty. -n line numbers, -I skip binaries,
# -C 1 for at most one line before/after the hit. Cache trees are skipped.
# Count/files-only/user context/pipes stay ordinary grep.
grep() {
    if [ ! -t 0 ]; then
        command grep --color=auto "$@"
        return
    fi

    local _snip _pat="" _i=0 _F=0 _pass=0 _e=0 _skip=0 _color=0 _a
    local -a _excl
    _snip="${HOME}/modern_dotfile/scripts/lib/grep-snip.awk"
    _excl=(
        --exclude-dir=.git
        --exclude-dir='*cache*'
        --exclude='*.cache'
        --exclude='*.pyc'
    )
    [ -t 1 ] && _color=1

    for _a in "$@"; do
        if [ "$_skip" -eq 1 ]; then
            _skip=0
            continue
        fi
        if [ "$_e" -eq 1 ]; then
            _pat="$_a"
            _e=0
            continue
        fi
        case "$_a" in
            --help|-V|--version)
                _pass=1
                break
                ;;
            -l|-L|-c|-q|--quiet|--silent|--count|--files-with-matches|--files-without-match|-o|--only-matching)
                _pass=1
                break
                ;;
            -A|-B|-C|--after-context|--before-context|--context)
                _pass=1
                break
                ;;
            -A?*|-B?*|-C?*)
                _pass=1
                break
                ;;
            -e|--regexp)
                _e=1
                ;;
            -e?*)
                _pat="${_a#-e}"
                ;;
            --regexp=*)
                _pat="${_a#--regexp=}"
                ;;
            -f|--file|--file=*)
                _pass=1
                break
                ;;
            -m|--max-count|--exclude-dir|--include|--exclude)
                _skip=1
                ;;
            -i|--ignore-case)
                _i=1
                ;;
            -F|--fixed-strings)
                _F=1
                ;;
            -*)
                case "$_a" in *[lLcqo]*) _pass=1; break ;; esac
                case "$_a" in *i*) _i=1 ;; esac
                case "$_a" in *F*) _F=1 ;; esac
                ;;
            *)
                if [ -z "$_pat" ]; then
                    _pat="$_a"
                fi
                ;;
        esac
    done

    if [ "$_pass" -eq 1 ] || [ -z "$_pat" ] || [ ! -f "$_snip" ]; then
        command grep --color=auto -rnI "${_excl[@]}" "$@"
        return
    fi

    command grep --color=never -rnIH -C 1 "${_excl[@]}" "$@" \
        | GREP_SNIP_PAT="$_pat" GREP_SNIP_I="$_i" GREP_SNIP_F="$_F" \
            GREP_SNIP_COLOR="$_color" awk -f "$_snip"
    return "${PIPESTATUS[0]}"
}
alias wallpaper='modern wallpaper picker'
alias reload_ui='modern ui reload'
alias reload_quickshell='modern shell reload'
alias find='find . -iname'
alias system_update='modern update'
alias system_cleanup='modern cleanup'
alias system_find='modern pkg find'
alias system_fix='modern repair'
alias fsr_on='optiscaler.sh on'
alias fsr_off='optiscaler.sh off'

# SSH
alias connect_macbook='kitty +kitten ssh bastianweigand@192.168.178.103'

shopt -s histappend checkwinsize
HISTSIZE=5000
HISTFILESIZE=20000

# shellcheck source=/dev/null
[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

load() { yay -S --needed -- "$@"; }
unload() { yay -Rns -- "$@"; }

if [ -d "$HOME/Android/Sdk" ]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
    PATH="$ANDROID_HOME/platform-tools:$PATH"
fi

if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
    echo ""
fi
