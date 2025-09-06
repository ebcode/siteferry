#!/bin/bash

# Configuration management utilities  
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/config_utils.sh"

# Site-aware functions for multi-site support
get_current_site_name() {
    # Extract site name from config file path: sites-config/sitename/sitename.config -> sitename
    # Default to "default" if not in a site-specific context
    local config_file="${SITE_CONFIG_FILE:-sites-config/default/default.config}"
    local site_dir
    site_dir="${config_file%/*}"    # Remove filename, get directory
    local site_name
    site_name="${site_dir##*/}"     # Remove path prefix, get site name
    echo "$site_name"
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
    # List all site directories in sites-config/ using parameter expansion
    local site_name
    for dir in sites-config/*/; do
        site_name="${dir%/}"      # Remove trailing slash
        site_name="${site_name##*/}"  # Remove path prefix, get site name
        echo "$site_name"
    done | sort
}

validate_site_name() {
    local site_name="$1"
    local available_sites
    mapfile -t available_sites < <(get_available_sites)
    
    for site in "${available_sites[@]}"; do
        if [[ "$site" == "$site_name" ]]; then
            return 0
        fi
    done
    return 1
}

# Load site configuration (replaces load_backup_config)
load_site_config() {
    local site_name="${1:-$(get_current_site_name)}"
    local config_file
    config_file="$(get_site_config_path "$site_name")"
    
    # Adjust path if we're in the lib directory
    if [[ "$(basename "$(dirname "${BASH_SOURCE[0]}")")" == "lib" ]]; then
        config_file="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/$config_file"
    fi
    
    if [[ -f "$config_file" ]]; then
        # Source the site config file to load variables
        # shellcheck source=/dev/null
        source "$config_file"
    else
        return 1
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