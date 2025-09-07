#!/bin/bash

# SiteFerry Extended Functional Programming Library
# Builds on fp_bash.sh with additional patterns for SiteFerry

set -euo pipefail

# Function composition and piping
compose() {
  local input="$1"
  shift
  local result="$input"
  
  for func in "$@"; do
    result="$($func "$result")"
  done
  
  echo "$result"
}

pipe() {
  local input="$1"
  shift
  
  local result="$input"
  for func in "$@"; do
    result=$(echo "$result" | "$func")
  done
  
  echo "$result"
}

# Currying and partial application
curry() {
  local func_name="$1"
  local fixed_arg="$2"
  local new_func_name="$3"
  
  eval "$new_func_name() { $func_name \"$fixed_arg\" \"\$@\"; }"
}

# Maybe type for safe operations
maybe_just() {
  local value="$1"
  echo "Just:$value"
}

maybe_nothing() {
  echo "Nothing"
}

maybe_is_just() {
  local maybe_value="$1"
  [[ "$maybe_value" =~ ^Just: ]]
}

maybe_is_nothing() {
  local maybe_value="$1"
  [[ "$maybe_value" == "Nothing" ]]
}

maybe_extract() {
  local maybe_value="$1"
  local default_value="${2:-}"
  
  if maybe_is_just "$maybe_value"; then
    echo "${maybe_value#Just:}"
  else
    echo "$default_value"
  fi
}

maybe_map() {
  local func="$1"
  local maybe_value="$2"
  
  if maybe_is_nothing "$maybe_value"; then
    echo "Nothing"
  else
    local value="${maybe_value#Just:}"
    local result
    if result=$("$func" "$value" 2>/dev/null); then
      echo "Just:$result"
    else
      echo "Nothing"
    fi
  fi
}

# Either type for error handling
either_left() {
  local error="$1"
  echo "Left:$error"
}

either_right() {
  local value="$1"
  echo "Right:$value"
}

either_is_left() {
  local either_value="$1"
  [[ "$either_value" =~ ^Left: ]]
}

either_is_right() {
  local either_value="$1"
  [[ "$either_value" =~ ^Right: ]]
}

either_extract_left() {
  local either_value="$1"
  echo "${either_value#Left:}"
}

either_extract_right() {
  local either_value="$1"
  echo "${either_value#Right:}"
}

either_map() {
  local func="$1"
  local either_value="$2"
  
  if either_is_left "$either_value"; then
    echo "$either_value"  # Pass through error
  else
    local value="${either_value#Right:}"
    local result
    if result=$("$func" "$value" 2>&1); then
      echo "Right:$result"
    else
      local exit_code=$?
      echo "Left:Function '$func' failed with code $exit_code: $result"
    fi
  fi
}

either_chain() {
  local either_value="$1"
  local next_func="$2"
  
  if either_is_left "$either_value"; then
    echo "$either_value"  # Pass through error
  else
    local value="${either_value#Right:}"
    "$next_func" "$value"
  fi
}

# Safe execution wrapper that returns Either
safe_execute() {
  local func="$1"
  shift
  local output
  local exit_code
  
  if output=$("$func" "$@" 2>&1); then
    either_right "$output"
  else
    exit_code=$?
    either_left "Command '$func' failed with code $exit_code: $output"
  fi
}

# Immutable state management
create_state() {
  declare -A state
  for arg in "$@"; do
    if [[ "$arg" =~ ^([^=]+)=(.*)$ ]]; then
      state[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    fi
  done
  
  # Serialize state
  for key in "${!state[@]}"; do
    printf '%s=%s\n' "$key" "${state[$key]}"
  done
}

update_state() {
  local state_data="$1"
  local key="$2"
  local value="$3"
  
  # Parse existing state
  declare -A current_state
  while IFS='=' read -r k v; do
    [[ -n "$k" ]] && current_state[$k]=$v
  done <<< "$state_data"
  
  # Update specific key
  current_state[$key]=$value
  
  # Return new state
  for k in "${!current_state[@]}"; do
    printf '%s=%s\n' "$k" "${current_state[$k]}"
  done
}

get_state_value() {
  local state_data="$1"
  local key="$2"
  local default_value="${3:-}"
  
  declare -A state_map
  while IFS='=' read -r k v; do
    [[ -n "$k" ]] && state_map[$k]=$v
  done <<< "$state_data"
  
  echo "${state_map[$key]:-$default_value}"
}

# Validation chain utilities
validate_chain() {
  local input="$1"
  shift
  
  for validator in "$@"; do
    if ! "$validator" "$input"; then
      return 1
    fi
  done
  return 0
}

# Parallel map implementation
parallel_map() {
  local func="$1"
  local max_jobs="${2:-4}"
  local input
  local -a pids=()
  
  while IFS= read -r input; do
    # Wait if we've hit the job limit
    while [[ ${#pids[@]} -ge $max_jobs ]]; do
      for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
          wait "${pids[$i]}"
          unset "pids[$i]"
        fi
      done
      pids=("${pids[@]}")  # Repack array
      sleep 0.1
    done
    
    # Start new job in background
    {
      result=$("$func" "$input")
      echo "$result"
    } &
    pids+=($!)
  done
  
  # Wait for all remaining jobs
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
}

# Higher-order utility functions
apply() {
  local func="$1"
  shift
  "$func" "$@"
}

flip() {
  local func="$1"
  local arg1="$2"
  local arg2="$3"
  shift 3
  "$func" "$arg2" "$arg1" "$@"
}

# Stream processing utilities
collect_to_array() {
  local array_name="$1"
  local -a collected=()
  local line
  
  while IFS= read -r line; do
    collected+=("$line")
  done
  
  # Use nameref to set the array  
  declare -n arr_ref=$array_name
  # shellcheck disable=SC2034
  arr_ref=("${collected[@]}")
}

# Function memoization for expensive operations
declare -A _memoize_cache

memoize() {
  local func="$1"
  local cache_key="$func:$*"
  
  if [[ -n "${_memoize_cache[$cache_key]:-}" ]]; then
    echo "${_memoize_cache[$cache_key]}"
  else
    local result
    result=$("$func" "${@:2}")
    _memoize_cache[$cache_key]=$result
    echo "$result"
  fi
}

# Export all functions for use in other modules
export -f compose pipe curry
export -f maybe_just maybe_nothing maybe_is_just maybe_is_nothing maybe_extract maybe_map
export -f either_left either_right either_is_left either_is_right either_extract_left either_extract_right either_map either_chain
export -f safe_execute create_state update_state get_state_value
export -f validate_chain parallel_map apply flip collect_to_array memoize
