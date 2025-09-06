#!/bin/bash
find . -name "*.sh" -print0 | xargs -0 grep  "() {" | sort | sed 's/() {//'
