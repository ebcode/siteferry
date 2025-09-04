#!/usr/bin/env bats

# Tests for lib/common.sh string processing functions
# Tests: strip_action_prefix(), get_action_base_name(), get_action_display_name()

load helper_common

setup() {
    setup_test_env
    source_lib "common.sh"
}

teardown() {
    teardown_test_env
}

# Tests for strip_action_prefix() function
@test "strip_action_prefix removes single digit prefix" {
    run strip_action_prefix "1_action_name"
    
    assert_success
    assert_output_equals "action_name"
}

@test "strip_action_prefix removes double digit prefix" {
    run strip_action_prefix "12_action_name"
    
    assert_success
    assert_output_equals "action_name"
}

@test "strip_action_prefix removes triple digit prefix" {
    run strip_action_prefix "123_action_name"
    
    assert_success
    assert_output_equals "action_name"
}

@test "strip_action_prefix handles zero-padded prefixes" {
    run strip_action_prefix "01_preflight_checks"
    
    assert_success
    assert_output_equals "preflight_checks"
}

@test "strip_action_prefix handles underscores in action name" {
    run strip_action_prefix "02_fetch_db_backup"
    
    assert_success
    assert_output_equals "fetch_db_backup"
}

@test "strip_action_prefix handles action with no numeric prefix" {
    run strip_action_prefix "action_name"
    
    assert_success
    assert_output_equals "action_name"
}

@test "strip_action_prefix handles multiple underscores after prefix" {
    run strip_action_prefix "03_import__database"
    
    assert_success
    assert_output_equals "import__database"
}

@test "strip_action_prefix handles empty string" {
    run strip_action_prefix ""
    
    assert_success
    assert_output_equals ""
}

@test "strip_action_prefix handles string with just underscore" {
    run strip_action_prefix "_"
    
    assert_success
    assert_output_equals "_"
}

# Tests for get_action_base_name() function
@test "get_action_base_name calls strip_action_prefix" {
    run get_action_base_name "01_preflight_checks"
    
    assert_success
    assert_output_equals "preflight_checks"
}

@test "get_action_base_name handles complex action names" {
    run get_action_base_name "99_finalize_results"
    
    assert_success
    assert_output_equals "finalize_results"
}

@test "get_action_base_name handles real project examples" {
    run get_action_base_name "02_fetch_db_backup"
    
    assert_success
    assert_output_equals "fetch_db_backup"
    
    run get_action_base_name "08_cleanup_temp"
    
    assert_success
    assert_output_equals "cleanup_temp"
}

# Tests for get_action_display_name() function
@test "get_action_display_name converts simple action name" {
    run get_action_display_name "01_action_name"
    
    assert_success
    assert_output_equals "Action Name"
}

@test "get_action_display_name handles preflight checks" {
    run get_action_display_name "01_preflight_checks"
    
    assert_success
    assert_output_equals "Preflight Checks"
}

@test "get_action_display_name handles fetch database backup" {
    run get_action_display_name "02_fetch_db_backup"
    
    assert_success
    assert_output_equals "Fetch Db Backup"
}

@test "get_action_display_name handles files backup" {
    run get_action_display_name "03_fetch_files_backup"
    
    assert_success
    assert_output_equals "Fetch Files Backup"
}

@test "get_action_display_name handles import operations" {
    run get_action_display_name "04_import_database"
    
    assert_success
    assert_output_equals "Import Database"
}

@test "get_action_display_name handles cleanup operations" {
    run get_action_display_name "08_cleanup_temp"
    
    assert_success
    assert_output_equals "Cleanup Temp"
}

@test "get_action_display_name handles finalize results" {
    run get_action_display_name "99_finalize_results"
    
    assert_success
    assert_output_equals "Finalize Results"
}

@test "get_action_display_name handles single word" {
    run get_action_display_name "01_backup"
    
    assert_success
    assert_output_equals "Backup"
}

@test "get_action_display_name handles multiple underscores" {
    run get_action_display_name "01_test_multiple_words_here"
    
    assert_success
    assert_output_equals "Test Multiple Words Here"
}

@test "get_action_display_name handles short abbreviations" {
    run get_action_display_name "02_db_import"
    
    assert_success
    assert_output_equals "Db Import"
}

@test "get_action_display_name handles action without prefix" {
    run get_action_display_name "no_prefix_action"
    
    assert_success
    assert_output_equals "No Prefix Action"
}

# Edge cases and error handling
@test "string functions handle empty input" {
    run strip_action_prefix ""
    assert_success
    assert_output_equals ""
    
    run get_action_base_name ""
    assert_success
    assert_output_equals ""
    
    run get_action_display_name ""
    assert_success
    # get_action_display_name on empty string may have different behavior
    # Just ensure it doesn't crash
}

@test "string functions handle whitespace input" {
    run strip_action_prefix "  "
    assert_success
    # Just ensure it doesn't crash - specific behavior may vary
    
    run get_action_base_name "  "
    assert_success
    
    run get_action_display_name "  "
    assert_success
}

# Integration test: full action name processing pipeline
@test "action name processing pipeline" {
    local test_action="02_fetch_db_backup"
    
    # Test the base name extraction
    run get_action_base_name "$test_action"
    assert_success
    assert_output_equals "fetch_db_backup"
    
    # Test the display name conversion
    run get_action_display_name "$test_action"
    assert_success
    assert_output_equals "Fetch Db Backup"
    
    # Test direct prefix stripping
    run strip_action_prefix "$test_action"
    assert_success
    assert_output_equals "fetch_db_backup"
}