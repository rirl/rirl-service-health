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

RECOVER is a service-specific, policy-controlled action.

It is invoked only when policy permits a corrective action after a definitive unhealthy or unavailable observation. RECOVER does not classify service health and does not prove that the resulting service state is healthy.

Initial exit contract:

```text
0 = recovery action completed successfully; VERIFY must run next
1 = recovery action was attempted but failed
2 = recovery could not be attempted safely or definitively
```

The semantic boundary is:

```text
OBSERVE decides state.
RECOVER performs an allowed corrective action.
VERIFY proves the resulting service state.
```

A successful recovery command is not proof of service recovery. For example, a successful `docker restart` means only that Docker accepted and completed the restart operation; it does not prove that the service subsequently became healthy.

RECOVER must therefore never collapse action and verification into one result.

#### Recovery policy

The first recovery policy should remain conservative:

- act only on a definitive unhealthy or unavailable condition;
- do not act when observation is indeterminate;
- do not infer recovery permission from Docker health `starting`;
- do not act when Docker itself is unavailable or health cannot be evaluated;
- preserve explicit operator intent where the adapter can distinguish it;
- leave service-specific safety rules inside the adapter.

For NGINX, the first likely recovery action is a controlled restart of the expected Docker container.

This does not imply that restart is the generic recovery action. A future Vault adapter may need to distinguish sealed, standby, active, and unavailable states and may deliberately refuse automated recovery for some conditions.

Automatic RECOVER execution is intentionally deferred until the adapter contract, safety policy, tests, and live validation are in place.

### VERIFY

VERIFY is a future capability.

It proves that a recovery operation restored the required service state.

VERIFY must use the service's actual health contract rather than treating recovery-command success as sufficient evidence.

For a Docker-backed NGINX adapter, VERIFY will likely require observing that the expected container is running and that Docker health has reached `healthy` after recovery. Exact timeout and retry policy should be defined when VERIFY is implemented rather than inferred prematurely.

## NGINX as the first adapter

The existing nginx validation service already demonstrates:

- Docker health can transition from `healthy` to `unhealthy` while PID 1 remains running.
- Docker `restart = "unless-stopped"` recovers process/container exit but does not remediate a running-but-unhealthy container.
- Explicit operator stop is preserved.
- Docker daemon restart and host reboot restore the container.

The first nginx adapter observes Docker health state externally.

The first RECOVER implementation will likely perform a controlled restart when policy permits it, but recovery must remain separate from both OBSERVE and VERIFY.

The adapter boundary remains:

```text
generic framework
    knows: service identity, adapter selection, behavioral exit contracts

nginx adapter
    knows: Docker container identity, running state, Docker health state,
           and nginx-specific recovery mechanics
```

The generic framework must not depend on nginx-specific health or restart behavior.

## Future services

A later HashiCorp Vault adapter may implement the same behavioral interface with different service-specific semantics.

A future Vault observer may need to distinguish states such as sealed, standby, active, and unavailable before mapping them into the generic OBSERVE contract.

Likewise, a future Vault RECOVER implementation may refuse automated action for some states or require a completely different corrective operation.

The generic contract should therefore remain intentionally small until a second real adapter demonstrates which additional distinctions are genuinely reusable.
