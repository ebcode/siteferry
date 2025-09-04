#!/bin/bash

# Preflight Checks - Verify system requirements
# Sets: preflight_checks_status, preflight_checks_message

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/messaging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

ACTION=$(get_current_action_name)

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
        if ddev_version=$(ddev version --json 2>/dev/null | grep -o '"version":"[^"]*' | cut -d'"' -f4); then
            msg_info "DDEV found: $ddev_version"
        else
            msg_info "DDEV found: $(ddev version 2>/dev/null | head -1 || echo 'version unknown')"
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
    
    # Test SSH connectivity to backup server (non-blocking)
    msg_info "Testing SSH connectivity to backup server..."
    if load_backup_config 2>/dev/null; then
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
