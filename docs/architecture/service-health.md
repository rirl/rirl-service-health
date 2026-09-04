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
0 = observed and healthy
1 = observed and unhealthy or unavailable
2 = observation could not produce a definitive health judgment
```

The contract distinguishes **service failure** from **observation failure**.

Exit `0` means the observer successfully evaluated the service and the service satisfies its health contract.

Exit `1` means the observer successfully evaluated the service and the service does not satisfy its health contract. For an expected service, a conclusively observed stopped or absent service is therefore unhealthy/unavailable rather than unevaluable.

Exit `2` means the observer could not reliably determine whether the service satisfies its health contract. Examples include provider unavailability, insufficient permissions, missing required health instrumentation, malformed provider state, or a transitional condition for which no definitive health judgment exists.

For the first Docker-backed NGINX adapter:

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

Docker `starting` is treated as not yet definitively evaluable rather than unhealthy. This preserves the semantic distinction between a service that has failed its health contract and a service for which the health system has not yet rendered a final judgment.

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

The first adapter must preserve the generic contract boundary:

```text
generic framework
    knows: service identity, adapter selection, OBSERVE exit semantics

nginx adapter
    knows: Docker container identity, running state, Docker health state
```

The generic framework must not depend on nginx-specific health mechanics.

## Future services

A later HashiCorp Vault adapter may implement the same behavioral interface with different service-specific semantics. The framework should not assume that restart is always an appropriate recovery action.

A future Vault observer may need to distinguish states such as sealed, standby, active, and unavailable before mapping them into the generic OBSERVE contract. The generic contract should therefore remain intentionally small until a second real adapter demonstrates which additional distinctions are genuinely reusable.
