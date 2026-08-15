# Bitbucket Pipelines Pipe: gocov coverage upload

![coverage](https://app.gocov.dev/badge/gocov/upload-pipe.svg)

Upload Go test coverage to [gocov](https://app.gocov.dev) from Bitbucket
Pipelines: PR diff coverage, commit statuses, Code Insights reports and a
README badge, on the hosted service or your own server.

The pipe is a thin wrapper around the gocov CLI, with the pinned CLI
release baked into the image at build time (sha256-verified) — nothing is
downloaded at runtime. Repo, commit, branch and PR id are auto-detected
from the Pipelines environment.

## YAML Definition

Add the following snippet to the script section of your
`bitbucket-pipelines.yml` file:

```yaml
- pipe: docker://gocov/upload-pipe:0
  variables:
    FILES: coverage.out
    TOKEN: $GOCOV_TOKEN
```

## Variables

| Variable        | Usage |
|-----------------|-------|
| FILES (*)       | Coverage profile(s) to upload. Comma-separated, globs allowed (`coverage.out`, `cover/*.out`). |
| TOKEN (*)       | gocov upload token, from a [secured repository variable](https://support.atlassian.com/bitbucket-cloud/docs/variables-and-secrets/). |
| PART            | Label for this upload when a build's coverage is split across parallel steps; the server merges parts for the same commit. Requires a pipe release whose pinned CLI has multi-part upload support. |
| SERVER          | gocov server URL; override when self-hosting. Default: `https://app.gocov.dev`. |
| FAIL_ON_ERROR   | Fail the step when the upload fails. Set `false` to only warn. Default: `true` — honest failures; flip this if you'd rather never block CI on coverage upload. |
| DEBUG           | Turn on extra debug output. Default: `false`. |

_(*) = required variable._

## Prerequisites

A gocov upload token for the repo, from the gocov dashboard. In your
Bitbucket repo go to **Repository settings → Repository variables**, name
it `GOCOV_TOKEN`, paste the token and tick **Secured**. That's the only
setup step.

## Examples

Basic example:

```yaml
- step:
    script:
      - go test -coverprofile=coverage.out ./...
      - pipe: docker://gocov/upload-pipe:0
        variables:
          FILES: coverage.out
          TOKEN: $GOCOV_TOKEN
```

Then add the badge to your README:

```markdown
![coverage](https://app.gocov.dev/badge/{workspace}/{repo}.svg)
```

Advanced example — parallel test steps merged into one report with
`PART`, against a self-hosted server:

```yaml
- parallel:
    - step:
        name: Unit tests
        script:
          - go test -coverprofile=coverage.out ./... -run TestUnit
          - pipe: docker://gocov/upload-pipe:0
            variables:
              FILES: coverage.out
              TOKEN: $GOCOV_TOKEN
              SERVER: https://gocov.example.com
              PART: unit
    - step:
        name: Integration tests
        script:
          - go test -coverprofile=coverage.out ./... -run TestIntegration
          - pipe: docker://gocov/upload-pipe:0
            variables:
              FILES: coverage.out
              TOKEN: $GOCOV_TOKEN
              SERVER: https://gocov.example.com
              PART: integration
```

The image is multi-arch (amd64 + arm64), so the pipe also runs on arm
self-hosted runners. Pin an exact version with
`docker://gocov/upload-pipe:0.1.0`, or track the latest major with `:0`.

Not just Go: the CLI auto-detects lcov, JaCoCo, Cobertura, Clover and
SimpleCov profiles too, so `FILES` can point at any of those.

## Support

If you'd like help with this pipe, or you have an issue or feature
request, [open an issue](https://bitbucket.org/gocov/upload-pipe/issues)
or check the [gocov docs](https://app.gocov.dev).

## License

[MIT](LICENSE). The pipe is a thin wrapper around the gocov CLI and is
deliberately MIT-licensed so it never pulls AGPL terms into your
pipeline; the gocov server remains separately licensed.
