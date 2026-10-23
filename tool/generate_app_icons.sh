#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc tool/generate_app_icons.swift -o "$tmp/generate_app_icons"
"$tmp/generate_app_icons"
python3 tool/package_ico.py
