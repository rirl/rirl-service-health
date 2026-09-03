# Service health architecture

## Purpose

`rirl-service-health` provides a small reliability interface for service availability. It is intended to support multiple services while allowing each service to own the details of health observation and recovery.

## Separation of concerns

Two orthogonal reliability concerns are deliberately kept separate:

```text
Certificate correctness
    RECONCILE

Service availability
    OBSERVE -> RECOVER -> VERIFY
```

`RECONCILE` answers whether a TLS consumer is serving the currently authoritative certificate and, when necessary, converges that state.

The service-health interface answers whether a service is available and healthy, whether availability recovery should be attempted, and whether recovery succeeded.

## Behavioral contracts

### OBSERVE

Read-only. It must not restart, reload, reconcile, or otherwise mutate the target service.

Initial exit contract:

```text
0 = healthy
1 = unhealthy
2 = unable to evaluate health
```

### RECOVER

Future capability. Service-specific and policy-controlled. Recovery must not be inferred from a single transient health failure unless policy explicitly permits it.

Examples may include controlled restart, but some services may require different handling. A Vault implementation, for example, may need to distinguish sealed, standby, active, and unavailable states before selecting a recovery action.

### VERIFY

Future capability. Proves that a recovery operation restored the required service state. Verification must use the service's actual health contract rather than assuming an action succeeded because a command returned success.

## NGINX as the first adapter

The existing nginx validation service already demonstrates:

- Docker health can transition from `healthy` to `unhealthy` while PID 1 remains running.
- Docker `restart = "unless-stopped"` recovers process/container exit but does not remediate a running-but-unhealthy container.
- Explicit operator stop is preserved.
- Docker daemon restart and host reboot restore the container.

The first nginx adapter should therefore observe Docker health state externally. Automatic remediation is intentionally deferred until observation behavior is implemented and validated.

## Future services

A later HashiCorp Vault adapter may implement the same behavioral interface with different service-specific semantics. The framework should not assume that restart is always an appropriate recovery action.
