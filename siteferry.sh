#!/bin/bash
# shellcheck disable=SC2016
# DDEV Backup Manager - Pipeline Orchestrator
# Builds and executes dynamic pipelines based on user configuration

set -euo pipefail

# SCRIPT_DIR can be overridden for testing (see test/unit_filesystem.bats)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions first for site detection
source "$SCRIPT_DIR/lib/common.sh"

# Site selection logic
SITE_NAME="${SITE_NAME:-default}"
CONFIG_FILE="${CONFIG_FILE:-internal-config/last-checked-${SITE_NAME}.config}"

# Source messaging system
source "$SCRIPT_DIR/lib/messaging.sh"

# For timing pipeline execution
PIPELINE_START_TIME=$(date +%s)
export PIPELINE_START_TIME

ensure_internal_config_exists() {
  # Create missing internal config file with all actions enabled by default
  if [[ ! -f "$CONFIG_FILE" ]]; then
    msg_debug "Creating missing config file: $CONFIG_FILE"
    local actions=()
    local action
    for action in $(get_all_numbered_scripts); do
      actions+=("$(strip_numeric_prefix "$action")")
    done
    
    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Write default config with all actions enabled
    {
      echo "# Auto-generated internal configuration for site: $SITE_NAME"
      echo "# Created: $(date)"
      echo ""
      for action in "${actions[@]}"; do
        echo "${action}=true"
      done
    } > "$CONFIG_FILE"
    
    msg_debug "Created config file with ${#actions[@]} actions enabled by default"
  fi
}

# Functional approach to getting enabled actions
get_enabled_actions() {
  ensure_internal_config_exists
  
  # Parse config directly (not using safe_execute for command strings)
  local config_output
  if config_output=$(bash "$SCRIPT_DIR/lib/parse_config.sh" "$CONFIG_FILE" 2>&1); then
    # Functional pipeline to extract enabled actions
    echo "$config_output" | \
      filter '( [[ "$1" =~ _enabled=\"true\" ]] )' | \
      map '( sed "s/export \\(.*\\)_enabled=\"true\"/\\1/" <<< "$1" )'
  else
    msg_error "Failed to parse configuration: $config_output"
    return 1
  fi
}

# Common functions already sourced above

