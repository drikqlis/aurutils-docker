#!/bin/bash

echo "Starting AUR sync at $(date)"

sudo pacman --noconfirm -Sy

echo "Updating all packages in repository..."
MAX_ATTEMPTS=5
attempt=1

while [ $attempt -le $MAX_ATTEMPTS ]; do
    echo "Sync attempt $attempt/$MAX_ATTEMPTS"
    set +e
    aur sync --no-view --no-confirm --database=aur -u 2>&1 | tee /tmp/aur-sync.log
    exit_code=$?
    set -e

    if grep -q "unknown public key" /tmp/aur-sync.log; then
        echo "Importing missing GPG keys..."
        grep "unknown public key" /tmp/aur-sync.log | sed -n 's/.*unknown public key \([A-F0-9]*\).*/\1/p' | sort -u | while read -r key; do
            echo "Importing key: $key"
            gpg --keyserver keyserver.ubuntu.com --recv-keys "$key" || gpg --keyserver keys.openpgp.org --recv-keys "$key" || echo "Failed to import $key"
        done
    elif [ $exit_code -ne 0 ]; then
        echo "Sync failed with exit code $exit_code"
    else
        echo "Sync successful!"
        break
    fi

    attempt=$((attempt + 1))
done

echo "Sync completed at $(date)"
