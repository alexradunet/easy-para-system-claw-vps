#!/bin/bash
cd /srv/nazar/vault || exit 1

# Check if there are any changes
if git diff --quiet && git diff --cached --quiet; then
    exit 0
fi

# Stage and commit changes
git add -A
git commit -m "Auto-commit-by-Nazar"

# Pull first (with rebase) to incorporate any remote changes, then push
git pull --rebase origin main || git pull origin main
git push origin main
