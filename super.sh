#!/bin/bash

# Default binary is latest stable release
BINARY_NAME="super"

# Extract arguments, removing --nightly if present
ARGS=()
for arg in "$@"; do
    if [[ "$arg" == "--nightly" ]]; then
        BINARY_NAME="super-nightly"
    else
        ARGS+=("$arg")
    fi
done

# Define the URL to the selected binary
BINARY_URL="https://archive.superclustr.net/${BINARY_NAME}"

# Download the selected binary to a temporary location
TMP_BINARY=$(mktemp /tmp/${BINARY_NAME}.XXXXXX)
curl -sSL "$BINARY_URL" -o "$TMP_BINARY"

# Make the binary executable
chmod +x "$TMP_BINARY"

# Execute the binary with the remaining arguments
"$TMP_BINARY" "${ARGS[@]}"

# Clean up the temporary binary after execution
rm -f "$TMP_BINARY"
