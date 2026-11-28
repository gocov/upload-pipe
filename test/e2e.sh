#!/usr/bin/env bash
# End-to-end test for the built pipe image with the CLI it bakes in:
#   bash test/e2e.sh gocov/upload-pipe:ci
# The pipe uploads a real profile to test/fake_server.py, as it would in a
# Bitbucket step, and the test checks what arrived — the credential, the
# repo and commit the CLI detected from the Bitbucket environment, the
# ignore patterns, and the uploader naming exactly the CLI release the
# Dockerfile pins. Twice: once with a TOKEN and IGNORE, once with no TOKEN
# and the step's OIDC token in the environment. Offline and secret-free, so
# it gates the bump PRs a gocov release opens here: the server side of a
# release is already smoke-tested by gocov's own deploy.
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

# The build every upload below reports, as Bitbucket's environment names it.
repo=gocov/e2e
commit=0123456789abcdef0123456789abcdef01234567
branch=main

# upload <docker run args...>: one upload through the pipe as a Bitbucket
# step would run it, with the given variables on top of the build
# environment. Leaves the pipe's output in $out and what reached the fake
# server in $dir/request.json, removed first so a stale one cannot pass.
upload() {
  rm -f "$dir/request.json"
  out=$(docker run --rm --network host \
    -e FILES=coverage.out -e SERVER="http://127.0.0.1:$port" \
    -e BITBUCKET_BUILD_NUMBER=1 \
    -e BITBUCKET_REPO_FULL_NAME="$repo" \
    -e BITBUCKET_COMMIT="$commit" \
    -e BITBUCKET_BRANCH="$branch" \
    "$@" -v "$dir":/work -w /work "$IMG" 2>&1) || {
    echo "FAIL: the pipe exited non-zero; got:"; printf '%s\n' "$out"; exit 1; }
  printf '%s\n' "$out"
  grep -q 'uploaded: 75.0% (3/4 statements)' <<<"$out" || {
    echo "FAIL: the CLI did not report the fake server's answer"; exit 1; }
  [ -f "$dir/request.json" ] || {
    echo "FAIL: no request reached the fake server"; exit 1; }
}

# check <json object>: compare $dir/request.json with what the upload
# should have sent. "authorization" is the header; every other key is a
# multipart field, null meaning the field must be absent. The uploader, the
# build and the profile are checked on every upload.
check() {
  python3 - "$dir/request.json" "$1" "$want" "$repo" "$commit" "$branch" <<'PY'
import json, sys
path, case, version, repo, commit, branch = sys.argv[1:]
req = json.load(open(path))
got = {**req["fields"], "authorization": req["authorization"]}
want = {"uploader": "gocov " + version, "repo": repo, "commit": commit,
        "branch": branch, **json.loads(case)}
bad = [f"{k}: got {got.get(k)!r}, want {w!r}" for k, w in want.items() if got.get(k) != w]
if "example.com/m/a.go" not in got.get("profile", ""):
    bad.append("profile: the coverage file did not arrive")
if bad:
    print("FAIL:\n  " + "\n  ".join(bad)); sys.exit(1)
PY
}

echo "--- token upload with IGNORE"
# Commas and a newline in one value: the CLI splits the list and sends one
# ignore field per pattern.
upload -e TOKEN=e2e-token -e IGNORE="$(printf 'cmd/preview/**, *_mock.go\ngen/**')"
check '{"authorization": "Bearer e2e-token", "oidc_token": null,
        "ignore": ["cmd/preview/**", "*_mock.go", "gen/**"]}'

echo "--- OIDC upload: no TOKEN, the step's identity token in the environment"
# The CLI exits 0 on a refused OIDC upload, so the assertion is the
# oidc_token field on the wire, with no Authorization header.
upload -e BITBUCKET_STEP_OIDC_TOKEN=e2e.oidc.token
check '{"authorization": "", "oidc_token": "e2e.oidc.token", "ignore": null}'

echo "e2e passed: $want uploaded through the pipe, by token and by OIDC"
