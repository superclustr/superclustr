#!/bin/bash

# Define the URL to the latest binary
BINARY_URL="https://archive.superclustr.net/super"

# Download the latest version of the binary to a temporary location
TMP_BINARY=$(mktemp /tmp/super.XXXXXX)
curl -sSL $BINARY_URL -o "$TMP_BINARY"

# Make the binary executable
chmod +x "$TMP_BINARY"

# Execute the binary with all the passed parameters
"$TMP_BINARY" "$@"

# Clean up the temporary binary after execution
rm -f "$TMP_BINARY"
