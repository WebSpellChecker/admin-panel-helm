# Admin-panel operator guide

This guide explains how the chart behaves after the first install: which dependencies
it owns, how traffic reaches it, where state lives, and how to upgrade or troubleshoot
it safely.

If you have not deployed it yet, follow the [quick start](QUICKSTART.md). For a specific
application setting, use the [environment-variable contract](ENVIRONMENT_VARIABLES.md).

## Architecture and ownership

One image runs as three Deployments and one Helm hook:

| Component | Responsibility | Scaling |
| --- | --- | --- |
| Web | nginx and PHP-FPM | fixed replicas or HPA |
| Worker | Laravel database queue | fixed replicas |
| Scheduler | Laravel scheduler | exactly one replica |
| Migration | waits for MySQL, then migrates Admin-panel's database | one `pre-install,pre-upgrade` hook Job |

Only the web Pods and the migration Job run the image entrypoint. The worker and the
scheduler start with `SKIP_ENTRYPOINT_CONFIG=true`, run `php artisan queue:work` and
`php artisan schedule:work` directly, and are watched by a `pgrep` liveness probe. This is
the same layout as the `examples/admin-panel` Compose stack in wproofreader-docker and
the Cloud Swarm stack, and it needs Admin-panel `3.0.0` or newer.

The chart owns Admin-panel workloads, Service, configuration, and optionally routing and
an uploads PVC. It does not install MySQL, provision the WProofreader database, install
WProofreader, or create a production certificate issuer.

That boundary matters during incidents:

- Admin-panel migration errors belong to the primary Admin-panel database.
- Missing `cloud_service` tables or grants belong to WProofreader `db-manager`.
- `/wscservice` routing and AppServer health involve the WProofreader release.
- Certificate issuance involves cert-manager and the configured Issuer.

## Dependency order

Bring a complete stack up in this order, waiting for each layer to become healthy:

1. Gateway API CRDs/controller or Ingress controller, if external routing is enabled.
2. cert-manager and an Issuer/ClusterIssuer, if the chart should request TLS.
3. Admin-panel MySQL and WProofreader MySQL.
4. WProofreader with its `db-manager` provisioning Job.
5. Admin-panel.

Admin-panel signup depends on the WProofreader service-ID hierarchy. For the WSC stack,
provision the service database with the required internal seed/context rather than only
creating an empty `cloud_service` database.

