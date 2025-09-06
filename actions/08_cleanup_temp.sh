#!/bin/bash

# Cleanup Temporary Files - Remove downloaded backups and temp files
# Sets: cleanup_temp_status, cleanup_temp_message
# Note: This action always runs if enabled, regardless of other failures

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
  
  msg_info "Cleaning up temporary files..."
  
  local cleaned_files=()
  local failed_cleanups=()
  
  # Load site configuration to determine which backup files to clean up
  if load_site_config 2>/dev/null; then
    # Use configuration to determine specific backup files
    local temp_files=(
      "${DB_BACKUP_PATH}/${REMOTE_DB_BACKUP:-database_backup.sql}"
      "${FILES_BACKUP_PATH}/${REMOTE_FILES_BACKUP:-files_backup.tar}"
    )
  else
    # Fallback to common backup file patterns
    local temp_files=(
      "${DB_BACKUP_PATH}/database_backup.sql"
      "${FILES_BACKUP_PATH}/files_backup.tar"
    )
  fi
  
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
      local IFS=', '
      files_list="${cleaned_files[*]}"
      set_status "$action" "success" "Cleaned up ${#cleaned_files[@]} files: $files_list"
    else
      set_status "$action" "success" "No temporary files found to clean up"
    fi
    msg_success "Cleanup completed successfully"
  else
    local failed_list
    local IFS=', '
    failed_list="${failed_cleanups[*]}"
    set_status "$action" "error" "Failed to clean up ${#failed_cleanups[@]} files: $failed_list"
    msg_error "Some files could not be cleaned up"
  fi
  
  # Pass state to next stage
  pass_state
}

main
