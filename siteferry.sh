#!/bin/bash

# DDEV Backup Manager - Pipeline Orchestrator
# Builds and executes dynamic pipelines based on user configuration

set -euo pipefail

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
        for action in $(get_all_actions); do
            actions+=("$(get_action_base_name "$action")")
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

get_enabled_actions() {
    # Ensure config file exists before parsing
    ensure_internal_config_exists
    
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

# Common functions already sourced above

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

parse_site_selection() {
    local args=("$@")
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        case "${args[i]}" in
            --site)
                if [[ $((i + 1)) -lt ${#args[@]} ]]; then
                    SITE_NAME="${args[$((i + 1))]}"
                    # Validate site name
                    if ! validate_site_name "$SITE_NAME"; then
                        msg_error "Site '$SITE_NAME' not found. Available sites:"
                        get_available_sites
                        exit 1
                    fi
                    # Update config file path for selected site
                    CONFIG_FILE="internal-config/last-checked-${SITE_NAME}.config"
                    SITE_CONFIG_FILE="$(get_site_config_path "$SITE_NAME")"
                    export SITE_CONFIG_FILE
                    i=$((i + 2))
                else
                    msg_error "--site requires a site name"
                    exit 1
                fi
                ;;
            --list-sites)
                echo "Available sites:"
                get_available_sites
                exit 0
                ;;
            *)
                i=$((i + 1))
                ;;
        esac
    done
}

main() {
    # Parse verbosity from command line first
    parse_verbosity "$@"
    
    # Parse site selection and handle special commands
    parse_site_selection "$@"
    
    # Ensure SITE_CONFIG_FILE is set for all site operations
    export SITE_CONFIG_FILE="${SITE_CONFIG_FILE:-$(get_site_config_path "$SITE_NAME")}"
    
    msg_user_info "SiteFerry - Multi-Site Backup Manager"
    msg_user_info "====================================="
    msg_user_info "Site: $SITE_NAME"
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
