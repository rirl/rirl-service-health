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

## Current phase

The first implementation phase is **OBSERVE only**.

Initial observer contract:

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

No automatic restart or other remediation is included in the initial phase.

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
