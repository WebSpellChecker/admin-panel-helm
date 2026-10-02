# Admin-panel operator guide

This guide describes chart ownership, routing, storage, scaling, upgrades, and troubleshooting.

If you have not deployed it yet, follow the [quick start](QUICKSTART.md).
For a specific application setting, use the
[environment-variable contract](ENVIRONMENT_VARIABLES.md).

## Architecture and ownership

One image runs as three Deployments and one Helm hook:

| Component | Responsibility | Scaling |
| --- | --- | --- |
| Web | nginx and PHP-FPM | fixed replicas or HPA |
| Worker | Laravel database queue | fixed replicas |
| Scheduler | Laravel scheduler | exactly one replica |
| Migration | waits for MySQL, then migrates Admin-panel's database | one `pre-install,pre-upgrade` hook Job |

Only the web Pods and the migration Job run the image entrypoint.
The worker and the scheduler start with `SKIP_ENTRYPOINT_CONFIG=true`,
run `php artisan queue:work` and `php artisan schedule:work` directly,
and are watched by a `pgrep` liveness probe.

The chart owns Admin-panel workloads, Service, configuration,
and optionally routing and an uploads PVC.
It does not install MySQL, provision the WProofreader database, install WProofreader,
or create a production certificate issuer.

Use these ownership rules during incident triage:

- Admin-panel migration errors belong to the primary Admin-panel database.
- Missing `cloud_service` tables or grants belong to WProofreader `db-manager`.
- `/wscservice` routing and AppServer health involve the WProofreader release.
- Certificate issuance involves cert-manager and the configured Issuer.

## Dependency order

Start the components in this order.
Wait for each component to become healthy:

1. Gateway API CRDs/controller or Ingress controller, if external routing is enabled.
2. cert-manager and an Issuer/ClusterIssuer, if the chart should request TLS.
3. Admin-panel MySQL and WProofreader MySQL.
4. WProofreader with its `db-manager` provisioning Job.
5. Admin-panel.

