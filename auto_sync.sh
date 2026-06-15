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
        local exit_code=${PIPESTATUS[0]}
        set -e

        if [ $exit_code -eq 0 ]; then
            echo "$name successful!"
            return 0
        fi

        echo "$name failed with exit code $exit_code"

        if grep -q "unknown public key" "$logfile"; then
            echo "Importing missing GPG keys..."
            grep "unknown public key" "$logfile" | sed -n 's/.*unknown public key \([A-F0-9]*\).*/\1/p' | sort -u | while read -r key; do
                echo "Importing key: $key"
                gpg --keyserver keyserver.ubuntu.com --recv-keys "$key" || gpg --keyserver keys.openpgp.org --recv-keys "$key" || echo "Failed to import $key"
            done
        fi

        attempt=$((attempt + 1))
        if [ $attempt -le $MAX_ATTEMPTS ]; then
            echo "Retrying in 5 seconds..."
            sleep 5
        else
            echo "$name failed after $MAX_ATTEMPTS attempts"
            return 1
        fi
    done
}

echo "Updating VCS packages..."
vcs_pkgs=$(pacman -Sl aur 2>/dev/null | awk '{print $2}' | grep -E -- '-(git|svn|hg|bzr)$' || true)
if [ -n "$vcs_pkgs" ]; then
    for pkg in $vcs_pkgs; do
        echo "Processing VCS package: $pkg"
        sync_with_retry "VCS sync $pkg" /tmp/aur-sync-vcs.log sh -c "
            cd /tmp && aur fetch '$pkg' && cd '$pkg'
            # Patch zfs-utils-git: upstream no longer installs sudoers.d with --with-config=user
            if [ '$pkg' = 'zfs-utils-git' ]; then
                sed -i 's|chmod 750 \${pkgdir}/etc/sudoers.d|[ -d \${pkgdir}/etc/sudoers.d ] \&\& chmod 750 \${pkgdir}/etc/sudoers.d|' PKGBUILD
                sed -i 's|chmod 440 \${pkgdir}/etc/sudoers.d/zfs|[ -f \${pkgdir}/etc/sudoers.d/zfs ] \&\& chmod 440 \${pkgdir}/etc/sudoers.d/zfs|' PKGBUILD
            fi
            aur build --no-confirm --database=aur --syncdeps --force --margs --noconfirm
        "
    done
else
    echo "No VCS packages found"
fi

echo "Updating all packages in repository..."
sync_with_retry "Sync" /tmp/aur-sync.log aur sync --no-view --no-confirm --database=aur -u

echo "Sync completed at $(date)"
