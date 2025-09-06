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

# Detect project type from current directory
detect_project_type() {
    local project_dir="${1:-.}"
    
    # Node.js projects
    if [[ -f "$project_dir/package.json" ]]; then
        # Check for specific Node.js frameworks
        if [[ -f "$project_dir/next.config.js" ]] || [[ -f "$project_dir/next.config.ts" ]]; then
            echo "nodejs:Next.js project detected"
            return 0
        elif [[ -f "$project_dir/nuxt.config.js" ]] || [[ -f "$project_dir/nuxt.config.ts" ]]; then
            echo "nodejs:Nuxt.js project detected"
            return 0
        elif grep -q '"@angular/core"' "$project_dir/package.json" 2>/dev/null; then
            echo "nodejs:Angular project detected"
            return 0
        elif grep -q '"react"' "$project_dir/package.json" 2>/dev/null; then
            echo "nodejs:React project detected"
            return 0
        else
            echo "nodejs:Node.js project detected"
            return 0
        fi
    fi
    
    # PHP projects
    if [[ -f "$project_dir/composer.json" ]]; then
        # Check for specific PHP frameworks/CMS
        if [[ -f "$project_dir/wp-config.php" ]] || [[ -d "$project_dir/wp-content" ]]; then
            echo "wordpress:WordPress project detected"
            return 0
        elif [[ -f "$project_dir/sites/default/settings.php" ]] || [[ -d "$project_dir/web/sites" ]]; then
            # Determine Drupal version
            if grep -q '"drupal/core".*"[^:]*:.*"1[01]\.' "$project_dir/composer.json" 2>/dev/null; then
                echo "drupal11:Drupal 11 project detected"
            elif grep -q '"drupal/core".*"[^:]*:.*"10\.' "$project_dir/composer.json" 2>/dev/null; then
                echo "drupal10:Drupal 10 project detected"
            else
                echo "drupal:Drupal project detected"
            fi
            return 0
        elif grep -q '"laravel/framework"' "$project_dir/composer.json" 2>/dev/null; then
            echo "laravel:Laravel project detected"
            return 0
        elif grep -q '"symfony/framework-bundle"' "$project_dir/composer.json" 2>/dev/null; then
            echo "symfony:Symfony project detected"
            return 0
        else
            echo "php:PHP project detected"
            return 0
        fi
    fi
    
    # Static sites or unknown
    if [[ -f "$project_dir/index.html" ]] || [[ -f "$project_dir/index.htm" ]]; then
        echo "generic:Static HTML project detected"
        return 0
    fi
    
    echo "generic:No specific project type detected"
    return 0
}

# Extract docroot from project structure
detect_docroot() {
    local project_dir="${1:-.}"
    
    # Common docroot directories, in order of preference
    local potential_docroots=("web" "public" "htdocs" "docroot" "www" "html")
    
    for docroot in "${potential_docroots[@]}"; do
        if [[ -d "$project_dir/$docroot" ]]; then
            echo "$docroot"
            return 0
        fi
    done
    
    # No specific docroot found, use empty (current directory)
    echo ""
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

# Build DDEV config command with intelligent flags
build_ddev_config_command() {
    local project_type="${1:-}"
    local project_name="${2:-}"
    local php_version="${3:-8.2}"
    local nodejs_version="${4:-20}"
    local docroot="${5:-}"
    
    local cmd="ddev config --auto"
    
    # Add project name if specified
    if [[ -n "$project_name" ]]; then
        cmd+=" --project-name='$project_name'"
    fi
    
    # Add project type - extract base type (before colon)
    if [[ -n "$project_type" ]]; then
        local base_type="${project_type%%:*}"
        cmd+=" --project-type='$base_type'"
    fi
    
    # Add docroot if specified
    if [[ -n "$docroot" ]]; then
        cmd+=" --docroot='$docroot'"
    fi
    
    # Add PHP version for PHP projects
    if [[ "$project_type" == php* ]] || [[ "$project_type" == *wordpress* ]] || [[ "$project_type" == *drupal* ]] || [[ "$project_type" == *laravel* ]] || [[ "$project_type" == *symfony* ]]; then
        cmd+=" --php-version='$php_version'"
    fi
    
    # Add Node.js version for Node.js projects
    if [[ "$project_type" == nodejs* ]]; then
        cmd+=" --nodejs-version='$nodejs_version'"
        cmd+=" --corepack-enable"
    fi
    
    echo "$cmd"
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


# Check user is in docker group
user_can_docker() {
	local user_groups
	user_groups="$(groups)"
	
	if [[ "$user_groups" =~ docker ]];then	  
	  echo "user can docker"
	  return 0
	fi
	echo "User may need to be added to docker group"
	return 1
}
