#!/usr/bin/env bats

# Tests for lib/common.sh state management functions
# Tests: set_status(), get_status(), get_message(), is_enabled(), dependency_met()

load helper_common

setup() {
    setup_test_env
    source_lib "common.sh"
}

teardown() {
    teardown_test_env
}

# Tests for set_status() function
@test "set_status sets action status and message" {
    set_status "test_action" "success" "Everything worked"
    
    assert_var_equals "test_action_status" "success"
    assert_var_equals "test_action_message" "Everything worked"
}

@test "set_status handles empty message" {
    set_status "test_action" "failed" ""
    
    assert_var_equals "test_action_status" "failed"
    assert_var_equals "test_action_message" ""
}

@test "set_status with no message parameter" {
    set_status "test_action" "running"
    
    assert_var_equals "test_action_status" "running"
    assert_var_equals "test_action_message" ""
}

@test "set_status overwrites existing status" {
    export test_action_status="old_status"
    export test_action_message="old_message"
    
    set_status "test_action" "new_status" "new_message"
    
    assert_var_equals "test_action_status" "new_status"
    assert_var_equals "test_action_message" "new_message"
}

# Tests for get_status() function
@test "get_status returns existing status" {
    export test_action_status="success"
    
    run get_status "test_action"
    
    assert_success
    assert_output_equals "success"
}

@test "get_status returns 'skipped' for unset action" {
    unset test_action_status
    
    run get_status "test_action"
    
    assert_success
    assert_output_equals "skipped"
}

@test "get_status returns 'skipped' for empty status" {
    export test_action_status=""
    
    run get_status "test_action"
    
    assert_success
    assert_output_equals "skipped"
}

# Tests for get_message() function
@test "get_message returns existing message" {
    export test_action_message="Test completed successfully"
    
    run get_message "test_action"
    
    assert_success
    assert_output_equals "Test completed successfully"
}

@test "get_message returns 'No details' for unset message" {
    unset test_action_message
    
    run get_message "test_action"
    
    assert_success
    assert_output_equals "No details"
}

@test "get_message returns 'No details' for empty message" {
    export test_action_message=""
    
    run get_message "test_action"
    
    assert_success
    assert_output_equals "No details"
}

# Tests for is_enabled() function
@test "is_enabled returns true when action is enabled" {
    export test_action_enabled="true"
    
    run is_enabled "test_action"
    
    assert_success
}

@test "is_enabled returns false when action is disabled" {
    export test_action_enabled="false"
    
    run is_enabled "test_action"
    
    assert_failure
}

@test "is_enabled returns false when action is unset" {
    unset test_action_enabled
    
    run is_enabled "test_action"
    
    assert_failure
}

@test "is_enabled returns false for empty value" {
    export test_action_enabled=""
    
    run is_enabled "test_action"
    
    assert_failure
}

@test "is_enabled returns false for non-true values" {
    export test_action_enabled="yes"
    
    run is_enabled "test_action"
    
    assert_failure
    
    export test_action_enabled="1"
    
    run is_enabled "test_action"
    
    assert_failure
}

# Tests for dependency_met() function
@test "dependency_met returns true when dependency succeeded" {
    export dependency_action_status="success"
    
    run dependency_met "dependency_action"
    
    assert_success
}

@test "dependency_met returns false when dependency failed" {
    export dependency_action_status="failed"
    
    run dependency_met "dependency_action"
    
    assert_failure
}

@test "dependency_met returns false when dependency was skipped" {
    export dependency_action_status="skipped"
    
    run dependency_met "dependency_action"
    
    assert_failure
}

@test "dependency_met returns false when dependency is unset" {
    unset dependency_action_status
    
    run dependency_met "dependency_action"
    
    assert_failure
}

@test "dependency_met returns false for empty status" {
    export dependency_action_status=""
    
    run dependency_met "dependency_action"
    
    assert_failure
}

# Integration tests for state management
@test "full state lifecycle: set, get, check dependency" {
    # Set initial state
    set_status "action_one" "success" "Completed successfully"
    
    # Verify state was set
    run get_status "action_one"
    assert_success
    assert_output_equals "success"
    
    run get_message "action_one"
    assert_success
    assert_output_equals "Completed successfully"
    
    # Check dependency
    run dependency_met "action_one"
    assert_success
    
    # Update status
    set_status "action_one" "failed" "Something went wrong"
    
    # Verify updated state
    run get_status "action_one"
    assert_success
    assert_output_equals "failed"
    
    run dependency_met "action_one"
    assert_failure
}