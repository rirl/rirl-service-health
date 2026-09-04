#!/usr/bin/env bash
set -Eeuo pipefail

PROGRAM_NAME="${0##*/}"

usage() {
    cat <<EOF
Usage: ${PROGRAM_NAME} <container-name>

Exit codes:
  0  observed and healthy
  1  observed and unhealthy or unavailable
  2  unable to produce a definitive health judgment
EOF
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

container_name="$1"

if ! docker info >/dev/null 2>&1; then
    printf 'Unable to evaluate health: Docker is unavailable.\n' >&2
    exit 2
fi

if ! inspect_json="$(docker inspect "${container_name}" 2>/dev/null)"; then
    printf 'Unhealthy: expected container %s is absent.\n' "${container_name}" >&2
    exit 1
fi

state_status="$(printf '%s' "${inspect_json}" | docker inspect --format '{{.State.Status}}' "${container_name}" 2>/dev/null || true)"
health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container_name}" 2>/dev/null || true)"

if [[ -z "${state_status}" || -z "${health_status}" ]]; then
    printf 'Unable to evaluate health: unexpected Docker inspect response.\n' >&2
    exit 2
fi

if [[ "${state_status}" != "running" ]]; then
    printf 'Unhealthy: container %s is %s.\n' "${container_name}" "${state_status}" >&2
    exit 1
fi

case "${health_status}" in
    healthy)
        printf 'Healthy: container %s is running and healthy.\n' "${container_name}"
        exit 0
        ;;
    unhealthy)
        printf 'Unhealthy: container %s is running but unhealthy.\n' "${container_name}" >&2
        exit 1
        ;;
    starting)
        printf 'Unable to evaluate health: container %s health is still starting.\n' "${container_name}" >&2
        exit 2
        ;;
    none)
        printf 'Unable to evaluate health: container %s has no Docker healthcheck.\n' "${container_name}" >&2
        exit 2
        ;;
    *)
        printf 'Unable to evaluate health: container %s reported unexpected health state %s.\n'             "${container_name}" "${health_status}" >&2
        exit 2
        ;;
esac
