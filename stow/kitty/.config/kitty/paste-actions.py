# kitty runs filter_paste() on every paste (paste_actions filter) without
# knowing whether a shell prompt is waiting, so only text that is exactly
# one existing absolute path is touched: the Files location bar copies the
# path as shown, and a shell needs it as one argument.
import os

META = " \t\\'\"`$&|;<>()*?[]{}!#~"


def filter_paste(text: str) -> str:
    path = text.strip()
    if "\n" in path or not path.startswith("/") or not any(c in META for c in path):
        return text
    if not os.path.exists(path):
        return text
    return "".join("\\" + c if c in META else c for c in path)
