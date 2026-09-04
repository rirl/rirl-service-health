#!/usr/bin/env bash
set -Eeuo pipefail

readonly PROGRAM_NAME="${0##*/}"

usage() {
    cat <<EOF
Usage: ${PROGRAM_NAME} <container-name>

Exit codes:
  0  observed and healthy
  1  observed and unhealthy or unavailable
  2  unable to produce a definitive health judgment
EOF
}

emit_reason() {
    printf 'reason=%s\n' "$1"
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

container_name="$1"

if ! docker info >/dev/null 2>&1; then
    emit_reason "docker-unavailable"
    printf 'Unable to evaluate health: Docker is unavailable.\n' >&2
    exit 2
fi

if ! docker inspect "${container_name}" >/dev/null 2>&1; then
    emit_reason "absent"
    printf 'Unhealthy: expected container %s is absent.\n' "${container_name}" >&2
    exit 1
fi

state_status="$(
    docker inspect         --format '{{.State.Status}}'         "${container_name}" 2>/dev/null || true
)"

health_status="$(
    docker inspect         --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'         "${container_name}" 2>/dev/null || true
)"

if [[ -z "${state_status}" || -z "${health_status}" ]]; then
    emit_reason "malformed-state"
    printf 'Unable to evaluate health: unexpected Docker inspect response.\n' >&2
    exit 2
fi

if [[ "${state_status}" != "running" ]]; then
    emit_reason "stopped"
    printf 'Unhealthy: container %s is %s.\n' "${container_name}" "${state_status}" >&2
    exit 1
fi

case "${health_status}" in
    healthy)
        emit_reason "healthy"
        printf 'Healthy: container %s is running and healthy.\n' "${container_name}"
        exit 0
        ;;
    unhealthy)
        emit_reason "unhealthy"
        printf 'Unhealthy: container %s is running but unhealthy.\n' "${container_name}" >&2
        exit 1
        ;;
    starting)
        emit_reason "starting"
        printf 'Unable to evaluate health: container %s health is still starting.\n' "${container_name}" >&2
        exit 2
        ;;
    none)
        emit_reason "no-healthcheck"
        printf 'Unable to evaluate health: container %s has no Docker healthcheck.\n' "${container_name}" >&2
        exit 2
        ;;
    *)
        emit_reason "malformed-state"
        printf 'Unable to evaluate health: container %s reported unexpected health state %s.\n'             "${container_name}" "${health_status}" >&2
        exit 2
        ;;
esac
