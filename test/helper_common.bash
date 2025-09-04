#!/bin/bash

# Common test helper utilities for BATS tests
# Load with: load test/helper_common

# Set up test environment
setup_test_env() {
    # Create temporary directory for test isolation
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    
    # Clean environment variables from previous tests
    unset_all_test_vars
}

# Clean up after tests
teardown_test_env() {
    # Remove temporary directory
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    # Clean environment variables
    unset_all_test_vars
}

# Unset all action-related environment variables for clean test state
unset_all_test_vars() {
    # Unset any variables that might interfere with tests
    local var
    while IFS= read -r var; do
        unset "$var"
    done < <(env | grep -E "_(status|message|enabled)=" | cut -d= -f1)
}

# Assert that a variable is set to expected value
assert_var_equals() {
    local var_name="$1"
    local expected="$2"
    local actual="${!var_name:-}"
    
    if [[ "$actual" != "$expected" ]]; then
        echo "Expected $var_name='$expected', got '$actual'" >&2
        return 1
    fi
}

# Assert that a variable is unset
assert_var_unset() {
    local var_name="$1"
    
    if [[ -n "${!var_name:-}" ]]; then
        echo "Expected $var_name to be unset, but it's set to '${!var_name}'" >&2
        return 1
    fi
}

# Source the library under test with proper path handling
source_lib() {
    local lib_name="$1"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "$script_dir/lib/$lib_name"
}

# Create a temporary config file for testing
create_test_config() {
    local config_content="$1"
    local config_file="$TEST_TEMP_DIR/test.config"
    echo "$config_content" > "$config_file"
    echo "$config_file"
}

# Mock external commands for testing
mock_command() {
    local command="$1"
    local mock_output="$2"
    local mock_exit_code="${3:-0}"
    
    # Create a mock script in test temp directory
    local mock_script="$TEST_TEMP_DIR/$command"
    cat > "$mock_script" << EOF
#!/bin/bash
echo "$mock_output"
exit $mock_exit_code
EOF
    chmod +x "$mock_script"
    
    # Add to PATH for this test
    export PATH="$TEST_TEMP_DIR:$PATH"
}

# Assert command output matches expected
assert_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain '$expected'" >&2
        echo "Actual output: '$output'" >&2
        return 1
    fi
}

# Assert command output equals expected
assert_output_equals() {
    local expected="$1"
    if [[ "$output" != "$expected" ]]; then
        echo "Expected output: '$expected'" >&2
        echo "Actual output: '$output'" >&2
        return 1
    fi
}

# Assert command succeeded (exit code 0)
assert_success() {
    if [[ "$status" != "0" ]]; then
        echo "Expected command to succeed (exit 0), got exit $status" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

# Assert command failed (non-zero exit code)
assert_failure() {
    if [[ "$status" == "0" ]]; then
        echo "Expected command to fail (non-zero exit), got exit 0" >&2
        echo "Output: $output" >&2
        return 1
    fi
}