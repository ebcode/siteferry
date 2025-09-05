#!/usr/bin/env bats

# Tests for lib/messaging.sh message output functions
# Tests: msg_error(), msg_warn(), msg_info(), msg_success(), msg_debug(), msg_trace(),
#        msg_user_info(), msg_user_success(), msg_user_error()

load helper_common

setup() {
    setup_test_env
    source_lib "messaging.sh"
    
    # Set up stderr/stdout capture files
    STDERR_FILE="$TEST_TEMP_DIR/stderr"
    STDOUT_FILE="$TEST_TEMP_DIR/stdout"
}

teardown() {
    teardown_test_env
}

# Helper function to capture stderr output
capture_stderr() {
    "$@" 2>"$STDERR_FILE"
    cat "$STDERR_FILE"
}

# Helper function to capture stdout output
capture_stdout() {
    "$@" >"$STDOUT_FILE"
    cat "$STDOUT_FILE"
}

# Tests for msg_error() - always shown (verbosity >= 0)

@test "msg_error outputs at default verbosity" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stderr msg_error "Test error message")
    [[ "$output" == *"ERROR: Test error message"* ]]
    [[ "$output" == *"["*":"*":"*"]"* ]] # Has timestamp
}

@test "msg_error outputs at quiet verbosity" {
    export VERBOSITY=0
    export NO_COLOR=1
    
    output=$(capture_stderr msg_error "Critical error")
    [[ "$output" == *"ERROR: Critical error"* ]]
}

@test "msg_error goes to stderr not stdout" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    stderr_output=$(capture_stderr msg_error "Error message")
    stdout_output=$(capture_stdout msg_error "Error message")
    
    [[ "$stderr_output" == *"ERROR: Error message"* ]]
    [[ -z "$stdout_output" ]]
}

@test "msg_error handles multiple arguments" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stderr msg_error "Error" "with" "multiple" "parts")
    [[ "$output" == *"ERROR: Error with multiple parts"* ]]
}

# Tests for msg_warn() - shown at normal level (verbosity >= 1)

@test "msg_warn outputs at default verbosity" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stderr msg_warn "Warning message")
    [[ "$output" == *"WARN: Warning message"* ]]
}

@test "msg_warn suppressed at quiet verbosity" {
    export VERBOSITY=0
    export NO_COLOR=1
    
    output=$(capture_stderr msg_warn "Warning message")
    [[ -z "$output" ]]
}

@test "msg_warn outputs at verbose verbosity" {
    export VERBOSITY=2
    export NO_COLOR=1
    
    output=$(capture_stderr msg_warn "Verbose warning")
    [[ "$output" == *"WARN: Verbose warning"* ]]
}

# Tests for msg_info() - shown at normal level (verbosity >= 1)

@test "msg_info outputs at default verbosity" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stderr msg_info "Info message")
    [[ "$output" == *"INFO: Info message"* ]]
}

@test "msg_info suppressed at quiet verbosity" {
    export VERBOSITY=0
    export NO_COLOR=1
    
    output=$(capture_stderr msg_info "Info message")
    [[ -z "$output" ]]
}

# Tests for msg_success() - shown at normal level (verbosity >= 1)

@test "msg_success outputs at default verbosity" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stderr msg_success "Success message")
    [[ "$output" == *"SUCCESS: Success message"* ]]
}

@test "msg_success suppressed at quiet verbosity" {
    export VERBOSITY=0
    export NO_COLOR=1
    
    output=$(capture_stderr msg_success "Success message")
    [[ -z "$output" ]]
}

# Tests for msg_debug() - shown at verbose level (verbosity >= 2)

@test "msg_debug outputs at verbose verbosity" {
    export VERBOSITY=2
    export NO_COLOR=1
    
    output=$(capture_stderr msg_debug "Debug message")
    [[ "$output" == *"DEBUG: Debug message"* ]]
}

@test "msg_debug suppressed at default verbosity" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stderr msg_debug "Debug message")
    [[ -z "$output" ]]
}

