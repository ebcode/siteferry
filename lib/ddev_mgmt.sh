#!/bin/bash

# DDEV Data Import and Project Lifecycle Management
# Source: source "$(dirname "${BASH_SOURCE[0]}")/ddev_mgmt.sh"

# Messaging functions available via common.sh

# Import database from backup file using DDEV
import_database_from_file() {
  local project_dir="${1:-.}"
  local backup_file="${2}"
  
  if [[ ! -f "$backup_file" ]]; then
    msg_error "Database backup file not found: $backup_file"
    return 1
  fi
  
  local original_dir="$PWD"
  cd "$project_dir" || { msg_error "Could not cd to $project_dir"; return 1; }
  
  # Check if DDEV project is running
  if ! ddev describe >/dev/null 2>&1; then
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "DDEV project not running - run 'ddev start' first"
    return 1
  fi
  
  # Handle different file formats
  local import_cmd="ddev import-db"
  if [[ "$backup_file" =~ \.gz$ ]]; then
    # DDEV can handle .gz files directly
    import_cmd+=" --file='$backup_file'"
  elif [[ "$backup_file" =~ \.sql$ ]]; then
    import_cmd+=" --file='$backup_file'"
  else
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "Unsupported database file format: $backup_file"
    return 1
  fi
  
  msg_debug "Importing database: $import_cmd"
  
  # Import database with timeout
  if timeout 300 eval "$import_cmd"; then
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_success "Database imported successfully from $backup_file"
    return 0
  else
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "Database import failed (timeout 300s or import error)"
    return 1
  fi
}

# Import files to DDEV project directory
import_files_to_container() {
  local project_dir="${1:-.}"
  local files_archive="${2}"
  
  if [[ ! -f "$files_archive" ]]; then
    msg_error "Files archive not found: $files_archive"
    return 1
  fi
  
  local original_dir="$PWD"
  cd "$project_dir" || { msg_error "Could not cd to $project_dir"; return 1; }
  
  msg_debug "Extracting files archive to project directory"
  
  # Extract files directly to project directory
  # DDEV will sync these automatically via bind mount
  if tar -xf "$files_archive" -C .; then
    # Get extracted file count for reporting
    local file_count
    if file_count=$(tar -tf "$files_archive" 2>/dev/null | wc -l); then
      cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
      msg_success "Extracted $file_count files from $files_archive"
      return 0
    else
      cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
      msg_success "Files extracted from $files_archive"
      return 0
    fi
  else
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "Failed to extract files from $files_archive"
    return 1
  fi
}

# Execute command inside DDEV container
execute_in_container() {
  local project_dir="${1:-.}"
  local service="${2:-web}"
  shift 2
  local cmd=("$@")
  
  local original_dir="$PWD"
  cd "$project_dir" || { msg_error "Could not cd to $project_dir"; return 1; }
  
  # Check if project is running
  if ! ddev describe >/dev/null 2>&1; then
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "DDEV project not running - run 'ddev start' first"
    return 1
  fi
  
  msg_debug "Executing in $service container: ${cmd[*]}"
  
  # Execute command in container
  if ddev exec -s "$service" "${cmd[@]}"; then
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_success "Command executed in $service container"
    return 0
  else
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "Command failed in $service container"
    return 1
  fi
}

# Install project dependencies using DDEV
install_project_dependencies() {
  local project_dir="${1:-.}"
  local original_dir="$PWD"
  
  cd "$project_dir" || { msg_error "Could not cd to $project_dir"; return 1; }
  
  # Check if project is running
  if ! ddev describe >/dev/null 2>&1; then
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "DDEV project not running - run 'ddev start' first"
    return 1
  fi
  
  local installed=()
  
  # Install Composer dependencies if composer.json exists
  if [[ -f "composer.json" ]]; then
    msg_debug "Installing Composer dependencies"
    if timeout 300 ddev composer install; then
      installed+=("composer")
    else
      cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
      msg_error "Composer install failed"
      return 1
    fi
  fi
  
  # Install npm dependencies if package.json exists
  if [[ -f "package.json" ]]; then
    msg_debug "Installing npm dependencies"
    if timeout 300 ddev npm install; then
      installed+=("npm")
    else
      cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
      msg_error "npm install failed"
      return 1
    fi
  fi
  
  cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
  
  if [[ ${#installed[@]} -gt 0 ]]; then
    local deps_list
    printf -v deps_list "%s, " "${installed[@]}"
    msg_success "Dependencies installed: ${deps_list%, }"
    return 0
  else
    msg_info "No dependency files found (composer.json, package.json)"
    return 0
  fi
}

# Manage DDEV project state (start/stop/restart/delete)
manage_project_state() {
  local project_dir="${1:-.}"
  local action="${2}"  # start, stop, restart, delete
  
  local original_dir="$PWD"
  cd "$project_dir" || { msg_error "Could not cd to $project_dir"; return 1; }
  
  msg_debug "Managing project state: $action"
  
  case "$action" in
    start)
      if timeout 120 ddev start; then
        cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
        msg_success "DDEV project started"
        return 0
      fi
      ;;
    stop)
      if ddev stop; then
        cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
        msg_success "DDEV project stopped"
        return 0
      fi
      ;;
    restart)
      if timeout 120 ddev restart; then
        cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
        msg_success "DDEV project restarted"
        return 0
      fi
      ;;
    delete)
      if ddev delete -y; then
        cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
        msg_success "DDEV project deleted"
        return 0
      fi
      ;;
    *)
      cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
      msg_error "Unknown action: $action (use: start, stop, restart, delete)"
      return 1
      ;;
  esac
  
  cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
  msg_error "DDEV $action command failed"
  return 1
}

# Export database backup using DDEV
export_database_backup() {
  local project_dir="${1:-.}"
  local output_file="${2}"
  
  local original_dir="$PWD"
  cd "$project_dir" || { msg_error "Could not cd to $project_dir"; return 1; }
  
  # Check if project is running
  if ! ddev describe >/dev/null 2>&1; then
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "DDEV project not running - run 'ddev start' first"
    return 1
  fi
  
  msg_debug "Exporting database to: $output_file"
  
  # Export database
  if ddev export-db --file="$output_file"; then
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_success "Database exported to $output_file"
    return 0
  else
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "Database export failed"
    return 1
  fi
}

# Get container logs for troubleshooting
get_container_logs() {
  local project_dir="${1:-.}"
  local service="${2:-web}"
  local lines="${3:-50}"
  
  local original_dir="$PWD"
  cd "$project_dir" || { msg_error "Could not cd to $project_dir"; return 1; }
  
  msg_debug "Retrieving $lines lines from $service service logs"
  
  # Get logs from specified service
  if ddev logs -s "$service" -t "$lines"; then
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_success "Retrieved $lines lines from $service service logs"
    return 0
  else
    cd "$original_dir" || { msg_error "Could not cd to $original_dir"; return 1; }
    msg_error "Failed to retrieve logs from $service service"
    return 1
  fi
}