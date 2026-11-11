#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Initialize local git repository if not already present
if [ ! -d ".git" ]; then
  echo "Initializing git repository in $(pwd)..."
  git init -b main
fi

DEFAULT_REMOTE="git@github.com:MahdiSoueid/Research-Project.git"

# Configure remote if passed as argument or fallback to DEFAULT_REMOTE
case "${1:-}" in
  http*|git@*)
    if git remote get-url origin >/dev/null 2>&1; then
      git remote set-url origin "$1"
    else
      git remote add origin "$1"
    fi
    shift
    ;;
  *)
    if ! git remote get-url origin >/dev/null 2>&1; then
      git remote add origin "$DEFAULT_REMOTE"
    fi
    ;;
esac

COMMIT_MSG="${1:-Update research notes ($(date +'%Y-%m-%d %H:%M'))}"

git add -A

# Ensure documentation files and local workspace configs are untracked
git rm --cached -r -f .obsidian .copilot copilot 2>/dev/null || true
git rm --cached -f documentation.md Documentation.md DOCUMENTATION.md 2>/dev/null || true

if git diff --cached --quiet; then
  echo "No new changes to publish."
else
  git commit -m "$COMMIT_MSG"
fi

BRANCH="$(git branch --show-current)"
git push -u origin "$BRANCH"
echo "Published! GitHub Actions is now building and deploying your Quartz site."

