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

The contract distinguishes service failure from observation failure.

Exit `0` means the observer successfully evaluated the service and the service satisfies its health contract.

Exit `1` means the observer successfully evaluated the service and the service does not satisfy its health contract.

Exit `2` means the observer could not reliably determine whether the service satisfies its health contract.

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

Docker `starting` is treated as not yet definitively evaluable rather than unhealthy.

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

A successful recovery command is not proof of service recovery.

For NGINX, the first recovery action is a controlled restart of the expected Docker container when policy permits it.

### VERIFY

VERIFY is a read-only proof operation over the post-recovery service state.

It does not restart, reload, reconcile, or perform any recovery action itself.

Initial exit contract:

```text
0 = required service health was proven
1 = service was observed but did not reach required health
2 = verification could not be completed definitively
```

The first VERIFY implementation should repeatedly evaluate the service through the existing OBSERVE contract rather than duplicating nginx/Docker health interpretation.

That gives VERIFY the following state machine:

```text
OBSERVE = 0
    -> VERIFY succeeds immediately

OBSERVE = 1
    -> service is definitively unhealthy/unavailable
    -> continue polling while verification time remains

OBSERVE = 2
    -> if the result is a known transitional state, continue polling
    -> if observation cannot continue definitively, VERIFY exits 2

verification deadline expires
    -> VERIFY exits 1
```

This preserves the distinction between:

```text
health not yet proven
```

and:

```text
health cannot be evaluated
```

A timeout means the service never reached the required healthy state within the verification window. That is a failed health proof and therefore exit `1`, not exit `2`.

#### Verification policy

VERIFY should have explicit policy inputs:

- total verification timeout;
- polling interval.

Defaults should be conservative and deterministic.

The defaults should not be derived implicitly from Docker healthcheck timing, because future adapters may use entirely different health mechanisms.

VERIFY should tolerate transitional states long enough for a recovery action to take effect, but it must not wait indefinitely.

#### NGINX behavior

For the first Docker-backed NGINX adapter, successful verification means:

```text
expected container exists
container state = running
Docker health = healthy
```

A stopped, absent, or persistently unhealthy container cannot satisfy VERIFY.

Docker health `starting` is transitional and may be retried while the verification deadline remains open.

If Docker itself becomes unavailable, permissions prevent inspection, required health instrumentation disappears, or provider state becomes malformed, verification cannot continue definitively and should exit `2`.

VERIFY must not invoke RECOVER.

### Composition

The intended orchestration model is:

```text
OBSERVE
    |
    | healthy
    +------------------------------> success
    |
    | unhealthy/unavailable
    v
RECOVER
    |
    | action completed
    v
VERIFY
    |
    +--> health proven              -> success
    |
    +--> deadline expired           -> failed recovery proof
    |
    +--> observation unavailable    -> indeterminate verification
```

The framework should preserve the contracts of the individual operations even when they are later composed by a higher-level supervisor.

## NGINX as the first adapter

The existing nginx validation service already demonstrates:

- Docker health can transition from `healthy` to `unhealthy` while PID 1 remains running.
- Docker `restart = "unless-stopped"` recovers process/container exit but does not remediate a running-but-unhealthy container.
- Explicit operator stop is preserved.
- Docker daemon restart and host reboot restore the container.

The nginx adapter now provides OBSERVE and RECOVER operations.

The next adapter capability is VERIFY, implemented by polling the established observation contract until health is proven or the verification policy terminates the attempt.

The adapter boundary remains:

```text
generic framework
    knows: service identity, adapter selection, behavioral exit contracts,
           verification timing policy

nginx adapter
    knows: Docker container identity, running state, Docker health state,
           and nginx-specific recovery mechanics
```

The generic framework must not depend on nginx-specific health or restart behavior.

## Future services

A later HashiCorp Vault adapter may implement the same behavioral interface with different service-specific semantics.

A Vault VERIFY implementation might need to prove an allowed state such as active or standby rather than simply mapping a Docker health value to healthy.

The generic VERIFY contract should therefore remain focused on proof semantics and timing rather than hard-coding Docker or nginx concepts.
