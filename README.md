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

OBSERVE has two machine-consumable outputs:

1. an exit code describing the broad health class;
2. a stable reason token describing the specific observation result.

Exit contract:

```text
0 = observed and healthy
1 = observed and unhealthy or unavailable
2 = observation could not produce a definitive health judgment
```

Reason tokens:

```text
healthy
unhealthy
stopped
absent
starting
docker-unavailable
no-healthcheck
malformed-state
```

The reason token is emitted in the form:

```text
reason=<token>
```

Human-readable text remains advisory. Consumers must use the exit code and reason token rather than parse prose.

For the first Docker-backed NGINX adapter:

```text
running + healthy       -> exit 0, reason=healthy
running + unhealthy     -> exit 1, reason=unhealthy
stopped                 -> exit 1, reason=stopped
expected container absent
                        -> exit 1, reason=absent

Docker unavailable      -> exit 2, reason=docker-unavailable
Docker health starting  -> exit 2, reason=starting
no required healthcheck -> exit 2, reason=no-healthcheck
unexpected provider state
                        -> exit 2, reason=malformed-state
```

This refinement allows VERIFY to distinguish transitional state from hard indeterminacy without duplicating service-specific health logic.

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

## VERIFY contract

VERIFY is read-only with respect to recovery actions. It does not restart, reload, or otherwise mutate the target service.

Its purpose is to prove that the service reached the required healthy state after recovery.

Initial exit contract:

```text
0 = required service health was proven
1 = service was observed but did not reach required health
2 = verification could not be completed definitively
```

VERIFY should reuse OBSERVE's machine-readable exit code and reason token:

```text
OBSERVE 0 / reason=healthy
    -> VERIFY succeeds

OBSERVE 1
    -> retry while verification time remains
    -> timeout -> VERIFY 1

OBSERVE 2 / reason=starting
    -> transitional; retry while verification time remains

OBSERVE 2 / any hard-indeterminate reason
    -> VERIFY 2
```

Human-readable OBSERVE text must not be parsed by VERIFY.

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
