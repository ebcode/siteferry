#!/bin/bash

# Common utilities for pipeline modules
# Source this file in other modules: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Path constants - centralized temporary and backup file management
declare -xr TEMP_DIR="${TEMP_DIR:-/tmp}"
declare -xr DB_BACKUP_PATH="$TEMP_DIR"
declare -xr FILES_BACKUP_PATH="$TEMP_DIR"

# Import focused utility modules
SOURCE_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SOURCE_DIR/string_utils.sh"
source "$SOURCE_DIR/file_utils.sh"
source "$SOURCE_DIR/config_utils.sh"
source "$SOURCE_DIR/ssh_utils.sh"

# Pipeline state management
set_status() {
    local action="$1"
    local status="$2"
    local message="${3:-}"
    
    export "${action}_status=$status"
    export "${action}_message=$message"
}

get_status() {
    local action="$1"
    local status_var="${action}_status"
    echo "${!status_var:-skipped}"
}

get_message() {
    local action="$1"
    local message_var="${action}_message"
    echo "${!message_var:-No details}"
}

is_enabled() {
    local action="$1"
    local enabled_var="${action}_enabled"
    [[ "${!enabled_var:-false}" == "true" ]]
}

# Check if dependency action completed successfully
dependency_met() {
    local dependency="$1"
    [[ "$(get_status "$dependency")" == "success" ]]
}

# Output current state for next stage in pipeline
pass_state() {
    # Read input from previous stage
    local input
    if input=$(cat); then
        # Apply the input (which contains export statements)
        eval "$input"
    fi
    
    # Get all current exports and pass them forward, properly quoted
    env | grep -E "_(status|message|enabled)=" | while IFS='=' read -r key value; do
        printf 'export %s=%q\n' "$key" "$value"
    done
}


# Remaining core utilities that don't fit in focused modules



