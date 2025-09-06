#!/bin/bash

# DDEV utilities for environment verification and project management
# Source this file in other modules: source "$(dirname "${BASH_SOURCE[0]}")/ddev_utils.sh"

# DDEV installation and environment verification
verify_ddev_installation() {
  if ! command -v ddev >/dev/null 2>&1; then
    echo "error:DDEV not installed"
    return 1
  fi
  
  # Get DDEV version for status reporting
  local version
  if version=$(ddev -v 2>/dev/null); then
    echo "success:$version"
    return 0
  else
    echo "error:DDEV installed but not functioning"
    return 1
  fi
}

# Verify Docker availability for DDEV
verify_docker_for_ddev() {
  # First check if Docker is installed
  if ! command -v docker >/dev/null 2>&1; then
    echo "error:Docker not installed"
    return 1
  fi
  
  # Check if Docker daemon is running by using DDEV's diagnostic
  if ddev debug dockercheck >/dev/null 2>&1; then
    echo "success:Docker available for DDEV"
    return 0
  else
    echo "error:Docker not available for DDEV"
    return 1
  fi
}

# Run comprehensive DDEV environment diagnostics
run_ddev_diagnostics() {
  local result
  result=$(verify_ddev_installation)
  if [[ $result != success:* ]]; then
    echo "$result"
    return 1
  fi
  
  result=$(verify_docker_for_ddev)
  if [[ $result != success:* ]]; then
    echo "$result"
    return 1
  fi
  
  # Run DDEV's built-in test suite
  if ddev debug test >/dev/null 2>&1; then
    echo "success:DDEV environment fully functional"
    return 0
  else
    echo "partial:DDEV installed but diagnostics failed"
    return 2
  fi
}

# Delegate project type detection to DDEV
get_ddev_project_info() {
  local project_dir="${1:-.}"
  
  # Change to project directory for DDEV commands
  local original_dir="$PWD"
  cd "$project_dir" || { echo "error:Could not cd to $project_dir"; return 1; }
  
  # Use DDEV to get project information
  if ddev describe --json >/dev/null 2>&1; then
    local project_info
    project_info=$(ddev describe --json 2>/dev/null)
    cd "$original_dir" || { echo "error:Could not cd to $original_dir"; return 1; }
    echo "success:$project_info"
    return 0
  else
    cd "$original_dir" || { echo "error:Could not cd to $original_dir"; return 1; }
    echo "none:No DDEV project configured"
    return 1
  fi
}

# Let DDEV detect docroot automatically - this function kept for compatibility
detect_docroot() {
  local project_dir="${1:-.}"
  echo "auto:Let DDEV auto-detect docroot"
  return 0
}

# Get appropriate Node.js version for project
detect_nodejs_version() {
  local project_dir="${1:-.}"
  
  # Check .nvmrc file
  if [[ -f "$project_dir/.nvmrc" ]]; then
    local version
    version=$(< "$project_dir/.nvmrc" tr -d '\n\r' | sed 's/^v//')
    if [[ -n "$version" ]]; then
      echo "$version"
      return 0
    fi
  fi
  
  # Check package.json engines field
  if [[ -f "$project_dir/package.json" ]]; then
    local version
    version=$(grep -o '"node"[[:space:]]*:[[:space:]]*"[^"]*"' "$project_dir/package.json" 2>/dev/null | cut -d'"' -f4 | sed 's/[^0-9.]//g' | head -1)
    if [[ -n "$version" ]]; then
      echo "$version"
      return 0
    fi
  fi
  
  # Default to LTS version
  echo "20"
  return 0
}

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

# Check if DDEV project exists and is configured
check_ddev_project_exists() {
  local project_dir="${1:-.}"
  
  if [[ ! -d "$project_dir/.ddev" ]]; then
    echo "none:No DDEV configuration found"
    return 1
  fi
  
  if [[ ! -f "$project_dir/.ddev/config.yaml" ]]; then
    echo "partial:DDEV directory exists but no config.yaml"
    return 1
  fi
  
  # Extract project name from config
  local project_name
  if project_name=$(grep "^name:" "$project_dir/.ddev/config.yaml" 2>/dev/null | cut -d: -f2 | tr -d ' "'); then
    echo "exists:$project_name"
    return 0
  else
    echo "partial:DDEV config exists but malformed"
    return 1
  fi
}

