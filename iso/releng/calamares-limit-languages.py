#!/usr/bin/env python3
"""Restrict Calamares welcome languages to English and German.

The welcome combo is compiled from availableLanguageList. Replace the
model so it matches Settings → Language (en.json / de.json).
"""
from __future__ import annotations

import sys
from pathlib import Path

OLD = """TranslationsModel*
availableTranslations()
{
    static TranslationsModel* model = new TranslationsModel( availableLanguageList );
    return model;
}"""

NEW = """TranslationsModel*
availableTranslations()
{
    static const QStringList limited{ QStringLiteral( "en" ), QStringLiteral( "de" ) };
    static TranslationsModel* model = new TranslationsModel( limited );
    return model;
}"""


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: calamares-limit-languages.py TranslationsModel.cpp", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")
    if NEW in text:
        return 0
    if OLD not in text:
        print(f"live-calamares: availableTranslations() not found in {path}", file=sys.stderr)
        return 1
    path.write_text(text.replace(OLD, NEW, 1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
