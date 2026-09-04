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

The initial policy boundary is:

```text
OBSERVE decides state.
RECOVER performs an allowed corrective action.
VERIFY proves the resulting service state.
```

RECOVER must never report a service as healthy merely because the recovery command itself succeeded.

For the first NGINX adapter, the likely recovery action is a controlled restart of the expected Docker container. Automatic execution remains deferred until the recovery policy and adapter behavior are implemented and validated.

RECOVER should only act when policy permits it. In particular, recovery must not be inferred from a transient or indeterminate observation such as Docker health `starting` or an inability to reach Docker.

## VERIFY contract

VERIFY is a future capability.

Its responsibility is to prove that a recovery operation restored the service's required health state. VERIFY must use the service's actual health contract rather than assuming success from the recovery command.

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
