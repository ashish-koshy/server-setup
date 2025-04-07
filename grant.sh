#!/bin/bash

# Get the name of the script itself
SELF=$(basename "$0")

# Loop through all .sh files, skip self
for script in *.sh; do
  if [ -f "$script" ] && [ "$script" != "$SELF" ]; then
    chmod +x "$script"
    echo "✅ Made $script executable"
  fi
done
