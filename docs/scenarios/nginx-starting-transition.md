# NGINX starting-to-healthy transition

## Purpose

Reproduce and validate the transitional Docker health state used by the NGINX
VERIFY adapter.

The expected lifecycle is:

```text
RECOVER
  -> container restarts
  -> OBSERVE reports starting
  -> VERIFY waits
  -> container becomes healthy
  -> VERIFY succeeds
```

## Safety / blast radius

This scenario intentionally stops and restarts the validation container:

```text
rirl-tls-validation-nginx
```

It should only be run against the validation instance, not an unrelated
production service.

## Preconditions

- Docker is running.
- `rirl-tls-validation-nginx` exists.
- The service-health scripts are available from the repository root.

## Procedure

```bash
container="rirl-tls-validation-nginx"

docker stop "$container"

bash ./scripts/recover.bash nginx "$container"
recover_rc=$?
printf 'recover exit=%s\n' "$recover_rc"

bash ./scripts/observe.bash nginx "$container"
observe_immediate_rc=$?
printf 'observe-immediate exit=%s\n' "$observe_immediate_rc"

bash ./scripts/verify.bash nginx \
  --timeout 30 \
  --poll-interval 1 \
  "$container"
verify_rc=$?
printf 'verify exit=%s\n' "$verify_rc"

bash ./scripts/observe.bash nginx "$container"
observe_final_rc=$?
printf 'observe-final exit=%s\n' "$observe_final_rc"
```

## Expected result

A successful run should demonstrate:

```text
RECOVER
  exit=0

OBSERVE immediately after restart
  exit=2
  reason=starting

VERIFY
  waits while starting
  exit=0 once healthy

FINAL OBSERVE
  exit=0
  reason=healthy
```

## Live result

Validated on 2026-09-04:

```text
Recovery action completed: restarted container rirl-tls-validation-nginx. VERIFY is required.
recover exit=0

reason=starting
Unable to evaluate health: container rirl-tls-validation-nginx health is still starting.
observe-immediate exit=2

Verification succeeded: container rirl-tls-validation-nginx is healthy.
verify exit=0

reason=healthy
Healthy: container rirl-tls-validation-nginx is running and healthy.
observe-final exit=0
```

## What this proves

The machine-readable OBSERVE reason contract is sufficient for VERIFY to
distinguish a transitional `starting` condition from hard indeterminacy.

VERIFY does not fail immediately on `starting`; it continues polling until the
service reaches the required healthy state or the verification deadline expires.
