#!/bin/bash

# Setup DDEV - Intelligent DDEV configuration with auto-detection
# Sets: setup_ddev_status, setup_ddev_message

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/messaging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

ACTION=$(get_current_script_name)

main() {
    # Get state from previous pipeline stage
    local input
    if input=$(cat); then
        eval "$input"
    fi
    
    # Check if this action is enabled
    if ! is_enabled "$ACTION"; then
        set_status "$ACTION" "skipped" "Disabled in configuration"
        pass_state
        return 0
    fi
    
    msg_info "Setting up DDEV project with intelligent configuration..."
    
    # Load site configuration
    if ! load_site_config; then
        set_status "$ACTION" "error" "Failed to load site configuration"
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
            set_status "$ACTION" "error" "DDEV environment verification failed: $status_msg"
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
            set_status "$ACTION" "error" "Failed to create site directory: $site_local_path"
            pass_state
            return 1
        fi
    fi
    
    # Change to site directory for DDEV operations
    local original_dir="$PWD"
    if ! cd "$site_local_path"; then
        set_status "$ACTION" "error" "Failed to change to site directory: $site_local_path"
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
                set_status "$ACTION" "error" "Cannot proceed without backing up existing config"
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
                    set_status "$ACTION" "success" "DDEV project already configured and running: $status_info"
                    pass_state
                    return 0
                fi
            fi
        fi
    fi
    
    # Intelligent project detection
    msg_info "Analyzing project structure for optimal DDEV configuration..."
    local detected_type
    detected_type=$(detect_project_type .)
    local project_type="${detected_type%%:*}"
    local type_details="${detected_type#*:}"
    msg_info "$type_details"
    
    # Use configured project type if available, otherwise use detection
    local final_project_type="${PROJECT_TYPE:-$project_type}"
    
    # Get project name from config or default to site name
    local project_name="${DDEV_PROJECT_NAME:-$(get_current_site_name)}"
    
    # Detect docroot
    local docroot
    docroot=$(detect_docroot .)
    if [[ -n "$docroot" ]]; then
        msg_info "Detected docroot: $docroot"
    fi
    
    # Get version settings
    local php_version="${DDEV_PHP_VERSION:-8.2}"
    local nodejs_version="${DDEV_NODEJS_VERSION:-$(detect_nodejs_version .)}"
    
    # Build intelligent DDEV config command
    local ddev_cmd
    ddev_cmd=$(build_ddev_config_command "$final_project_type" "$project_name" "$php_version" "$nodejs_version" "$docroot")
    
    msg_info "Configuring DDEV project: $project_name"
    msg_info "Project type: $final_project_type"
    if [[ "$final_project_type" == php* ]] || [[ "$final_project_type" == *wordpress* ]] || [[ "$final_project_type" == *drupal* ]] || [[ "$final_project_type" == *laravel* ]] || [[ "$final_project_type" == *symfony* ]]; then
        msg_info "PHP version: $php_version"
    fi
    if [[ "$final_project_type" == nodejs* ]]; then
        msg_info "Node.js version: $nodejs_version"
    fi
    if [[ -n "$docroot" ]]; then
        msg_info "Document root: $docroot"
    fi
    
    # Execute DDEV configuration
    msg_info "Running: $ddev_cmd"
    if eval "$ddev_cmd"; then
        msg_success "DDEV configuration completed"
    else
        # If auto-config fails, try fallback manual configuration
        msg_warn "Auto-configuration failed, attempting manual configuration..."
        
        # Create basic configuration manually
        if ! mkdir -p .ddev; then
            cd "$original_dir"
            set_status "$ACTION" "error" "Failed to create .ddev directory"
            pass_state
            return 1
        fi
        
        # Generate basic config.yaml
        cat > .ddev/config.yaml << EOF
name: ${project_name}
type: ${final_project_type}
docroot: "${docroot}"
EOF
        
        # Add version-specific settings
        if [[ "$final_project_type" == php* ]] || [[ "$final_project_type" == *wordpress* ]] || [[ "$final_project_type" == *drupal* ]] || [[ "$final_project_type" == *laravel* ]] || [[ "$final_project_type" == *symfony* ]]; then
            echo "php_version: \"${php_version}\"" >> .ddev/config.yaml
        fi
        
        if [[ "$final_project_type" == nodejs* ]]; then
            echo "nodejs_version: \"${nodejs_version}\"" >> .ddev/config.yaml
        fi
        
        # Add SiteFerry metadata
        cat >> .ddev/config.yaml << EOF

# Auto-generated by SiteFerry
# Generated on: $(date)
# Site: $(get_current_site_name)
EOF
        
        if [[ -f ".ddev/config.yaml" ]]; then
            msg_success "Manual DDEV configuration created"
        else
            cd "$original_dir"
            set_status "$ACTION" "error" "Failed to create DDEV configuration"
            pass_state
            return 1
        fi
    fi
    
    # Attempt to start the DDEV project
    msg_info "Starting DDEV project..."
    if ddev start; then
        # Get project status and URL
        local project_status
        if project_status=$(get_ddev_project_status .); then
            local status_type="${project_status%%:*}"
            local status_info="${project_status#*:}"
            
            if [[ "$status_type" == "running" ]] && [[ "$status_info" != "URL not available" ]]; then
                msg_success "DDEV project started successfully"
                msg_info "Project URL: $status_info"
                cd "$original_dir"
                set_status "$ACTION" "success" "DDEV project configured and started: $status_info"
                pass_state
                return 0
            else
                msg_success "DDEV project started successfully"
                cd "$original_dir"
                set_status "$ACTION" "success" "DDEV project configured and started"
                pass_state
                return 0
            fi
        else
            msg_success "DDEV project started successfully"
            cd "$original_dir"
            set_status "$ACTION" "success" "DDEV project configured and started"
            pass_state
            return 0
        fi
    else
        # DDEV start failed - provide helpful diagnostics
        msg_warn "DDEV project configured but failed to start"
        msg_info "Configuration saved to: ${site_local_path}/.ddev/config.yaml"
        msg_info "You can manually start the project with: cd '$site_local_path' && ddev start"
        
        # Check if it's a Docker issue
        if ! ddev debug dockercheck >/dev/null 2>&1; then
            msg_warn "Docker may not be running or properly configured"
            msg_info "Try: docker --version && docker ps"
        fi
        
        cd "$original_dir"
        set_status "$ACTION" "partial" "DDEV configured but failed to start (run 'ddev start' manually from $site_local_path)"
        pass_state
        return 0
    fi
}

main