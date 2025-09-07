#!/bin/bash

# File discovery and validation utilities
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/file_utils.sh"

# Find all numbered shell scripts in actions directory (functional approach)
get_all_numbered_scripts() {
  local script_dir="${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}"
  local actions_dir
  
  # Determine actions directory functionally
  if [[ "$(basename "$script_dir")" == "lib" ]]; then
    actions_dir="$(dirname "$script_dir")/actions"
  else
    actions_dir="$script_dir/actions"
  fi
  
  # Functional pipeline for file discovery and processing
  # shellcheck disable=SC2012,SC2016
  find "$actions_dir" -name "[0-9]*_*.sh" -not -name "*finalize_results.sh" 2>/dev/null | \
    map '( basename "$1" )' | \
    map '( echo "${1%.sh}" )' | \
    sort
}

# Validate that action files follow naming conventions
validate_numbered_script_files() {
  # SCRIPT_DIR can be overridden for testing; fallback to current script's directory  
  local actions_dir="${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/actions"
  local invalid_files=()
  
  # Check all .sh files in actions directory
  while IFS= read -r -d '' file; do
    local basename
    basename=$(basename "$file")
    if [[ ! "$basename" =~ ^[0-9]{1,3}_[a-z_]+\.sh$ ]] && [[ "$basename" != "*finalize_results.sh" ]]; then
      invalid_files+=("$basename")
    fi
  done < <(find "$actions_dir" -name "*.sh" -print0 2>/dev/null)
  
  if [[ ${#invalid_files[@]} -gt 0 ]]; then
    return 1
  fi
  
  return 0
}
