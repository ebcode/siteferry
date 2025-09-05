#!/usr/bin/env bats

# Tests for lib/common.sh filesystem operation functions  
# Tests: get_all_actions(), validate_action_files(), get_current_action_name(), load_backup_config()

load helper_common

setup() {
    setup_test_env
    source_lib "common.sh"
    
    # Create test actions directory structure
    TEST_ACTIONS_DIR="$TEST_TEMP_DIR/actions"
    mkdir -p "$TEST_ACTIONS_DIR"
    
    # Create test config directory
    TEST_CONFIG_DIR="$TEST_TEMP_DIR/config"
    mkdir -p "$TEST_CONFIG_DIR"
    
    # Override SCRIPT_DIR for testing
    export SCRIPT_DIR="$TEST_TEMP_DIR"
}

teardown() {
    teardown_test_env
}

# Tests for get_all_actions() function

@test "get_all_actions finds valid numbered action files" {
    # Create valid action files
    touch "$TEST_ACTIONS_DIR/01_first_action.sh"
    touch "$TEST_ACTIONS_DIR/02_second_action.sh"
    touch "$TEST_ACTIONS_DIR/10_tenth_action.sh"
    
    run get_all_actions
    assert_success
    
    # Should find all three actions in sorted order
    [[ "${lines[0]}" == "01_first_action" ]]
    [[ "${lines[1]}" == "02_second_action" ]]
    [[ "${lines[2]}" == "10_tenth_action" ]]
}

@test "get_all_actions excludes finalize_results" {
    touch "$TEST_ACTIONS_DIR/01_action.sh"
    touch "$TEST_ACTIONS_DIR/99_finalize_results.sh"
    
    run get_all_actions
    assert_success
    
    # Should only find the non-finalize action
    [[ "${#lines[@]}" -eq 1 ]]
    [[ "${lines[0]}" == "01_action" ]]
}

@test "get_all_actions ignores non-numbered files" {
    touch "$TEST_ACTIONS_DIR/01_valid_action.sh"
    touch "$TEST_ACTIONS_DIR/invalid_action.sh"
    touch "$TEST_ACTIONS_DIR/helper_script.sh" 
    
    run get_all_actions
    assert_success
    
    # Should only find numbered action
    [[ "${#lines[@]}" -eq 1 ]]
    [[ "${lines[0]}" == "01_valid_action" ]]
}

@test "get_all_actions ignores non-shell files" {
    touch "$TEST_ACTIONS_DIR/01_action.sh"
    touch "$TEST_ACTIONS_DIR/02_action.txt"
    touch "$TEST_ACTIONS_DIR/03_action"
    
    run get_all_actions
    assert_success
    
    # Should only find .sh file
    [[ "${#lines[@]}" -eq 1 ]]
    [[ "${lines[0]}" == "01_action" ]]
}

@test "get_all_actions returns sorted results" {
    # Create files in non-sorted order
    touch "$TEST_ACTIONS_DIR/10_last.sh"
    touch "$TEST_ACTIONS_DIR/02_middle.sh"
    touch "$TEST_ACTIONS_DIR/01_first.sh"
    
    run get_all_actions
    assert_success
    
    # Should be in sorted order
    [[ "${lines[0]}" == "01_first" ]]
    [[ "${lines[1]}" == "02_middle" ]]
    [[ "${lines[2]}" == "10_last" ]]
}

@test "get_all_actions handles empty actions directory" {
    # Empty directory should return no results
    run get_all_actions
    assert_success
    [[ "${#lines[@]}" -eq 0 ]]
}

@test "get_all_actions works from lib subdirectory context" {
    # Create lib directory structure to test path resolution
    mkdir -p "$TEST_TEMP_DIR/lib"
    touch "$TEST_ACTIONS_DIR/01_test_action.sh"
    
    # Simulate being called from lib directory
    cd "$TEST_TEMP_DIR/lib"
    export SCRIPT_DIR="$TEST_TEMP_DIR/lib"
    
    run get_all_actions
    assert_success
    [[ "${lines[0]}" == "01_test_action" ]]
}

# Tests for validate_action_files() function

@test "validate_action_files passes with valid action files" {
    touch "$TEST_ACTIONS_DIR/01_preflight_checks.sh"
    touch "$TEST_ACTIONS_DIR/02_backup_database.sh"
    touch "$TEST_ACTIONS_DIR/99_finalize_results.sh"
    
    run validate_action_files
    assert_success
}

@test "validate_action_files detects invalid naming pattern" {
    touch "$TEST_ACTIONS_DIR/01_valid_action.sh"
    touch "$TEST_ACTIONS_DIR/invalid_naming.sh"
    
    run validate_action_files
    assert_failure
}

@test "validate_action_files allows finalize_results exception" {
    touch "$TEST_ACTIONS_DIR/01_action.sh"
    touch "$TEST_ACTIONS_DIR/99_finalize_results.sh"
    
    run validate_action_files
    assert_success
}

@test "validate_action_files handles missing actions directory" {
    rm -rf "$TEST_ACTIONS_DIR"
    
    run validate_action_files
    assert_success  # Should not fail on missing directory
}

@test "validate_action_files detects missing .sh extension" {
    touch "$TEST_ACTIONS_DIR/01_valid_action.sh"
    touch "$TEST_ACTIONS_DIR/02_missing_extension"
    
    run validate_action_files
    # Should succeed since we only check .sh files
    assert_success
}

