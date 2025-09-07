#!/bin/bash

# Common utilities for pipeline modules
# Source this file in other modules: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Path constants - centralized temporary and backup file management
declare -xr TEMP_DIR="${TEMP_DIR:-/tmp}"
declare -xr DB_BACKUP_PATH="$TEMP_DIR"
declare -xr FILES_BACKUP_PATH="$TEMP_DIR"

# Import functional programming libraries first
SOURCE_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SOURCE_DIR/fp_bash.sh"
source "$SOURCE_DIR/siteferry-functional.sh"

# Import focused utility modules
source "$SOURCE_DIR/messaging.sh"
source "$SOURCE_DIR/string_utils.sh"
source "$SOURCE_DIR/file_utils.sh"
source "$SOURCE_DIR/config_utils.sh"
source "$SOURCE_DIR/ssh_utils.sh"
source "$SOURCE_DIR/ddev_env_utils.sh"
source "$SOURCE_DIR/ddev_setup_utils.sh"
source "$SOURCE_DIR/ddev_mgmt.sh"

# FUNCTIONAL STATE MANAGEMENT - Pure functions for immutable state
# Replace global state with functional state threading

# Pure function to create pipeline state entry
create_state_entry() {
  local action="$1"
  local status="$2" 
  local message="${3:-}"
  printf "%s_status=%s\n%s_message=%s\n" "$action" "$status" "$action" "$message"
}

# Pure function to update state with new entry  
update_pipeline_state() {
  local current_state="$1"
  local action="$2"
  local status="$3"
  local message="${4:-}"
  
  # Remove existing entries for this action
  local filtered_state
  filtered_state="$(echo "$current_state" | grep -v "^${action}_")"
  
  # Add new state entry
  printf "%s\n%s\n" "$filtered_state" "$(create_state_entry "$action" "$status" "$message")"
}

# Pure function to extract status from state data
extract_status() {
  local state_data="$1"
  local action="$2"
  
  echo "$state_data" | \
    filter "( [[ \"\$1\" =~ ^${action}_status= ]] )" | \
    map "( echo \"\${1#${action}_status=}\" )" | \
    head -1 || echo "skipped"
}

# Pure function to extract message from state data
extract_message() {
  local state_data="$1"
  local action="$2"
  
  echo "$state_data" | \
    filter "( [[ \"\$1\" =~ ^${action}_message= ]] )" | \
    map "( echo \"\${1#${action}_message=}\" )" | \
    head -1 || echo "No details"
}

# Pure function to check if action is enabled
extract_enabled_status() {
  local state_data="$1"
  local action="$2"
  
  local enabled_status
  enabled_status="$(echo "$state_data" | \
    filter "( [[ \"\$1\" =~ ^${action}_enabled= ]] )" | \
    map "( echo \"\${1#${action}_enabled=}\" )" | \
    head -1)"
  
  [[ "$enabled_status" == "true" ]]
}

# Pure function to check dependencies
check_dependency() {
  local state_data="$1"
  local dependency="$2"
  
  local dep_status
  dep_status="$(extract_status "$state_data" "$dependency")"
  [[ "$dep_status" == "success" ]]
}

# Backwards compatibility wrappers (imperative shell over functional core)
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

dependency_met() {
  local dependency="$1"
  [[ "$(get_status "$dependency")" == "success" ]]
}

# Functional state threading for pipeline
thread_state() {
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

# Backwards compatibility alias
pass_state() {
  thread_state
}
