#!/usr/bin/env bash
# Identify current project. Output: REPO OWNER PROJECT (space-separated)
REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#.+[:/]([^/]+/[^/.]+)(\.git)?$#\1#')
OWNER=$(echo "$REPO" | cut -d/ -f1)
PROJECT=$(echo "$REPO" | cut -d/ -f2)
if [ -z "$PROJECT" ]; then
  PROJECT=$(basename "$PWD")
  OWNER="local"
  REPO="local/${PROJECT}"
fi
echo "$REPO $OWNER $PROJECT"
