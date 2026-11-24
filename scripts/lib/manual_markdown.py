"""Markdown to Qt rich text for the ModernOS Manual.

Qt's own markdown mode cannot be styled, so the manual renders this HTML
instead. Colors, sizes and fonts are left as {{name}} placeholders that
the app fills from the theme tokens; nothing here knows the palette.

Covers what the docs use: ATX headings, paragraphs, nested lists, fenced
code, tables, block quotes, rules, links, inline code, bold and italic,
plus the README's HTML, images and badges (lib/manual_html.py).
"""

import html
import re

from manual_html import Html

FENCE = re.compile(r"^\s*(```|~~~)")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
RULE = re.compile(r"^\s*([-*_])(\s*\1){2,}\s*$")
ITEM = re.compile(r"^(\s*)([-*+]|\d+[.)])\s+(.*)$")
TABLE_RULE = re.compile(r"^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?\s*$")
IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)\)")
# Set per document by to_html: images resolve against its folder.
_doc = Html("")


def _inline(text: str) -> str:
    codes: list[str] = []

    def keep(m: re.Match) -> str:
        codes.append(m.group(1))
        return f"\x00{len(codes) - 1}\x00"

    pictures: list[str] = []

    def picture(m: re.Match) -> str:
        pictures.append(_doc.image(m.group(2), m.group(1)))
        return f"\x01{len(pictures) - 1}\x01"

    text = re.sub(r"`([^`]+)`", keep, text)
    text = IMAGE.sub(picture, _doc.badges(text))
    text = html.escape(text, quote=False)
    text = re.sub("\x01(\\d+)\x01", lambda m: pictures[int(m.group(1))], text)
    text = re.sub(r"&lt;((?:https?|mailto):[^\s&]+)&gt;", r'<a href="\1">\1</a>', text)
    text = re.sub(
        r"\[([^\]]+)\]\(([^)\s]+)(?:\s+&quot;[^)]*&quot;)?\)",
        lambda m: f'<a href="{m.group(2)}" style="color:{{{{link}}}}">{m.group(1)}</a>',
        text,
    )
    text = re.sub(r"\*\*(.+?)\*\*|__(.+?)__", lambda m: f"<b>{m.group(1) or m.group(2)}</b>", text)
    text = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<i>\1</i>", text)
    text = re.sub(r"(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)", r"<i>\1</i>", text)
    return re.sub(
        "\x00(\\d+)\x00",
        lambda m: '<code style="font-family:{{mono}};background-color:{{codeBg}}">'
        + html.escape(codes[int(m.group(1))], quote=False)
        + "</code>",
        text,
    )


def _cells(line: str) -> list[str]:
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [c.strip() for c in re.split(r"(?<!\\)\|", line)]


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _starts_block(line: str) -> bool:
    return bool(FENCE.match(line) or HEADING.match(line) or RULE.match(line)
                or ITEM.match(line) or line.lstrip().startswith(">") or _doc.starts(line))


def _code(lines: list[str], i: int) -> tuple[str, int]:
    fence = FENCE.match(lines[i]).group(1)
    body = []
    i += 1
    while i < len(lines) and not lines[i].strip().startswith(fence):
        body.append(lines[i])
        i += 1
    code = html.escape("\n".join(body), quote=False)
    # A percentage width is resolved before the column exists, so the
    # document keeps the unwrapped width and the page opens on a blank
    # stretch. {{measure:100}} is the column, filled when the window lays out.
    # The table margin is the gap outside the shade. A pre also has its
    # own margin, and Qt paints that inside the table background, so a
    # blank line shows up in the block. Zero it.
    out = ('<table width="{{measure:100}}" cellpadding="{{pad}}" cellspacing="0" bgcolor="{{codeBg}}" '
           'style="margin-top:{{gap}}px;margin-bottom:{{gap}}px"><tr><td>'
           f'<pre style="font-family:{{{{mono}}}};font-size:{{{{codeSize}}}}px;color:{{{{heading}}}};'
           f'margin-top:0px;margin-bottom:0px;white-space:pre-wrap">{code}</pre>'
           "</td></tr></table>")
    return out, i + 1


