#!/bin/bash

# Import Database - Import SQL dump into DDEV database
# Sets: import_database_status, import_database_message
# Dependency: fetch_db_backup

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
    
    # Check dependency - database backup must have been fetched successfully
    if ! dependency_met "fetch_db_backup"; then
        set_status "$ACTION" "skipped" "Database backup not available (dependency failed)"
        msg_warn "Skipping database import - no backup available"
        pass_state
        return 0
    fi
    
    msg_info "Importing database..."
    
    # Load site configuration to get the actual backup filename
    if ! load_site_config; then
        set_status "$ACTION" "error" "Failed to load site configuration"
        pass_state
        return 0
    fi
    
    # Use system temp path
    local backup_file
    backup_file="${DB_BACKUP_PATH}/${REMOTE_DB_BACKUP}"
    
    # Check if backup file exists
    if [[ ! -f "$backup_file" ]]; then
        set_status "$ACTION" "error" "Database backup file not found: $backup_file"
        msg_error "Database backup file missing"
        pass_state
        return 0
    fi
    
    # Simulate import process with 90% success rate
    if (( RANDOM % 100 < 90 )); then
        msg_debug "Starting DDEV database service..."
        sleep 0.5
        msg_debug "Importing SQL dump..."
        sleep 2
        msg_debug "Verifying database import..."
        sleep 0.5
        
        set_status "$ACTION" "success" "Database imported successfully (1,247 tables, 89,542 records)"
        msg_success "Database import completed successfully"
    else
        set_status "$ACTION" "error" "SQL syntax error at line 1247 - invalid character encoding"
        msg_error "Database import failed"
    fi
    
    # Pass state to next stage
    pass_state
}

main
