# NGINX RECOVER validation

## Scope

This validation covers the first concrete `RECOVER` implementation in
`rirl-service-health`, using the nginx Docker adapter.

The RECOVER contract is:

```text
0 = recovery action completed successfully; VERIFY must run next
1 = recovery action was attempted but failed
2 = recovery could not be attempted safely or definitively
```

RECOVER performs an allowed corrective action only. It does not determine
service health and does not claim recovery success merely because the action
command succeeded.

## Implementation under test

Commits:

```text
266f71c docs(sre): define recover contract and policy
c034226 feat(sre): add nginx recover adapter
```

Implementation:

```text
scripts/recover.bash
adapters/nginx/recover.bash
tests/recover.bats
tests/fixtures/bin/docker
tests/run.bash
```

## Mocked validation

The canonical Bats wrapper:

```text
tests/run.bash
```

executed both OBSERVE and RECOVER suites in `bats/bats:1.14.0`.

Result:

```text
1..19
ok 1 generic observer requires an adapter
ok 2 generic observer rejects unsupported adapter
ok 3 nginx observer reports healthy container
ok 4 nginx observer reports running unhealthy container
ok 5 nginx observer reports stopped container as unhealthy
ok 6 nginx observer reports absent expected container as unhealthy
ok 7 nginx observer reports starting as unevaluable
ok 8 nginx observer reports missing healthcheck as unevaluable
ok 9 nginx observer reports Docker unavailable as unevaluable
ok 10 generic recover requires an adapter
ok 11 generic recover rejects unsupported adapter
ok 12 nginx recover restarts running unhealthy container
ok 13 nginx recover restarts stopped container
ok 14 nginx recover refuses healthy container
ok 15 nginx recover refuses starting container
ok 16 nginx recover refuses container without healthcheck
ok 17 nginx recover reports absent container as not recoverable
ok 18 nginx recover reports Docker unavailable as not recoverable
ok 19 nginx recover reports restart failure
```

Result: PASS.

## Live validation

### Stopped container recovery

The real nginx validation consumer was explicitly stopped:

```text
rirl-tls-validation-nginx
```

RECOVER was then invoked against the stopped container.

RECOVER completed the restart action and returned exit `0`.

The recovery output explicitly required a subsequent VERIFY step rather than
claiming that the service was already healthy.

Result: PASS.

### Post-recovery observation

Immediately after recovery, OBSERVE was used as the temporary manual stand-in
for the future VERIFY operation.

While Docker health was still transitional, OBSERVE could return exit `2`
because the service had not yet reached a definitive health state.

After Docker health reached `healthy`, OBSERVE returned exit `0`.

Result: PASS.

## Contract separation

The live test confirms the intended semantic boundary:

```text
OBSERVE decides state.
RECOVER performs an allowed corrective action.
VERIFY proves the resulting service state.
```

RECOVER did not collapse action and verification into a single success result.

## Conclusion

The nginx RECOVER adapter satisfies the initial action contract in mocked and
live validation:

```text
recovery action completed                 -> 0
recovery action attempted but failed      -> 1
recovery cannot be attempted safely       -> 2
```

The implementation remains separate from VERIFY.

A dedicated VERIFY capability remains intentionally deferred to the next phase.
