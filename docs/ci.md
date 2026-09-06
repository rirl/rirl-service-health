# Continuous Integration

This repository uses GitHub Actions as a behavioral regression gate for the
service-health framework.

## Required checks

The stable pull-request check names are:

- `CI / Static`
- `CI / Unit & Contract`

Both checks run for pull requests targeting `development` or `main`, pushes to
`development` or `main`, and manual `workflow_dispatch` runs.

`CI / Unit & Contract` invokes the repository-owned `./tests/run.bash` entry
point. The workflow does not select individual Bats files.

## Reporting

The test runner writes:

- `test-results/unit/report.tap`
- `test-results/unit/report.xml`

The workflow preserves the test step's original exit status, writes a readable
GitHub Actions job summary from TAP, and uploads TAP/JUnit as
`unit-contract-reports` even after test failures.

Generated reports are not tracked by Git.

## Security boundary

Pull-request jobs use `pull_request`, never `pull_request_target`. The workflow
has only `contents: read` permission, persists no checkout credentials, and
receives no repository secrets.

The tests use mocked service-health adapters and must not depend on deployed
services, LAN connectivity, production certificate material, or deployment
topology.

## Local workflow-equivalent validation

Run:

```bash
bash -n \
  scripts/observe.bash \
  scripts/recover.bash \
  scripts/verify.bash \
  adapters/nginx/observe.bash \
  adapters/nginx/recover.bash \
  adapters/nginx/verify.bash \
  tests/run.bash

shellcheck \
  scripts/observe.bash \
  scripts/recover.bash \
  scripts/verify.bash \
  adapters/nginx/observe.bash \
  adapters/nginx/recover.bash \
  adapters/nginx/verify.bash \
  tests/run.bash

rm -rf test-results/unit
./tests/run.bash
```

Then inspect `test-results/unit/report.tap` and
`test-results/unit/report.xml`.

## Pinned GitHub Actions

External actions are pinned to immutable commits:

- `actions/checkout` v7.0.1: `3d3c42e5aac5ba805825da76410c181273ba90b1`
- `actions/upload-artifact` v7.0.1: `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`

Version comments in the workflow document the human-readable release while the
commit SHA is the executable reference.
