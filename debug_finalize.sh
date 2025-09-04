#!/bin/bash

# Debug version of finalize_results.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source messaging and common functions
source "$SCRIPT_DIR/lib/messaging.sh"
source "$SCRIPT_DIR/lib/common.sh"

main() {
    # Get state from previous pipeline stage
    local input
    if input=$(cat); then
        echo "=== DEBUG: Input received ==="
        echo "$input"
        echo "=== DEBUG: Evaluating input ==="
        eval "$input"
    fi
    
    echo "=== DEBUG: Environment variables after eval ==="
    env | grep -E "_(status|message|enabled)=" | sort
    
    echo ""
    echo "=== DEBUG: Actions discovered ==="
    local numbered_actions=($(get_all_actions))
    local actions=()
    # Convert numbered actions to base names for status lookup
    for action in "${numbered_actions[@]}"; do
        actions+=("$(get_action_base_name "$action")")
    done
    printf "Actions: %s\n" "${actions[*]}"
    
    echo ""
    echo "=== DEBUG: Testing variable access ==="
    echo "Numbered actions: ${numbered_actions[*]}"
    echo "Base actions: ${actions[*]}"
    echo ""
    
    for action in "${actions[@]}"; do
        local status_var="${action}_status"
        local message_var="${action}_message"
        local status="${!status_var:-skipped}"
        local message="${!message_var:-No details}"
        echo "$action: status='$status' message='$message'"
    done
}

main