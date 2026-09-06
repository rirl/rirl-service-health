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

@test "nginx observer reports healthy container with stable reason" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=healthy

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"reason=healthy"* ]]
    [[ "${output}" == *"running and healthy"* ]]
}

@test "nginx observer reports running unhealthy container with stable reason" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=unhealthy

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"reason=unhealthy"* ]]
}

@test "nginx observer reports stopped container with stable reason" {
    export MOCK_STATE_STATUS=exited
    export MOCK_HEALTH_STATUS=unhealthy

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"reason=stopped"* ]]
}

@test "nginx observer reports absent expected container with stable reason" {
    export MOCK_CONTAINER_ABSENT=1

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"reason=absent"* ]]
}

@test "nginx observer reports starting as transitional reason" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=starting

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"reason=starting"* ]]
}

@test "nginx observer reports missing healthcheck with stable reason" {
    export MOCK_STATE_STATUS=running
    export MOCK_HEALTH_STATUS=none

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"reason=no-healthcheck"* ]]
}

@test "nginx observer reports Docker unavailable with stable reason" {
    export MOCK_DOCKER_INFO_FAIL=1

    run "${REPO_ROOT}/scripts/observe.bash" nginx rirl-tls-validation-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"reason=docker-unavailable"* ]]
}
