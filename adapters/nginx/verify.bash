#!/usr/bin/env bash
set -Eeuo pipefail

readonly PROGRAM_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OBSERVE_COMMAND="${OBSERVE_COMMAND:-${SCRIPT_DIR}/../../scripts/observe.bash}"

readonly DEFAULT_TIMEOUT_SECONDS=120
readonly DEFAULT_POLL_SECONDS=2

usage() {
    cat <<EOF
Usage: ${PROGRAM_NAME} [--timeout SECONDS] [--poll-interval SECONDS] <container-name>

Exit codes:
  0  required service health was proven
  1  service was observed but did not reach required health
  2  verification could not be completed definitively
EOF
}

is_nonnegative_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

is_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

timeout_seconds="${VERIFY_TIMEOUT_SECONDS:-${DEFAULT_TIMEOUT_SECONDS}}"
poll_seconds="${VERIFY_POLL_SECONDS:-${DEFAULT_POLL_SECONDS}}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            timeout_seconds="$2"
            shift 2
            ;;
        --poll-interval)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            poll_seconds="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            printf 'Unsupported option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

if ! is_nonnegative_integer "${timeout_seconds}"; then
    printf 'Timeout must be a non-negative integer number of seconds.\n' >&2
    exit 2
fi

if ! is_positive_integer "${poll_seconds}"; then
    printf 'Poll interval must be a positive integer number of seconds.\n' >&2
    exit 2
fi

container_name="$1"
deadline=$((SECONDS + timeout_seconds))
last_reason=""

while :; do
    set +e
    observation="$("${OBSERVE_COMMAND}" nginx "${container_name}" 2>&1)"
    observe_status=$?
    set -e

    reason="$(
        printf '%s\n' "${observation}" |
            sed -n 's/^reason=\([a-z0-9-][a-z0-9-]*\)$/\1/p' |
            head -n 1
    )"

    if [[ -z "${reason}" ]]; then
        printf 'Verification indeterminate: OBSERVE returned no valid reason token.\n' >&2
        exit 2
    fi

    last_reason="${reason}"

    case "${observe_status}:${reason}" in
        0:healthy)
            printf 'Verification succeeded: container %s is healthy.\n' "${container_name}"
            exit 0
            ;;
        1:healthy|2:healthy|0:*)
            printf \
                'Verification indeterminate: inconsistent OBSERVE result status=%s reason=%s.\n' \
                "${observe_status}" \
                "${reason}" >&2
            exit 2
            ;;
        1:unhealthy|1:stopped|1:absent|2:starting)
            ;;
        2:docker-unavailable|2:no-healthcheck|2:malformed-state)
            printf 'Verification indeterminate: OBSERVE reason=%s.\n' "${reason}" >&2
            exit 2
            ;;
        *)
            printf \
                'Verification indeterminate: unexpected OBSERVE result status=%s reason=%s.\n' \
                "${observe_status}" \
                "${reason}" >&2
            exit 2
            ;;
    esac

    if (( SECONDS >= deadline )); then
        printf \
            'Verification failed: container %s did not become healthy before timeout; last reason=%s.\n' \
            "${container_name}" \
            "${last_reason}" >&2
        exit 1
    fi

    sleep "${poll_seconds}"
done
