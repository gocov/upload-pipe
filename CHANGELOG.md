# Changelog

## 0.12.0

- Bake gocov CLI v0.20.0 (was v0.19.0).

## 0.11.0

- Bake gocov CLI v0.19.0 (was v0.18.0).

## 0.10.0

- Bake gocov CLI v0.18.0 (was v0.17.0).

## 0.9.0

- Bake gocov CLI v0.17.0 (was v0.16.0).

## 0.8.0

- Bake gocov CLI v0.16.0 (was v0.15.0).

## 0.7.0

- Bake gocov CLI v0.15.0 (was v0.14.0).

## 0.6.0

- Bake gocov CLI v0.14.0 (was v0.13.2).

## 0.5.0

- Bake gocov CLI v0.13.2 (was v0.13.1).

## 0.4.0

- Bake gocov CLI v0.13.1 (was v0.12.0).

## 0.3.0

- Bake gocov CLI v0.12.0 (was v0.9.0). Uploads from Bitbucket Pipelines now
  carry the provenance the upload page shows — commit subject and author,
  the build number and a link back to the pipeline run — and PR builds are
  measured against the default branch when the PR's own branch has no
  earlier passing upload, so before -> after and diff coverage appear on the
  builds that need them most.

## 0.2.0

- Bake gocov CLI v0.9.0, which merges multiple coverage reports per commit:
  give each matrix job's upload a distinct `PART` and the server combines
  them into one report (status, badge, gate, PR comment).
- Broaden the catalog description and tags to reflect multi-language support
  (JavaScript/TypeScript, Java, Python) alongside Go.
- Security: enable `DEBUG=true` command tracing only after the token is
  exported, so the trace can no longer print `export GOCOV_TOKEN=<token>`.

## 0.1.1

- pipe.yml is ASCII-only so the Atlassian pipe catalog's validator can
  parse it. No functional changes.

## 0.1.0

- Initial release: uploads Go (and lcov/JaCoCo/Cobertura/Clover/SimpleCov)
  coverage profiles to gocov with `FILES`, `TOKEN`, `PART`, `SERVER`,
  `FAIL_ON_ERROR` and `DEBUG` variables. gocov CLI v0.8.3 baked into the
  image; multi-arch (amd64 + arm64).
