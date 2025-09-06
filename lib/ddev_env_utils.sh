#!/bin/bash

# DDEV Environment Testing and Information Gathering
# Source: source "$(dirname "${BASH_SOURCE[0]}")/ddev_env_utils.sh"

# Messaging functions available via common.sh

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
  if ! command -v docker >/dev/null 2>&1; then
    echo "error:Docker not installed"
    return 1
  fi
  
  # Use DDEV's diagnostic
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

# Get project information via DDEV
get_ddev_project_info() {
  local project_dir="${1:-.}"
  local original_dir="$PWD"
  
  cd "$project_dir" || { echo "error:Could not cd to $project_dir"; return 1; }
  
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

# Check if DDEV project exists and is configured
check_ddev_project_exists() {
  local project_dir="${1:-.}"
  
  if [[ ! -d "$project_dir/.ddev" ]] || [[ ! -f "$project_dir/.ddev/config.yaml" ]]; then
    echo "none:No DDEV configuration found"
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
  local original_dir="$PWD"
  
  cd "$project_dir" || { echo "Could not cd to $project_dir"; return 1; }
  
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

# Check DDEV environment permissions and requirements
check_ddev_permissions() {
  local issues=()
  
  # Check Docker group membership
  if [[ ! "$(groups)" =~ docker ]]; then
    issues+=("User not in docker group (run: sudo usermod -aG docker $USER)")
  fi
  
  # Check /etc/hosts write permissions
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

# Get Node.js version from DDEV project config
get_ddev_nodejs_version() {
  local project_dir="${1:-.}"
  local original_dir="$PWD"
  
  cd "$project_dir" || { echo "error:Could not cd to $project_dir"; return 1; }
  
  # Get nodejs version from DDEV config
  local nodejs_version
  if [[ -f ".ddev/config.yaml" ]] && nodejs_version=$(grep "^nodejs_version:" ".ddev/config.yaml" 2>/dev/null | cut -d: -f2 | tr -d ' "'); then
    cd "$original_dir" || { echo "error:Could not cd to $original_dir"; return 1; }
    echo "$nodejs_version"
    return 0
  else
    cd "$original_dir" || { echo "error:Could not cd to $original_dir"; return 1; }
    echo "none:No Node.js version configured"
    return 1
  fi
}

# Legacy compatibility function
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