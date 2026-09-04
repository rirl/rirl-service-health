#!/usr/bin/env bash
set -Eeuo pipefail

readonly PROGRAM_NAME="${0##*/}"
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<EOF
Usage: ${PROGRAM_NAME} <adapter> [adapter arguments...]

Adapters:
  nginx
EOF
}

if [[ $# -lt 1 ]]; then
    usage >&2
    exit 2
fi

adapter="$1"
shift

case "${adapter}" in
    nginx)
        exec "${ROOT_DIR}/adapters/nginx/recover.bash" "$@"
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        printf 'Unsupported adapter: %s\n' "${adapter}" >&2
        usage >&2
        exit 2
        ;;
esac
