# Expected container absent

## Purpose

Validate the semantic boundary for an expected service container that is
definitively absent.

The expected behavior is:

```text
OBSERVE -> exit 1 / reason=absent
RECOVER -> exit 2
VERIFY  -> timeout / exit 1
```

Absence is a conclusive availability failure, but the NGINX adapter does not
treat container creation as a safe recovery action.

## Safety / blast radius

This scenario does not remove or modify the real validation container.

It uses an intentionally nonexistent container name:

```text
rirl-service-health-intentionally-absent
```

The real `rirl-tls-validation-nginx` container should remain healthy and
unaffected.

## Preconditions

- Docker is running.
- The intentionally absent container name does not exist.
- The service-health scripts are available from the repository root.

## Procedure

```bash
missing_container="rirl-service-health-intentionally-absent"

docker inspect "$missing_container" >/dev/null 2>&1
docker_inspect_rc=$?
printf 'docker inspect exit=%s\n' "$docker_inspect_rc"

bash ./scripts/observe.bash nginx "$missing_container"
observe_rc=$?
printf 'observe exit=%s\n' "$observe_rc"

bash ./scripts/recover.bash nginx "$missing_container"
recover_rc=$?
printf 'recover exit=%s\n' "$recover_rc"

bash ./scripts/verify.bash nginx \
  --timeout 3 \
  --poll-interval 1 \
  "$missing_container"
verify_rc=$?
printf 'verify exit=%s\n' "$verify_rc"

bash ./scripts/observe.bash nginx rirl-tls-validation-nginx
real_rc=$?
printf 'real container observe exit=%s\n' "$real_rc"
```

## Expected result

```text
docker inspect:
  nonzero

OBSERVE:
  reason=absent
  exit=1

RECOVER:
  refuses because the expected container is absent
  exit=2

VERIFY:
  retries during the verification window
  times out
  exit=1
  last reason=absent

real validation container:
  reason=healthy
  exit=0
```

## Live result

Validated on 2026-09-04.

The intentionally named test container was confirmed absent:

```text
docker inspect exit=1
```

OBSERVE reported a conclusive availability failure:

```text
reason=absent
Unhealthy: expected container rirl-service-health-intentionally-absent is absent.
observe exit=1
```

RECOVER refused to act because there was no container to restart:

```text
Unable to recover: expected container rirl-service-health-intentionally-absent is absent.
recover exit=2
```

VERIFY continued to treat absence as an unhealthy service state, then timed out:

```text
Verification failed: container rirl-service-health-intentionally-absent did not become healthy before timeout; last reason=absent.
verify exit=1
```

The real validation container remained unaffected:

```text
reason=healthy
Healthy: container rirl-tls-validation-nginx is running and healthy.
real container observe exit=0
```

## What this proves

The framework preserves three distinct semantics:

```text
absence
  -> definitive availability failure
  -> OBSERVE 1

absence
  -> not safely recoverable by this adapter
  -> RECOVER 2

persistent absence
  -> service did not reach required health
  -> VERIFY 1
```

This distinction prevents the NGINX adapter from silently broadening recovery
policy from "restart an existing container" into "create missing infrastructure."
