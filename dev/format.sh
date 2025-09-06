#!/bin/bash

two_spaces() {
    local file="$1"
    awk '{
        match($0, /^[ ]*/)
        spaces = RLENGTH
        new_spaces = int(spaces / 2)
        rest = substr($0, spaces + 1)
        printf "%*s%s\n", new_spaces, "", rest
    }' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}
