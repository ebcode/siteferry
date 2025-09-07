#!/bin/bash

# Import Files - Extract and install files from backup archive
# Sets: import_files_status, import_files_message
# Dependency: fetch_files_backup

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
  
  # Check dependency - files backup must have been fetched successfully
  if ! dependency_met "fetch_files_backup"; then
    set_status "$action" "skipped" "Files backup not available (dependency failed)"
    msg_warn "Skipping files import - no backup available"
    pass_state
    return 0
  fi
  
  msg_info "Importing files..."
  
  # Load site configuration to get the actual backup filename
  if ! load_site_config; then
    set_status "$action" "error" "Failed to load site configuration"
    pass_state
    return 0
  fi
  
  # Use site-aware paths for extraction, but temp files in /tmp
  local backup_file
  backup_file="${FILES_BACKUP_PATH}/${REMOTE_FILES_BACKUP}"
  local sites_dir
  sites_dir="$(get_site_local_path)"
  
  # Check if backup file exists
  if [[ ! -f "$backup_file" ]]; then
    set_status "$action" "error" "Files backup archive not found: $backup_file"
    msg_error "Files backup archive missing"
    pass_state
    return 0
  fi
  
  # Create sites directory if it doesn't exist
  if [[ ! -d "$sites_dir" ]]; then
    msg_debug "Creating sites directory: $sites_dir"
    mkdir -p "$sites_dir"
  fi
  
  # Extract files archive to sites directory
  msg_debug "Extracting files archive to $sites_dir..."
  if tar -xf "$backup_file" -C "$sites_dir"; then
    # Get extracted file count
    local file_count
    file_count=$(find "$sites_dir" -type f | wc -l)
    
    msg_debug "Setting proper permissions..."
    # Set reasonable permissions: 755 for directories, 644 for files
    find "$sites_dir" -type d -exec chmod 755 {} \;
    find "$sites_dir" -type f -exec chmod 644 {} \;
    
    set_status "$action" "success" "Extracted $file_count files to $sites_dir"
    msg_success "Files import completed successfully ($file_count files)"
  else
    set_status "$action" "error" "Failed to extract archive (tar exit code: $?)"
    msg_error "Files extraction failed - archive may be corrupted"
  fi
  
  # Pass state to next stage
  pass_state
}

main
