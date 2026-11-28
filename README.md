# Bitbucket Pipelines Pipe: gocov coverage upload

[![coverage](https://app.gocov.dev/badge/bitbucket/gocov/upload-pipe.svg)](https://app.gocov.dev/repos/bitbucket/gocov/upload-pipe?ref=badge)

Upload test coverage to [gocov](https://app.gocov.dev) from Bitbucket
Pipelines: PR diff coverage, commit statuses, Code Insights reports and a
README badge, on the hosted service or your own server. Go, JavaScript /
TypeScript, Java / Kotlin, Python, PHP, Ruby, .NET, Swift and more — see
[Languages & formats](https://docs.gocov.dev/languages/).

The pipe is a thin wrapper around the gocov CLI, with the pinned CLI
release baked into the image at build time (sha256-verified) — nothing is
downloaded at runtime. Repo, commit, branch and PR id are auto-detected
from the Pipelines environment, and the coverage format from the file's
content.

## YAML Definition

Add the following snippet to the script section of your
`bitbucket-pipelines.yml` file:

```yaml
- pipe: docker://gocov/upload-pipe:0
  variables:
    FILES: coverage.out
```

Name your gocov server under the step's `oidc.audiences` and the upload
needs no secret; otherwise pass an upload token as `TOKEN`. The examples
below show the whole step both ways.

## Variables

| Variable        | Usage |
|-----------------|-------|
| FILES (*)       | Coverage file(s) to upload. Comma-separated, globs allowed (`coverage.out`, `cover/*.out`). |
| TOKEN           | gocov upload token, from a [secured variable](https://support.atlassian.com/bitbucket-cloud/docs/variables-and-secrets/). Leave it unset when the step uploads via [OIDC](#uploading-without-a-token). |
| PART            | Label for this upload when a build's coverage is split across parallel steps; the server merges the parts for the same commit. See [parts](https://docs.gocov.dev/parts/). |
| IGNORE          | Glob patterns for files to leave out of the report, comma-separated (`cmd/preview/**,*_mock.go`). They add to the repository's own **Ignored files** setting. See [Ignoring files](https://docs.gocov.dev/ignoring-files/). |
| SERVER          | gocov server URL; override when self-hosting. Default: `https://app.gocov.dev`. |
| FAIL_ON_ERROR   | Fail the step when the upload fails. Set `false` to only warn. Default: `true` — honest failures; flip this if you'd rather never block CI on coverage upload. |
| DEBUG           | Turn on extra debug output. Default: `false`. |

_(*) = required variable._

## Prerequisites

A gocov workspace for your Bitbucket workspace. With a token that is
enough to upload. [Connecting](https://docs.gocov.dev/connecting/) the
workspace to Bitbucket is what posts the build status and Code Insights
report, and it is what the server checks an OIDC upload against. The
repository itself needs no setup: its first upload registers it.

That is all OIDC needs. To use a token instead, an owner can reveal the
workspace's upload token in the gocov workspace settings, under
*Uploads*. In Bitbucket, add it as a variable named `GOCOV_TOKEN` (a
workspace variable covers every repository; a repository variable works
too) and tick **Secured**.

## Uploading without a token

Bitbucket can hand a step a short-lived, signed OIDC identity token, so
you can skip the `GOCOV_TOKEN` variable entirely. Naming your gocov server
under the step's `oidc.audiences` both turns OIDC on and binds the token
to your server so it can't be replayed elsewhere. Leave `TOKEN` unset; the
pipe passes on the token Bitbucket injects and the server verifies which
repository it came from.

The audience must equal your gocov server's URL (`https://app.gocov.dev`
on the hosted service). A `TOKEN` always takes precedence, and a rejected
OIDC upload logs the reason and does not fail the step. Full details:
[uploading without a token](https://docs.gocov.dev/bitbucket-pipelines/#uploading-without-a-token).

## Examples

Basic example, uploading via OIDC:

```yaml
- step:
    oidc:
      audiences:
        - https://app.gocov.dev   # your gocov server URL
    script:
      - go test ./... -covermode=atomic -coverprofile=coverage.out
      - pipe: docker://gocov/upload-pipe:0
        variables:
          FILES: coverage.out
```

The same with a token:

```yaml
- step:
    script:
      - go test ./... -covermode=atomic -coverprofile=coverage.out
      - pipe: docker://gocov/upload-pipe:0
        variables:
          FILES: coverage.out
          TOKEN: $GOCOV_TOKEN
```

Then add the badge to your README:

```markdown
[![coverage](https://app.gocov.dev/badge/bitbucket/{workspace}/{repo}.svg)](https://app.gocov.dev/repos/bitbucket/{workspace}/{repo}?ref=badge)
```

Other languages change only the test command and `FILES` — a JavaScript
project with Jest, for example:

```yaml
- npx jest --coverage
- pipe: docker://gocov/upload-pipe:0
  variables:
    FILES: coverage/lcov.info
```

[Languages & formats](https://docs.gocov.dev/languages/) lists what each
test tool writes.

### Ignoring files

Keep generated code, mocks or dev tooling out of the number without
touching the test command:

```yaml
- pipe: docker://gocov/upload-pipe:0
  variables:
    FILES: coverage.out
    IGNORE: "cmd/preview/**,**/*.pb.go,*_mock.go"
```

Patterns are globs in the `.gitignore` spirit, matched against the paths
in the report. They are applied on top of the repository's **Ignored
files** setting, never instead of it. Syntax and details:
[Ignoring files](https://docs.gocov.dev/ignoring-files/).

### Parallel steps

Parallel test steps merged into one report with `PART`, against a
self-hosted server:

```yaml
- parallel:
    - step:
        name: Unit tests
        oidc:
          audiences:
            - https://gocov.example.com
        script:
          - go test -coverprofile=coverage.out ./... -run TestUnit
          - pipe: docker://gocov/upload-pipe:0
            variables:
              FILES: coverage.out
              SERVER: https://gocov.example.com
              PART: unit
    - step:
        name: Integration tests
        oidc:
          audiences:
            - https://gocov.example.com
        script:
          - go test -coverprofile=coverage.out ./... -run TestIntegration
          - pipe: docker://gocov/upload-pipe:0
            variables:
              FILES: coverage.out
              SERVER: https://gocov.example.com
              PART: integration
```

The image is multi-arch (amd64 + arm64), so the pipe also runs on arm
self-hosted runners. `:0` tracks the latest 0.x release; to pin one, use
its full version from the [changelog](CHANGELOG.md) as the tag.

## Support

If you'd like help with this pipe, or you have an issue or feature
request, [open an issue](https://bitbucket.org/gocov/upload-pipe/issues)
or check the [gocov docs](https://docs.gocov.dev).

## License

[MIT](LICENSE). The pipe is a thin wrapper around the gocov CLI and is
deliberately MIT-licensed so it never pulls AGPL terms into your
pipeline; the gocov server remains separately licensed.
