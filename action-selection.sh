#!/bin/bash

# DDEV Backup Manager - Proof of Concept
# Interactive checklist with state persistence

set -euo pipefail

# Site-aware configuration
SITE_NAME="${SITE_NAME:-default}"
CONFIG_FILE="${CONFIG_FILE:-internal-config/last-checked-${SITE_NAME}.config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source messaging system and common functions
source "$SCRIPT_DIR/lib/messaging.sh"
source "$SCRIPT_DIR/lib/common.sh"

# Set site config file for site-aware functions
export SITE_CONFIG_FILE="${SITE_CONFIG_FILE:-$(get_site_config_path "$SITE_NAME")}"

# Dynamic action discovery
get_actions() {
    get_all_numbered_scripts
}

get_action_label() {
    local action="$1"
    get_display_name "$action"
}

# Global variables for checkbox states
declare -A CHECKBOX_STATES

# Function to load previous selections from config file
load_last_selections() {
    local actions
    mapfile -t actions < <(get_actions)
    
    # Initialize all actions as checked by default
    for action in "${actions[@]}"; do
        local base_name
        base_name=$(strip_numeric_prefix "$action")
        CHECKBOX_STATES["$base_name"]="on"
    done
    
    # Load from config file if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            
            # Remove whitespace
            key=$(echo "$key" | tr -d '[:space:]')
            value=$(echo "$value" | tr -d '[:space:]')
            
            # Check if this key matches any action base name
            local actions
            mapfile -t actions < <(get_actions)
            for action in "${actions[@]}"; do
                local base_name
                base_name=$(strip_numeric_prefix "$action")
                if [[ "$key" == "$base_name" ]]; then
                    if [[ "$value" == "true" ]]; then
                        CHECKBOX_STATES["$base_name"]="on"
                    else
                        CHECKBOX_STATES["$base_name"]="off"
                    fi
                    break
                fi
            done
        done < "$CONFIG_FILE"
    fi
}

# Function to save selections to config file
save_selections() {
    local selected_actions=("$@")
    local actions
    mapfile -t actions < <(get_actions)
    
    # Reset all to false first
    for action in "${actions[@]}"; do
        local base_name
        base_name=$(strip_numeric_prefix "$action")
        CHECKBOX_STATES["$base_name"]="false"
    done
    
    # Set selected ones to true
    for action in "${selected_actions[@]}"; do
        CHECKBOX_STATES["$action"]="true"
    done
    
    # Write to config file
    {
        echo "# SiteFerry - Last Selected Actions for site: $SITE_NAME"
        echo "# Generated on $(date)"
        echo ""
        for action in "${actions[@]}"; do
            local base_name
            base_name=$(strip_numeric_prefix "$action")
            echo "$base_name=${CHECKBOX_STATES[$base_name]}"
        done
    } > "$CONFIG_FILE"
    
    msg_success "Selections saved to $CONFIG_FILE"
}

# Function to show dialog checklist
show_action_menu() {
    # Build dialog checklist arguments
    local dialog_args=(
        --backtitle "SiteFerry - Multi-Site Backup Manager"
        --title "Select Actions to Perform - Site: $SITE_NAME"
        --checklist "Use SPACE to select/deselect, ENTER to confirm, ESC to cancel:"
        15 70 6
    )
    
    # Add each action as a checklist item
    local actions
    mapfile -t actions < <(get_actions)
    for action in "${actions[@]}"; do
        local base_name
        base_name=$(strip_numeric_prefix "$action")
        local label
        label=$(get_action_label "$action")
        dialog_args+=("$base_name" "$label" "${CHECKBOX_STATES[$base_name]}")
    done
    
    # Show dialog and capture output
    local selected_actions
    if selected_actions=$(dialog "${dialog_args[@]}" 2>&1 >/dev/tty); then
        # Parse space-separated output into array
        IFS=' ' read -r -a selected_array <<< "$selected_actions"
        echo "${selected_array[@]}"
    else
        # User cancelled
        return 1
    fi
}

# Function to simulate executing selected actions
simulate_actions() {
    local selected_actions=("$@")
    
    echo ""
    echo "=== Executing Selected Actions ==="
    echo ""
    
    if [[ ${#selected_actions[@]} -eq 0 ]]; then
        echo "No actions selected. Nothing to do."
        return 0
    fi
    
    for selected_action in "${selected_actions[@]}"; do
        local action_label
        action_label=$(get_display_name "$selected_action")
        echo "▶ Executing: $action_label"
        case "$selected_action" in
            "preflight_checks")
                echo "  • Checking DDEV installation..."
                echo "  • Verifying disk space..."
                echo "  • Testing SSH connection..."
                ;;
            "fetch_db_backup")
                echo "  • Connecting to backup server..."
                echo "  • Downloading database dump..."
                echo "  • Verifying download integrity..."
                ;;
            "fetch_files_backup")
                echo "  • Downloading files archive..."
                echo "  • Checking archive integrity..."
                ;;
            "import_database")
                echo "  • Starting DDEV database service..."
                echo "  • Importing SQL dump..."
                echo "  • Verifying database import..."
                ;;
            "import_files")
                echo "  • Extracting files archive..."
                echo "  • Setting proper permissions..."
                ;;
            "cleanup_temp")
                echo "  • Removing temporary files..."
                echo "  • Cleaning up downloads..."
                ;;
        esac
        echo "  ✓ $action_label completed"
        echo ""
        
        # Add small delay for realism
        sleep 0.5
    done
    
    echo "=== All Selected Actions Completed ==="
}

# Main function
main() {
    # Check if dialog is available
    if ! command -v dialog &> /dev/null; then
        msg_error "'dialog' command not found. Please install dialog package."
        msg_user_error "Ubuntu/Debian: sudo apt-get install dialog"
        msg_user_error "CentOS/RHEL: sudo yum install dialog"
        exit 1
    fi
    
    # Load previous selections
    load_last_selections
    
    # Show menu and get selected actions
    local selected_actions
    if selected_actions=$(show_action_menu); then
        # Parse space-separated output into array
        IFS=' ' read -r -a selected_actions <<< "$selected_actions"
        # Clear screen after dialog
        clear
        
        msg_user_info "DDEV Backup Manager - Selected Actions:"
        if [[ ${#selected_actions[@]} -eq 0 ]]; then
            msg_user_info "  (none)"
        else
            for action in "${selected_actions[@]}"; do
                local label
                label=$(get_display_name "$action")
                msg_user_info "  • $label"
            done
        fi
        msg_user_info ""
        
        # Save selections
        save_selections "${selected_actions[@]}"
        msg_user_info ""
        
        # Simulate execution
        simulate_actions "${selected_actions[@]}"
        
    else
        # User cancelled, clear dialog
        clear
        exit 1
    fi
}

# Run main function only when script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
