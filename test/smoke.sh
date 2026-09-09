#!/usr/bin/env bash
# Smoke tests for the built pipe image, run both in CI and locally:
#   bash test/smoke.sh gocov/upload-pipe:ci
# Every case is offline. The real dogfood upload lives in
# bitbucket-pipelines.yml, through the step's OIDC token — no secret.
set -euo pipefail

IMG=${1:?usage: smoke.sh <image>}
cd "$(dirname "$0")/.."

# The scratch dir lives under the repo, not under $TMPDIR: Bitbucket
# Cloud only allows `docker run -v` mounts below the build directory.
dir=$(mktemp -d "$PWD/smoke-scratch.XXXXXX")
trap 'rm -rf "$dir"' EXIT
# mktemp makes 700; the container user is not the host build user under
# Bitbucket's user-namespaced daemon, so open the dir up.
chmod 777 "$dir"

t() { echo "--- $1"; }

# expect_contains <output> <needle>: assert with the output echoed on
# failure, so a CI log shows what actually happened.
expect_contains() {
  grep -q "$2" <<<"$1" || {
    echo "FAIL: output does not contain '$2'; got:"
    printf '%s\n' "$1"
    exit 1
  }
}

t "missing TOKEN fails"
out=$(docker run --rm -e FILES=coverage.out "$IMG" 2>&1) && { echo "expected exit 1"; exit 1; }
expect_contains "$out" "TOKEN is required"

t "missing TOKEN with FAIL_ON_ERROR=false succeeds with a warning"
out=$(docker run --rm -e FILES=coverage.out -e FAIL_ON_ERROR=false "$IMG" 2>&1)
expect_contains "$out" "WARNING: TOKEN is required"

t "no matching files fails"
out=$(docker run --rm -e FILES='nope-*.out' -e TOKEN=dummy "$IMG" 2>&1) && { echo "expected exit 1"; exit 1; }
expect_contains "$out" "no coverage files matched"

t "glob expansion finds files (upload fails on the dummy token, not on matching)"
printf 'mode: atomic\n' >"$dir/a.out"
printf 'mode: atomic\n' >"$dir/b.out"
out=$(docker run --rm -e FILES='*.out' -e TOKEN=dummy -e SERVER=http://localhost:9 \
  -v "$dir":/work -w /work "$IMG" 2>&1) && { echo "expected exit 1"; exit 1; }
expect_contains "$out" "uploading a.out"
expect_contains "$out" "uploading b.out"
expect_contains "$out" "2 of 2 upload(s) failed"

t "OIDC token present, no TOKEN: attempts the upload, never demands a token"
# With an OIDC identity token in the env and no TOKEN, the pipe must take the
# OIDC path (attempt the upload) rather than fail asking for a token. The
# upload itself fails here (unreachable server), so FAIL_ON_ERROR=false keeps
# the step green — that isolates the behaviour under test (path choice) from
# whether the pinned CLI actually speaks OIDC yet.
# NOTE: asserting the request truly carries oidc_token needs a fake server
# and a CLI that speaks OIDC; that lands with the CLI-version bump.
out=$(docker run --rm -e FILES='*.out' -e BITBUCKET_STEP_OIDC_TOKEN=dummy.jwt.token \
  -e FAIL_ON_ERROR=false -e SERVER=http://localhost:9 -v "$dir":/work -w /work "$IMG" 2>&1)
expect_contains "$out" "uploading a.out"
expect_contains "$out" "uploading via OIDC"
if grep -q "TOKEN is required" <<<"$out"; then
  echo "FAIL: demanded a token despite an OIDC token being present; got:"
  printf '%s\n' "$out"
  exit 1
fi

echo "smoke tests passed"
