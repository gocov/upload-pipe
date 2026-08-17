#!/usr/bin/env bash
# Pipe entrypoint: expands the comma-separated globs in $FILES and runs
# `gocov upload` for each match. The token and server reach the CLI via
# $GOCOV_TOKEN and $GOCOV_SERVER (never argv, so they cannot leak through
# process listings); repo/commit/branch/PR are auto-detected by the CLI
# from the Bitbucket Pipelines environment. The CLI binary is baked into
# the image at build time — nothing is downloaded at runtime.
set -eo pipefail

FAIL_ON_ERROR=${FAIL_ON_ERROR:-true}

info() { printf '\033[36mINFO: %s\033[0m\n' "$1"; }
warn() { printf '\033[33mWARNING: %s\033[0m\n' "$1"; }

fail() {
  if [ "$FAIL_ON_ERROR" = "false" ]; then
    warn "$1 (FAIL_ON_ERROR is false, not failing the step)"
    exit 0
  fi
  printf '\033[31m✖ %s\033[0m\n' "$1"
  exit 1
}

[ -n "${FILES:-}" ] ||
  fail "FILES is required: comma-separated coverage profile path(s), globs allowed"
[ -n "${TOKEN:-}" ] ||
  fail "TOKEN is required: pass the repo's upload token from a secured repository variable (see the README)"

export GOCOV_TOKEN="$TOKEN"
export GOCOV_SERVER="${SERVER:-https://app.gocov.dev}"

# Pipe convention: DEBUG=true traces every command. Enabled only *after* the
# token is exported, so the trace never prints `export GOCOV_TOKEN=<token>`.
[ "${DEBUG:-}" = "true" ] && set -x

# globstar is a bash >= 4 feature; without it "**" still matches one level
# as "*", so degrade silently rather than erroring on old bash.
shopt -s nullglob
shopt -s globstar 2>/dev/null || true

files=()
IFS=',' read -ra patterns <<<"$FILES"
for pat in "${patterns[@]}"; do
  # trim surrounding whitespace
  pat="${pat#"${pat%%[![:space:]]*}"}"
  pat="${pat%"${pat##*[![:space:]]}"}"
  [ -n "$pat" ] || continue
  # shellcheck disable=SC2206 # unquoted on purpose: glob expansion
  matched=($pat)
  if [ ${#matched[@]} -eq 0 ]; then
    warn "no files match '$pat'"
    continue
  fi
  files+=("${matched[@]}")
done
[ ${#files[@]} -gt 0 ] || fail "no coverage files matched: $FILES"

args=()
[ -n "${PART:-}" ] && args+=(-part "$PART")

failures=0
for f in "${files[@]}"; do
  info "uploading $f"
  gocov upload ${args[@]+"${args[@]}"} "$f" || failures=$((failures + 1))
done
[ "$failures" -eq 0 ] || fail "$failures of ${#files[@]} upload(s) failed"
printf '\033[32m✔ uploaded %d file(s)\033[0m\n' "${#files[@]}"
