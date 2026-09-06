# NGINX OBSERVE validation

## Scope

This validation covers the first concrete `OBSERVE` implementation in
`rirl-service-health`, using the nginx Docker adapter.

The OBSERVE contract is:

```text
0 = observed and healthy
1 = observed and unhealthy or unavailable
2 = observation could not produce a definitive health judgment
```

OBSERVE is read-only and does not restart, reload, reconcile, or otherwise
mutate the target service.

## Implementation under test

Commit:

```text
a95f014 feat(sre): add nginx observe adapter
```

Implementation:

```text
scripts/observe.bash
adapters/nginx/observe.bash
tests/observe.bats
tests/fixtures/bin/docker
tests/run.bash
```

## Mocked validation

The canonical Bats wrapper:

```text
tests/run.bash
```

executed the suite in `bats/bats:1.14.0`.

Result:

```text
1..9
ok 1 generic observer requires an adapter
ok 2 generic observer rejects unsupported adapter
ok 3 nginx observer reports healthy container
ok 4 nginx observer reports running unhealthy container
ok 5 nginx observer reports stopped container as unhealthy
ok 6 nginx observer reports absent expected container as unhealthy
ok 7 nginx observer reports starting as unevaluable
ok 8 nginx observer reports missing healthcheck as unevaluable
ok 9 nginx observer reports Docker unavailable as unevaluable
```

Result: PASS.

## Live validation

### Healthy container

The real nginx validation consumer was running and healthy:

```text
rirl-tls-validation-nginx
```

OBSERVE returned:

```text
Healthy: container rirl-tls-validation-nginx is running and healthy.
observe exit=0
```

Result: PASS.

### Stopped container

The container was explicitly stopped.

OBSERVE returned exit `1`, classifying the expected-but-stopped service as
unhealthy/unavailable.

The container was then manually started and allowed to return healthy.

OBSERVE subsequently returned exit `0`.

Result: PASS.

### Docker unavailable

Docker unavailability was simulated for a single OBSERVE invocation by setting
`DOCKER_HOST` to a nonexistent Unix socket.

OBSERVE returned:

```text
Unable to evaluate health: Docker is unavailable.
observe exit=2
```

The real Docker daemon and nginx validation container were not modified by this
test.

Result: PASS.

## Conclusion

The nginx adapter satisfies the initial OBSERVE contract in both mocked and live
validation:

```text
healthy                     -> 0
unhealthy or unavailable    -> 1
unable to evaluate          -> 2
```

The implementation remains read-only and does not introduce recovery behavior.

RECOVER and VERIFY remain intentionally deferred.
