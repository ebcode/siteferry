#!/bin/bash

# Preflight Checks - Verify system requirements
# Sets: preflight_checks_status, preflight_checks_message

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/messaging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

ACTION=$(get_current_script_name)

main() {
    # Get state from previous pipeline stage
    local input
    if input=$(cat); then
        eval "$input"
    fi
    
    # Check if this action is enabled
    if ! is_enabled "$ACTION"; then
        set_status "$ACTION" "skipped" "Disabled in configuration"
        pass_state
        return 0
    fi
    
    msg_info "Starting preflight checks..."
    
    local errors=()
    
    # Check DDEV installation
    if ! command -v ddev &> /dev/null; then
        errors+=("DDEV not installed - see https://ddev.com/get-started/")
    else
        local ddev_version
        local version_output
        if version_output=$(ddev -v 2>/dev/null); then
            ddev_version="${version_output##* }"
            msg_info "DDEV found: $ddev_version"
        else
            msg_info "DDEV found: version unknown"
        fi
    fi
    
    # Check required tools
    local required_tools=("dialog" "ssh" "rsync")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            case "$tool" in
                dialog)
                    errors+=("dialog not installed - run: sudo apt-get install dialog (Ubuntu/Debian) or brew install dialog (macOS)")
                    ;;
                ssh)
                    errors+=("ssh not installed - install openssh-client package")
                    ;;
                rsync)
                    errors+=("rsync not installed - run: sudo apt-get install rsync (Ubuntu/Debian) or brew install rsync (macOS)")
                    ;;
            esac
        else
            msg_debug "$tool found"
        fi
    done
    
    # Check for curl or wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        errors+=("Neither curl nor wget installed - install one with: sudo apt-get install curl wget")
    elif command -v curl &> /dev/null; then
        msg_debug "curl found"
    else
        msg_debug "wget found"
    fi
    
    # Validate action files structure (user-facing check)
    msg_info "Validating action files structure..."
    local action_validation_errors=()
    
    # Check for duplicate action numbers
    local action_numbers=()
    local script_dir
    script_dir="$(dirname "${BASH_SOURCE[0]}")/.."
    local actions_dir="$script_dir/actions"
    
    if [[ -d "$actions_dir" ]]; then
        while IFS= read -r -d '' file; do
            local basename
            basename=$(basename "$file" .sh)
            if [[ "$basename" =~ ^([0-9]+)_ ]]; then
                local number="${BASH_REMATCH[1]}"
                # Check if this number already exists
                if [[ " ${action_numbers[*]} " == *" $number "* ]]; then
                    action_validation_errors+=("Duplicate action number '$number' found in $(basename "$file") - each action must have a unique number")
                else
                    action_numbers+=("$number")
                fi
            fi
        done < <(find "$actions_dir" -name "*.sh" -print0 2>/dev/null)
        
        # Check for invalid action naming
        while IFS= read -r -d '' file; do
            local basename
            basename=$(basename "$file")
            # Skip finalize_results as it's allowed to be special
            if [[ "$basename" != "*finalize_results.sh" ]] && [[ ! "$basename" =~ ^[0-9]{1,3}_[a-z_]+\.sh$ ]]; then
                action_validation_errors+=("Invalid action file name: '$basename' - must follow pattern: N_action_name.sh (e.g., 1_action.sh, 01_preflight_checks.sh, 001_custom.sh)")
            fi
        done < <(find "$actions_dir" -name "*.sh" -print0 2>/dev/null)
        
        # Check for non-executable action files
        while IFS= read -r -d '' file; do
            if [[ ! -x "$file" ]]; then
                action_validation_errors+=("Action file '$(basename "$file")' is not executable - run: chmod +x $(basename "$file")")
            fi
        done < <(find "$actions_dir" -name "[0-9]*_*.sh" -print0 2>/dev/null)
        
    else
        action_validation_errors+=("Actions directory not found at: $actions_dir")
    fi
    
    # Add action validation errors to main errors array
    errors+=("${action_validation_errors[@]}")
    
    # Validate configuration files
    msg_info "Validating configuration files..."
    local site_config_path
    site_config_path=$(get_site_config_path)
    
    if [[ ! -f "$site_config_path" ]]; then
        errors+=("Site configuration not found at: $site_config_path")
    elif [[ ! -r "$site_config_path" ]]; then
        errors+=("Site configuration exists but is not readable - check file permissions: $site_config_path")
    else
        # Validate site configuration contents
        if load_site_config 2>/dev/null; then
            local config_errors=()
            [[ -z "${REMOTE_HOST:-}" ]] && config_errors+=("REMOTE_HOST not set in site config")
            [[ -z "${REMOTE_USER:-}" ]] && config_errors+=("REMOTE_USER not set in site config")
            [[ -z "${REMOTE_PORT:-}" ]] && config_errors+=("REMOTE_PORT not set in site config")
            [[ -z "${REMOTE_PATH:-}" ]] && config_errors+=("REMOTE_PATH not set in site config")
            
            if [[ ${#config_errors[@]} -gt 0 ]]; then
                local config_error_msg
                config_error_msg=$(IFS=', '; echo "${config_errors[*]}")
                errors+=("Site configuration validation failed: $config_error_msg")
            fi
        else
            errors+=("Site configuration has syntax errors - check for valid bash variable assignments")
        fi
    fi
    
    # Test SSH connectivity to backup server (non-blocking)
    msg_info "Testing SSH connectivity to backup server..."
    if load_site_config 2>/dev/null; then
        msg_debug "Attempting SSH connection to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}"
        
        # Use the robust SSH connectivity test function
        # This function handles all timeout scenarios and provides detailed error classification
        # It's designed to be non-blocking and will not break the pipeline
        test_ssh_connectivity "${REMOTE_HOST}" "${REMOTE_PORT}" "${REMOTE_USER}" || true
    else
        msg_info "Backup configuration not found - skipping SSH connectivity test"
    fi
    
    # Set status based on results
    if [[ ${#errors[@]} -eq 0 ]]; then
        set_status "$ACTION" "success" "All preflight checks passed"
        msg_success "Preflight checks completed successfully"
    else
        local error_msg
        error_msg=$(IFS='; '; echo "${errors[*]}")
        set_status "$ACTION" "error" "$error_msg"
        msg_error "Preflight checks failed: $error_msg"
        exit 1
    fi
    
    # Pass state to next stage
    pass_state
}

main
