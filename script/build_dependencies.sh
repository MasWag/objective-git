#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

"$SCRIPT_DIR/update_libssl_ios"
"$SCRIPT_DIR/update_libssh2_ios"
"$SCRIPT_DIR/update_libgit2_ios"

# Copy Git headers
mkdir -p "$SCRIPT_DIR/../Headers"
cp -r "$SCRIPT_DIR/../External/libgit2/include/" "$SCRIPT_DIR/../Headers"
mkdir -p "$SCRIPT_DIR/../Headers/git2/sys/git2"
find "$SCRIPT_DIR/../External/libgit2/include/git2" -type f -maxdepth 1 -exec cp {} "$SCRIPT_DIR/../Headers/git2/sys/git2" \;
