# NGINX persistent-unhealthy condition

## Purpose

Reproduce a durable Docker `unhealthy` state while the NGINX container remains
running, then validate:

```text
OBSERVE -> exit 1 / reason=unhealthy
VERIFY  -> timeout / exit 1
```

This proves that VERIFY distinguishes a service that is conclusively unhealthy
from an observation failure.

## Safety / blast radius

This scenario temporarily changes the validation container's NGINX `/healthz`
location to return HTTP 503.

The original configuration is copied to the host before modification and is
restored before the scenario completes.

Run this only against:

```text
rirl-tls-validation-nginx
```

## Preconditions

- Docker is running.
- `rirl-tls-validation-nginx` exists and is currently healthy.
- The healthcheck is configured to probe `https://127.0.0.1/healthz`.
- The service-health scripts are available from the repository root.

## Fault injection

```bash
container="rirl-tls-validation-nginx"
backup="$(mktemp /tmp/rirl-nginx-default.conf.XXXXXX)"

docker cp   "$container:/etc/nginx/conf.d/default.conf"   "$backup"

docker exec "$container" sh -c '
  cp /etc/nginx/conf.d/default.conf /tmp/default.conf.original

  awk "
    BEGIN { replacing=0 }

    /location[[:space:]]*=[[:space:]]*\/healthz[[:space:]]*\{/ {
        print \"    location = /healthz {\"
        print \"        return 503;\"
        print \"    }\"
        replacing=1
        next
    }

    replacing && /^[[:space:]]*}/ {
        replacing=0
        next
    }

    !replacing { print }
  " /tmp/default.conf.original > /etc/nginx/conf.d/default.conf
'

docker exec "$container" nginx -t
docker exec "$container" nginx -s reload
```

## Wait for Docker to classify the container unhealthy

The validation healthcheck runs every 30 seconds with 3 retries, so allow enough
time for Docker to accumulate failures:

```bash
for i in $(seq 1 15); do
    state="$(
      docker inspect         --format 'status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'         "$container"
    )"

    printf '%s\n' "$state"

    health="$(
      docker inspect         --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'         "$container"
    )"

    [[ "$health" == "unhealthy" ]] && break
    sleep 10
done
```

## Validate OBSERVE and VERIFY

```bash
bash ./scripts/observe.bash nginx "$container"
observe_rc=$?
printf 'observe exit=%s\n' "$observe_rc"

bash ./scripts/verify.bash nginx   --timeout 5   --poll-interval 1   "$container"
verify_rc=$?
printf 'verify exit=%s\n' "$verify_rc"
```

Expected result:

```text
status=running health=unhealthy

reason=unhealthy
observe exit=1

Verification failed: ... last reason=unhealthy
verify exit=1
```

## Restore

```bash
docker cp   "$backup"   "$container:/etc/nginx/conf.d/default.conf"

docker exec "$container" nginx -t
docker exec "$container" nginx -s reload

for i in $(seq 1 15); do
    state="$(
      docker inspect         --format 'status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'         "$container"
    )"

    printf '%s\n' "$state"

    health="$(
      docker inspect         --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'         "$container"
    )"

    [[ "$health" == "healthy" ]] && break
    sleep 10
done

bash ./scripts/observe.bash nginx "$container"

rm -f "$backup"
```

## Live result

Validated on 2026-09-04.

Docker remained running while its health state transitioned to unhealthy:

```text
status=running health=unhealthy
```

OBSERVE correctly classified the service:

```text
reason=unhealthy
Unhealthy: container rirl-tls-validation-nginx is running but unhealthy.
observe exit=1
```

VERIFY timed out because the unhealthy condition persisted:

```text
Verification failed: container rirl-tls-validation-nginx did not become healthy before timeout; last reason=unhealthy.
verify exit=1
```

After restoring the original NGINX configuration and reloading:

```text
status=running health=healthy

reason=healthy
Healthy: container rirl-tls-validation-nginx is running and healthy.
final observe exit=0
```

Docker healthcheck history confirmed the injected failure:

```text
exit=1
HTTP/1.1 503 Service Temporarily Unavailable

exit=1
HTTP/1.1 503 Service Temporarily Unavailable

exit=0
exit=0
exit=0
```

## Note about the immediate manual probe

An immediate manual request issued directly after `nginx -s reload` returned
HTTP 200 even though later Docker healthchecks returned HTTP 503 and the
container became unhealthy.

Do not use the immediate probe as the success criterion for this scenario.
The authoritative fault evidence is the Docker healthcheck history and Docker's
resulting `unhealthy` state.

## What this proves

A running container can be definitively unhealthy without being stopped.

For that condition:

```text
OBSERVE -> 1 / unhealthy
VERIFY  -> retry until deadline
VERIFY  -> 1 when health is not restored
```

The adapter therefore preserves the distinction between:

- unhealthy service state (`1`), and
- indeterminate observation failure (`2`).
