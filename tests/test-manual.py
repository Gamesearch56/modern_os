#!/usr/bin/env python3
"""Manual: the markdown renderer, the index, and links between documents."""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts", "lib"))
from manual_markdown import headings, plain, to_html  # noqa: E402

FAIL = 0


def check(cond: bool, what: str) -> None:
    global FAIL
    if cond:
        print(f"test-manual: ok {what}")
    else:
        print(f"test-manual: FAIL {what}", file=sys.stderr)
        FAIL = 1


def html(md: str) -> str:
    return to_html(md)


check("<h1" in html("# Title") and "<h2" in html("## Sub"), "headings")
check(headings("# T\n\n## A\n```\n# not\n```\n### B\n") == [
    {"level": 1, "text": "T"}, {"level": 2, "text": "A"}, {"level": 3, "text": "B"},
], "an outline lists headings and skips a fence")
check(html("a\nb").count("<p") == 1, "lines join into one paragraph")
check(html("- a\n- b").count("<li") == 2 and "<ul" in html("- a"), "bullet list")
check("<ol" in html("1. one\n2. two"), "numbered list")
nested = html("- a\n  - b\n- c")
check(nested.count("<ul") == 2 and nested.count("<li") == 3, "nested list")
code = html("```bash\necho <x> & y\n```")
check("<pre" in code and "&lt;x&gt; &amp; y" in code, "fenced code is escaped")
check("margin-top:0px;margin-bottom:0px" in code
      and 'style="margin:0px"' in code
      and "padding-top:{{gap}}px;padding-bottom:{{gap}}px" in code,
      "a code block keeps its blank line outside the shade")
check("# not a heading" in html("```\n# not a heading\n```"), "a fence keeps its lines")
table = html("| A | B |\n|---|---|\n| 1 | 2 |")
check(table.count("<th") == 2 and table.count("<td") == 2, "table")
body = html("Hello")
check('width="{{measure:100}}"' in table and "line-height:1.5" in body and "line-height:1.5" in html("- a")
      and "line-height:" not in body.replace("line-height:1.5", ""),
      "tables use the column and body lines have unitless leading")
check(table.count("color:{{heading}}") >= 4 and "color:{{heading}}" in html("Hello"), "body and cells carry the surface text color")
check('<a href="07-settings.md"' in html("[Settings](07-settings.md)"), "links")
check('<a href="https://example.org">' in html("<https://example.org>"), "autolinks")
check("<b>x</b>" in html("**x**") and "<i>y</i>" in html("*y*"), "bold and italic")
check("<i>" not in html("config_default_json and snake_case"), "underscores inside words stay")
check("&lt;script&gt;" in html("<script>alert(1)</script>"), "raw HTML is shown, not run")
check("<code" in html("`a*b*c`") and "<i>" not in html("`a*b*c`"), "inline code is literal")
check(not re.search(r"#[0-9a-fA-F]{6}", table + code) and "{{rule}}" in table, "colors are placeholders, never literal")
check(plain("Isolation: stays out of `install.sh`") == "Isolation: stays out of install.sh", "plain titles")
readme = to_html(open(os.path.join(ROOT, "README.md"), encoding="utf-8").read(), ROOT)
check(not re.search(r"&lt;/?(div|img|table|tr|td)\b", readme) and "![" not in readme,
      "the README's HTML and badges are rendered, not shown as text")
check(f'src="file://{ROOT}/docs/screenshots/desktop.jpg"' in readme and 'width="{{measure:100}}"' in readme,
      "a local picture resolves against the document and sizes to the column")
check(re.search(r'<p align="center"[^>]*>&nbsp;<img src="[^"]*logo\.png"', readme) is not None,
      "a centred picture stays inline so Qt does not float it left")
check('<a href="https://archlinux.org/"' in readme and "img.shields.io" not in readme,
      "a badge becomes a plain link with its alt text")
check(to_html('<img src="https://example.org/x.png" alt="web">') == "web", "a web picture shows its alt text")
check("onclick" not in to_html('<div onclick="x()" align="center">hi</div>'), "only known attributes pass")

docs = json.loads(subprocess.run(
    [sys.executable, os.path.join(ROOT, "scripts", "manual-index.py"), ROOT],
    check=True, capture_output=True, text=True).stdout)
paths = {d["path"] for d in docs}
manual = [d for d in docs if d["group"] == "manual"]
check(len(manual) > 0 and docs[0]["group"] == "manual", "the user manual comes first")
check([d["rel"] for d in manual] == sorted(d["rel"] for d in manual), "chapters keep file-name order")
check(all(d["title"] and d["html"] and isinstance(d.get("headings"), list) for d in docs),
      "every document has a title, a body and an outline")
check(os.path.join(ROOT, "docs", "MANUAL.md") in paths, "the reference includes docs/MANUAL.md")
check('<ol start="3"' in html("3. c\n4. d"), "a numbered list keeps its first number")
unplaced = [d["rel"] for d in docs if d.get("section") == "more"]
check(not unplaced, "every document has a sidebar section in manual-index.py" + "".join("\n  " + u for u in unplaced))
numbers = [d["number"] for d in manual]
check(numbers == list(range(1, len(manual) + 1)), "chapters count up through the sections without gaps")
with open(os.path.join(ROOT, "stow/modern/.config/modern/translations/en.json"), encoding="utf-8") as fh:
    named = json.load(fh)["manual"]["sections"]
missing = sorted({d["section"] for d in docs} - set(named))
check(not missing, "every sidebar section has a name" + "".join("\n  " + m for m in missing))

LINK = re.compile(r"\[[^\]]+\]\(([^)\s]+)\)")
broken = []
for d in docs:
    text = re.sub(r"`[^`\n]+`", "", re.sub(r"```.*?```", "", d["text"], flags=re.S))
    for target in LINK.findall(text):
        if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
            continue
        rel = target.split("#", 1)[0]
        if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(d["path"]), rel))):
            broken.append(f"{d['rel']} -> {target}")
check(not broken, "every relative link points at a file" + ("".join("\n  " + b for b in broken)))

sys.exit(FAIL)
