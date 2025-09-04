#!/bin/bash

# Fetch Files Backup - Download files archive from remote server
# Sets: fetch_files_backup_status, fetch_files_backup_message

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
    
    msg_info "Fetching files backup..."
    
    # Simulate files download
    local backup_file="/tmp/files_backup.tar.gz"
    local backup_size="2.1GB"
    
    # Simulate with 85% success rate
    if (( RANDOM % 100 < 85 )); then
        msg_debug "Downloading files archive..."
        sleep 1.5
        
        # Create dummy backup file
        echo "Files backup archive created at $(date)" > "$backup_file"
        
        set_status "$ACTION" "success" "Downloaded ${backup_size} files backup to ${backup_file}"
        msg_success "Files backup downloaded successfully"
    else
        set_status "$ACTION" "error" "Transfer interrupted - network connection lost"
        msg_error "Failed to download files backup"
    fi
    
    # Pass state to next stage
    pass_state
}

main
