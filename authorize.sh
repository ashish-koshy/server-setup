#!/bin/bash

GITHUB_USER="ashish-koshy"
KEYS_URL="https://github.com/$GITHUB_USER.keys"

# Fetch keys from GitHub
echo "🌐 Fetching SSH keys from $KEYS_URL..."
KEYS=$(curl -s "$KEYS_URL")

if [ -z "$KEYS" ]; then
  echo "❌ No keys found at $KEYS_URL"
  exit 1
fi

# Ensure .ssh directory and authorized_keys file exist
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Loop through each line (key) in the response
echo "$KEYS" | while IFS= read -r key; do
  if ! grep -qxF "$key" ~/.ssh/authorized_keys; then
    echo "$key" >> ~/.ssh/authorized_keys
    echo "✅ Added key: $key"
  else
    echo "ℹ️  Key already exists: $key"
  fi
done
