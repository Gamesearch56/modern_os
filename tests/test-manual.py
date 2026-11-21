#!/usr/bin/env python3
"""Manual: the markdown renderer, the index, and links between documents."""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts", "lib"))
from manual_markdown import plain, to_html  # noqa: E402

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
check(html("a\nb").count("<p") == 1, "lines join into one paragraph")
check(html("- a\n- b").count("<li") == 2 and "<ul" in html("- a"), "bullet list")
check("<ol" in html("1. one\n2. two"), "numbered list")
nested = html("- a\n  - b\n- c")
check(nested.count("<ul") == 2 and nested.count("<li") == 3, "nested list")
code = html("```bash\necho <x> & y\n```")
check("<pre" in code and "&lt;x&gt; &amp; y" in code, "fenced code is escaped")
check("# not a heading" in html("```\n# not a heading\n```"), "a fence keeps its lines")
table = html("| A | B |\n|---|---|\n| 1 | 2 |")
check(table.count("<th") == 2 and table.count("<td>") == 2, "table")
check('<a href="07-settings.md"' in html("[Settings](07-settings.md)"), "links")
check('<a href="https://example.org">' in html("<https://example.org>"), "autolinks")
check("<b>x</b>" in html("**x**") and "<i>y</i>" in html("*y*"), "bold and italic")
check("<i>" not in html("config_default_json and snake_case"), "underscores inside words stay")
check("&lt;script&gt;" in html("<script>alert(1)</script>"), "raw HTML is shown, not run")
check("<code" in html("`a*b*c`") and "<i>" not in html("`a*b*c`"), "inline code is literal")
check(not re.search(r"#[0-9a-fA-F]{6}", table + code) and "{{rule}}" in table, "colors are placeholders, never literal")
check(plain("Isolation: stays out of `install.sh`") == "Isolation: stays out of install.sh", "plain titles")

docs = json.loads(subprocess.run(
    [sys.executable, os.path.join(ROOT, "scripts", "manual-index.py"), ROOT],
    check=True, capture_output=True, text=True).stdout)
paths = {d["path"] for d in docs}
manual = [d for d in docs if d["group"] == "manual"]
check(len(manual) > 0 and docs[0]["group"] == "manual", "the user manual comes first")
check([d["rel"] for d in manual] == sorted(d["rel"] for d in manual), "chapters keep file-name order")
check(all(d["title"] and d["html"] for d in docs), "every document has a title and a body")
check(os.path.join(ROOT, "docs", "MANUAL.md") in paths, "the reference includes docs/MANUAL.md")

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
