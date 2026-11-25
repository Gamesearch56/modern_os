"""Bytes <-> editor text for the ModernOS Texteditor. No file access.

The editor shows text in a QML TextEdit, which hands back NBSP as a
plain space and U+2028/U+2029 as a newline. decode() swaps NBSP for
FIGURE SPACE when the file has none, and encode() swaps it back, so a
save keeps every byte the user did not touch. A file that cannot make
that round trip is reported as lossy and the editor opens it read-only.
"""

NBSP = "\u00a0"
STAND_IN = "\u2007"
SEPARATORS = ("\u2028", "\u2029")

ENCODINGS = ("utf-8", "utf-8-bom", "utf-16le", "utf-16be", "windows-1252", "iso-8859-1")
EOLS = ("lf", "crlf", "cr")

_BOMS = (
    (b"\xef\xbb\xbf", "utf-8-bom"),
    (b"\xff\xfe", "utf-16le"),
    (b"\xfe\xff", "utf-16be"),
)
_PY = {
    "utf-8": "utf-8",
    "utf-8-bom": "utf-8",
    "utf-16le": "utf-16-le",
    "utf-16be": "utf-16-be",
    "windows-1252": "cp1252",
    "iso-8859-1": "latin-1",
}
_BOM_OF = {"utf-8-bom": b"\xef\xbb\xbf", "utf-16le": b"\xff\xfe", "utf-16be": b"\xfe\xff"}
_EOL_OF = {"lf": "\n", "crlf": "\r\n", "cr": "\r"}
# Tab, LF, VT, FF, CR, and ESC show up in real text files.
_TEXT_CONTROLS = {0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x1B}
_SNIFF = 8192


class Refuse(Exception):
    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason


def _binary(sample):
    if not sample:
        return False
    if b"\x00" in sample:
        return True
    controls = sum(1 for b in sample if b < 0x20 and b not in _TEXT_CONTROLS)
    return controls * 10 > len(sample)


def _sniff(data):
    for bom, name in _BOMS:
        if data.startswith(bom):
            return name, data[len(bom):]
    if _binary(data[:_SNIFF]):
        raise Refuse("binary")
    try:
        data.decode("utf-8")
        return "utf-8", data
    except UnicodeDecodeError:
        pass
    try:
        data.decode("cp1252")
        return "windows-1252", data
    except UnicodeDecodeError:
        return "iso-8859-1", data


def _eol(text):
    crlf = text.count("\r\n")
    cr = text.count("\r") - crlf
    lf = text.count("\n") - crlf
    best = max((crlf, "crlf"), (lf, "lf"), (cr, "cr"))
    mixed = sum(1 for n in (crlf, cr, lf) if n) > 1
    return (best[1] if best[0] else "lf"), mixed


def decode(data):
    """Return {text, encoding, eol, mixed, standIn, lossy} or raise Refuse."""
    encoding, body = _sniff(data)
    try:
        text = body.decode(_PY[encoding])
    except UnicodeDecodeError:
        raise Refuse("encoding") from None
    if encoding.startswith("utf-16") and "\x00" in text:
        raise Refuse("binary")
    eol, mixed = _eol(text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lossy = any(sep in text for sep in SEPARATORS)
    stand_in = False
    if NBSP in text:
        if STAND_IN in text:
            lossy = True
        else:
            text = text.replace(NBSP, STAND_IN)
            stand_in = True
    return {
        "text": text,
        "encoding": encoding,
        "eol": eol,
        "mixed": mixed,
        "standIn": stand_in,
        "lossy": lossy,
    }


def encode(text, encoding, eol, stand_in):
    if encoding not in _PY:
        raise Refuse("encoding")
    if eol not in _EOL_OF:
        raise Refuse("eol")
    if stand_in:
        text = text.replace(STAND_IN, NBSP)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    if eol != "lf":
        text = text.replace("\n", _EOL_OF[eol])
    try:
        body = text.encode(_PY[encoding])
    except UnicodeEncodeError:
        raise Refuse("unencodable") from None
    return _BOM_OF.get(encoding, b"") + body