def _table(lines: list[str], i: int) -> tuple[str, int]:
    head = _cells(lines[i])
    i += 2
    rows = []
    while i < len(lines) and "|" in lines[i] and lines[i].strip():
        rows.append(_cells(lines[i]))
        i += 1
    # border="1" draws the grid in the palette color and leaves the cell
    # text black. On a dark page that is an empty stretch with a faint
    # grid at the bottom. The cell color is the same one headings use.
    cell = 'style="color:{{heading}};border:1px solid {{rule}}"'
    out = ['<table width="{{measure:100}}" cellpadding="{{pad}}" cellspacing="0" '
           'style="border-collapse:collapse;margin-top:{{gap}}px;margin-bottom:{{gap}}px">',
           "<tr>" + "".join(f'<th align="left" {cell}>{_inline(c)}</th>' for c in head) + "</tr>"]
    for r in rows:
        r = (r + [""] * len(head))[: len(head)]
        out.append("<tr>" + "".join(f"<td {cell}>{_inline(c)}</td>" for c in r) + "</tr>")
    out.append("</table>")
    return "".join(out), i


def _list(lines: list[str], i: int) -> tuple[str, int]:
    first = ITEM.match(lines[i])
    base = len(first.group(1))
    ordered = first.group(2)[0].isdigit()
    items: list[list[str]] = []
    while i < len(lines):
        line = lines[i]
        m = ITEM.match(line)
        if m and len(m.group(1)) == base and m.group(2)[0].isdigit() == ordered:
            items.append([m.group(3)])
        elif m and len(m.group(1)) < base:
            break
        elif not line.strip():
            nxt = i + 1
            if nxt < len(lines) and lines[nxt].strip() and _indent(lines[nxt]) > base:
                items[-1].append("")
            else:
                break
        elif _indent(line) > base:
            items[-1].append(line[min(_indent(line), base + 2):] if _indent(line) >= base + 2 else line.strip())
        elif _starts_block(line):
            break
        else:
            items[-1].append(line.strip())
        i += 1
    tag = "ol" if ordered else "ul"
    start = int(re.match(r"\d+", first.group(2)).group()) if ordered else 1
    begin = f' start="{start}"' if start != 1 else ""
    out = [f'<{tag}{begin} style="margin-top:0px;margin-bottom:{{{{gap}}}}px">']
    for body in items:
        inner = render(body)
        inner = re.sub(r'^<p style="[^"]*">(.*?)</p>', r"\1", inner, count=1, flags=re.S)
        # No line-height. Qt has treated both a percentage and a pixel
        # length as a multiplier, and either one opens a blank page.
        out.append(f'<li style="margin-bottom:{{{{tight}}}}px;color:{{{{heading}}}}">{inner}</li>')
    out.append(f"</{tag}>")
    return "".join(out), i


def render(lines: list[str]) -> str:
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if FENCE.match(line):
            block, i = _code(lines, i)
            out.append(block)
            continue
        if _doc.starts(line):
            out.append(_doc.line(line.strip(), _inline))
            i += 1
            continue
        m = HEADING.match(line)
        if m:
            level = len(m.group(1))
            top = "0" if not out else "{{headGap}}"
            out.append(f'<h{level} style="margin-top:{top}px;margin-bottom:{{{{tight}}}}px;'
                       f'font-size:{{{{h{min(level, 4)}}}}}px;color:{{{{heading}}}}">{_inline(m.group(2))}</h{level}>')
            i += 1
            continue
        if RULE.match(line):
            out.append('<hr style="margin-top:{{gap}}px;margin-bottom:{{gap}}px"/>')
            i += 1
            continue
        if "|" in line and i + 1 < len(lines) and TABLE_RULE.match(lines[i + 1]):
            block, i = _table(lines, i)
            out.append(block)
            continue
        if ITEM.match(line):
            block, i = _list(lines, i)
            out.append(block)
            continue
        if line.lstrip().startswith(">"):
            quote = []
            while i < len(lines) and lines[i].lstrip().startswith(">"):
                quote.append(re.sub(r"^\s*>\s?", "", lines[i]))
                i += 1
            out.append('<blockquote style="margin-left:{{pad}}px;color:{{muted}}">'
                       + render(quote) + "</blockquote>")
            continue
        para = [line.strip()]
        i += 1
        while i < len(lines) and lines[i].strip() and not _starts_block(lines[i]) \
                and not ("|" in lines[i] and i + 1 < len(lines) and TABLE_RULE.match(lines[i + 1])):
            para.append(lines[i].strip())
            i += 1
        out.append(f'<p style="margin-top:0px;margin-bottom:{{{{gap}}}}px;color:{{{{heading}}}}">{_inline(" ".join(para))}</p>')
    return "".join(out)


def plain(text: str) -> str:
    """A heading as plain text, for window titles and the document list."""
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    return re.sub(r"[`*]|(?<!\w)_|_(?!\w)", "", text).strip()


def to_html(text: str, base: str = "") -> str:
    """base is the document's folder, for its relative image paths."""
    global _doc
    _doc = Html(base)
    return render(text.replace("\r", "").replace("\t", "    ").split("\n"))
