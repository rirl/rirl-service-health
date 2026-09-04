# rirl-service-health

A small, service-agnostic reliability framework for observing, recovering, and verifying service availability.

The repository is intentionally separate from service-specific implementations such as `rirl-tls-nginx-validation`.
NGINX is the first concrete service adapter; future services such as HashiCorp Vault may implement analogous contracts.

## Reliability interface

```text
OBSERVE -> RECOVER -> VERIFY
```

- **OBSERVE** classifies current service health without changing the service.
- **RECOVER** performs a service-specific corrective action when policy permits it.
- **VERIFY** proves that recovery restored the required service state.

Certificate correctness remains a separate concern. For TLS consumers, `RECONCILE` belongs to the certificate lifecycle and must not be conflated with service-health recovery.

## OBSERVE contract

```text
0 = observed and healthy
1 = observed and unhealthy or unavailable
2 = observation could not produce a definitive health judgment
```

The distinction is intentional:

- exit `0` means observation completed and the service satisfies its health contract;
- exit `1` means observation completed and the service does not satisfy its health contract;
- exit `2` means the observer could not reliably determine whether the service satisfies its health contract.

For the first Docker-backed NGINX adapter, examples include:

```text
container exists + running + healthy      -> 0

container exists + running + unhealthy    -> 1
container exists + stopped                -> 1
expected container absent                 -> 1

Docker unavailable                        -> 2
permission denied                         -> 2
required healthcheck absent               -> 2
Docker health = starting                  -> 2
unexpected or malformed provider state    -> 2
```

A stopped or absent expected service is an availability failure, not an observation failure, when the observer can determine that state conclusively.

A transitional health state such as Docker `starting` is not classified as unhealthy because Docker has not yet produced a definitive health judgment.

## RECOVER contract

RECOVER is service-specific and policy-controlled.

Its purpose is to perform an allowed corrective action after a definitive unhealthy or unavailable observation. RECOVER does not determine service health and does not prove that recovery restored health.

Initial exit contract:

```text
0 = recovery action completed successfully; VERIFY must run next
1 = recovery action was attempted but failed
2 = recovery could not be attempted safely or definitively
```

The policy boundary is:

```text
OBSERVE decides state.
RECOVER performs an allowed corrective action.
VERIFY proves the resulting service state.
```

RECOVER must never report a service as healthy merely because the recovery command itself succeeded.

For the first NGINX adapter, the likely recovery action is a controlled restart of the expected Docker container.

## VERIFY contract

VERIFY is read-only with respect to recovery actions. It does not restart, reload, or otherwise mutate the target service.

Its purpose is to prove that the service reached the required healthy state after recovery.

Initial exit contract:

```text
0 = required service health was proven
1 = service was observed but did not reach required health
2 = verification could not be completed definitively
```

The first NGINX VERIFY implementation should:

- poll the service's OBSERVE result;
- succeed only when the expected container is running and Docker health is `healthy`;
- tolerate transitional observation results such as Docker health `starting` while the verification window remains open;
- return exit `1` when the verification timeout expires without proving health;
- return exit `2` when verification cannot continue definitively because observation itself fails in a non-transitional way, such as Docker becoming unavailable;
- never invoke RECOVER itself.

VERIFY must distinguish between:

```text
not healthy yet
```

and:

```text
cannot determine health
```

A timeout is therefore a failed health proof, not an observation error.

Timeout and polling interval are policy inputs to VERIFY and should have explicit defaults rather than depending on shell timing or Docker's internal healthcheck cadence implicitly.

## Layout

```text
adapters/        service-specific implementations
  nginx/         first concrete adapter
scripts/         framework entry points
systemd/user/    optional host-side scheduling/observation units
tests/           automated tests
docs/architecture/
```

## Design principle

Keep the behavioral contract generic and the operational mechanics service-specific. Do not extract additional abstractions until at least a second real service implementation demonstrates what is genuinely common.
