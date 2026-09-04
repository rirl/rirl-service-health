#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export VERIFY_SCRIPT="${REPO_ROOT}/scripts/verify.bash"

    export TMP_VERIFY_DIR="${BATS_TEST_TMPDIR}/verify"
    mkdir -p "${TMP_VERIFY_DIR}"
    export OBSERVE_SEQUENCE_FILE="${TMP_VERIFY_DIR}/sequence"
    export OBSERVE_STATE_FILE="${TMP_VERIFY_DIR}/state"

    cat > "${TMP_VERIFY_DIR}/observe-mock" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

index=1
if [[ -f "${OBSERVE_STATE_FILE}" ]]; then
    index="$(cat "${OBSERVE_STATE_FILE}")"
fi

line="$(sed -n "${index}p" "${OBSERVE_SEQUENCE_FILE}")"
if [[ -z "${line}" ]]; then
    line="$(tail -n 1 "${OBSERVE_SEQUENCE_FILE}")"
fi

printf '%s\n' "$((index + 1))" > "${OBSERVE_STATE_FILE}"

status="${line%% *}"
reason="${line#* }"

printf 'reason=%s\n' "${reason}"
case "${reason}" in
    healthy)
        printf 'Healthy mock observation.\n'
        ;;
    *)
        printf 'Mock observation: %s.\n' "${reason}" >&2
        ;;
esac

exit "${status}"
EOF
    chmod 0755 "${TMP_VERIFY_DIR}/observe-mock"

    cat > "${TMP_VERIFY_DIR}/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod 0755 "${TMP_VERIFY_DIR}/sleep"

    export OBSERVE_COMMAND="${TMP_VERIFY_DIR}/observe-mock"
    export PATH="${TMP_VERIFY_DIR}:${PATH}"
}

set_sequence() {
    printf '%s\n' "$@" > "${OBSERVE_SEQUENCE_FILE}"
}

@test "generic verify requires an adapter" {
    run "${VERIFY_SCRIPT}"
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Usage:"* ]]
}

@test "generic verify rejects unsupported adapter" {
    run "${VERIFY_SCRIPT}" vault
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Unsupported adapter"* ]]
}

@test "nginx verify succeeds when healthy immediately" {
    set_sequence "0 healthy"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout 0 \
        --poll-interval 1 \
        test-nginx

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Verification succeeded"* ]]
}

@test "nginx verify succeeds after unhealthy becomes healthy" {
    set_sequence \
        "1 unhealthy" \
        "0 healthy"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout 5 \
        --poll-interval 1 \
        test-nginx

    [ "${status}" -eq 0 ]
}

@test "nginx verify succeeds after starting becomes healthy" {
    set_sequence \
        "2 starting" \
        "0 healthy"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout 5 \
        --poll-interval 1 \
        test-nginx

    [ "${status}" -eq 0 ]
}

@test "nginx verify times out on persistent unhealthy" {
    set_sequence "1 unhealthy"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout 0 \
        --poll-interval 1 \
        test-nginx

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"last reason=unhealthy"* ]]
}

@test "nginx verify times out on persistent starting" {
    set_sequence "2 starting"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout 0 \
        --poll-interval 1 \
        test-nginx

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"last reason=starting"* ]]
}

@test "nginx verify returns indeterminate when Docker is unavailable" {
    set_sequence "2 docker-unavailable"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout 5 \
        --poll-interval 1 \
        test-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"reason=docker-unavailable"* ]]
}

@test "nginx verify returns indeterminate without healthcheck" {
    set_sequence "2 no-healthcheck"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout 5 \
        --poll-interval 1 \
        test-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"reason=no-healthcheck"* ]]
}

@test "nginx verify returns indeterminate on malformed state" {
    set_sequence "2 malformed-state"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout 5 \
        --poll-interval 1 \
        test-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"reason=malformed-state"* ]]
}

@test "nginx verify rejects invalid timeout" {
    set_sequence "0 healthy"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout nope \
        test-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Timeout must be a non-negative integer"* ]]
}

@test "nginx verify rejects zero poll interval" {
    set_sequence "0 healthy"

    run env \
        OBSERVE_COMMAND="${OBSERVE_COMMAND}" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --poll-interval 0 \
        test-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Poll interval must be a positive integer"* ]]
}

@test "nginx verify rejects missing reason token" {
    cat > "${TMP_VERIFY_DIR}/observe-bad" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
    chmod 0755 "${TMP_VERIFY_DIR}/observe-bad"

    run env \
        OBSERVE_COMMAND="${TMP_VERIFY_DIR}/observe-bad" \
        PATH="${PATH}" \
        "${VERIFY_SCRIPT}" nginx \
        --timeout 0 \
        --poll-interval 1 \
        test-nginx

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"no valid reason token"* ]]
}
