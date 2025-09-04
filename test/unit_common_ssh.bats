#!/usr/bin/env bats

# Tests for lib/common.sh SSH error classification function
# Tests: classify_ssh_error()

load helper_common

setup() {
    setup_test_env
    source_lib "common.sh"
}

teardown() {
    teardown_test_env
}

# Tests for classify_ssh_error() function - Success cases
@test "classify_ssh_error recognizes successful SSH connection" {
    run classify_ssh_error "0" "SSH_TEST_OK"
    
    assert_success
    assert_output_equals "success|SSH connection successful"
}

@test "classify_ssh_error handles partial success" {
    run classify_ssh_error "0" "Some other output without success marker"
    
    assert_success
    assert_output_equals "partial|SSH connected but command execution unclear"
}

@test "classify_ssh_error handles exit code 0 with mixed output" {
    run classify_ssh_error "0" "Warning: Permanently added 'host' to known hosts. SSH_TEST_OK"
    
    assert_success
    assert_output_equals "success|SSH connection successful"
}

# Tests for classify_ssh_error() function - Network-level failures
@test "classify_ssh_error recognizes port unreachable (exit 2)" {
    run classify_ssh_error "2" "Port 22 unreachable on example.com"
    
    assert_success
    assert_output_equals "unreachable|Port 22 unreachable on example.com"
}

@test "classify_ssh_error recognizes timeout (exit 124)" {
    run classify_ssh_error "124" "Connection timed out"
    
    assert_success
    assert_output_equals "timeout|Connection timed out (host unreachable or filtered)"
}

# Tests for classify_ssh_error() function - SSH-specific errors (exit 255)
@test "classify_ssh_error recognizes connection refused" {
    run classify_ssh_error "255" "ssh: connect to host example.com port 22: Connection refused"
    
    assert_success
    assert_output_equals "refused|Connection refused (SSH service not running on port)"
}

@test "classify_ssh_error recognizes no route to host" {
    run classify_ssh_error "255" "ssh: connect to host example.com port 22: No route to host"
    
    assert_success
    assert_output_equals "no_route|No route to host (network/routing issue)"
}

@test "classify_ssh_error recognizes DNS resolution failure" {
    run classify_ssh_error "255" "ssh: Could not resolve hostname badhost.com: Name or service not known"
    
    assert_success
    assert_output_equals "dns|Hostname resolution failed (DNS issue)"
}

@test "classify_ssh_error recognizes permission denied" {
    run classify_ssh_error "255" "user@example.com: Permission denied (publickey,password)"
    
    assert_success
    assert_output_equals "auth|SSH service available but authentication failed"
}

@test "classify_ssh_error recognizes SSH handshake timeout" {
    run classify_ssh_error "255" "ssh: connect to host example.com port 22: Connection timed out"
    
    assert_success
    assert_output_equals "timeout|Connection timed out during SSH handshake"
}

@test "classify_ssh_error handles generic SSH errors" {
    run classify_ssh_error "255" "ssh: Some other SSH error occurred"
    
    assert_success
    assert_output_equals "ssh_error|SSH connection failed: ssh: Some other SSH error occurred"
}

# Tests for classify_ssh_error() function - Other exit codes
@test "classify_ssh_error handles general errors (exit 1)" {
    run classify_ssh_error "1" "General connection error message"
    
    assert_success
    assert_output_equals "general|General connection error: General connection error message"
}

@test "classify_ssh_error handles unknown exit codes" {
    run classify_ssh_error "42" "Unknown error occurred"
    
    assert_success
    assert_output_equals "unknown|Unexpected error (code 42): Unknown error occurred"
}

@test "classify_ssh_error handles exit code 130 (Ctrl+C)" {
    run classify_ssh_error "130" "Interrupted by user"
    
    assert_success
    assert_output_equals "unknown|Unexpected error (code 130): Interrupted by user"
}

# Tests for edge cases and real-world scenarios
@test "classify_ssh_error handles empty error output" {
    run classify_ssh_error "255" ""
    
    assert_success
    assert_output_equals "ssh_error|SSH connection failed: "
}

@test "classify_ssh_error handles complex error messages" {
    local complex_error="ssh: connect to host example.com port 2222: Connection refused"
    run classify_ssh_error "255" "$complex_error"
    
    assert_success
    assert_output_equals "refused|Connection refused (SSH service not running on port)"
}

@test "classify_ssh_error handles multiple error patterns in output" {
    # Test that it matches the first pattern found
    local mixed_error="Connection refused and then Name or service not known"
    run classify_ssh_error "255" "$mixed_error"
    
    assert_success
    assert_output_equals "refused|Connection refused (SSH service not running on port)"
}

@test "classify_ssh_error handles real openssh error messages" {
    # Test with actual OpenSSH error format
    run classify_ssh_error "255" "ssh: connect to host 192.168.1.999 port 22: No route to host"
    
    assert_success
    assert_output_equals "no_route|No route to host (network/routing issue)"
}

@test "classify_ssh_error handles permission denied with different formats" {
    run classify_ssh_error "255" "Permission denied (publickey)"
    
    assert_success
    assert_output_equals "auth|SSH service available but authentication failed"
    
    run classify_ssh_error "255" "root@server: Permission denied (password)"
    
    assert_success  
    assert_output_equals "auth|SSH service available but authentication failed"
}

@test "classify_ssh_error handles verbose SSH output" {
    local verbose_success="debug1: Authentication succeeded (publickey).
debug1: channel 0: new [client-session]
SSH_TEST_OK
debug1: Sending environment."
    
    run classify_ssh_error "0" "$verbose_success"
    
    assert_success
    assert_output_equals "success|SSH connection successful"
}

# Tests for output format consistency
@test "classify_ssh_error always returns status|message format" {
    # Test various exit codes to ensure consistent format
    local test_cases=(
        "0|SSH_TEST_OK"
        "255|Connection refused"
        "124|timeout"
        "1|general error"
        "99|unknown error"
    )
    
    for case in "${test_cases[@]}"; do
        local exit_code="${case%%|*}"
        local error_msg="${case#*|}"
        
        run classify_ssh_error "$exit_code" "$error_msg"
        assert_success
        
        # Output should contain exactly one pipe character
        local pipe_count
        pipe_count=$(echo "$output" | tr -cd '|' | wc -c)
        [[ "$pipe_count" -eq 1 ]]
        
        # Output should not be empty
        [[ -n "$output" ]]
    done
}

# Integration test with real SSH scenarios
@test "classify_ssh_error integration with common SSH failure scenarios" {
    # Test scenario: SSH service not running
    run classify_ssh_error "255" "ssh: connect to host server.local port 22: Connection refused"
    assert_success
    assert_output_contains "refused"
    
    # Test scenario: Firewall blocking
    run classify_ssh_error "124" "Connection attempt timed out"
    assert_success
    assert_output_contains "timeout"
    
    # Test scenario: Wrong hostname
    run classify_ssh_error "255" "ssh: Could not resolve hostname wronghost: Name or service not known"
    assert_success
    assert_output_contains "dns"
    
    # Test scenario: SSH keys not set up
    run classify_ssh_error "255" "Permission denied (publickey)"
    assert_success
    assert_output_contains "auth"
}