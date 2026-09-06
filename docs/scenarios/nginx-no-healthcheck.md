# NGINX container without Docker healthcheck

## Purpose

Validate the hard-indeterminate path when a running container has no Docker
healthcheck.

The expected behavior is:

```text
OBSERVE -> exit 2 / reason=no-healthcheck
RECOVER -> exit 2
VERIFY  -> exit 2 immediately
```

A running process is not sufficient evidence of service health for this
adapter; the required Docker health instrumentation must exist.

## Safety / blast radius

This scenario uses a disposable `nginx:alpine` container named:

```text
rirl-service-health-no-healthcheck
```

The real validation container is not modified.

## Preconditions

- Docker is running.
- The `nginx:alpine` image is available or can be pulled.
- The service-health scripts are available from the repository root.

## Procedure

```bash
test_container="rirl-service-health-no-healthcheck"

docker rm -f "$test_container" >/dev/null 2>&1 || true

docker run -d \
  --name "$test_container" \
  nginx:alpine

docker inspect \
  --format 'status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
  "$test_container"

bash ./scripts/observe.bash nginx "$test_container"
observe_rc=$?
printf 'observe exit=%s\n' "$observe_rc"

bash ./scripts/recover.bash nginx "$test_container"
recover_rc=$?
printf 'recover exit=%s\n' "$recover_rc"

bash ./scripts/verify.bash nginx \
  --timeout 10 \
  --poll-interval 1 \
  "$test_container"
verify_rc=$?
printf 'verify exit=%s\n' "$verify_rc"

docker rm -f "$test_container"

bash ./scripts/observe.bash nginx rirl-tls-validation-nginx
real_rc=$?
printf 'real container observe exit=%s\n' "$real_rc"
```

## Expected result

```text
status=running health=none

OBSERVE:
  reason=no-healthcheck
  exit=2

RECOVER:
  exit=2

VERIFY:
  exit=2 immediately

real validation container:
  reason=healthy
  exit=0
```

## Live result

Validated on 2026-09-04.

The disposable container was running without Docker health instrumentation:

```text
status=running health=none
```

OBSERVE returned a hard-indeterminate result:

```text
reason=no-healthcheck
Unable to evaluate health: container rirl-service-health-no-healthcheck has no Docker healthcheck.
observe exit=2
```

RECOVER refused to act:

```text
Unable to recover: container rirl-service-health-no-healthcheck has no Docker healthcheck.
recover exit=2
```

VERIFY returned immediately rather than waiting for the verification deadline:

```text
Verification indeterminate: OBSERVE reason=no-healthcheck.
verify exit=2
```

The disposable container was removed, and the real validation container remained
healthy:

```text
reason=healthy
Healthy: container rirl-tls-validation-nginx is running and healthy.
real container observe exit=0
```

## What this proves

The adapter requires explicit health instrumentation before it can make or prove
a health judgment.

```text
running without healthcheck
  -> OBSERVE 2 / no-healthcheck
  -> RECOVER 2
  -> VERIFY 2
```

This prevents the framework from treating process liveness alone as evidence of
service readiness or health.
