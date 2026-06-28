#!/usr/bin/env bash
#
# Builds the DocC static-hosting site into ./docs for a local preview.
#
# This mirrors what .github/workflows/docs.yml does in CI — normally you don't
# need to run it, since pushing to `main` rebuilds and deploys the docs
# automatically. Use it only to preview the generated site locally. The ./docs
# output is gitignored.
#
# Usage:
#   ./build-docs.sh
#
set -euo pipefail

HOSTING_BASE_PATH="SwiftPy"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Generating documentation -> docs/"
swift package --allow-writing-to-directory "$REPO_ROOT/docs" \
    generate-documentation \
    --target SwiftPy \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path "$HOSTING_BASE_PATH" \
    --output-path "$REPO_ROOT/docs"

echo "==> Done. Preview with:"
echo "    python3 -m http.server -d \"$REPO_ROOT/docs\""
echo "    open http://localhost:8000/documentation/swiftpy/"
