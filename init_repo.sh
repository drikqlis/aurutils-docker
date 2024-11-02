#!/bin/sh

if ! (aur repo > /dev/null 2>&1); then
    printf "Aur repo not initialized, initializing /repo...\n"
    repo-add /repo/aur.db.tar.xz
fi

sudo pacman --noconfirm -Syu
repoctl conf new "$(readlink -f /repo/aur.db)"
