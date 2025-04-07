#!/bin/bash

# Find all .sh files in the current directory and make them executable
for script in *.sh; do
  if [ -f "$script" ]; then
    chmod +x "$script"
    echo "✅ Made $script executable"
  fi
done
