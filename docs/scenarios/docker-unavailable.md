# Docker unavailable observation failure

## Purpose

Validate the hard-indeterminate path when the Docker provider cannot be reached.

The expected behavior is:

```text
OBSERVE -> exit 2 / reason=docker-unavailable
VERIFY  -> exit 2 immediately
```

VERIFY must not wait for its timeout when OBSERVE cannot continue definitively.

## Safety / blast radius

This scenario does not stop Docker and does not modify the real daemon.

Instead, the command invocation is pointed at a nonexistent Docker socket using
`DOCKER_HOST`.

The real validation container should remain healthy and unaffected throughout.

## Preconditions

- Docker is running normally.
- `rirl-tls-validation-nginx` exists and is healthy.
- The service-health scripts are available from the repository root.

## Procedure

```bash
container="rirl-tls-validation-nginx"
bad_socket="unix:///tmp/rirl-service-health-no-such-docker.sock"

bash ./scripts/observe.bash nginx "$container"
baseline_rc=$?
printf 'baseline observe exit=%s\n' "$baseline_rc"

DOCKER_HOST="$bad_socket" \
  bash ./scripts/observe.bash nginx "$container"
observe_rc=$?
printf 'observe exit=%s\n' "$observe_rc"

DOCKER_HOST="$bad_socket" \
  bash ./scripts/verify.bash nginx \
    --timeout 10 \
    --poll-interval 1 \
    "$container"
verify_rc=$?
printf 'verify exit=%s\n' "$verify_rc"

bash ./scripts/observe.bash nginx "$container"
final_rc=$?
printf 'final observe exit=%s\n' "$final_rc"
```

## Expected result

```text
baseline:
  reason=healthy
  exit=0

Docker unavailable:
  reason=docker-unavailable
  OBSERVE exit=2

VERIFY:
  exit=2 immediately

final:
  reason=healthy
  exit=0
```

## Live result

Validated on 2026-09-04.

Baseline:

```text
reason=healthy
Healthy: container rirl-tls-validation-nginx is running and healthy.
baseline observe exit=0
```

With `DOCKER_HOST` pointed at a nonexistent socket:

```text
reason=docker-unavailable
Unable to evaluate health: Docker is unavailable.
observe exit=2
```

VERIFY treated the condition as hard indeterminacy and returned immediately:

```text
Verification indeterminate: OBSERVE reason=docker-unavailable.
verify exit=2
```

The real Docker environment remained unaffected:

```text
reason=healthy
Healthy: container rirl-tls-validation-nginx is running and healthy.
final observe exit=0
```

## What this proves

The framework distinguishes between:

- a service that is conclusively unhealthy, and
- an observation provider that cannot produce a reliable judgment.

For Docker provider failure:

```text
OBSERVE -> 2 / docker-unavailable
VERIFY  -> 2 immediately
```

This prevents VERIFY from waiting for a timeout when it has no reliable
observation source.
