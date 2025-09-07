#!/bin/bash

# Import Database - Import SQL dump into DDEV database (Functional Refactor)
# Uses functional core/imperative shell pattern
# Sets: import_database_status, import_database_message
# Dependency: fetch_db_backup

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

action=$(get_current_script_name)

# FUNCTIONAL CORE - Pure functions for business logic

# Pure function to build database backup file path
build_db_backup_path() {
  local db_backup_path="$1"
  local remote_db_backup="$2"
  echo "${db_backup_path}/${remote_db_backup}"
}

# Pure function to validate backup file existence
validate_backup_file() {
  local backup_file="$1"
  [[ -f "$backup_file" ]]
}

# Pure function to determine database import strategy
determine_import_strategy() {
  local backup_file="$1"
  local file_extension="${backup_file##*.}"
  
  case "$file_extension" in
    "sql"|"dump")
      echo "direct_import"
      ;;
    "gz"|"gzip")
      echo "compressed_import"
      ;;
    "tar")
      echo "archive_import"
      ;;
    *)
      echo "unknown_format"
      ;;
  esac
}

# Pure function to create import command based on strategy
create_import_command() {
  local strategy="$1"
  local backup_file="$2"
  
  case "$strategy" in
    "direct_import")
      echo "ddev import-db --src='$backup_file'"
      ;;
    "compressed_import")
      echo "ddev import-db --src='$backup_file'"
      ;;
    "archive_import")
      echo "tar -xOf '$backup_file' | ddev import-db"
      ;;
    *)
      return 1
      ;;
  esac
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
  
  # Check dependency using functional approach
  if ! dependency_met "fetch_db_backup"; then
    set_status "$action" "skipped" "Database backup not available (dependency failed)"
    msg_warn "Skipping database import - no backup available"
    pass_state
    return 0
  fi
  
  msg_info "Importing database..."
  
  # Load site configuration with error handling
  if ! load_site_config; then
    set_status "$action" "error" "Failed to load site configuration"
    pass_state
    return 0
  fi
  
  # Use functional core to compute backup file path
  local backup_file
  # shellcheck disable=SC2153
  backup_file="$(build_db_backup_path "$DB_BACKUP_PATH" "$REMOTE_DB_BACKUP")"
  
  # Validate backup file exists using functional approach
  if ! validate_backup_file "$backup_file"; then
    set_status "$action" "error" "Database backup file not found: $backup_file"
    msg_error "Database backup file missing"
    pass_state
    return 0
  fi
  
  # Determine import strategy functionally
  local import_strategy
  import_strategy="$(determine_import_strategy "$backup_file")"
  
  # Create import command using functional core
  local import_cmd
  if import_cmd="$(create_import_command "$import_strategy" "$backup_file")"; then
    msg_debug "Using strategy '$import_strategy' to import database from $backup_file"
    
    # Get site directory for DDEV project
    local sites_dir
    sites_dir="$(get_site_local_path)"
    
    # Execute import command (I/O operation) 
    local import_result
    import_result="$(cd "$sites_dir" && safe_execute eval "$import_cmd")"
    
    if either_is_right "$import_result"; then
      set_status "$action" "success" "Database imported successfully using DDEV ($import_strategy)"
      msg_success "Database import completed successfully"
    else
      local error_msg
      error_msg="$(either_extract_left "$import_result")"
      set_status "$action" "error" "DDEV database import failed: $error_msg"
      msg_error "Database import failed - check DDEV project is running"
    fi
  else
    set_status "$action" "error" "Unknown backup format for file: $backup_file"
    msg_error "Cannot determine import strategy for backup file format"
  fi
  
  # Pass state to next stage
  pass_state
}

main
