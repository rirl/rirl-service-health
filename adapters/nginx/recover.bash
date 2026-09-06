#!/usr/bin/env bash
set -Eeuo pipefail

readonly PROGRAM_NAME="${0##*/}"

usage() {
    cat <<EOF
Usage: ${PROGRAM_NAME} <container-name>

Exit codes:
  0  recovery action completed successfully; VERIFY must run next
  1  recovery action was attempted but failed
  2  recovery could not be attempted safely or definitively
EOF
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

container_name="$1"

if ! docker info >/dev/null 2>&1; then
    printf 'Unable to recover: Docker is unavailable.\n' >&2
    exit 2
fi

if ! docker inspect "${container_name}" >/dev/null 2>&1; then
    printf 'Unable to recover: expected container %s is absent.\n' "${container_name}" >&2
    exit 2
fi

state_status="$(
    docker inspect         --format '{{.State.Status}}'         "${container_name}" 2>/dev/null || true
)"

health_status="$(
    docker inspect         --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'         "${container_name}" 2>/dev/null || true
)"

if [[ -z "${state_status}" || -z "${health_status}" ]]; then
    printf 'Unable to recover: unexpected Docker inspect response.\n' >&2
    exit 2
fi

if [[ "${state_status}" == "running" ]]; then
    case "${health_status}" in
        unhealthy)
            ;;
        healthy)
            printf 'Recovery not permitted: container %s is already healthy.\n'                 "${container_name}" >&2
            exit 2
            ;;
        starting)
            printf 'Recovery not permitted: container %s health is still starting.\n'                 "${container_name}" >&2
            exit 2
            ;;
        none)
            printf 'Unable to recover: container %s has no Docker healthcheck.\n'                 "${container_name}" >&2
            exit 2
            ;;
        *)
            printf 'Unable to recover: container %s reported unexpected health state %s.\n'                 "${container_name}" "${health_status}" >&2
            exit 2
            ;;
    esac
fi

if ! docker restart "${container_name}" >/dev/null; then
    printf 'Recovery failed: Docker could not restart container %s.\n'         "${container_name}" >&2
    exit 1
fi

printf 'Recovery action completed: restarted container %s. VERIFY is required.\n'     "${container_name}"
exit 0
