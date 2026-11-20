#!/usr/bin/env python3
"""Redact a collected problem report in place.

Usage: report-redact.py <files-dir>

Runs before the user sees the review list, so what they can open is what
gets sent. JSON files lose every value under an account/location/secret
key; every text file loses tokens, credentials, mail addresses, IPs, MAC
addresses (the last byte stays so two devices remain distinguishable),
network names, the hostname, the username and the home path.
"""
import json
import os
import re
import socket
import sys

SENSITIVE_KEY = re.compile(
    r"(url|uri|account|email|mail|password|passwd|token|secret|apikey|api_key|"
    r"username|^user$|ssid|latitude|longitude|^lat$|^lon$|location|city|address)",
    re.I,
)

TEXT_RULES = [
    (re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{30,})"), "<token>"),
    (re.compile(r"(?i)\b(bearer|token)\s+[A-Za-z0-9._~+/=-]{16,}"), r"\1 <token>"),
    (re.compile(r"(?i)\b(password|passwd|pass|psk|secret|token|api[_-]?key|auth)(\s*[=:]\s*)(\"?)[^\s\",;]+"), r"\1\2\3<redacted>"),
    (re.compile(r"(https?://[^\s?\"'<>]+)\?[^\s\"'<>]+"), r"\1?<redacted>"),
    (re.compile(r"private-[0-9a-f]{8,}"), "private-<redacted>"),
    (re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"), "<email>"),
    (re.compile(r"\b(?:[0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})\b"), r"xx:xx:xx:xx:xx:\1"),
    (re.compile(r"\bdev_(?:[0-9A-Fa-f]{2}_){5}([0-9A-Fa-f]{2})\b"), r"dev_xx_xx_xx_xx_xx_\1"),
    # PipeWire names a Bluetooth card bluez_card.AA_BB_CC_DD_EE_FF.
    (re.compile(r"(?<=[._])(?:[0-9A-Fa-f]{2}_){5}([0-9A-Fa-f]{2})(?![0-9A-Za-z])"), r"xx_xx_xx_xx_xx_\1"),
    (re.compile(r"\b(?!127\.)(?!0\.0\.0\.0\b)(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)\b"), "<ip>"),
    (re.compile(r"\b(?:[0-9A-Fa-f]{1,4}:){4,7}[0-9A-Fa-f]{1,4}\b"), "<ip6>"),
    (re.compile(r"\b[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4})*::(?:[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4})*)?\b"), "<ip6>"),
    # Quoted names first: they may contain spaces. NetworkManager says
    # access point 'X' and connection 'X'; wpa_supplicant says ssid="X".
    (re.compile(r"(?i)((?:ssid|access point|connection|network)\s*[=:]?\s*)(['\"])[^'\"\n]*\2"), r"\1\2<network>\2"),
    (re.compile(r"(?im)^(\s*[\w.-]*SSID:[ \t]+)(?!['\"]).+$"), r"\1<network>"),
    (re.compile(r"(?i)(ssid[\s:=]+)(?!['\"]<network>)(['\"]?)[^'\"\s]+"), r"\1\2<network>"),
]


def redact_value(key, value):
    if isinstance(value, dict):
        return {k: redact_value(k, v) for k, v in value.items()}
    if isinstance(value, list):
        return [redact_value(key, v) for v in value]
    if key and SENSITIVE_KEY.search(key) and value not in ("", None, False, 0):
        return "<redacted>"
    return value


def identity_rules():
    rules = []
    home = os.path.expanduser("~")
    if home and home != "/":
        rules.append((re.compile(re.escape(home)), "~"))
    user = os.environ.get("USER") or os.path.basename(home)
    if user and len(user) >= 3:
        rules.append((re.compile(r"\b" + re.escape(user) + r"\b"), "<user>"))
    host = os.environ.get("BUG_REPORT_HOSTNAME") or socket.gethostname()
    if host and len(host) >= 3 and host != "localhost":
        rules.append((re.compile(r"\b" + re.escape(host) + r"\b"), "<host>"))
    return rules


def redact_text(text, rules):
    for pattern, repl in rules:
        text = pattern.sub(repl, text)
    return text


def main():
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        print("usage: report-redact.py <files-dir>", file=sys.stderr)
        return 2
    rules = TEXT_RULES + identity_rules()
    for name in sorted(os.listdir(sys.argv[1])):
        path = os.path.join(sys.argv[1], name)
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        if name.endswith(".json"):
            try:
                text = json.dumps(redact_value("", json.loads(text)), indent=2, ensure_ascii=False) + "\n"
            except ValueError:
                pass
        text = redact_text(text, rules)
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
