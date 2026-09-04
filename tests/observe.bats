#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PATH="${BATS_TEST_DIRNAME}/fixtures/bin:${PATH}"
    unset MOCK_DOCKER_INFO_FAIL
    unset MOCK_CONTAINER_ABSENT
    unset MOCK_STATE_STATUS
    unset MOCK_HEALTH_STATUS
}

@test "generic observer requires an adapter" {
    run "${REPO_ROOT}/scripts/observe.bash"
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Usage:"* ]]
}

@test "generic observer rejects unsupported adapter" {
    run "${REPO_ROOT}/scripts/observe.bash" vault
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Unsupported adapter"* ]]
}

@test "nginx observer reports healthy container" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=healthy

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"running and healthy"* ]]
}

@test "nginx observer reports running unhealthy container" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=unhealthy

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"running but unhealthy"* ]]
}

@test "nginx observer reports stopped container as unhealthy" {
    export MOCK_STATE_STATUS=exited
    export MOCK_HEALTH_STATUS=unhealthy

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"is exited"* ]]
}

@test "nginx observer reports absent expected container as unhealthy" {
    export MOCK_CONTAINER_ABSENT=1

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"is absent"* ]]
}

@test "nginx observer reports starting as unevaluable" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=starting

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"still starting"* ]]
}

@test "nginx observer reports missing healthcheck as unevaluable" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=none

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"has no Docker healthcheck"* ]]
}

@test "nginx observer reports Docker unavailable as unevaluable" {
    export MOCK_DOCKER_INFO_FAIL=1

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Docker is unavailable"* ]]
}
