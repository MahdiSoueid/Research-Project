#!/usr/bin/env bash
set -e

# Optional: navigate to the repository directory
# cd "$(dirname "$0")"

# Check Git status
if [[ -z $(git status -s) ]]; then
  echo "No changes to publish."
  exit 0
fi

# Stage all modified and new notes (respecting .gitignore)
git add -A

# Prompt for a commit message or fallback to timestamp
COMMIT_MSG="$1"
if [ -z "$COMMIT_MSG" ]; then
  COMMIT_MSG="Vault update: $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo "Committing: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

echo "Pushing to remote repository..."
git push origin main

echo "Done! GitHub Actions will now build and publish your site."
