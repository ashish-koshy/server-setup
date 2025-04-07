#!/bin/bash

# Find the first .pub file
PUB_FILE=$(find . -maxdepth 1 -type f -name "*.pub" | head -n 1)

if [ -z "$PUB_FILE" ]; then
  echo "❌ No .pub file found in the current directory."
  exit 1
fi

# Ensure .ssh directory and authorized_keys file exist
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Loop through each line (key) in the .pub file
while IFS= read -r key; do
  if ! grep -qxF "$key" ~/.ssh/authorized_keys; then
    echo "$key" >> ~/.ssh/authorized_keys
    echo "✅ Added key: $key"
  else
    echo "ℹ️  Key already exists: $key"
  fi
done < "$PUB_FILE"
