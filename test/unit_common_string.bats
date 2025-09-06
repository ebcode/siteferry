#!/usr/bin/env bats

# Tests for lib/common.sh string processing functions
# Tests: strip_numeric_prefix(), get_display_name()

load helper_common

setup() {
    setup_test_env
    source_lib "common.sh"
}

teardown() {
    teardown_test_env
}

# Tests for strip_numeric_prefix() function
@test "strip_numeric_prefix removes single digit prefix" {
    run strip_numeric_prefix "1_action_name"
    
    assert_success
    assert_output_equals "action_name"
}

@test "strip_numeric_prefix removes double digit prefix" {
    run strip_numeric_prefix "12_action_name"
    
    assert_success
    assert_output_equals "action_name"
}

@test "strip_numeric_prefix removes triple digit prefix" {
    run strip_numeric_prefix "123_action_name"
    
    assert_success
    assert_output_equals "action_name"
}

@test "strip_numeric_prefix handles zero-padded prefixes" {
    run strip_numeric_prefix "01_preflight_checks"
    
    assert_success
    assert_output_equals "preflight_checks"
}

@test "strip_numeric_prefix handles underscores in action name" {
    run strip_numeric_prefix "02_fetch_db_backup"
    
    assert_success
    assert_output_equals "fetch_db_backup"
}

@test "strip_numeric_prefix handles action with no numeric prefix" {
    run strip_numeric_prefix "action_name"
    
    assert_success
    assert_output_equals "action_name"
}

@test "strip_numeric_prefix handles multiple underscores after prefix" {
    run strip_numeric_prefix "03_import__database"
    
    assert_success
    assert_output_equals "import__database"
}

@test "strip_numeric_prefix handles empty string" {
    run strip_numeric_prefix ""
    
    assert_success
    assert_output_equals ""
}

@test "strip_numeric_prefix handles string with just underscore" {
    run strip_numeric_prefix "_"
    
    assert_success
    assert_output_equals "_"
}

@test "strip_numeric_prefix handles additional test case" {
    run strip_numeric_prefix "08_cleanup_temp"
    
    assert_success
    assert_output_equals "cleanup_temp"
}

# Tests for get_display_name() function
@test "get_display_name converts simple script name" {
    run get_display_name "01_action_name"
    
    assert_success
    assert_output_equals "Action Name"
}


@test "get_display_name handles single word" {
    run get_display_name "01_backup"
    
    assert_success
    assert_output_equals "Backup"
}

@test "get_display_name handles multiple underscores" {
    run get_display_name "01_test_multiple_words_here"
    
    assert_success
    assert_output_equals "Test Multiple Words Here"
}

@test "get_display_name handles short abbreviations" {
    run get_display_name "02_db_import"
    
    assert_success
    assert_output_equals "Db Import"
}

@test "get_display_name handles action without prefix" {
    run get_display_name "no_prefix_action"
    
    assert_success
    assert_output_equals "No Prefix Action"
}

# Edge cases and error handling
@test "string functions handle empty input" {
    run strip_numeric_prefix ""
    assert_success
    assert_output_equals ""
    
    run get_display_name ""
    assert_success
    # get_display_name on empty string may have different behavior
    # Just ensure it doesn't crash
}

@test "string functions handle whitespace input" {
    run strip_numeric_prefix "  "
    assert_success
    # Just ensure it doesn't crash - specific behavior may vary
    
    run get_display_name "  "
    assert_success
}

# Integration test: full script name processing pipeline
@test "script name processing pipeline" {
    local test_script="02_fetch_db_backup"
    
    # Test the base name extraction
    run strip_numeric_prefix "$test_script"
    assert_success
    assert_output_equals "fetch_db_backup"
    
    # Test the display name conversion
    run get_display_name "$test_script"
    assert_success
    assert_output_equals "Fetch Db Backup"
}