#!/bin/bash

# DDEV Project Setup and Initial Configuration
# Source: source "$(dirname "${BASH_SOURCE[0]}")/ddev_setup_utils.sh"

# Dependencies available via common.sh

# Setup DDEV project using auto-detection with minimal overrides
setup_ddev_project() {
  local project_dir="${1:-.}"
  local project_name="${2:-}"
  local php_version="${3:-}"
  local nodejs_version="${4:-}"
  
  # Change to project directory
  local original_dir="$PWD"
  cd "$project_dir" || { echo "error:Could not cd to $project_dir"; return 1; }
  
  # Start with auto-detection
  local cmd="ddev config --auto"
  
  # Override only what user explicitly specified
  if [[ -n "$project_name" ]]; then
    cmd+=" --project-name='$project_name'"
  fi
  
  if [[ -n "$php_version" ]]; then
    cmd+=" --php-version='$php_version'"
  fi
  
  if [[ -n "$nodejs_version" ]]; then
    cmd+=" --nodejs-version='$nodejs_version'"
    cmd+=" --corepack-enable"
  fi
  
  # Execute DDEV config command
  if eval "$cmd" 2>/dev/null; then
    cd "$original_dir" || { echo "error:Could not cd to $original_dir"; return 1; }
    echo "success:DDEV project configured with: $cmd"
    return 0
  else
    cd "$original_dir" || { echo "error:Could not cd to $original_dir"; return 1; }
    echo "error:DDEV configuration failed"
    return 1
  fi
}

# Setup mkcert SSL certificates (requires user interaction)
setup_mkcert_ssl() {
  msg_info "Setting up SSL certificates with mkcert..."
  msg_info "This may require sudo password for certificate installation"
  
  # Run mkcert -install with user interaction
  if mkcert -install; then
    echo "success:SSL certificates installed successfully"
    return 0
  else
    echo "error:Failed to install SSL certificates"
    return 1
  fi
}

# Interactive setup helper for DDEV environment
setup_ddev_environment() {
  msg_info "Setting up DDEV environment..."
  
  # Check current permissions
  local perm_status
  perm_status=$(check_ddev_permissions)
  local perm_result="${perm_status%%:*}"
  
  if [[ "$perm_result" == "success" ]]; then
    echo "success:DDEV environment already set up"
    return 0
  fi
  
  msg_warn "${perm_status#*:}"
  msg_info "Some setup steps may require user interaction..."
  
  # Setup mkcert if needed
  local mkcert_status
  mkcert_status=$(check_mkcert_setup)
  local mkcert_result="${mkcert_status%%:*}"
  
  if [[ "$mkcert_result" == "partial" ]]; then
    msg_info "Setting up SSL certificates..."
    if setup_mkcert_ssl; then
      echo "success:SSL certificates configured"
    else
      echo "warn:SSL certificate setup failed - HTTPS may not work"
    fi
  fi
  
  echo "success:DDEV environment setup completed"
  return 0
}

# Start DDEV project with interactive setup support
start_ddev_project() {
  local project_dir="${1:-.}"
  local original_dir="$PWD"
  
  cd "$project_dir" || { echo "error:Could not cd to $project_dir"; return 1; }
  
  # Check mkcert setup before starting
  local mkcert_status
  mkcert_status=$(check_mkcert_setup)
  local mkcert_result="${mkcert_status%%:*}"
  
  if [[ "$mkcert_result" == "partial" ]]; then
    msg_warn "${mkcert_status#*:}"
    msg_info "HTTPS may not work properly without mkcert setup"
  elif [[ "$mkcert_result" == "missing" ]]; then
    msg_warn "mkcert not available - HTTPS certificates may not work"
  fi
  
  # Start DDEV with skip-confirmation to avoid hanging on interactive prompts
  msg_info "Starting DDEV project (may require sudo for /etc/hosts)..."
  if timeout 120 ddev start -y; then
    # Get project URL using JSON output for reliable parsing
    local url
    if url=$(ddev describe --json-output 2>/dev/null | grep -o '"primary_url":"[^"]*"' | cut -d'"' -f4); then
      cd "$original_dir" || { echo "error:Could not cd to $original_dir"; return 1; }
      echo "success:Project started at $url"
      return 0
    else
      cd "$original_dir" || { echo "error:Could not cd to $original_dir"; return 1; }
      echo "success:Project started (URL not available)"
      return 0
    fi
  else
    cd "$original_dir" || { echo "error:Could not cd to $original_dir"; return 1; }
    echo "error:Failed to start DDEV project (timeout or permission issue -- timeout is 120s)"
    return 1
  fi
}

# Backup existing DDEV configuration
backup_ddev_config() {
  local project_dir="${1:-.}"
  
  if [[ ! -d "$project_dir/.ddev" ]]; then
    echo "none:No DDEV configuration to backup"
    return 0
  fi
  
  local backup_dir
  backup_dir="$project_dir/.ddev.backup.$(date +%Y%m%d_%H%M%S)"
  if mv "$project_dir/.ddev" "$backup_dir"; then
    echo "success:$backup_dir"
    return 0
  else
    echo "error:Failed to backup DDEV configuration"
    return 1
  fi
}

# Let DDEV detect docroot automatically - kept for compatibility
detect_docroot() {
  local project_dir="${1:-.}"
  echo "auto:Let DDEV auto-detect docroot"
  return 0
}