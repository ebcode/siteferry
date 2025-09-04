#!/bin/bash

# Config Parser - Extracts action selections and outputs as export statements
# Usage: parse_config.sh [config_file]
# Output: export statements for each action's enabled state

set -euo pipefail

CONFIG_FILE="${1:-config/last-checked.config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions for dynamic action discovery
source "$SCRIPT_DIR/common.sh"

# Get all actions dynamically
get_actions_array() {
    local actions
    mapfile -t actions < <(get_all_actions)
    for action in "${actions[@]}"; do
        get_action_base_name "$action"
    done
}

# Initialize all actions as enabled by default
declare -A ACTION_ENABLED
declare -a local_actions
mapfile -t local_actions < <(get_actions_array)
for action in "${local_actions[@]}"; do
    ACTION_ENABLED["$action"]="true"
done

# Load from config file if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        
        # Remove whitespace
        key=$(echo "$key" | tr -d '[:space:]')
        value=$(echo "$value" | tr -d '[:space:]')
        
        # Set action state if valid action
        if [[ " ${local_actions[*]} " =~ \ $key\  ]]; then
            ACTION_ENABLED["$key"]="$value"
        fi
    done < "$CONFIG_FILE"
fi

# Output export statements for pipeline
echo "# Config loaded from: $CONFIG_FILE"
for action in "${local_actions[@]}"; do
    echo "export ${action}_enabled=\"${ACTION_ENABLED[$action]}\""
done