For WProofreader container behavior and the equivalent Docker Compose topology, see
[wproofreader-docker](https://github.com/WebSpellChecker/wproofreader-docker). On
Kubernetes, carry those settings through `wproofreader-helm`; do not add `WPR_*`
variables to the Admin-panel release.

## Configuration model

The chart generates a ConfigMap from `config.*` and either generates a Secret from
`secrets.*` or reads `secrets.existingSecret`.

For production, prefer an existing Secret managed outside Helm:

```yaml
secrets:
  existingSecret: admin-panel-secrets
```

The minimum Secret keys are:

```text
APP_KEY
DB_PASSWORD
SERVICE_DB_PASSWORD
```

Feature-specific keys such as SMTP, OAuth, or S3 credentials are listed in
[Environment variables](ENVIRONMENT_VARIABLES.md). The Secret must exist before a first
install because the migration hook uses it before normal release resources are created.

Inspect non-secret configuration safely:

```bash
kubectl -n admin-panel get configmap admin-panel-env -o yaml
kubectl -n admin-panel describe secret admin-panel-secrets
```

`describe secret` prints key names and byte lengths, not decoded values.

Service-account tokens are not mounted by default because Admin-panel does not call the
Kubernetes API. Enable the token only when your runtime integration explicitly requires
a projected Kubernetes identity:

```yaml
serviceAccount:
  automountServiceAccountToken: true
```

For reproducible deployments, set `image.digest` to the approved image digest. The
digest takes precedence over `image.tag`.

## Routing

Routing is disabled by default. Choose one method, never both. The step-by-step
installation of the supported controllers, the values for each, and the verification
commands are in the [routing guide](ROUTING.md):

- Gateway API with Traefik (recommended);
- Gateway API with Envoy Gateway;
- classic Ingress with Traefik.

Quick status checks once routing is enabled:

```bash
kubectl -n admin-panel get gateway,httproute,certificate
kubectl -n admin-panel get ingress
kubectl -n admin-panel describe httproute admin-panel
```

### Same-origin WProofreader routing

Both routing methods can send `/wscservice` to the WProofreader Kubernetes Service and
everything else to Admin-panel. This makes `config.appServerUrl` same-origin with the
Admin-panel UI:

```yaml
config:
  appUrl: https://admin-panel.example.com
  appServerUrl: https://admin-panel.example.com/wscservice/api
```

Keep `config.appServerInternalUrl` pointed at the cluster Service so server-to-server
requests do not leave and re-enter the cluster. With Gateway API, a WProofreader Service
in another namespace works through `gateway.wproofreader.namespace`; with Ingress both
charts must share a namespace. Details in the [routing guide](ROUTING.md).

## TLS and proxies

Keep `config.sslMode: "off"` when TLS terminates at the Gateway or Ingress. The container
listens on plain HTTP behind that proxy.

Choose the proxy profile that matches the entry point:

```yaml
config:
  proxyType: generic    # generic, aws, cloudflare, or image-supported direct
  extraEnv:
    FORCE_HTTPS: "true"
    SESSION_SECURE_COOKIE: "true"
```

Only force HTTPS when every public request is served over HTTPS and the proxy forwards
the original scheme correctly. A wrong proxy setup commonly causes redirect loops or
insecure generated URLs.

## Uploads and profile photos

The default Laravel disks write into a Pod. That is acceptable only for a disposable,
single-Pod smoke test. It is not durable across Pod replacement and is not shared by
multiple web Pods.

Choose one production pattern from
[`examples/values-storage.yaml`](examples/values-storage.yaml):

- S3-compatible object storage for stateless Pods; or
- one ReadWriteMany PVC shared by every role.

Do not use a ReadWriteOnce volume with replicas that may run on different nodes. The PVC
is annotated with `helm.sh/resource-policy: keep`, so Helm uninstall leaves the data in
place; deletion is an explicit operator action.

## Scaling and availability

The web Deployment can use a fixed replica count or an HPA. Before increasing it:

- keep `config.sessionDriver: database`;
- place uploads and profile photos in S3 or on RWX storage;
- size database connection limits for web Pods and workers together;
- enable a PodDisruptionBudget only when at least two web Pods can be scheduled;
- install metrics-server or another metrics provider before enabling the HPA.

The scheduler is deliberately fixed at one replica. Multiple schedulers would enqueue
scheduled work more than once. Scale workers based on queue latency and job duration,
not HTTP traffic.

## NetworkPolicy

`networkPolicy.enabled` selects only web Pods. It controls inbound HTTP and leaves egress
open, so workers and the scheduler can still reach databases and external integrations.

If `networkPolicy.ingressFrom` is empty, any Pod in the cluster can reach the web port.
Restrict it to the routing-controller namespace only after confirming that namespace's
labels:

```bash
kubectl get namespace --show-labels
```

## Upgrades

Render and review before every upgrade:

```bash
helm lint ./admin-panel --values values.production.yaml
helm diff upgrade admin-panel ./admin-panel \
  --namespace admin-panel \
  --values values.production.yaml
```

`helm diff` requires the Helm diff plugin. Without it, compare a rendered manifest in
version control. Apply the upgrade with:

```bash
helm upgrade admin-panel ./admin-panel \
  --namespace admin-panel \
  --values values.production.yaml \
  --atomic \
  --timeout 10m
```

The migration hook runs before workloads roll. A Helm rollback cannot reverse a database
migration, so read Admin-panel release notes and verify backup/restore procedures before
upgrading across schema changes.

After an upgrade:

```bash
kubectl -n admin-panel rollout status deployment/admin-panel-web --timeout=5m
kubectl -n admin-panel rollout status deployment/admin-panel-worker --timeout=5m
kubectl -n admin-panel rollout status deployment/admin-panel-scheduler --timeout=5m
helm test admin-panel --namespace admin-panel
```

## Secret rotation

Chart-managed secret changes alter the Pod checksum and trigger a rollout. Changes to an
external Secret do not, because Helm cannot hash data it does not own. After rotating an
external Secret:

```bash
kubectl -n admin-panel rollout restart deployment/admin-panel-web
kubectl -n admin-panel rollout restart deployment/admin-panel-worker
kubectl -n admin-panel rollout restart deployment/admin-panel-scheduler
```

Keep the old database password valid until every rollout completes if your database
platform supports an overlap window.

## Uninstall

```bash
helm uninstall admin-panel --namespace admin-panel
```

This removes Admin-panel workloads and routing. It does not remove external databases,
an externally managed Secret, WProofreader, or a retained uploads PVC.

## Failure guide

| Symptom | First checks |
| --- | --- |
| Helm waits on `admin-panel-migrate` | Failed Job logs, DB DNS, password, TLS requirements, migration grants |
| Web Pod is running but not Ready | `/up` response and web logs; application boot or DB configuration is failing |
| Worker or scheduler Pod restarts every few minutes | The `pgrep` liveness probe found no `artisan` process; read the previous container's logs for the PHP error and check database connectivity |
| Migration Job succeeds at once but tables are missing | The image is older than `3.0.0` and ignores the provisioning switches this chart sets; deploy `3.0.0` or newer |
| `ImagePullBackOff` | Image tag, registry authentication, `imagePullSecrets`, node architecture |
| Login works on one Pod only | `SESSION_DRIVER` must be `database`; clear stale file sessions |
| Upload disappears after restart | Configure S3 or RWX storage |
| OAuth callback mismatch | Public `APP_URL`, provider callback, and proxy HTTPS headers must agree exactly |
| HTTPRoute has no address | GatewayClass/controller readiness and HTTPRoute status conditions |
| Certificate stays pending | Issuer existence, DNS/ACME challenge, and Certificate events |
| WProofreader UI calls fail | Public `APP_SERVER_URL`, same-origin route, AppServer health, and browser network errors |

Useful commands:

```bash
helm status admin-panel --namespace admin-panel
kubectl -n admin-panel get all
kubectl -n admin-panel get events --sort-by=.lastTimestamp
kubectl -n admin-panel logs job/admin-panel-migrate --all-containers
kubectl -n admin-panel logs deployment/admin-panel-web --all-containers --tail=200
kubectl -n admin-panel logs deployment/admin-panel-worker --all-containers --tail=200
kubectl -n admin-panel logs deployment/admin-panel-scheduler --all-containers --tail=200
```

A successful migration Job is deleted automatically. A failed one remains so its logs
can be inspected. This also applies when `--atomic` rolls back a first install: Helm
uninstalls the release, but the failed `admin-panel-migrate` Job, its Pod, and the
`admin-panel-migrate-env` ConfigMap stay in the namespace because the hook delete policy
only covers success. Read the Job logs first, then remove the leftovers before retrying so
the next attempt does not show a stale, still-backing-off Job next to the new one:

```bash
kubectl -n admin-panel logs job/admin-panel-migrate --all-containers
kubectl -n admin-panel delete job admin-panel-migrate configmap admin-panel-migrate-env --ignore-not-found
```

When `secrets.existingSecret` is unset, also delete the hook Secret
`admin-panel-migrate-env`.

## Production readiness checklist

- All image and chart versions are pinned and available for the cluster architecture.
- Admin-panel and WProofreader databases are separate, backed up, and restorable.
- The service database was provisioned by the matching WProofreader `db-manager` image.
- Secrets are created by a secret-management workflow, not committed or passed in CLI history.
- Public `APP_URL` and `APP_SERVER_URL` match DNS, TLS certificates, and OAuth callbacks.
- Internal AppServer traffic uses `APP_SERVER_INTERNAL_URL`.
- SMTP is tested, or the mailer is intentionally `log` for a non-production environment.
- Uploads are durable before web replicas exceed one.
- Resource requests/limits, disruption budgets, HPA metrics, and node scheduling are reviewed.
- Network policies allow routing, DNS, database, AppServer, SMTP, and required external APIs.
- `helm test` and a browser sign-in flow succeed after installation.
