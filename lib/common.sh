#!/bin/bash

# Common utilities for pipeline modules
# Source this file in other modules: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Pipeline state management
set_status() {
    local action="$1"
    local status="$2"
    local message="${3:-}"
    
    export "${action}_status=$status"
    export "${action}_message=$message"
}

get_status() {
    local action="$1"
    local status_var="${action}_status"
    echo "${!status_var:-skipped}"
}

get_message() {
    local action="$1"
    local message_var="${action}_message"
    echo "${!message_var:-No details}"
}

is_enabled() {
    local action="$1"
    local enabled_var="${action}_enabled"
    [[ "${!enabled_var:-false}" == "true" ]]
}

# Check if dependency action completed successfully
dependency_met() {
    local dependency="$1"
    [[ "$(get_status "$dependency")" == "success" ]]
}

# Output current state for next stage in pipeline
pass_state() {
    # Read input from previous stage
    local input
    if input=$(cat); then
        # Apply the input (which contains export statements)
        eval "$input"
    fi
    
    # Get all current exports and pass them forward, properly quoted
    env | grep -E "_(status|message|enabled)=" | while IFS='=' read -r key value; do
        printf 'export %s=%q\n' "$key" "$value"
    done
}


# Action discovery and management functions
get_all_actions() {
    # Find all .sh files in actions/, remove .sh extension, exclude finalize_results
    local script_dir="${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}"
    # If we're in the lib directory, go up one level; otherwise use current directory
    if [[ "$(basename "$script_dir")" == "lib" ]]; then
        local actions_dir
        actions_dir="$(dirname "$script_dir")/actions"
    else
        local actions_dir="$script_dir/actions"
    fi
    find "$actions_dir" -name "[0-9]*_*.sh" -not -name "*finalize_results.sh" 2>/dev/null | \
        sed 's|.*/||; s|\.sh$||' | sort
}

get_action_display_name() {
    local action_name="$1"
    # Strip numeric prefix (N_) and convert to display format
    echo "$action_name" | sed 's/^[0-9]*_//' | sed 's/_/ /g' | sed 's/\b\w/\U&/g'
}

# Core function: strip numeric prefix (leading digits + underscore) from action name
strip_action_prefix() {
    local action_with_prefix="$1"
    echo "${action_with_prefix/*[0-9]_/}"
}

# For action scripts: determine their own ACTION name from filename
get_current_action_name() {
    local script_name
    script_name=$(basename "${BASH_SOURCE[1]}" .sh)
    strip_action_prefix "$script_name"
}

get_action_base_name() {
    local action_name="$1"
    # Use shared logic for consistency
    strip_action_prefix "$action_name"
}

# Load backup configuration
load_backup_config() {
    local config_file="${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/config/backup.config"
    # If we're in the lib directory, go up one level; otherwise use current directory
    if [[ "$(basename "$(dirname "${BASH_SOURCE[0]}")")" == "lib" ]]; then
        config_file="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/config/backup.config"
    fi
    
    if [[ -f "$config_file" ]]; then
        # Source the config file to load variables
        # shellcheck source=/dev/null
        source "$config_file"
    else
        return 1
    fi
}

