# Changelog

## 0.1.1

- pipe.yml is ASCII-only so the Atlassian pipe catalog's validator can
  parse it. No functional changes.

## 0.1.0

- Initial release: uploads Go (and lcov/JaCoCo/Cobertura/Clover/SimpleCov)
  coverage profiles to gocov with `FILES`, `TOKEN`, `PART`, `SERVER`,
  `FAIL_ON_ERROR` and `DEBUG` variables. gocov CLI v0.8.3 baked into the
  image; multi-arch (amd64 + arm64).
