#!/bin/bash
find . -name "*.sh" -exec ls -lh {} \; | sort -k5 -hr | cut -d' ' -f5,10
