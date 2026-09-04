# NGINX VERIFY live validation

Date: 2026-09-04

## Purpose

Validate the NGINX `VERIFY` adapter against the real
`rirl-tls-validation-nginx` container and prove the complete service-health
lifecycle:

```text
OBSERVE -> RECOVER -> VERIFY
```

This validation is separate from the mocked Bats test suite.

## Automated test baseline

The canonical containerized Bats suite passed:

```text
1..32
32/32 passed
```

Coverage included:

- OBSERVE healthy, unhealthy, stopped, absent, starting, missing healthcheck,
  Docker unavailable, and malformed state
- RECOVER permitted and refused recovery paths
- VERIFY immediate healthy success
- VERIFY unhealthy -> healthy
- VERIFY starting -> healthy
- persistent unhealthy timeout
- persistent starting timeout
- Docker unavailable
- missing healthcheck
- malformed observation
- invalid timeout
- zero poll interval rejection
- missing OBSERVE reason token

## Live steady-state VERIFY

Command:

```bash
bash ./scripts/verify.bash nginx \
  --timeout 10 \
  --poll-interval 1 \
  rirl-tls-validation-nginx
```

Observed result:

```text
Verification succeeded: container rirl-tls-validation-nginx is healthy.
verify exit=0
```

OBSERVE cross-check:

```text
reason=healthy
Healthy: container rirl-tls-validation-nginx is running and healthy.
observe exit=0
```

Result: PASS.

## Live OBSERVE -> RECOVER -> VERIFY

The validation container was explicitly stopped:

```bash
docker stop rirl-tls-validation-nginx
```

OBSERVE correctly classified the stopped service:

```text
reason=stopped
Unhealthy: container rirl-tls-validation-nginx is exited.
observe-before exit=1
```

RECOVER performed the allowed corrective action:

```text
Recovery action completed: restarted container rirl-tls-validation-nginx. VERIFY is required.
recover exit=0
```

VERIFY then proved required service health:

```text
Verification succeeded: container rirl-tls-validation-nginx is healthy.
verify exit=0
```

Final OBSERVE cross-check:

```text
reason=healthy
Healthy: container rirl-tls-validation-nginx is running and healthy.
observe-after exit=0
```

Final Docker state:

```text
status=running health=healthy restart-count=0
```

Result: PASS.

## Interpretation

The live validation proves the intended behavioral boundary:

```text
OBSERVE
  determines service health

RECOVER
  performs the allowed corrective action
  but does not claim success of service health

VERIFY
  independently proves that the required healthy state was reached
```

The NGINX adapter successfully recovered a definitively stopped service and
VERIFY independently established post-recovery health.

The Docker `RestartCount` value remained `0` because the test used an explicit
operator stop followed by an explicit `docker restart`; this counter is not a
count of every manual restart.

## Conclusion

The first real service adapter now demonstrates the complete framework
lifecycle:

```text
OBSERVE -> RECOVER -> VERIFY
```

The implementation is backed by both mocked automated tests and live validation
against the real NGINX validation container.
