#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PATH="${BATS_TEST_DIRNAME}/fixtures/bin:${PATH}"

    unset MOCK_DOCKER_INFO_FAIL
    unset MOCK_CONTAINER_ABSENT
    unset MOCK_STATE_STATUS
    unset MOCK_HEALTH_STATUS
    unset MOCK_DOCKER_RESTART_FAIL
}

@test "generic recover requires an adapter" {
    run "${REPO_ROOT}/scripts/recover.bash"

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Usage:"* ]]
}

@test "generic recover rejects unsupported adapter" {
    run "${REPO_ROOT}/scripts/recover.bash" vault

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Unsupported adapter"* ]]
}

@test "nginx recover restarts running unhealthy container" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=unhealthy

    run "${REPO_ROOT}/scripts/recover.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"restarted container"* ]]
    [[ "${output}" == *"VERIFY is required"* ]]
}

@test "nginx recover restarts stopped container" {
    export MOCK_STATE_STATUS=exited
    export MOCK_HEALTH_STATUS=unhealthy

    run "${REPO_ROOT}/scripts/recover.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"restarted container"* ]]
}

@test "nginx recover refuses healthy container" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=healthy

    run "${REPO_ROOT}/scripts/recover.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"already healthy"* ]]
}

@test "nginx recover refuses starting container" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=starting

    run "${REPO_ROOT}/scripts/recover.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"still starting"* ]]
}

@test "nginx recover refuses container without healthcheck" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=none

    run "${REPO_ROOT}/scripts/recover.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"no Docker healthcheck"* ]]
}

@test "nginx recover reports absent container as not recoverable" {
    export MOCK_CONTAINER_ABSENT=1

    run "${REPO_ROOT}/scripts/recover.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"is absent"* ]]
}

@test "nginx recover reports Docker unavailable as not recoverable" {
    export MOCK_DOCKER_INFO_FAIL=1

    run "${REPO_ROOT}/scripts/recover.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Docker is unavailable"* ]]
}

@test "nginx recover reports restart failure" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=unhealthy
    export MOCK_DOCKER_RESTART_FAIL=1

    run "${REPO_ROOT}/scripts/recover.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Recovery failed"* ]]
}
