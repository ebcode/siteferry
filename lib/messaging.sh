#!/bin/bash

# Unix-Style Tiered Messaging System
# Provides verbosity-aware messaging functions with color support

# Color definitions
readonly GREEN='\033[0;32m'
readonly ORANGE='\033[0;33m'
readonly RED='\033[0;31m'
readonly RESET='\033[0m'

# Default verbosity level (0=quiet, 1=normal, 2=verbose, 3=debug, 4=trace)
VERBOSITY=${VERBOSITY:-1}

# Detect if terminal supports colors
use_colors() {
  [[ -t 2 ]] && [[ "${NO_COLOR:-}" != "1" ]] && [[ "${TERM:-}" != "dumb" ]]
}

# Apply color if terminal supports it
colorize() {
  local color="$1"
  local text="$2"
  if use_colors; then
    echo -e "${color}${text}${RESET}"
  else
    echo "$text"
  fi
}

# Timestamp for messages
timestamp() {
  date '+%H:%M:%S'
}

# Critical errors - always shown (verbosity >= 0)
msg_error() {
  [[ $VERBOSITY -ge 0 ]] || return 0
  colorize "$RED" "[$(timestamp)] ERROR: $*" >&2
}

# Warnings and important info - shown at normal level (verbosity >= 1) 
msg_warn() {
  [[ $VERBOSITY -ge 1 ]] || return 0
  colorize "$ORANGE" "[$(timestamp)] WARN: $*" >&2
}

# Informational messages - shown at normal level (verbosity >= 1)
msg_info() {
  [[ $VERBOSITY -ge 1 ]] || return 0
  colorize "$ORANGE" "[$(timestamp)] INFO: $*" >&2
}

# Success messages - shown at normal level (verbosity >= 1)
msg_success() {
  [[ $VERBOSITY -ge 1 ]] || return 0
  colorize "$GREEN" "[$(timestamp)] SUCCESS: $*" >&2
}

# Debug information - shown at verbose level (verbosity >= 2)
msg_debug() {
  [[ $VERBOSITY -ge 2 ]] || return 0
  colorize "$ORANGE" "[$(timestamp)] DEBUG: $*" >&2
}

# Trace information - shown at trace level (verbosity >= 3)
msg_trace() {
  [[ $VERBOSITY -ge 3 ]] || return 0
  echo "[$(timestamp)] TRACE: $*" >&2
}

# User-facing output functions (stdout)
msg_user_info() {
  [[ $VERBOSITY -ge 1 ]] || return 0
  echo "$*"
}

msg_user_success() {
  [[ $VERBOSITY -ge 1 ]] || return 0
  if use_colors; then
    colorize "$GREEN" "$*"
  else
    echo "$*"
  fi
}

msg_user_error() {
  [[ $VERBOSITY -ge 0 ]] || return 0
  if use_colors; then
    colorize "$RED" "$*"
  else
    echo "$*"
  fi
}

# Set verbosity level from command line flags
set_verbosity() {
  case "$1" in
    -q|--quiet)
      VERBOSITY=0
      ;;
    -v|--verbose)
      VERBOSITY=2
      ;;
    -vv)
      VERBOSITY=3
      ;;
    -vvv)
      VERBOSITY=4
      ;;
    *)
      VERBOSITY=1  # default/normal
      ;;
  esac
  export VERBOSITY
}

# Parse verbosity from command line arguments
parse_verbosity() {
  local args=("$@")
  for arg in "${args[@]}"; do
    case "$arg" in
      -q|--quiet|-v|--verbose|-vv|-vvv)
        set_verbosity "$arg"
        return
        ;;
    esac
  done
  # Default if no verbosity flags found
  set_verbosity ""
}
