# SiteFerry - Project Context

## Project Overview

**SiteFerry** is a modular, pipeline-based Bash automation system designed to streamline database and file backup operations for DDEV-based development environments. The system provides an interactive interface for selecting backup/restore actions and executes them in a configurable, dependency-aware pipeline with **multi-site architecture support**.

### Core Architecture

- **Pipeline Orchestrator** (`siteferry.sh`) - Main entry point with `--site SITE_NAME` support
- **Interactive Interface** (`action-selection.sh`) - Dialog-based action selection with state persistence
- **Action Modules** (`actions/NN_*.sh`) - Numbered pipeline stages for ordered execution
- **Configuration System** - Site-aware configuration with `sites-config/` and `internal-config/`
- **State Management** - Environment variable-based state passing between pipeline stages
- **Multi-Site Support** - Complete site isolation with `--site`, `--list-sites`, and `--tags` commands

## Project Structure

```
siteferry/
├── siteferry.sh                  # Main pipeline orchestrator
├── action-selection.sh           # Interactive action selection interface
├── sites-config/                 # Site-specific configurations
│   ├── default/
│   │   └── default.config        # Default site configuration
│   ├── mystore/
│   └── blog-prod/
├── internal-config/              # Site-specific internal state
├── lib/                          # Shared utilities (modular architecture)
│   ├── common.sh                 # Core orchestrator & state management
│   ├── string_utils.sh           # String processing utilities
│   ├── file_utils.sh             # File discovery and validation
│   ├── config_utils.sh           # Configuration management
│   ├── ssh_utils.sh              # SSH connectivity testing
│   └── parse_config.sh           # Dynamic configuration parser
└── actions/                      # Numbered action modules
    ├── 01_preflight_checks.sh    # System requirements & SSH connectivity
    ├── 02_fetch_files_backup.sh  # Files backup retrieval (REAL)
    ├── 03_import_files.sh        # Files import operations (REAL)
    ├── 04_fetch_db_backup.sh     # Database backup retrieval (REAL)
    ├── 05_import_database.sh     # Database import operations (simulated)
    ├── 06_setup_ddev.sh          # DDEV auto-setup (NEW - PENDING)
    ├── 08_cleanup_temp.sh        # Temporary file cleanup (simulated)
    └── 99_finalize_results.sh    # Pipeline results reporting
```

## Key Features

### ✅ Strengths

1. **Multi-Site Architecture**: Complete site isolation with `sites-config/` structure
2. **Dynamic Action Discovery**: Automatic discovery of numbered action files
3. **Site-Aware Operations**: All actions support per-site configuration
4. **Drop-in Actions**: Add new actions by placing `NN_action_name.sh` files
5. **Modular Design**: Clean separation with focused utility modules
6. **Real Implementation**: 50% complete - files-first workflow operational
7. **Unix Philosophy Adherence**: Each action does one thing well

### ⚠️ Current Issues

1. **Implementation Status**: 50% complete (3/6 actions real, 2/6 simulated)
2. **Pending DDEV Integration**: Task 8 - auto-setup action not yet implemented
3. **Tags System**: `--tags` command filtering not yet implemented
4. **Security**: Uses `StrictHostKeyChecking=no` (needs proper SSH key management)

## Technical Assessment

- **Architecture**: A-grade modular pipeline with multi-site support
- **Code Quality**: Shellcheck-compliant, generalized function names
- **Implementation**: 50% real functionality, files-first workflow complete
- **Testing**: 136/136 bats tests passing for all library functions

## Usage Examples

### Multi-Site Operations
```bash
# List available sites
./siteferry.sh --list-sites

# Work with specific site
./siteferry.sh --site mystore

# Filter sites by tags (planned)
./siteferry.sh --tags "production,laravel"
```

### Basic Operations
```bash
# Interactive mode (default site)
./siteferry.sh

# Preview pipeline without execution
./siteferry.sh --dry-run

# Non-interactive execution
./siteferry.sh --no-select
```

## Current Implementation Status

### ✅ Completed Multi-Site Architecture
- Site-specific config structure (`sites-config/` and `internal-config/`)
- Site selection with `--site SITE_NAME` and `--list-sites`
- Site-aware action selection and execution
- Dynamic site config creation
- Modular utility architecture (5 focused modules)

### 🔄 Current Phase: Remaining Multi-Site Tasks
1. **Task 8**: Implement DDEV auto-setup action (`06_setup_ddev.sh`)
2. **Task 9**: Implement tags system with `--tags` command
3. **Task 10**: Add hook placeholders to config template
4. **Task 11**: Test multi-site functionality and DDEV integration

### Real vs Simulated Actions
- **Real**: `02_fetch_files_backup.sh`, `03_import_files.sh`, `04_fetch_db_backup.sh`
- **Simulated**: `05_import_database.sh`, `08_cleanup_temp.sh`
- **New/Pending**: `06_setup_ddev.sh` (DDEV auto-setup)

## Development Guidelines

### Unix Philosophy
Write programs that do one thing and do it well. Write programs to work together. Handle text streams as universal interface.

### Project Rules
- **No backwards compatibility required** - brand new project
- **Test changes first** - always verify in shell before editing files
- **No networking tests** - avoid testing SSH/scp functions
- **Use `--no-select`** when testing siteferry.sh to avoid dialogs
- **Succinct commit messages** - one line, semicolon-separated
- **Fix bats tests** - never use `--no-verify` with git commit

### Path Management
- Configurable via `TEMP_DIR` environment variable
- Centralized constants in `lib/common.sh`
- Site-specific paths for multi-site isolation

---
*Context updated: 2025-09-06*  
*Multi-site architecture: Complete*  
*Implementation progress: 50% (3/6 actions real)*  
*Test coverage: 136/136 tests passing*