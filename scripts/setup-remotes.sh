#!/usr/bin/env bash
# This repo lives in two places and a release needs both of them.
#
# Bitbucket carries the Atlassian pipe catalog entry, which is what
# `pipe: docker://gocov/upload-pipe:0` users find; GitHub runs the release
# workflow that actually builds and pushes the multi-arch image, because
# Bitbucket Cloud runners refuse the --privileged/QEMU setup buildx needs.
# So a tag pushed to only one remote publishes nothing on the other, with
# no error anywhere — the catalog silently keeps serving the old version,
# or the image never gets built at all.
#
# Remembering to push twice is not a plan. This teaches the clone to do it:
# after running it, `git push origin <tag>` writes to both remotes at once.
# Run it once per clone; it is idempotent, so running it again is free.
#
# The safety net behind it is scripts/verify-release.sh over in the gocov
# repo, which checks that a released tag exists on both — for the clone
# that never ran this.
set -euo pipefail

cd "$(dirname "$0")/.."

GITHUB_URL=git@github.com:gocov/upload-pipe.git

# Whatever this clone actually uses for Bitbucket. Read rather than
# assumed: people reach it through their own SSH host aliases.
bitbucket_url=$(git remote get-url origin)
case "$bitbucket_url" in
*bitbucket*) ;;
*)
  echo "setup-remotes: origin is $bitbucket_url, which does not look like Bitbucket." >&2
  echo "This script expects origin to be the Bitbucket repo. Fix origin, or push by hand." >&2
  exit 1
  ;;
esac

# A remote with no explicit push URL pushes to its fetch URL. Adding the
# first push URL replaces that implicit one, so both have to be named.
git remote set-url --delete --push origin '.*' 2>/dev/null || true
git remote set-url --add --push origin "$bitbucket_url"
git remote set-url --add --push origin "$GITHUB_URL"

# Keep the plain `github` remote too: the release workflow's logs and
# `gh` are easier to reach when the GitHub side is addressable on its own.
if ! git remote get-url github >/dev/null 2>&1; then
  git remote add github "$GITHUB_URL"
fi

echo "setup-remotes: 'git push origin' now writes to both:"
git remote get-url --all --push origin | sed 's/^/  /'
