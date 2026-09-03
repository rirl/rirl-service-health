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
0 = service exists, is running, and is healthy
1 = service exists and is unhealthy
2 = health cannot be evaluated
```

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
