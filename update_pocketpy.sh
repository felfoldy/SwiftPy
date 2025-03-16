#!/bin/bash
set -e

HEADER_URL="https://github.com/pocketpy/pocketpy/releases/latest/download/pocketpy.h"
SOURCE_URL="https://github.com/pocketpy/pocketpy/releases/latest/download/pocketpy.c"

HEADER_DEST="Sources/pocketpy/include/pocketpy.h"
SOURCE_DEST="Sources/pocketpy/src/pocketpy.c"

echo "Downloading latest pocketpy.h..."
curl -L "$HEADER_URL" -o "$HEADER_DEST" || { echo "Failed to download pocketpy.h"; exit 1; }

echo "Appending extension include to $HEADER_DEST"
EXT_INCLUDE_LINE='#include "pocketpy_extensions.h"'
echo "$EXT_INCLUDE_LINE" >> "$HEADER_DEST"

echo "Downloading latest pocketpy.c..."
curl -L "$SOURCE_URL" -o "$SOURCE_DEST" || { echo "Failed to download pocketpy.c"; exit 1; }

echo "Update complete."
