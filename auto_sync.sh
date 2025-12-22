#!/bin/bash

echo "Starting AUR sync at $(date)"

sudo pacman --noconfirm -Sy

MAX_ATTEMPTS=5

sync_with_retry() {
    local name="$1"
    local logfile="$2"
    shift 2

    local attempt=1
    while [ $attempt -le $MAX_ATTEMPTS ]; do
        echo "$name attempt $attempt/$MAX_ATTEMPTS"
        set +e
        "$@" 2>&1 | tee "$logfile"
        local exit_code=$?
        set -e

        if grep -q "unknown public key" "$logfile"; then
            echo "Importing missing GPG keys..."
            grep "unknown public key" "$logfile" | sed -n 's/.*unknown public key \([A-F0-9]*\).*/\1/p' | sort -u | while read -r key; do
                echo "Importing key: $key"
                gpg --keyserver keyserver.ubuntu.com --recv-keys "$key" || gpg --keyserver keys.openpgp.org --recv-keys "$key" || echo "Failed to import $key"
            done
        elif [ $exit_code -ne 0 ]; then
            echo "$name failed with exit code $exit_code"
        else
            echo "$name successful!"
            break
        fi

        attempt=$((attempt + 1))
    done
}

echo "Updating VCS packages..."
vcs_pkgs=$(pacman -Sl aur 2>/dev/null | awk '{print $2}' | grep -E -- '-(git|svn|hg|bzr)$' || true)
if [ -n "$vcs_pkgs" ]; then
    for pkg in $vcs_pkgs; do
        echo "Processing VCS package: $pkg"
        sync_with_retry "VCS sync $pkg" /tmp/aur-sync-vcs.log sh -c "aur fetch '$pkg' && aur build --no-view --no-confirm --database=aur --force '$pkg'"
    done
else
    echo "No VCS packages found"
fi

echo "Updating all packages in repository..."
sync_with_retry "Sync" /tmp/aur-sync.log aur sync --no-view --no-confirm --database=aur -u

echo "Sync completed at $(date)"
