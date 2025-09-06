#!/bin/bash

# Setup DDEV - Intelligent DDEV configuration with auto-detection
# Sets: setup_ddev_status, setup_ddev_message

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
  
  msg_info "Setting up DDEV project with intelligent configuration..."
  
  # Load site configuration
  if ! load_site_config; then
    set_status "$action" "error" "Failed to load site configuration"
    pass_state
    return 1
  fi
  
  # Verify DDEV environment
  msg_info "Verifying DDEV environment..."
  local ddev_status
  if ddev_status=$(run_ddev_diagnostics); then
    msg_success "${ddev_status#*:}"
  else
    local status_type="${ddev_status%%:*}"
    local status_msg="${ddev_status#*:}"
    
    if [[ "$status_type" == "partial" ]]; then
      msg_warn "$status_msg"
      msg_warn "DDEV configuration will be created but may not start"
    else
      msg_error "$status_msg"
      set_status "$action" "error" "DDEV environment verification failed: $status_msg"
      pass_state
      return 1
    fi
  fi
  
  # Get site local path
  local site_local_path
  site_local_path=$(get_site_local_path)
  
  # Ensure site directory exists
  if [[ ! -d "$site_local_path" ]]; then
    msg_info "Creating site directory: $site_local_path"
    if ! mkdir -p "$site_local_path"; then
      set_status "$action" "error" "Failed to create site directory: $site_local_path"
      pass_state
      return 1
    fi
  fi
  
  # Change to site directory for DDEV operations
  local original_dir="$PWD"
  if ! cd "$site_local_path"; then
    set_status "$action" "error" "Failed to change to site directory: $site_local_path"
    pass_state
    return 1
  fi
  
  # Check for existing DDEV configuration
  local existing_config
  existing_config=$(check_ddev_project_exists .)
  local existing_status="${existing_config%%:*}"
  local existing_name="${existing_config#*:}"
  
  if [[ "$existing_status" == "exists" ]]; then
    # Validate existing configuration against site config
    if [[ -n "${DDEV_PROJECT_NAME:-}" ]] && [[ "$existing_name" != "$DDEV_PROJECT_NAME" ]]; then
      msg_warn "Existing DDEV project name '$existing_name' differs from configured '${DDEV_PROJECT_NAME}'"
      
      # Backup existing configuration
      local backup_result
      backup_result=$(backup_ddev_config .)
      local backup_status="${backup_result%%:*}"
      
      if [[ "$backup_status" == "success" ]]; then
        msg_info "Backed up existing configuration to: ${backup_result#*:}"
      else
        msg_error "Failed to backup existing DDEV configuration"
        cd "$original_dir"
        set_status "$action" "error" "Cannot proceed without backing up existing config"
        pass_state
        return 1
      fi
    else
      msg_info "Existing DDEV configuration found for project: $existing_name"
      
      # Check if project is already running
      local project_status
      if project_status=$(get_ddev_project_status .); then
        local status_type="${project_status%%:*}"
        local status_info="${project_status#*:}"
        
        if [[ "$status_type" == "running" ]]; then
          msg_success "DDEV project already running: $status_info"
          cd "$original_dir"
          set_status "$action" "success" "DDEV project already configured and running: $status_info"
          pass_state
          return 0
        fi
      fi
    fi
  fi
  
  # Get project name from config or default to site name
  local project_name="${DDEV_PROJECT_NAME:-$(get_current_site_name)}"
  local php_version="${DDEV_PHP_VERSION:-}"
  local nodejs_version="${DDEV_NODEJS_VERSION:-}"
  
  msg_info "Configuring DDEV project: $project_name"
  if [[ -n "$php_version" ]]; then
    msg_info "Using configured PHP version: $php_version"
  fi
  if [[ -n "$nodejs_version" ]]; then
    msg_info "Using configured Node.js version: $nodejs_version"
  fi
  
  # Use DDEV's intelligent auto-detection with minimal overrides
  msg_info "Using DDEV auto-detection for optimal configuration..."
  local setup_result
  setup_result=$(setup_ddev_project "." "$project_name" "$php_version" "$nodejs_version")
  local setup_status="${setup_result%%:*}"
  local setup_message="${setup_result#*:}"
  
  if [[ "$setup_status" == "success" ]]; then
    msg_success "$setup_message"
  else
    msg_error "$setup_message"
    cd "$original_dir"
    set_status "$action" "error" "DDEV configuration failed: $setup_message"
    pass_state
    return 1
  fi
  
  # Start the DDEV project
  msg_info "Starting DDEV project..."
  local start_result
  start_result=$(start_ddev_project ".")
  local start_status="${start_result%%:*}"
  local start_message="${start_result#*:}"
  
  if [[ "$start_status" == "success" ]]; then
    msg_success "DDEV project started successfully"
    if [[ "$start_message" != *"URL not available"* ]]; then
      msg_info "Project URL: ${start_message#*started at }"
    fi
    cd "$original_dir"
    set_status "$action" "success" "DDEV project configured and started: $start_message"
    pass_state
    return 0
  else
    # DDEV start failed - provide helpful diagnostics
    msg_warn "DDEV project configured but failed to start: $start_message"
    msg_info "Configuration saved to: ${site_local_path}/.ddev/config.yaml"
    msg_info "You can manually start the project with: cd '$site_local_path' && ddev start"
    
    # Check if it's a Docker issue
    if ! ddev debug dockercheck >/dev/null 2>&1; then
      msg_warn "Docker may not be running or properly configured"
      msg_info "Try: docker --version && docker ps"
    fi
    
    cd "$original_dir"
    set_status "$action" "partial" "DDEV configured but failed to start (run 'ddev start' manually from $site_local_path)"
    pass_state
    return 0
  fi
}

main
