#!/bin/bash
grep -r "^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=" . --include="*.sh" | \
grep -v "+=" | cut -d: -f2 | cut -d= -f1 | sed 's/^[[:space:]]*//' | \
 LC_COLLATE=C sort | uniq
