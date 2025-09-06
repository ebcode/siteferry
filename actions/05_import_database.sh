#!/bin/bash

# Import Database - Import SQL dump into DDEV database
# Sets: import_database_status, import_database_message
# Dependency: fetch_db_backup

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

action=$(get_current_script_name)

main() {
  # Get state from previous pipeline stage
  local input
  if input=$(cat); then
    eval "$input"
  fi
  
  # Check if this action is enabled
  if ! is_enabled "$action"; then
    set_status "$action" "skipped" "Disabled in configuration"
    pass_state
    return 0
  fi
  
  # Check dependency - database backup must have been fetched successfully
  if ! dependency_met "fetch_db_backup"; then
    set_status "$action" "skipped" "Database backup not available (dependency failed)"
    msg_warn "Skipping database import - no backup available"
    pass_state
    return 0
  fi
  
  msg_info "Importing database..."
  
  # Load site configuration to get the actual backup filename
  if ! load_site_config; then
    set_status "$action" "error" "Failed to load site configuration"
    pass_state
    return 0
  fi
  
  # Use system temp path
  local backup_file
  backup_file="${DB_BACKUP_PATH}/${REMOTE_DB_BACKUP}"
  
  # Check if backup file exists
  if [[ ! -f "$backup_file" ]]; then
    set_status "$action" "error" "Database backup file not found: $backup_file"
    msg_error "Database backup file missing"
    pass_state
    return 0
  fi
  
  # Get site directory for DDEV project
  local sites_dir
  sites_dir="$(get_site_local_path)"
  
  # Import database using DDEV
  msg_debug "Using DDEV to import database from $backup_file"
  if import_database_from_file "$sites_dir" "$backup_file"; then
    set_status "$action" "success" "Database imported successfully using DDEV"
    msg_success "Database import completed successfully"
  else
    set_status "$action" "error" "DDEV database import failed"
    msg_error "Database import failed - check DDEV project is running"
  fi
  
  # Pass state to next stage
  pass_state
}

main
