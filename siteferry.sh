#!/bin/bash

# DDEV Backup Manager - Pipeline Orchestrator
# Builds and executes dynamic pipelines based on user configuration

# set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-config/last-checked.config}"

# Source messaging system
source "$SCRIPT_DIR/lib/messaging.sh"

# For timing pipeline execution
PIPELINE_START_TIME=$(date +%s)
export PIPELINE_START_TIME

get_enabled_actions() {
    # Parse config and extract enabled actions
    local config_output
    if config_output=$(bash "$SCRIPT_DIR/lib/parse_config.sh" "$CONFIG_FILE"); then
        # Extract action names from export statements where value is "true"
        echo "$config_output" | grep '_enabled="true"' | sed 's/export \(.*\)_enabled="true"/\1/'
    else
        msg_error "Failed to parse configuration"
        exit 1
    fi
}

# Source common functions
source "$SCRIPT_DIR/lib/common.sh"

# Map base action names to numbered filenames
map_action_to_filename() {
    local base_name="$1"
    local actions
    mapfile -t actions < <(get_all_actions)
    for action in "${actions[@]}"; do
        if [[ "$(get_action_base_name "$action")" == "$base_name" ]]; then
            echo "$action"
            return 0
        fi
    done
    echo "$base_name"  # fallback to original name
}

build_pipeline() {
    local enabled_actions=("$@")
    local pipeline_cmd="bash '$SCRIPT_DIR/lib/parse_config.sh' '$CONFIG_FILE'"
    
    # Add each enabled action to the pipeline
    for base_action in "${enabled_actions[@]}"; do
        local action_filename
        action_filename=$(map_action_to_filename "$base_action")
        local action_script="$SCRIPT_DIR/actions/${action_filename}.sh"
        
        if [[ ! -f "$action_script" ]]; then
            msg_warn "Action script not found: $action_script"
            continue
        fi
        
        pipeline_cmd="$pipeline_cmd | bash '$action_script'"
    done
    
    # Always add finalize_results at the end (find the numbered version)
    local finalize_script
    finalize_script=$(find "$SCRIPT_DIR/actions" -name "*finalize_results.sh" | head -1)
    if [[ -f "$finalize_script" ]]; then
        pipeline_cmd="$pipeline_cmd | bash '$finalize_script'"
    else
        msg_warn "finalize_results.sh not found"
    fi
    
    echo "$pipeline_cmd"
}

show_action_selection() {
    # For now, use the original POC dialog interface
    # This could be replaced with a more sophisticated interface later
    if command -v dialog &> /dev/null; then
        if ! bash "$SCRIPT_DIR/action-selection.sh"; then
            echo "Operation cancelled"
            exit 0
        fi
    else
        msg_warn "dialog not found. Using default configuration."
    fi
}

main() {
    # Parse verbosity from command line first
    parse_verbosity "$@"
    
    msg_user_info "DDEV Backup Manager - Pipeline Mode"
    msg_user_info "==================================="
    msg_user_info ""
    
    # Show action selection unless --no-select is specified
    if [[ "$*" != *"--no-select"* ]]; then
        msg_info "Opening action selection..."
        show_action_selection
        msg_user_info ""
    fi
    
    # Get enabled actions from config
    msg_info "Loading configuration..."
    local enabled_actions
    mapfile -t enabled_actions < <(get_enabled_actions)
    
    if [[ ${#enabled_actions[@]} -eq 0 ]]; then
        msg_user_error "No actions enabled in configuration. Run with --select to choose actions."
        exit 1
    fi
    
    msg_info "Enabled actions: ${enabled_actions[*]}"
    msg_user_info ""
    
    # Build and execute pipeline
    msg_debug "Building pipeline..."
    local pipeline_cmd
    pipeline_cmd=$(build_pipeline "${enabled_actions[@]}")
    
    if [[ "$*" == *"--dry-run"* ]]; then
        msg_user_info "Dry run - pipeline would execute:"
        msg_user_info "$pipeline_cmd"
        exit 0
    fi
    
    msg_info "Executing pipeline..."
    msg_user_info ""
    
    # Execute the pipeline using eval
    eval "$pipeline_cmd"
}

# Show help if requested
if [[ "$*" == *"--help"* ]] || [[ "$*" == *"-h"* ]]; then
    cat << 'EOF'
DDEV Backup Manager - Pipeline Mode

Usage:
  ./siteferry.sh [options]

Options:
  --select      Show action selection dialog before execution
  --dry-run     Show pipeline command without executing
  -q, --quiet   Quiet mode (errors only)
  -v, --verbose Verbose mode (show info and debug)
  -vv           Debug mode (show debug details)
  -vvv          Trace mode (show all internals)
  --help, -h    Show this help message

The script reads configuration from 'config/last-checked.config' and builds
a dynamic pipeline of enabled actions. Each action is executed in
sequence, with error handling and state passing between stages.

Actions are auto-discovered from actions/*.sh files and executed based
on configuration. Results are reported at the end of the pipeline.
EOF
    exit 0
fi

# Run main function only when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