Admin-panel needs the service data that `db-manager` seeds into `cloud_service`.
Follow the [`wproofreader-helm` database provisioning guide](https://github.com/WebSpellChecker/wproofreader-helm/blob/main/README.md#connect-to-and-provision-a-database).
Keep WProofreader settings in its release.
Do not add `WPR_*` variables to Admin-panel.

Use `db-manager` `6.17.0.0` or newer.
Older schemas lack the grants Admin-panel needs to remove WProofreader branding
during product activation.

## Configuration model

The chart generates a ConfigMap from `config.*` and either generates a Secret from `secrets.*`
or reads `secrets.existingSecret`.
For production, use `existingSecret` with a Secret managed outside Helm.
[Environment variables](ENVIRONMENT_VARIABLES.md) lists every key, which Secret keys are required,
and how to inspect the result.

Create the existing Secret before the first install.
The migration hook reads it before Helm creates the normal release resources.

Service-account tokens are not mounted by default because Admin-panel does not
call the Kubernetes API.
Enable the token only when your runtime integration explicitly requires
a projected Kubernetes identity:

```yaml
serviceAccount:
  automountServiceAccountToken: true
```

For reproducible deployments, set `image.digest` to the approved image digest.
The digest takes precedence over `image.tag`.

## Routing

Routing is disabled by default.
The chart supports Gateway API and Ingress but does not install their controllers.
Use the [routing guide](ROUTING.md) for prerequisites, examples,
same-origin WProofreader routing, and verification.

## TLS and proxies

Keep `config.sslMode: "off"` when TLS terminates at the Gateway or Ingress.
The container listens on plain HTTP behind that proxy.

Choose the proxy profile that matches the entry point:

```yaml
config:
  proxyType: generic    # generic, aws, cloudflare, or image-supported direct
  extraEnv:
    FORCE_HTTPS: "true"
    SESSION_SECURE_COOKIE: "true"
```

Set `FORCE_HTTPS` only when all public requests use HTTPS and the proxy forwards
the original scheme.
An incorrect proxy configuration can cause redirect loops or insecure URLs.

## Uploads and profile photos

The default Laravel disks write into a Pod.
That is acceptable only for a disposable, single-Pod smoke test.
It is not durable across Pod replacement and is not shared by multiple web Pods.

Choose one production pattern from [`examples/values-storage.yaml`](examples/values-storage.yaml):

- S3-compatible object storage for stateless Pods.
- one ReadWriteMany PVC shared by every role.

Do not use a ReadWriteOnce volume with replicas that may run on different nodes.
The PVC is annotated with `helm.sh/resource-policy: keep`,
so Helm uninstall leaves the data in place.
Delete the PVC only when you intend to remove its data.

## Scaling and availability

The web Deployment can use a fixed replica count or an HPA.
Before you add replicas:

- Keep `config.sessionDriver: database`.
- Put uploads and profile photos in S3 or on RWX storage.
- Size database connection limits for web Pods and workers together.
- Enable a PodDisruptionBudget only when at least two web Pods can be scheduled.
- Install metrics-server or another metrics provider before you enable the HPA.

Keep the scheduler enabled.
It runs the hourly service reconciliation that repairs incomplete activations.
The chart uses one scheduler because multiple schedulers can enqueue the same work.
Scale workers from queue latency and job duration.

## NetworkPolicy

`networkPolicy.enabled` selects only web Pods.
It controls inbound HTTP and leaves egress open, so workers and
the scheduler can still reach databases and external integrations.

If `networkPolicy.ingressFrom` is empty, any Pod in the cluster can reach the web port.
Restrict it to the routing-controller namespace only after confirming that namespace's labels:

```bash
kubectl get namespace --show-labels
```

## Upgrades

Render and review before every upgrade:

```bash
helm lint ./admin-panel --values values.production.yaml
helm diff upgrade admin-panel ./admin-panel \
  --namespace wsc \
  --values values.production.yaml
```

`helm diff` requires the Helm diff plugin.
Without it, compare a rendered manifest in version control.
Apply the upgrade with:

```bash
helm upgrade admin-panel ./admin-panel \
  --namespace wsc \
  --values values.production.yaml \
  --atomic \
  --timeout 10m
```

The migration hook runs before workloads roll.

> [!WARNING]
> A Helm rollback cannot reverse a database migration. Read the Admin-panel release notes
> and verify your backup and restore procedures before you upgrade across schema changes.

After an upgrade, repeat the [application health checks](QUICKSTART.md#7-verify-application-health).

## Secret rotation

Chart-managed secret changes alter the Pod checksum and trigger a rollout.
Changes to an external Secret do not, because Helm cannot hash data it does not own.
After rotating an external Secret:

```bash
kubectl -n wsc rollout restart deployment/admin-panel-web
kubectl -n wsc rollout restart deployment/admin-panel-worker
kubectl -n wsc rollout restart deployment/admin-panel-scheduler
```

Keep the old database password valid until every rollout completes
if your database platform supports an overlap window.

## Uninstall

```bash
helm uninstall admin-panel --namespace wsc
```

This removes Admin-panel workloads and routing.
It does not remove external databases, an externally managed Secret, WProofreader,
or a retained uploads PVC.

## Failure guide

| Symptom | First checks |
| --- | --- |
| Helm waits on `admin-panel-migrate` | Failed Job logs, DB DNS, password, TLS requirements, migration grants |
| Web Pod is running but not Ready | Check the `/up` response and web logs. Application startup or database configuration is failing. |
| Worker or scheduler Pod restarts every few minutes | The `pgrep` liveness probe found no `artisan` process. Read the previous container logs and check database connectivity. |
| Migration Job succeeds at once but tables are missing | The image is older than `3.0.0` and ignores the provisioning switches. Deploy `3.0.0` or newer. |
| `ImagePullBackOff` | Image tag, registry authentication, `imagePullSecrets`, node architecture |
| Login works on one Pod only | Set `SESSION_DRIVER` to `database`. Clear stale file sessions. |
| Upload disappears after restart | Configure S3 or RWX storage |
| OAuth callback mismatch | Public `APP_URL`, provider callback, and proxy HTTPS headers must agree exactly |

For Gateway, Ingress, certificate, or same-origin routing failures,
use the [routing troubleshooting table](ROUTING.md#troubleshooting).

Useful commands:

```bash
helm status admin-panel --namespace wsc
kubectl -n wsc get all
kubectl -n wsc get events --sort-by=.lastTimestamp
kubectl -n wsc logs job/admin-panel-migrate --all-containers
kubectl -n wsc logs deployment/admin-panel-web --all-containers --tail=200
kubectl -n wsc logs deployment/admin-panel-worker --all-containers --tail=200
kubectl -n wsc logs deployment/admin-panel-scheduler --all-containers --tail=200
```

A successful migration Job is deleted automatically.
A failed Job remains for inspection.
If `--atomic` rolls back the first installation, the failed Job, its Pod,
and the `admin-panel-migrate-env` ConfigMap remain.
Read the Job logs.
Then remove these resources before you retry:

```bash
kubectl -n wsc delete job admin-panel-migrate configmap admin-panel-migrate-env --ignore-not-found
```

When `secrets.existingSecret` is unset, also delete the hook Secret `admin-panel-migrate-env`.

## Production readiness checklist

- All image and chart versions are pinned and available for the cluster architecture.
- Admin-panel and WProofreader databases are separate, backed up, and restorable.
- The service database was provisioned by the matching WProofreader `db-manager` image.
- Secrets are created by a secret-management workflow, not committed or passed in CLI history.
- Public `APP_URL` and `APP_SERVER_URL` match DNS, TLS certificates, and OAuth callbacks.
- The Admin-panel Pods can reach WProofreader Server at `APP_SERVER_INTERNAL_URL`,
  or at `APP_SERVER_URL` when the internal URL is not set.
- SMTP is tested, or the mailer is intentionally `log` for a non-production environment.
- Uploads are durable before web replicas exceed one.
- Resource requests/limits, disruption budgets, HPA metrics, and node scheduling are reviewed.
- Network policies allow routing, DNS, database, AppServer, SMTP, and required external APIs.
- `helm test` and a browser sign-in flow succeed after installation.