@test "msg_debug outputs at trace verbosity" {
    export VERBOSITY=3
    export NO_COLOR=1
    
    output=$(capture_stderr msg_debug "Trace debug")
    [[ "$output" == *"DEBUG: Trace debug"* ]]
}

# Tests for msg_trace() - shown at trace level (verbosity >= 3)

@test "msg_trace outputs at trace verbosity" {
    export VERBOSITY=3
    export NO_COLOR=1
    
    output=$(capture_stderr msg_trace "Trace message")
    [[ "$output" == *"TRACE: Trace message"* ]]
}

@test "msg_trace suppressed at verbose verbosity" {
    export VERBOSITY=2
    export NO_COLOR=1
    
    output=$(capture_stderr msg_trace "Trace message")
    [[ -z "$output" ]]
}

@test "msg_trace outputs at highest verbosity" {
    export VERBOSITY=4
    export NO_COLOR=1
    
    output=$(capture_stderr msg_trace "Max trace")
    [[ "$output" == *"TRACE: Max trace"* ]]
}

# Tests for user-facing stdout functions

@test "msg_user_info goes to stdout at default verbosity" {
    export VERBOSITY=1
    
    # Capture both stderr and stdout separately
    msg_user_info "User info" 2>"$STDERR_FILE" >"$STDOUT_FILE"
    stderr_output=$(cat "$STDERR_FILE")
    stdout_output=$(cat "$STDOUT_FILE")
    
    [[ -z "$stderr_output" ]]
    [[ "$stdout_output" == "User info" ]]
}

@test "msg_user_info suppressed at quiet verbosity" {
    export VERBOSITY=0
    
    output=$(capture_stdout msg_user_info "User info")
    [[ -z "$output" ]]
}

@test "msg_user_success goes to stdout with colors when supported" {
    export VERBOSITY=1
    export TERM="xterm"
    unset NO_COLOR
    
    # Redirect stderr to make terminal detection work
    exec 2>"$TEST_TEMP_DIR/term_stderr"
    output=$(capture_stdout msg_user_success "Success message")
    [[ "$output" == *"Success message"* ]]
}

@test "msg_user_success goes to stdout without colors when not supported" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stdout msg_user_success "Success message")
    [[ "$output" == "Success message" ]]
}

@test "msg_user_error goes to stdout at default verbosity" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    # Capture both stderr and stdout separately
    msg_user_error "User error" 2>"$STDERR_FILE" >"$STDOUT_FILE"
    stderr_output=$(cat "$STDERR_FILE")
    stdout_output=$(cat "$STDOUT_FILE")
    
    [[ -z "$stderr_output" ]]
    [[ "$stdout_output" == "User error" ]]
}

@test "msg_user_error outputs at quiet verbosity" {
    export VERBOSITY=0
    export NO_COLOR=1
    
    output=$(capture_stdout msg_user_error "Critical user error")
    [[ "$output" == "Critical user error" ]]
}

# Tests for color handling in messages

@test "messages include color codes when colors enabled" {
    export VERBOSITY=1
    export TERM="xterm"
    unset NO_COLOR
    
    # Override use_colors to simulate color support for this test
    use_colors() { return 0; }
    
    # Test with mocked color support
    msg_error "Colored error" 2>"$STDERR_FILE"
    output=$(cat "$STDERR_FILE")
    # Check that some color escape sequence is present
    [[ "$output" == *$'\033['* ]] # Any ANSI escape sequence
}

@test "messages exclude color codes when colors disabled" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stderr msg_success "No color success")
    [[ "$output" != *$'\033['* ]] # No escape sequences
}

# Edge cases

@test "message functions handle empty messages" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stderr msg_info "")
    [[ "$output" == *"INFO:"* ]]
}

@test "message functions handle special characters" {
    export VERBOSITY=1
    export NO_COLOR=1
    
    output=$(capture_stderr msg_warn "Special chars: \$HOME & \"quotes\" 'single'")
    [[ "$output" == *"Special chars: \$HOME & \"quotes\" 'single'"* ]]
}