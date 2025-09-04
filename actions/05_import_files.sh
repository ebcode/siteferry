#!/bin/bash

# Import Files - Extract and install files from backup archive
# Sets: import_files_status, import_files_message
# Dependency: fetch_files_backup

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
    
    # Check dependency - files backup must have been fetched successfully
    if ! dependency_met "fetch_files_backup"; then
        set_status "$ACTION" "skipped" "Files backup not available (dependency failed)"
        msg_warn "Skipping files import - no backup available"
        pass_state
        return 0
    fi
    
    msg_info "Importing files..."
    
    # Simulate files import
    local backup_file="/tmp/files_backup.tar.gz"
    
    # Check if backup file exists
    if [[ ! -f "$backup_file" ]]; then
        set_status "$ACTION" "error" "Files backup archive not found: $backup_file"
        msg_error "Files backup archive missing"
        pass_state
        return 0
    fi
    
    # Simulate extraction with 95% success rate
    if (( RANDOM % 100 < 95 )); then
        msg_debug "Extracting files archive..."
        sleep 1.5
        msg_debug "Setting proper permissions..."
        sleep 0.5
        msg_debug "Updating file ownership..."
        sleep 0.3
        
        set_status "$ACTION" "success" "Extracted 12,847 files to project directory"
        msg_success "Files import completed successfully"
    else
        set_status "$ACTION" "error" "Archive corruption detected - checksum mismatch"
        msg_error "Files import failed"
    fi
    
    # Pass state to next stage
    pass_state
}

main