# Get DDEV project status and URL
get_ddev_project_status() {
  local project_dir="${1:-.}"
  
  # Change to project directory for DDEV commands
  local original_dir="$PWD"
  cd "$project_dir" || { echo "Could not cd to $project_dir"; return 1; }
  
  # Check if project is running
  if ! ddev describe >/dev/null 2>&1; then
    cd "$original_dir" || { echo "Could not cd to $original_dir"; return 1; }
    echo "stopped:Project not running"
    return 1
  fi
  
  # Extract URL from ddev describe
  local url
  if url=$(ddev describe 2>/dev/null | grep -i "primary url" | cut -d: -f2- | tr -d ' ' | head -1); then
    cd "$original_dir" || { echo "Could not cd to $original_dir"; return 1; }
    echo "running:$url"
    return 0
  else
    cd "$original_dir" || { echo "Could not cd to $original_dir"; return 1; }
    echo "running:URL not available"
    return 0
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


# Check if mkcert is installed and CA is set up
check_mkcert_setup() {
  if ! command -v mkcert >/dev/null 2>&1; then
    echo "missing:mkcert not installed"
    return 1
  fi
  
  # Check if CA root exists and is installed
  local caroot
  if caroot=$(mkcert -CAROOT 2>/dev/null) && [[ -d "$caroot" ]]; then
    echo "success:mkcert CA available at $caroot"
    return 0
  else
    echo "partial:mkcert installed but CA not set up (run 'mkcert -install')"
    return 2
  fi
}

# Setup mkcert SSL certificates (requires user interaction)
setup_mkcert_ssl() {
  echo "info:Setting up SSL certificates with mkcert..."
  echo "info:This may require sudo password for certificate installation"
  
  # Run mkcert -install with user interaction
  if mkcert -install; then
    echo "success:SSL certificates installed successfully"
    return 0
  else
    echo "error:Failed to install SSL certificates"
    return 1
  fi
}

# Start DDEV project with interactive setup support
start_ddev_project() {
  local project_dir="${1:-.}"
  
  # Change to project directory
  local original_dir="$PWD"
  cd "$project_dir" || { echo "error:Could not cd to $project_dir"; return 1; }
  
  # Check mkcert setup before starting
  local mkcert_status
  mkcert_status=$(check_mkcert_setup)
  local mkcert_result="${mkcert_status%%:*}"
  
  if [[ "$mkcert_result" == "partial" ]]; then
    echo "warn:${mkcert_status#*:}"
    echo "info:HTTPS may not work properly without mkcert setup"
  elif [[ "$mkcert_result" == "missing" ]]; then
    echo "warn:mkcert not available - HTTPS certificates may not work"
  fi
  
  # Start DDEV with skip-confirmation to avoid hanging on interactive prompts
  # This allows /etc/hosts modifications and other setup to proceed
  echo "info:Starting DDEV project (may require sudo for /etc/hosts)..."
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

# Comprehensive DDEV environment and permissions check
check_ddev_permissions() {
  local issues=()
  
  # Check Docker group membership
  local user_groups
  user_groups="$(groups)"
  if [[ ! "$user_groups" =~ docker ]]; then
    issues+=("User not in docker group (run: sudo usermod -aG docker $USER)")
  fi
  
  # Check if user can write to /etc/hosts (for DDEV hostname management)
  if [[ ! -w "/etc/hosts" ]] && ! sudo -n true 2>/dev/null; then
    issues+=("Cannot write to /etc/hosts - DDEV start may require sudo password")
  fi
  
  # Check mkcert setup
  local mkcert_status
  mkcert_status=$(check_mkcert_setup)
  local mkcert_result="${mkcert_status%%:*}"
  if [[ "$mkcert_result" != "success" ]]; then
    issues+=("${mkcert_status#*:}")
  fi
  
  if [[ ${#issues[@]} -eq 0 ]]; then
    echo "success:DDEV permissions and SSL setup complete"
    return 0
  else
    local issue_list
    printf -v issue_list "%s; " "${issues[@]}"
    echo "partial:${issue_list%; }"
    return 1
  fi
}

# Interactive setup helper for DDEV environment
setup_ddev_environment() {
  echo "info:Setting up DDEV environment..."
  
  # Check current permissions
  local perm_status
  perm_status=$(check_ddev_permissions)
  local perm_result="${perm_status%%:*}"
  
  if [[ "$perm_result" == "success" ]]; then
    echo "success:DDEV environment already set up"
    return 0
  fi
  
  echo "warn:${perm_status#*:}"
  echo "info:Some setup steps may require user interaction..."
  
  # Setup mkcert if needed
  local mkcert_status
  mkcert_status=$(check_mkcert_setup)
  local mkcert_result="${mkcert_status%%:*}"
  
  if [[ "$mkcert_result" == "partial" ]]; then
    echo "info:Setting up SSL certificates..."
    if setup_mkcert_ssl; then
      echo "success:SSL certificates configured"
    else
      echo "warn:SSL certificate setup failed - HTTPS may not work"
    fi
  fi
  
  echo "success:DDEV environment setup completed"
  return 0
}

# Legacy function - kept for compatibility
user_can_docker() {
  local perm_status
  perm_status=$(check_ddev_permissions)
  local perm_result="${perm_status%%:*}"
  
  if [[ "$perm_result" == "success" ]]; then
    echo "user can docker and DDEV environment is ready"
    return 0
  else
    echo "${perm_status#*:}"
    return 1
  fi
}
