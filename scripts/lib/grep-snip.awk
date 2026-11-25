# Format grep -nH -C 1 output: path, line, up to 3 source lines per hit.
# Driven by GREP_SNIP_PAT, GREP_SNIP_I, GREP_SNIP_F, GREP_SNIP_COLOR.
BEGIN {
    pat = ENVIRON["GREP_SNIP_PAT"]
    ign = ENVIRON["GREP_SNIP_I"] + 0
    fixed = ENVIRON["GREP_SNIP_F"] + 0
    color = ENVIRON["GREP_SNIP_COLOR"] + 0
    maxw = 120
    if (ign)
        IGNORECASE = 1
}

function locate(text,    hay, needle) {
    pos = 0
    mlen = 0
    if (fixed) {
        hay = ign ? tolower(text) : text
        needle = ign ? tolower(pat) : pat
        pos = index(hay, needle)
        mlen = length(pat)
        return
    }
    if (pat != "" && match(text, pat)) {
        pos = RSTART
        mlen = RLENGTH
    }
}

function clip(text, want_hl,    s, e, extra, left, mid, right, n) {
    n = length(text)
    locate(text)
    if (pos < 1) {
        if (n > maxw)
            return substr(text, 1, maxw) "…"
        return text
    }
    if (n <= maxw) {
        s = 1
        e = n
    } else {
        extra = maxw - mlen
        if (extra < 0)
            extra = 0
        s = pos - int(extra / 2)
        if (s < 1)
            s = 1
        e = s + maxw - 1
        if (e > n) {
            e = n
            s = e - maxw + 1
            if (s < 1)
                s = 1
        }
    }
    left = substr(text, s, pos - s)
    mid = substr(text, pos, mlen)
    right = substr(text, pos + mlen, e - (pos + mlen) + 1)
    if (s > 1)
        left = "…" left
    if (e < n)
        right = right "…"
    if (color && want_hl)
        mid = "\033[1;31m" mid "\033[0m"
    return left mid right
}

function emit(file, sep, line, text, is_match) {
    snip = clip(text, is_match)
    if (color)
        printf "\033[35m%s\033[0m%s\033[32m%s\033[0m%s%s\n", file, sep, line, sep, snip
    else
        printf "%s%s%s%s%s\n", file, sep, line, sep, snip
}

{
    if ($0 == "--") {
        if (color)
            printf "\033[36m--\033[0m\n"
        else
            print "--"
        next
    }
    if (match($0, /:[0-9]+:/)) {
        file = substr($0, 1, RSTART - 1)
        rest = substr($0, RSTART + 1)
        if (!match(rest, /:/)) {
            print
            next
        }
        emit(file, ":", substr(rest, 1, RSTART - 1), substr(rest, RSTART + 1), 1)
        next
    }
    if (match($0, /-[0-9]+-/)) {
        file = substr($0, 1, RSTART - 1)
        rest = substr($0, RSTART + 1)
        if (!match(rest, /-/)) {
            print
            next
        }
        emit(file, "-", substr(rest, 1, RSTART - 1), substr(rest, RSTART + 1), 0)
        next
    }
    print
}