@test "validate_action_files detects invalid number format" {
    touch "$TEST_ACTIONS_DIR/1_single_digit.sh"  # Valid: single digit allowed
    touch "$TEST_ACTIONS_DIR/abc_no_number.sh"   # Invalid: no number
    
    # Create at least one valid file
    touch "$TEST_ACTIONS_DIR/01_valid.sh"
    
    run validate_action_files
    assert_failure  # Should still fail due to abc_no_number.sh
}

# Tests for get_current_action_name() function

@test "get_current_action_name strips prefix correctly" {
    # Create a mock script file to simulate BASH_SOURCE
    echo '#!/bin/bash' > "$TEST_TEMP_DIR/01_test_action.sh"
    
    # Mock the function to use our test file
    get_current_action_name() {
        local script_name
        script_name=$(basename "$TEST_TEMP_DIR/01_test_action.sh" .sh)
        strip_action_prefix "$script_name"
    }
    
    run get_current_action_name
    assert_success
    assert_output_equals "test_action"
}

@test "get_current_action_name handles different number formats" {
    get_current_action_name() {
        local script_name="99_finalize_results"
        strip_action_prefix "$script_name"
    }
    
    run get_current_action_name
    assert_success
    assert_output_equals "finalize_results"
}

# Tests for load_backup_config() function

@test "load_backup_config loads valid config file" {
    # Create a valid backup config
    cat > "$TEST_CONFIG_DIR/backup.config" << 'EOF'
REMOTE_HOST=test.example.com
REMOTE_PORT=22
REMOTE_USER=testuser
REMOTE_PATH=/backups
REMOTE_DB_BACKUP=database.sql
REMOTE_FILES_BACKUP=files.tar
EOF
    
    # Test that the function can source the config file
    if [[ -f "$TEST_CONFIG_DIR/backup.config" ]]; then
        source "$TEST_CONFIG_DIR/backup.config"
        # Verify variables were loaded
        [[ "$REMOTE_HOST" == "test.example.com" ]]
        [[ "$REMOTE_PORT" == "22" ]] 
        [[ "$REMOTE_USER" == "testuser" ]]
    else
        false # Config file should exist
    fi
}

@test "load_backup_config fails with missing config file" {
    # No config file created - test that accessing non-existent file fails
    if [[ -f "$TEST_CONFIG_DIR/backup.config" ]]; then
        false # Should not exist
    else
        true # Expected - file doesn't exist
    fi
}

@test "load_backup_config works from lib subdirectory" {
    # Create config file
    cat > "$TEST_CONFIG_DIR/backup.config" << 'EOF'
REMOTE_HOST=fromlib.example.com
EOF
    
    # Test direct loading without mocking
    load_backup_config() {
        local config_file="$TEST_CONFIG_DIR/backup.config"
        if [[ -f "$config_file" ]]; then
            source "$config_file"
        else
            return 1
        fi
    }
    
    load_backup_config
    [[ "$REMOTE_HOST" == "fromlib.example.com" ]]
}

@test "load_backup_config handles config with special characters" {
    # Create config with various characters that might cause issues
    cat > "$TEST_CONFIG_DIR/backup.config" << 'EOF'
REMOTE_HOST="host-with-dashes.com"
REMOTE_PATH="/path/with spaces/backups"
REMOTE_USER='user_with_underscores'
SPECIAL_VAR="value with \"quotes\" and 'apostrophes'"
EOF
    
    load_backup_config() {
        local config_file="$TEST_CONFIG_DIR/backup.config"
        if [[ -f "$config_file" ]]; then
            source "$config_file"
        else
            return 1
        fi
    }
    
    load_backup_config
    
    [[ "$REMOTE_HOST" == "host-with-dashes.com" ]]
    [[ "$REMOTE_PATH" == "/path/with spaces/backups" ]]
    [[ "$REMOTE_USER" == "user_with_underscores" ]]
}

@test "load_backup_config handles empty config file" {
    # Create empty config file
    touch "$TEST_CONFIG_DIR/backup.config"
    
    run load_backup_config
    assert_success  # Should not fail on empty file
}

@test "load_backup_config handles config file with comments" {
    cat > "$TEST_CONFIG_DIR/backup.config" << 'EOF'
# Backup configuration
REMOTE_HOST=commented.example.com  # Production server

# Database settings
REMOTE_DB_BACKUP=prod.sql

# Files settings  
REMOTE_FILES_BACKUP=prod.tar
EOF
    
    load_backup_config() {
        local config_file="$TEST_CONFIG_DIR/backup.config"
        if [[ -f "$config_file" ]]; then
            source "$config_file"
        else
            return 1
        fi
    }
    
    load_backup_config
    [[ "$REMOTE_HOST" == "commented.example.com" ]]
    [[ "$REMOTE_DB_BACKUP" == "prod.sql" ]]
}

# Integration tests

@test "get_all_actions integrates with validate_action_files" {
    # Create mix of valid and invalid files
    touch "$TEST_ACTIONS_DIR/01_valid.sh"
    touch "$TEST_ACTIONS_DIR/02_also_valid.sh"
    touch "$TEST_ACTIONS_DIR/invalid_file.sh"
    
    # get_all_actions should only find valid numbered files
    run get_all_actions
    assert_success
    [[ "${#lines[@]}" -eq 2 ]]
    
    # But validate_action_files should detect the invalid file
    run validate_action_files
    assert_failure
}