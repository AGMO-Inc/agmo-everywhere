#!/usr/bin/env bash
# Regression tests for identify-project.sh repo name parsing. Requires only Bash + git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

assert_eq() {
  [ "$1" = "$2" ] || { echo "expected '$2', got '$1' ($3)" >&2; exit 1; }
}

run_in() {
  (cd "$1" && bash "$ROOT/scripts/identify-project.sh")
}

remote_dir() {
  mkdir -p "$TMP/$1"
  git -C "$TMP/$1" init -q
  git -C "$TMP/$1" remote add origin "$2"
  echo "$TMP/$1"
}

assert_eq "$(run_in "$(remote_dir dotted-ssh git@github.com:AGMO-Inc/my.app.git)")" "AGMO-Inc/my.app AGMO-Inc my.app" "dotted-ssh"
assert_eq "$(run_in "$(remote_dir dotted-https https://github.com/AGMO-Inc/next.js)")" "AGMO-Inc/next.js AGMO-Inc next.js" "dotted-https"
assert_eq "$(run_in "$(remote_dir hyphen-ssh git@github.com:AGMO-Inc/agmo-everywhere.git)")" "AGMO-Inc/agmo-everywhere AGMO-Inc agmo-everywhere" "hyphen-ssh"
assert_eq "$(run_in "$(remote_dir plain-https https://github.com/AGMO-Inc/plain)")" "AGMO-Inc/plain AGMO-Inc plain" "plain-https"

mkdir -p "$TMP/norepo"
git -C "$TMP/norepo" init -q
assert_eq "$(run_in "$TMP/norepo")" "local/$(basename "$TMP/norepo") local $(basename "$TMP/norepo")" "no remote"

echo "identify-project tests passed"