validate_action_files() {
    local actions_dir="${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/actions"
    local invalid_files=()
    
    # Check all .sh files in actions directory
    while IFS= read -r -d '' file; do
        local basename
        basename=$(basename "$file")
        if [[ ! "$basename" =~ ^[0-9]{1,3}_[a-z_]+\.sh$ ]] && [[ "$basename" != "*finalize_results.sh" ]]; then
            invalid_files+=("$basename")
        fi
    done < <(find "$actions_dir" -name "*.sh" -print0 2>/dev/null)
    
    if [[ ${#invalid_files[@]} -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# SSH connectivity testing functions

# Test SSH connectivity with layered timeout approach
# Returns: "exit_code|error_output"
test_ssh_connectivity_raw() {
    local host="$1"
    local port="$2" 
    local user="$3"
    
    # Quick TCP port test first (1 second timeout)
    if ! timeout 1 bash -c "</dev/tcp/$host/$port" &>/dev/null; then
        echo "2|Port $port unreachable on $host"
        return 0
    fi
    
    # SSH connectivity test with proper timeout handling
    local ssh_output ssh_exit_code
    ssh_output=$(timeout 3 ssh -o BatchMode=yes -o ConnectTimeout=2 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -p "$port" "$user@$host" 'echo "SSH_TEST_OK"' 2>&1)
    ssh_exit_code=$?
    
    # Return both exit code and output for caller analysis
    echo "$ssh_exit_code|$ssh_output"
}

# Classify SSH error and return user-friendly message
# Usage: classify_ssh_error exit_code error_output
classify_ssh_error() {
    local exit_code="$1"
    local error_output="$2"
    
    case "$exit_code" in
        0)
            if [[ "$error_output" == *"SSH_TEST_OK"* ]]; then
                echo "success|SSH connection successful"
            else
                echo "partial|SSH connected but command execution unclear"  
            fi
            ;;
        2)
            echo "unreachable|$error_output"
            ;;
        124)
            echo "timeout|Connection timed out (host unreachable or filtered)"
            ;;
        255)
            if [[ "$error_output" == *"Connection refused"* ]]; then
                echo "refused|Connection refused (SSH service not running on port)"
            elif [[ "$error_output" == *"No route to host"* ]]; then
                echo "no_route|No route to host (network/routing issue)"
            elif [[ "$error_output" == *"Name or service not known"* ]]; then
                echo "dns|Hostname resolution failed (DNS issue)"
            elif [[ "$error_output" == *"Permission denied"* ]]; then
                echo "auth|SSH service available but authentication failed"
            elif [[ "$error_output" == *"Connection timed out"* ]]; then
                echo "timeout|Connection timed out during SSH handshake"
            else
                echo "ssh_error|SSH connection failed: $error_output"
            fi
            ;;
        1)
            echo "general|General connection error: $error_output"
            ;;
        *)
            echo "unknown|Unexpected error (code $exit_code): $error_output"
            ;;
    esac
}

# High-level SSH connectivity test with user-friendly messaging
# Usage: test_ssh_connectivity host port user
# Returns: 0 for success, 1 for any failure (but provides detailed messaging)
test_ssh_connectivity() {
    local host="$1"
    local port="$2"
    local user="$3"
    
    # Import messaging functions if available
    if command -v msg_success &>/dev/null; then
        local has_messaging=true
    else
        local has_messaging=false
    fi
    
    # Perform the raw SSH test
    local test_result
    test_result=$(test_ssh_connectivity_raw "$host" "$port" "$user")
    
    # Parse the result
    local exit_code="${test_result%%|*}"
    local error_output="${test_result#*|}"
    
    # Classify the error
    local classification
    classification=$(classify_ssh_error "$exit_code" "$error_output")
    
    local status="${classification%%|*}"
    local message="${classification#*|}"
    
    # Provide user messaging based on classification
    case "$status" in
        "success")
            if [[ "$has_messaging" == "true" ]]; then
                msg_success "SSH connection to $user@$host:$port successful"
            else
                echo "SUCCESS: SSH connection to $user@$host:$port successful"
            fi
            return 0
            ;;
        "partial")
            if [[ "$has_messaging" == "true" ]]; then
                msg_warn "SSH connection to $user@$host:$port established but test command unclear"
            else
                echo "WARNING: SSH connection to $user@$host:$port established but test command unclear"
            fi
            return 0
            ;;
        *)
            if [[ "$has_messaging" == "true" ]]; then
                msg_warn "SSH connection to $user@$host:$port failed: $message"
                case "$status" in
                    "timeout"|"unreachable")
                        msg_warn "This may indicate network issues or firewall blocking"
                        ;;
                    "refused")
                        msg_warn "SSH service may not be running or configured on this port"
                        ;;
                    "dns")
                        msg_warn "Check hostname spelling and DNS configuration"
                        ;;
                    "auth")
                        msg_warn "SSH service is running but requires authentication setup"
                        ;;
                esac
                msg_warn "This may not be a problem if you have local backups or don't need remote access"
            else
                echo "WARNING: SSH connection to $user@$host:$port failed: $message"
            fi
            return 1
            ;;
    esac
}
