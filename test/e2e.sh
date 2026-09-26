#!/usr/bin/env bash
# End-to-end test for the built pipe image with the CLI it bakes in:
#   bash test/e2e.sh gocov/upload-pipe:ci
# The pipe uploads a real profile to test/fake_server.py, as it would in a
# Bitbucket step, and the test checks what arrived — the token, the repo
# and commit the CLI detected from the Bitbucket environment, and the
# uploader naming exactly the CLI release the Dockerfile pins. Offline and
# secret-free, so it gates the bump PRs a gocov release opens here: the
# server side of a release is already smoke-tested by gocov's own deploy.
set -euo pipefail

IMG=${1:?usage: e2e.sh <image>}
cd "$(dirname "$0")/.."
want=$(sed -n 's/^ARG GOCOV_VERSION=\(v[0-9][0-9.]*\) *$/\1/p' Dockerfile)
[ -n "$want" ] || { echo "no ARG GOCOV_VERSION in Dockerfile" >&2; exit 1; }

dir=$(mktemp -d "$PWD/e2e-scratch.XXXXXX")
chmod 777 "$dir"
port=18765
python3 test/fake_server.py "$port" "$dir" &
server=$!
trap 'kill "$server" 2>/dev/null; rm -rf "$dir"' EXIT
for _ in $(seq 1 50); do
  (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break
  sleep 0.1
done

printf 'mode: atomic\nexample.com/m/a.go:1.1,3.2 1 1\n' >"$dir/coverage.out"
out=$(docker run --rm --network host \
  -e FILES=coverage.out -e TOKEN=e2e-token -e SERVER="http://127.0.0.1:$port" \
  -e BITBUCKET_BUILD_NUMBER=1 \
  -e BITBUCKET_REPO_FULL_NAME=gocov/e2e \
  -e BITBUCKET_COMMIT=0123456789abcdef0123456789abcdef01234567 \
  -e BITBUCKET_BRANCH=main \
  -v "$dir":/work -w /work "$IMG" 2>&1) || {
  echo "FAIL: the pipe exited non-zero; got:"; printf '%s\n' "$out"; exit 1; }
printf '%s\n' "$out"

grep -q 'uploaded: 75.0% (3/4 statements)' <<<"$out" || {
  echo "FAIL: the CLI did not report the fake server's answer"; exit 1; }
python3 - "$dir/request.json" "$want" <<'PY'
import json, sys
req = json.load(open(sys.argv[1])); f = req["fields"]
checks = {
    "authorization": (req["authorization"], "Bearer e2e-token"),
    "repo": (f.get("repo"), "gocov/e2e"),
    "commit": (f.get("commit"), "0123456789abcdef0123456789abcdef01234567"),
    "branch": (f.get("branch"), "main"),
    "uploader": (f.get("uploader"), "gocov " + sys.argv[2]),
}
bad = [f"{k}: got {g!r}, want {w!r}" for k, (g, w) in checks.items() if g != w]
if "example.com/m/a.go" not in f.get("profile", ""):
    bad.append("profile: the coverage file did not arrive")
if bad:
    print("FAIL:\n  " + "\n  ".join(bad)); sys.exit(1)
PY
echo "e2e passed: $want uploaded through the pipe"
