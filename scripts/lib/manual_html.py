"""The bits of HTML the README uses, for the ModernOS Manual.

GitHub renders <div align>, a screenshot <table> and <img> in markdown;
Qt's rich text can show the same subset. Only these tags pass, with only
these attributes. Any other tag stays escaped text, so a document cannot
inject markup. Images must be local files next to the document; a web
image (a badge) shows its alt text instead, since the reader never loads
from the network.

Widths in percent become {{measure:N}}, which the reader fills from its
column width.
"""

import html
import os
import re

TAG = re.compile(r"<(/?)([a-zA-Z][a-zA-Z0-9]*)\b([^>]*?)/?>")
ATTR = re.compile(r'([a-zA-Z-]+)\s*=\s*"([^"]*)"')
KEEP = {"div", "p", "br", "table", "tr", "td", "th", "img", "center"}
ALIGN = {"left", "center", "right"}
PICTURE = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg")
BADGE = re.compile(r"\[!\[([^\]]*)\]\([^)]*\)\]\(([^)\s]+)\)")
IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)\)")


class Html:
    def __init__(self, base: str):
        self.base = base
        self.cell = 100
        self.aligns = []

    def starts(self, line: str) -> bool:
        m = TAG.match(line.strip())
        return bool(m and m.group(2).lower() in KEEP)

    def _width(self, value: str) -> str:
        if re.fullmatch(r"\d{1,4}", value):
            return value
        m = re.fullmatch(r"(\d{1,3})%", value)
        return f"{{{{measure:{min(100, int(m.group(1)))}}}}}" if m else ""

    def image(self, src: str, alt: str, width: str = "") -> str:
        path = os.path.normpath(os.path.join(self.base, src))
        local = not re.match(r"^[a-z][a-z0-9+.-]*:", src, re.I)
        if not (local and path.lower().endswith(PICTURE) and os.path.isfile(path)):
            return html.escape(alt, quote=False)
        # Inside a cell, an unsized picture fills the cell, less its padding.
        size = self._width(width) or f"{{{{measure:{max(10, self.cell - 4)}}}}}"
        url = "file://" + path
        return (f'<img src="{html.escape(url)}" alt="{html.escape(alt)}" '
                f'width="{size}"/>')

    def _tag(self, m: re.Match) -> str:
        close, name, rest = m.group(1), m.group(2).lower(), m.group(3)
        if name not in KEEP:
            return html.escape(m.group(0), quote=False)
        attrs = {k.lower(): v for k, v in ATTR.findall(rest)}
        if name == "img":
            return self.image(attrs.get("src", ""), attrs.get("alt", ""), attrs.get("width", ""))
        if close:
            if name in ("td", "th"):
                self.cell = 100
            if name in ("div", "center") and self.aligns:
                self.aligns.pop()
            return f"</{name}>"
        kept = []
        align = "center" if name == "center" else attrs.get("align", "").lower()
        if align in ALIGN:
            kept.append(f'align="{align}"')
        if name in ("div", "center"):
            self.aligns.append(align if align in ALIGN else self.align())
        width = self._width(attrs.get("width", "")) if name in ("td", "th", "table") else ""
        if width:
            kept.append(f'width="{width}"')
        if name in ("td", "th"):
            m2 = re.fullmatch(r"(\d{1,3})%", attrs.get("width", ""))
            self.cell = int(m2.group(1)) if m2 else 100
        return f"<{name}{''.join(' ' + k for k in kept)}>"

    def line(self, line: str, inline) -> str:
        """A line of allowed tags; text between them is markdown inline."""
        out, at = [], 0
        for m in TAG.finditer(line):
            out.append(inline(line[at:m.start()]))
            out.append(self._tag(m))
            at = m.end()
        out.append(inline(line[at:]))
        # Qt floats a picture that starts its block to the left, whatever
        # the align; text on both sides keeps it inline and centred. A
        # column-wide picture would no longer fit beside that text.
        body = "".join(out)
        first = TAG.match(line)
        if (first and first.group(2).lower() == "img" and self.align()
                and "{{measure:" not in body):
            return (f'<p align="{self.align()}" style="margin-top:0px;margin-bottom:0px">'
                    f"&nbsp;{body}&nbsp;</p>")
        return body

    def align(self) -> str:
        return self.aligns[-1] if self.aligns else ""

    def badges(self, text: str) -> str:
        """[![alt](badge)](url) becomes a plain [alt](url) link."""
        return BADGE.sub(r"[\1](\2)", text)
