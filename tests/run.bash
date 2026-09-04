#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BATS_IMAGE="bats/bats:1.14.0"

exec docker run --rm \
  -v "${REPO_ROOT}:/work" \
  -w /work \
  "${BATS_IMAGE}" \
  tests/observe.bats \
  tests/recover.bats \
  tests/verify.bats
