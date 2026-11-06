#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if ! command -v xcrun >/dev/null 2>&1; then
    echo 'Connect badge tests require macOS with Xcode Command Line Tools.' >&2
    exit 2
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
xcrun --sdk macosx clang -fobjc-arc -Wall -Wextra -Werror \
    -framework Foundation -framework CoreGraphics \
    -I"$ROOT/tweak/Sources/Shared/AdBlock" \
    "$ROOT/tests/connect-badge/main.m" -o "$TMP/connect-tests"
"$TMP/connect-tests"
