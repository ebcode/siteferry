#!/bin/bash

# Finalize Results - Auto-discover and report status of all actions
# Always runs last in pipeline, never fails

set -euo pipefail

# Source messaging system and common functions
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

format_duration() {
  local start_time="$1"
  local end_time="$2"
  local duration=$((end_time - start_time))
  
  if [[ $duration -lt 60 ]]; then
    echo "${duration}s"
  else
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    echo "${minutes}m${seconds}s"
  fi
}

main() {
  local start_time=${PIPELINE_START_TIME:-$(date +%s)}
  local end_time
  end_time=$(date +%s)
  
  # Get state from previous pipeline stage
  local input
  if input=$(cat); then
    msg_debug "Pipeline input received:"
    msg_debug "$input"
    eval "$input"
  fi
  
  # Debug: show what status variables are available
  msg_debug "Available status variables:"
  local status_vars
  status_vars=$(env | grep -E "_(status|message)=" || echo "None found")
  msg_debug "$status_vars"
  
  msg_user_info ""
  msg_user_info "=== DDEV Backup Manager - Pipeline Results ==="
  msg_user_info ""
  
  local numbered_actions
  mapfile -t numbered_actions < <(get_all_numbered_scripts)
  msg_debug "Numbered actions found: ${numbered_actions[*]}"
  
  local actions=()
  # Convert numbered actions to base names for status lookup
  for action in "${numbered_actions[@]}"; do
    actions+=("$(strip_numeric_prefix "$action")")
  done
  msg_debug "Base action names: ${actions[*]}"
  
  local success_count=0
  local error_count=0
  local skipped_count=0
  
  for action in "${actions[@]}"; do
    # Debug output
    msg_debug "Processing action: $action"
    
    # Get status and message directly from environment variables
    local status_var="${action}_status"
    local message_var="${action}_message"
    msg_debug "Looking for variables: $status_var, $message_var"
    
    local status="${!status_var:-skipped}"
    msg_debug "Status retrieved: $status"
    
    local message="${!message_var:-No details}"
    msg_debug "Message retrieved: $message"
    
    # Format action name for display
    msg_debug "Formatting display name for: $action"
    local display_name
    display_name=$(echo "$action" | sed 's/_/ /g' | sed 's/\b\w/\U&/g')
    msg_debug "Display name: $display_name"
    
    case "$status" in
      "success")
        msg_user_success "SUCCESS: $display_name"
        [[ -n "$message" ]] && msg_user_info "   $message"
        success_count=$((success_count + 1))
        ;;
      "error")
        msg_user_error "ERROR: $display_name"
        [[ -n "$message" ]] && msg_user_info "   $message"
        error_count=$((error_count + 1))
        ;;
      "skipped")
        msg_user_info "SKIPPED: $display_name"
        [[ -n "$message" ]] && msg_user_info "   $message"
        skipped_count=$((skipped_count + 1))
        ;;
    esac
    msg_user_info ""
    msg_debug "Completed processing action: $action, continuing loop..."
  done
  
  msg_debug "Loop completed, proceeding to summary"
  
  # Summary
  msg_user_info "=== Summary ==="
  msg_user_info "Actions completed: $success_count"
  msg_user_info "Actions failed: $error_count"
  msg_user_info "Actions skipped: $skipped_count"
  msg_user_info "Total runtime: $(format_duration "$start_time" "$end_time")"
  msg_user_info ""
  
  # Final status message
  if [[ $error_count -eq 0 ]]; then
    if [[ $success_count -gt 0 ]]; then
      msg_user_success "All enabled actions completed successfully!"
    else
      msg_user_info "No actions were executed (all skipped or disabled)"
    fi
  else
    msg_user_error "Pipeline completed with $error_count error(s)"
    msg_user_info ""
    msg_user_info "Check the error messages above for details."
    msg_user_info "Some operations may still be available for retry."
  fi
  
  msg_user_info ""
  
  # Always exit 0 - never break the pipeline
  exit 0
}

main
