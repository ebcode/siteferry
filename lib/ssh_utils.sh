#!/bin/bash

# SSH connectivity testing utilities
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/ssh_utils.sh"

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
