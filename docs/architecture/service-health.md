# Service health architecture

## Purpose

`rirl-service-health` provides a small reliability interface for service availability. It is intended to support multiple services while allowing each service to own the details of health observation and recovery.

## Separation of concerns

```text
Certificate correctness
    RECONCILE

Service availability
    OBSERVE -> RECOVER -> VERIFY
```

## Behavioral contracts

### OBSERVE

OBSERVE is read-only.

Its machine-readable contract consists of an exit code plus a stable reason token.

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

The stable output form is:

```text
reason=<token>
```

Human-readable messages are not part of the machine interface.

For the first Docker-backed NGINX adapter:

```text
running + healthy       -> 0 / healthy
running + unhealthy     -> 1 / unhealthy
stopped                 -> 1 / stopped
expected container absent
                        -> 1 / absent
Docker unavailable      -> 2 / docker-unavailable
Docker health starting  -> 2 / starting
no required healthcheck -> 2 / no-healthcheck
unexpected provider state
                        -> 2 / malformed-state
```

This refinement is required so higher-level orchestration can distinguish a transitional state such as `starting` from a hard observation failure such as `docker-unavailable`.

### RECOVER

RECOVER remains action-only:

```text
0 = recovery action completed successfully; VERIFY must run next
1 = recovery action was attempted but failed
2 = recovery could not be attempted safely or definitively
```

RECOVER must not claim health.

### VERIFY

VERIFY is a read-only proof operation over post-recovery state.

Exit contract:

```text
0 = required service health was proven
1 = service was observed but did not reach required health
2 = verification could not be completed definitively
```

VERIFY must reuse OBSERVE's machine interface rather than duplicate adapter-specific health interpretation.

State handling:

```text
OBSERVE exit 0 / reason=healthy
    -> VERIFY 0

OBSERVE exit 1
    -> retry until deadline
    -> deadline -> VERIFY 1

OBSERVE exit 2 / reason=starting
    -> retry until deadline

OBSERVE exit 2 / reason in:
    docker-unavailable
    no-healthcheck
    malformed-state
    -> VERIFY 2
```

The human-readable OBSERVE message must never be parsed by VERIFY.

### Composition

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
    +--> deadline expired           -> failed recovery proof
    +--> hard observation failure   -> indeterminate verification
```

## NGINX as the first adapter

The NGINX adapter owns Docker/container-specific interpretation.

The generic framework owns only the behavioral contracts, reason-token semantics, and verification timing policy.

## Future services

A later Vault adapter may emit different service-specific internal states but should map them into the generic OBSERVE exit classes and a stable reason vocabulary appropriate to the framework.

The reason vocabulary may grow only when a second real adapter demonstrates a genuinely reusable distinction.
