#!/bin/bash

# Fetch Files Backup - Download files archive from remote server (Functional Refactor)
# Uses functional core/imperative shell pattern
# Sets: fetch_files_backup_status, fetch_files_backup_message

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

action=$(get_current_script_name)

# FUNCTIONAL CORE - Pure functions for business logic

# Pure function to calculate backup file path
calculate_backup_file_path() {
  local files_backup_path="$1"
  local remote_files_backup="$2"
  echo "${files_backup_path}/${remote_files_backup}"
}

# Pure function to build scp command
build_scp_command() {
  local remote_port="$1"
  local remote_user="$2"
  local remote_host="$3"
  local remote_path="$4"
  local remote_files_backup="$5"
  local local_backup_file="$6"
  
  echo "scp -P ${remote_port} ${remote_user}@${remote_host}:${remote_path}/${remote_files_backup} ${local_backup_file}"
}

# Pure function to create connection info message
create_connection_message() {
  local remote_host="$1"
  local remote_port="$2"
  local remote_user="$3"
  echo "Connecting to ${remote_host}:${remote_port} as ${remote_user}"
}

# Pure function to create download debug message
create_download_message() {
  local remote_path="$1"
  local remote_files_backup="$2"
  echo "Downloading ${remote_path}/${remote_files_backup}"
}

# Pure function to calculate file size and create success message
create_success_message() {
  local backup_file="$1"
  
  if [[ -f "$backup_file" ]]; then
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    echo "Downloaded ${file_size} files backup to ${backup_file}"
  else
    return 1
  fi
}

# IMPERATIVE SHELL - I/O operations and side effects
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
  
  msg_info "Fetching files backup..."
  
  # Load site configuration with error handling
  if ! load_site_config; then
    set_status "$action" "error" "Failed to load site configuration"
    pass_state
    return 1
  fi
  
  # Use functional core to compute all values
  local backup_file
  # shellcheck disable=SC2153
  backup_file="$(calculate_backup_file_path "$FILES_BACKUP_PATH" "$REMOTE_FILES_BACKUP")"
  
  local scp_cmd
  # shellcheck disable=SC2153
  scp_cmd="$(build_scp_command "$REMOTE_PORT" "$REMOTE_USER" "$REMOTE_HOST" "$REMOTE_PATH" "$REMOTE_FILES_BACKUP" "$backup_file")"
  
  local connection_msg
  # shellcheck disable=SC2153
  connection_msg="$(create_connection_message "$REMOTE_HOST" "$REMOTE_PORT" "$REMOTE_USER")"
  
  local download_msg
  # shellcheck disable=SC2153
  download_msg="$(create_download_message "$REMOTE_PATH" "$REMOTE_FILES_BACKUP")"
  
  # Display computed messages
  msg_info "$connection_msg"
  msg_debug "$download_msg"
  
  # Execute scp command (I/O operation)
  local scp_result
  scp_result="$(safe_execute eval "$scp_cmd")"
  
  if either_is_right "$scp_result"; then
    # Try to create success message
    local success_msg
    if success_msg="$(create_success_message "$backup_file")"; then
      local file_size
      file_size=$(echo "$success_msg" | grep -o '[0-9.]*[KMGT]')
      set_status "$action" "success" "$success_msg"
      msg_success "Files backup downloaded successfully (${file_size})"
    else
      set_status "$action" "error" "Download completed but backup file not found"
      msg_error "Download completed but backup file not found at $backup_file"
    fi
  else
    local error_msg
    error_msg="$(either_extract_left "$scp_result")"
    set_status "$action" "error" "Failed to download files backup: $error_msg"
    msg_error "Failed to download files backup from ${REMOTE_HOST}"
  fi
  
  # Pass state to next stage
  pass_state
}

main