# Functional mapping of base action names to numbered filenames
map_action_to_filename() {
  local base_name="$1"
  
  # Use functional operations to find matching action
  local matched_action
  matched_action="$(get_all_numbered_scripts | \
    filter "( [[ \"\$(strip_numeric_prefix \"\$1\")\" == \"$base_name\" ]] )" | \
    head -1)"
  
  # Return matched action or fallback to original name
  echo "${matched_action:-$base_name}"
}

# Pure function to build action script path
build_action_script_path() {
  local base_action="$1"
  local action_filename
  action_filename="$(map_action_to_filename "$base_action")"
  echo "$SCRIPT_DIR/actions/${action_filename}.sh"
}

# Pure function to validate action script exists
validate_action_script() {
  local script_path="$1"
  [[ -f "$script_path" ]]
}

# Functional pipeline construction
build_pipeline() {
  local enabled_actions=("$@")
  local pipeline_cmd="bash '$SCRIPT_DIR/lib/parse_config.sh' '$CONFIG_FILE'"
  
  # Transform actions to script paths and validate them functionally
  local -a valid_scripts
  mapfile -t valid_scripts < <(printf '%s\n' "${enabled_actions[@]}" | \
    map build_action_script_path | \
    filter validate_action_script)
  
  # Build pipeline command using simple loop (more reliable than reduce with complex quoting)
  for script in "${valid_scripts[@]}"; do
    pipeline_cmd="$pipeline_cmd | bash '$script'"
  done
  
  # Add finalize script
  local finalize_script
  finalize_script="$(find "$SCRIPT_DIR/actions" -name "*finalize_results.sh" | head -1)"
  if [[ -f "$finalize_script" ]]; then
    pipeline_cmd="$pipeline_cmd | bash '$finalize_script'"
  else
    msg_warn "finalize_results.sh not found"
  fi
  
  echo "$pipeline_cmd"
}


show_action_selection() {
  # Pass site context to action selection dialog
  if command -v dialog &> /dev/null; then
    if ! SITE_NAME="$SITE_NAME" CONFIG_FILE="$CONFIG_FILE" SITE_CONFIG_FILE="$SITE_CONFIG_FILE" bash "$SCRIPT_DIR/action-selection.sh"; then
      echo "Operation cancelled"
      exit 0
    fi
  else
    msg_warn "dialog not found. Using default configuration."
  fi
}

# Pure function to extract site name from arguments
extract_site_option() {
  local -a args=("$@")
  local i
  
  for ((i=0; i<${#args[@]}; i++)); do
    if [[ "${args[i]}" == "--site" ]] && [[ $((i + 1)) -lt ${#args[@]} ]]; then
      echo "${args[$((i + 1))]}"
      return 0
    fi
  done
  return 1
}

# Pure function to validate and setup site configuration
setup_site_config() {
  local site_name="$1"
  
  if validate_site_name "$site_name"; then
    local config_file="internal-config/last-checked-${site_name}.config"
    local site_config_file
    site_config_file="$(get_site_config_path "$site_name")"
    
    # Return configuration as data
    printf "SITE_NAME=%s\n" "$site_name"
    printf "CONFIG_FILE=%s\n" "$config_file"
    printf "SITE_CONFIG_FILE=%s\n" "$site_config_file"
  else
    return 1
  fi
}

# Functional argument processing
parse_site_selection() {
  local -a args=("$@")
  
  # Handle list-sites command functionally
  printf '%s\n' "${args[@]}" | \
    some '( [[ "$1" == "--list-sites" ]] )' && {
    echo "Available sites:"
    get_available_sites
    exit 0
  }
  
  # Extract and validate site option functionally
  local site_result
  if site_result="$(extract_site_option "${args[@]}")"; then
    local config_result
    if config_result="$(setup_site_config "$site_result")"; then
      # Apply configuration
      eval "$config_result"
      export SITE_CONFIG_FILE
    else
      msg_error "Site '$site_result' not found. Available sites:"
      get_available_sites
      exit 1
    fi
  fi
}

# Pure functions for main orchestration
should_show_action_selection() {
  local args=("$@")
  ! printf '%s\n' "${args[@]}" | some '( [[ "$1" == "--no-select" ]] )'
}

should_run_dry() {
  local args=("$@")
  printf '%s\n' "${args[@]}" | some '( [[ "$1" == "--dry-run" ]] )'
}

display_banner() {
  local site_name="$1"
  msg_user_info "SiteFerry - Multi-Site Backup Manager"
  msg_user_info "====================================="
  msg_user_info "Site: $site_name"
  msg_user_info ""
}

validate_enabled_actions() {
  local -a enabled_actions=("$@")
  [[ ${#enabled_actions[@]} -gt 0 ]]
}

# Functional main orchestrator
main() {
  local -a args=("$@")
  
  # Parse arguments functionally
  parse_verbosity "${args[@]}"
  parse_site_selection "${args[@]}"
  
  # Ensure SITE_CONFIG_FILE is set for all site operations
  export SITE_CONFIG_FILE="${SITE_CONFIG_FILE:-$(get_site_config_path "$SITE_NAME")}"
  
  # Display banner
  display_banner "$SITE_NAME"
  
  # Show action selection conditionally using functional predicate
  if should_show_action_selection "${args[@]}"; then
    msg_info "Opening action selection..."
    show_action_selection
    msg_user_info ""
  fi
  
  # Get enabled actions functionally with error handling
  msg_info "Loading configuration..."
  local -a enabled_actions
  if ! mapfile -t enabled_actions < <(get_enabled_actions); then
    msg_user_error "Failed to load enabled actions"
    exit 1
  fi
  
  # Validate actions using functional approach
  if ! validate_enabled_actions "${enabled_actions[@]}"; then
    msg_user_error "No actions enabled in configuration. Run with --select to choose actions."
    exit 1
  fi
  
  msg_info "Enabled actions: ${enabled_actions[*]}"
  msg_user_info ""
  
  # Build pipeline functionally with error handling
  msg_debug "Building pipeline..."
  local pipeline_cmd
  if ! pipeline_cmd="$(build_pipeline "${enabled_actions[@]}")"; then
    msg_user_error "Failed to build pipeline"
    exit 1
  fi
  
  # Handle dry run using functional predicate
  if should_run_dry "${args[@]}"; then
    msg_user_info "Dry run - pipeline would execute:"
    msg_user_info "$pipeline_cmd"
    exit 0
  fi
  
  # Execute pipeline with error handling
  msg_info "Executing pipeline..."
  msg_user_info ""
  
  if ! eval "$pipeline_cmd"; then
    msg_user_error "Pipeline execution failed"
    exit 1
  fi
}

# Show help if requested (handle before parse_site_selection to avoid conflicts)
if [[ "$*" == *"--help"* ]] || [[ "$*" == *"-h"* ]]; then
  cat << 'EOF'
SiteFerry - Multi-Site Backup Manager

Usage: siteferry.sh [OPTIONS] [--site SITE_NAME]

Site Options:
  --site SITE_NAME    Select specific site (default: default)
  --list-sites       Show available sites
  --tags             Show all tags across all sites

Pipeline Options:
  --select           Show action selection dialog before execution
  --no-select        Skip action selection dialog
  --dry-run          Show pipeline command without executing

Verbosity Options:
  -q, --quiet        Quiet mode (errors only)
  -v, --verbose      Verbose mode (show info and debug)
  -vv                Debug mode (show debug details)
  -vvv               Trace mode (show all internals)
  --help, -h         Show this help message

Examples:
  siteferry.sh                          # Run with default site
  siteferry.sh --site mystore           # Run with mystore site  
  siteferry.sh --list-sites             # List available sites
  siteferry.sh --site mystore --select  # Select actions for mystore

The script reads site configuration and builds dynamic pipelines of enabled 
actions. Each action is executed in sequence, with error handling and state 
passing between stages.
EOF
  exit 0
fi

# Run main function only when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
