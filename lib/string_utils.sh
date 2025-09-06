#!/bin/bash

# String processing utilities
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/string_utils.sh"

# Convert numbered script name to display format (e.g. "01_fetch_db" -> "Fetch Db")
get_display_name() {
    local script_name="$1"
    # Strip numeric prefix (N_) and convert to display format
    echo "$script_name" | sed 's/^[0-9]*_//' | sed 's/_/ /g' | sed 's/\b\w/\U&/g'
}

# Strip numeric prefix (leading digits + underscore) from any string
strip_numeric_prefix() {
    local string_with_prefix="$1"
    echo "${string_with_prefix/*[0-9]_/}"
}

# For scripts: determine their own name from filename without numeric prefix
get_current_script_name() {
    local script_name
    script_name=$(basename "${BASH_SOURCE[1]}" .sh)
    strip_numeric_prefix "$script_name"
}