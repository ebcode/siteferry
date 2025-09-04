#!/bin/bash

# Fetch Database Backup - Download SQL dump from remote server
# Sets: fetch_db_backup_status, fetch_db_backup_message

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
    
    msg_info "Fetching database backup..."
    
    # Load backup configuration
    if ! load_backup_config; then
        set_status "$ACTION" "error" "Failed to load backup configuration"
        pass_state
        return 1
    fi
    
    # Set local backup file destination
    local backup_file="/tmp/database_backup.sql"
    
    # Build scp command with configuration values
    local scp_cmd="scp -P ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${REMOTE_FILE} ${backup_file}"
    
    msg_info "Connecting to ${REMOTE_HOST}:${REMOTE_PORT} as ${REMOTE_USER}"
    msg_debug "Downloading ${REMOTE_PATH}/${REMOTE_FILE}"
    
    # Execute scp command
    if $scp_cmd; then
        # Get file size for status message
        local file_size
        if [[ -f "$backup_file" ]]; then
            file_size=$(du -h "$backup_file" | cut -f1)
            set_status "$ACTION" "success" "Downloaded ${file_size} database backup to ${backup_file}"
            msg_success "Database backup downloaded successfully (${file_size})"
        else
            set_status "$ACTION" "error" "Download completed but backup file not found"
            msg_error "Download completed but backup file not found at $backup_file"
        fi
    else
        set_status "$ACTION" "error" "Failed to download database backup (scp exit code: $?)"
        msg_error "Failed to download database backup from ${REMOTE_HOST}"
    fi
    
    # Pass state to next stage
    pass_state
}

main
