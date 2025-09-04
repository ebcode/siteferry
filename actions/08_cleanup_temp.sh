#!/bin/bash

# Cleanup Temporary Files - Remove downloaded backups and temp files
# Sets: cleanup_temp_status, cleanup_temp_message
# Note: This action always runs if enabled, regardless of other failures

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
    
    msg_info "Cleaning up temporary files..."
    
    local cleaned_files=()
    local failed_cleanups=()
    
    # List of files to clean up
    local temp_files=(
        "/tmp/database_backup.sql"
        "/tmp/files_backup.tar.gz"
    )
    
    # Clean up each file
    for file in "${temp_files[@]}"; do
        if [[ -f "$file" ]]; then
            if rm -f "$file"; then
                cleaned_files+=("$(basename "$file")")
                msg_debug "Removed: $file"
            else
                failed_cleanups+=("$(basename "$file")")
                msg_warn "Failed to remove: $file"
            fi
        fi
    done
    
    # Set status based on results
    if [[ ${#failed_cleanups[@]} -eq 0 ]]; then
        if [[ ${#cleaned_files[@]} -gt 0 ]]; then
            local files_list
            files_list=$(IFS=', '; echo "${cleaned_files[*]}")
            set_status "$ACTION" "success" "Cleaned up ${#cleaned_files[@]} files: $files_list"
        else
            set_status "$ACTION" "success" "No temporary files found to clean up"
        fi
        msg_success "Cleanup completed successfully"
    else
        local failed_list
        failed_list=$(IFS=', '; echo "${failed_cleanups[*]}")
        set_status "$ACTION" "error" "Failed to clean up ${#failed_cleanups[@]} files: $failed_list"
        msg_error "Some files could not be cleaned up"
    fi
    
    # Pass state to next stage
    pass_state
}

main
