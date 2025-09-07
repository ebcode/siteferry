#!/bin/bash

# Configuration management utilities  
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/config_utils.sh"

# Source functional programming libraries
SOURCE_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SOURCE_DIR/fp_bash.sh"
source "$SOURCE_DIR/siteferry-functional.sh"

# Functional site-aware functions for multi-site support
get_current_site_name() {
  local config_file="${SITE_CONFIG_FILE:-sites-config/default/default.config}"
  
  # Pure function chain for path extraction using simpler approach
  local site_dir
  site_dir=$(dirname "$config_file")
  basename "$site_dir"
}

get_site_config_path() {
  local site_name="${1:-$(get_current_site_name)}"
  echo "sites-config/${site_name}/${site_name}.config"
}

get_site_local_path() {
  local site_name="${1:-$(get_current_site_name)}"
  echo "sites/${site_name}/"
}

get_available_sites() {
  # Functional approach to listing site directories
  # shellcheck disable=SC2012,SC2016
  ls -d sites-config/*/ 2>/dev/null | \
    map '( basename "${1%/}" )' | \
    sort
}

validate_site_name() {
  local site_name="$1"
  
  # Use functional 'some' to check if site exists
  get_available_sites | some "( [[ \"$1\" == \"$site_name\" ]] )"
}

# Pure functional site configuration creation
create_immutable_site_config() {
  local site_name="${1:-$(get_current_site_name)}"
  local config_file
  config_file="$(get_site_config_path "$site_name")"
  
  # Adjust path if we're in the lib directory
  if [[ "$(basename "$(dirname "${BASH_SOURCE[0]}")")" == "lib" ]]; then
    config_file="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/$config_file"
  fi
  
  if [[ -f "$config_file" ]]; then
    # Parse config file
    # shellcheck disable=SC2002
    cat "$config_file" | \
      filter 'has_assignment' | \
      reduce 'combine_lines' ""
  else
    either_left "Config file not found: $config_file"
  fi
}

# Helper functions for functional config processing
has_assignment() {
  local line="$1"
  [[ "$line" =~ ^[^#]*= ]] && [[ -n "${line%%#*}" ]]
}

combine_lines() {
  local acc="$1"
  local line="$2"
  if [[ -n "$acc" ]]; then
    printf "%s\n%s\n" "$acc" "$line"
  else
    echo "$line"
  fi
}

# Backwards compatibility wrapper using functional core
load_site_config() {
  local site_name="${1:-$(get_current_site_name)}"
  local config_result
  config_result="$(create_immutable_site_config "$site_name")"
  
  if either_is_right "$config_result"; then
    # Parse and source the config functionally
    local config_data
    config_data="$(either_extract_right "$config_result")"
    while IFS='=' read -r key value; do
      if [[ -n "$key" ]] && [[ "$key" != *" "* ]]; then
        export "$key=$value"
      fi
    done <<< "$config_data"
    return 0
  else
    # Fallback to direct sourcing if functional approach fails
    local config_file
    config_file="$(get_site_config_path "$site_name")"
    
    # Adjust path if we're in the lib directory
    if [[ "$(basename "$(dirname "${BASH_SOURCE[0]}")")" == "lib" ]]; then
      config_file="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/$config_file"
    fi
    
    if [[ -f "$config_file" ]]; then
      # shellcheck source=/dev/null
      source "$config_file"
      return 0
    else
      return 1
    fi
  fi
}

# Create a default site config template with empty values
create_default_site_config() {
  local site_name="${1:-default}"
  local config_dir="sites-config/${site_name}"
  local config_file="${config_dir}/${site_name}.config"
  
  # Create directory if it doesn't exist
  mkdir -p "$config_dir"
  
  # Create config file with empty values
  cat > "$config_file" << 'TEMPLATE'
# SiteFerry - Site Configuration: SITE_NAME
# Connection settings for database and files backup retrieval

# Remote server connection
REMOTE_HOST=
REMOTE_PORT=
REMOTE_PATH=
REMOTE_USER=
REMOTE_DB_BACKUP=
REMOTE_FILES_BACKUP=

# Site metadata
TAGS=""

# DDEV integration
PROJECT_TYPE=""
DDEV_PROJECT_NAME=""
DDEV_PHP_VERSION=""

# Hook placeholders (not implemented yet)
POST_DB_IMPORT=""
PRE_FILES_IMPORT=""
TEMPLATE

  # Replace SITE_NAME placeholder with actual site name
  sed -i "s/SITE_NAME/${site_name}/g" "$config_file"
  
  echo "Created template config: $config_file"
}

# Pure functional configuration accessor functions
get_config_value() {
  local config_data="$1"
  local key="$2"
  local default_value="${3:-}"
  
  echo "$config_data" | \
    filter "( [[ \"\$1\" =~ ^$key= ]] )" | \
    map "( echo \"\${1#$key=}\" )" | \
    head -1 || echo "$default_value"
}

# Validate configuration using functional patterns
validate_config_chain() {
  local config_data="$1"
  shift
  
  for validator in "$@"; do
    if ! echo "$config_data" | "$validator"; then
      return 1
    fi
  done
  return 0
}

# Configuration validation predicates
has_required_keys() {
  local required_keys=("$@")
  local line
  local found=0
  
  while IFS= read -r line; do
    for key in "${required_keys[@]}"; do
      if [[ "$line" =~ ^$key= ]]; then
        ((found++))
      fi
    done
  done
  
  [[ $found -eq ${#required_keys[@]} ]]
}
