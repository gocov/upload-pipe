#!/usr/bin/env bash
# Two versions live in this repo and they are not the same number:
#
#   the pipe's own version   0.3.0   — pipe.yml's image tag, the git tag,
#                                      the top CHANGELOG heading
#   the baked CLI version    v0.12.0 — Dockerfile's GOCOV_VERSION, fetched
#                                      and verified at image build time
#
# Both are written down more than once, and both have drifted. Between
# 16 and 26 August the image shipped with ARG GOCOV_VERSION=v0.9.0 while
# the changelog and the action had moved on to v0.11.0, so every Bitbucket
# user got a CLI two releases old for ten days and nothing said a word.
# This script is what should have said a word.
#
# Deliberately *not* checked here: that the CLI pin is gocov/gocov's
# newest release, and that pipe.yml matches the git tag. The first belongs
# after a release, not before it (scripts/verify-release.sh, in the gocov
# repo); the second already runs at tag time in both
# .github/workflows/release.yml and bitbucket-pipelines.yml, where a tag
# actually exists to compare against.
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "check-pins: $1" >&2
  shift
  [ $# -gt 0 ] && printf '%s\n' "$@" | sed 's/^/  /' >&2
  exit 1
}

# --- the pipe's own version ------------------------------------------
image=$(sed -n 's|^image: gocov/upload-pipe:\([0-9][0-9.]*\) *$|\1|p' pipe.yml)
[ -n "$image" ] || fail "no 'image: gocov/upload-pipe:X.Y.Z' line in pipe.yml."

changelog=$(sed -n 's/^## \([0-9][0-9.]*\) *$/\1/p' CHANGELOG.md | head -1)
[ -n "$changelog" ] || fail "no '## X.Y.Z' heading in CHANGELOG.md."

if [ "$image" != "$changelog" ]; then
  fail "pipe.yml and CHANGELOG.md disagree on the pipe version." \
    "pipe.yml     image: gocov/upload-pipe:$image" \
    "CHANGELOG.md ## $changelog" \
    "" \
    "The release tag is checked against pipe.yml at tag time, so a stale" \
    "changelog heading would otherwise only surface after the tag is cut."
fi

# --- the baked CLI version -------------------------------------------
cli=$(sed -n 's/^ARG GOCOV_VERSION=\(v[0-9][0-9.]*\) *$/\1/p' Dockerfile)
[ -n "$cli" ] || fail "no 'ARG GOCOV_VERSION=vX.Y.Z' line in Dockerfile."
if [ "$(echo "$cli" | wc -l | tr -d ' ')" -ne 1 ]; then
  fail "Dockerfile declares GOCOV_VERSION more than once:" "$cli"
fi

# The newest changelog entry states the CLI it bakes in the phrase the
# entries have always used — "Bake gocov CLI v0.12.0" — which is the claim
# users read. Only that phrase is matched, not every version in the entry:
# the same sentence carries the version it replaces ("(was v0.9.0)"), and
# that one is supposed to differ. An entry that changes nothing about the
# CLI need not say anything — 0.1.1 did not — so silence is fine and a
# contradiction is not.
entry=$(awk '/^## /{n++} n==1' CHANGELOG.md)
baked=$(echo "$entry" | sed -n 's/.*[Bb]ake gocov CLI \(v[0-9][0-9.]*\).*/\1/p' | head -1)
if [ -n "$baked" ] && [ "$baked" != "$cli" ]; then
  fail "the Dockerfile bakes a different CLI than the changelog claims." \
    "Dockerfile   ARG GOCOV_VERSION=$cli" \
    "CHANGELOG.md entry $changelog says it bakes $baked" \
    "" \
    "This is the drift that shipped a ten-day-old CLI in August."
fi

echo "check-pins: pipe $image, baking gocov CLI $cli${baked:+ (as the changelog says)}"
