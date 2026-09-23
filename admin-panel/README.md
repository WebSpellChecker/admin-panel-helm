# admin-panel

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.0.0](https://img.shields.io/badge/AppVersion-3.0.0-informational?style=flat-square)

A Helm chart for deploying WProofreader Admin-panel on Kubernetes

> Documentation and examples: [`docs/`](../docs/)

## How to install

Follow [`docs/QUICKSTART.md`](../docs/QUICKSTART.md) for dependency
checks, Secret creation, installation, and application-level verification. The smallest
values file looks like this:

```yaml
# values.yaml (minimal, external MySQL)
config:
  appUrl: http://127.0.0.1:8080
  appServerUrl: https://wproofreader.example.com/wscservice/api
  db: { host: mysql.example.com, database: admin_panel_db, username: admin_panel }
  serviceDb: { host: wproofreader-mysql.example.com, port: 3306, database: cloud_service, username: app_service }
  mail: { mailer: log }
secrets:
  existingSecret: admin-panel-secrets
```

```bash
helm upgrade --install admin-panel ./admin-panel -n admin-panel -f values.yaml --atomic --timeout 10m
```

More scenarios (Gateway API + TLS, Ingress, S3/RWX storage): [`docs/examples/`](../docs/examples).

## Architecture

One image, three roles (web = nginx+php-fpm, worker = `queue:work`, scheduler = `schedule:work`)
plus a one-shot migration hook Job. See the [documentation](../docs/README.md) for details.

## Requirements

Kubernetes: `>=1.27.0-0`

## Values

The **Required** column flags which values you must set.

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| config.appEnv | string | No | `"production"` | Laravel environment (production|staging|local). |
| config.appName | string | No | `"Admin-panel"` | Application display name. |
| config.appServerInternalUrl | string | No | `""` | In-cluster WProofreader AppServer URL (optional; e.g. http://wproofreader:8443/wscservice/api). |
| config.appServerUrl | string | **Yes** | `""` | Public WProofreader AppServer API URL. |
| config.appUrl | string | **Yes** | `""` | Public application URL. MUST match the hostname served by your ingress/gateway. |
| config.cacheStore | string | No | `"database"` | Cache store. The database option needs no additional service. |
| config.db.database | string | No | `"admin_panel_db"` | Primary DB name. |
| config.db.host | string | **Yes** | `""` | Primary DB host or Kubernetes Service name. |
| config.db.port | int | No | `3306` | Primary DB port. |
| config.db.username | string | No | `"admin_panel"` | Primary DB username. |
| config.extraEnv | object | No | `{}` | Arbitrary extra NON-SECRET env (key/value). e.g. { FOO: "bar" } |
| config.filesystemDisk | string | No | `"local"` | Default filesystem disk (local|s3). Use s3 for shared storage across replicas. |
| config.logOutputLevel | string | No | `"info"` | Container log verbosity (debug|info|warn|error). |
| config.mail.encryption | string | No | `"tls"` | SMTP encryption (tls|ssl|""). |
| config.mail.fromAddress | string | No | `"hello@example.com"` | From address. |
| config.mail.fromName | string | No | `"Admin-panel"` | From name. |
| config.mail.host | string | No | `""` | SMTP host. |
| config.mail.mailer | string | No | `"smtp"` | Mailer transport. |
| config.mail.port | int | No | `587` | SMTP port. |
| config.objectStorage.bucket | string | No | `""` | Bucket name. |
| config.objectStorage.endpoint | string | No | `""` | S3 API endpoint. When empty, the application uses the AWS regional endpoint. |
| config.objectStorage.region | string | No | `""` | AWS_DEFAULT_REGION. |
| config.objectStorage.usePathStyleEndpoint | bool | No | `true` | Path-style addressing. Only applied when `endpoint` is set (true for MinIO/Ceph);    ignored for AWS S3, which uses virtual-hosted addressing. |
| config.profilePhotoDisk | string | No | `"public"` | Jetstream profile photo / avatar disk (public|s3). Use s3 to persist avatars    across pod restarts and share them across web replicas. |
| config.proxyType | string | No | `"generic"` | Real-IP/proxy profile (generic|aws|cloudflare). |
| config.queueConnection | string | No | `"database"` | Queue connection. The database option needs no additional service. |
| config.serviceDb.database | string | No | `"app_service_db"` | Service DB name. |
| config.serviceDb.host | string | No | `""` | Service DB host. When empty, the application uses config.db.host. |
| config.serviceDb.port | int | No | `3306` | Service DB port. |
| config.serviceDb.username | string | No | `""` | Service DB username. When empty, Laravel uses config.db.username,    but the image requires an explicit value when serviceDb.host differs from db.host. |
| config.sessionDriver | string | No | `"database"` | Session driver. Use 'database' for >1 web replica (NEVER file). |
| config.sslMode | string | No | `"off"` | nginx SSL mode. Keep "off" when TLS terminates at the ingress or gateway. |
| fullnameOverride | string | No | `""` | Override the fully-qualified release name used for resource names. |
| gateway.annotations | object | No | `{}` | Extra annotations on the HTTPRoute. |
| gateway.create | bool | No | `false` | Create a Gateway managed by this chart. If false, attach the HTTPRoute to an    existing Gateway via parentRefs. |
| gateway.enabled | bool | No | `false` | Enable Gateway API HTTPRoute (PRIMARY/recommended). |
| gateway.gatewayClassName | string | No | `""` | GatewayClass name (only used when create: true). Must match your controller's    class. Examples: eg (Envoy Gateway), istio, nginx (NGINX Gateway Fabric), traefik. |
| gateway.hostnames | list | No | `["admin-panel.example.com"]` | Hostnames for the route. |
| gateway.listenerPort | int | No | `80` | Gateway listener port (only used when create: true). Must match the controller's    entryPoint/port. Envoy Gateway: 80. Traefik binds listeners to an entryPoint by    port. Its `web` entryPoint is 8000 (the Service still maps external 80 to 8000). |
| gateway.parentRefs | list | No | `[]` | parentRefs to an existing Gateway (only used when create: false).    e.g. [{ name: my-gw, namespace: gateway-system }] |
| gateway.tls | object | No | `{"certManager":{"enabled":false,"issuerRef":{"kind":"ClusterIssuer","name":""}},"enabled":false,"httpsRedirect":true,"listenerPort":443,"secretName":""}` | HTTPS listener (TLS termination at the Gateway). Provide a cert Secret in    `secretName` (e.g. issued by cert-manager). listenerPort must match the controller's    TLS entryPoint: Envoy 443, Traefik `websecure` 8443. |
| gateway.tls.certManager | object | No | `{"enabled":false,"issuerRef":{"kind":"ClusterIssuer","name":""}}` | Issue the certificate with cert-manager. With create: false, this only creates    a Certificate in the release namespace. The existing Gateway must already use    the same Secret and must be in that namespace. Manage TLS separately when the    Gateway is in another namespace. |
| gateway.tls.httpsRedirect | bool | No | `true` | Redirect plaintext HTTP to HTTPS (301). Only effective with create: true (the    chart owns the listeners): the app is served only on the HTTPS listeners and the    HTTP listener gets a redirect-only route. For an external Gateway, configure the    redirect there. |
| gateway.wproofreader | object | No | `{"enabled":false,"namespace":"","paths":["/wscservice/api","/wscservice"],"serviceName":"wproofreader-app","servicePort":80}` | Co-host the WProofreader AppServer under the same hostname(s) so the in-UI    widget can call it same-origin. Adds /wscservice(/api) routes before the    admin-panel catch-all, pointing at the WProofreader Service. |
| gateway.wproofreader.namespace | string | No | `""` | Namespace of the WProofreader Service when it is not the release namespace.    The chart then renders a ReferenceGrant into that namespace so the HTTPRoute    may reference the Service (Gateway API only; Ingress cannot cross namespaces). |
| image.digest | string | No | `""` | Image digest, for example sha256:abc123. When set, this takes precedence over tag. |
| image.pullPolicy | string | No | `"IfNotPresent"` | Image pull policy. |
| image.registry | string | No | `"docker.io"` | Image registry. Empty uses the repository as-is (Docker Hub). |
| image.repository | string | **Yes** | `"webspellchecker/admin-panel"` | Application image repository. |
| image.tag | string | No | `""` | Image tag. Defaults to the chart appVersion when empty. |
| imagePullSecrets | list | No | `[]` | Pull secrets for private registries / mirrored images. e.g. [{ name: regcred }] |
| ingress.annotations | object | No | `{}` | Ingress annotations (e.g. cert-manager.io/cluster-issuer: letsencrypt-prod).    HTTP-to-HTTPS redirects are controller-specific. Add the setting for your controller,    e.g. nginx.ingress.kubernetes.io/ssl-redirect: "true" (nginx auto-redirects when    a tls block is set), or configure a redirect entryPoint/middleware on Traefik. |
| ingress.className | string | No | `""` | IngressClass name (nginx|traefik|alb). |
| ingress.enabled | bool | No | `false` | Enable an Ingress (compatibility option for clusters not on Gateway API). |
| ingress.hosts | list | No | `[{"host":"admin-panel.example.com","paths":[{"path":"/","pathType":"Prefix"}]}]` | Hosts and paths (admin-panel backend). |
| ingress.tls | list | No | `[]` | TLS config. e.g. [{ secretName: admin-panel-tls, hosts: [admin-panel.example.com] }] |
| ingress.wproofreader | object | No | `{"enabled":false,"pathType":"Prefix","paths":["/wscservice/api","/wscservice"],"serviceName":"wproofreader-app","servicePort":80}` | Co-host the WProofreader AppServer under the same host(s) so the in-UI widget    can call it same-origin. Adds the paths below (pointing at the WProofreader    Service) BEFORE the admin-panel paths on every host. |
| migrations.affinity | object | No | `{}` |  |
| migrations.backoffLimit | int | No | `3` | Job backoffLimit (retries). |
| migrations.enabled | bool | No | `true` | Run the migration hook Job. |
| migrations.hooks | string | No | `"pre-install,pre-upgrade"` | Hook phases. pre-install/pre-upgrade run the migration (with hook-managed env)    BEFORE the app pods are created/rolled, so the DB is always migrated first. |
| migrations.nodeSelector | object | No | `{}` | Scheduling for the migrate Job. Set these to match the app nodes when they are    tainted/segregated, or the pre-install hook Job cannot schedule and the install    fails. (e.g. reuse web.nodeSelector/tolerations/affinity.) |
| migrations.resources.limits.cpu | string | No | `"500m"` |  |
| migrations.resources.limits.memory | string | No | `"512Mi"` |  |
| migrations.resources.requests.cpu | string | No | `"100m"` |  |
| migrations.resources.requests.memory | string | No | `"256Mi"` |  |
| migrations.runSeed | bool | No | `false` | Run db:seed whenever the migration hook runs. |
| migrations.tolerations | list | No | `[]` |  |
| migrations.waitDbTimeout | int | No | `120` | Seconds the entrypoint waits for the DB before failing. |
| nameOverride | string | No | `""` | Override the chart name used for resource names and the app.kubernetes.io/name label. |
| networkPolicy.enabled | bool | No | `false` | Render a NetworkPolicy for the web pods (HTTP ingress; allow-all egress by    default). Worker and scheduler Pods are not selected because they accept no inbound traffic. |
| networkPolicy.ingressFrom | list | No | `[]` | Restrict who may reach the web HTTP port (a list of NetworkPolicyPeer). Empty =    allow from anywhere in the cluster. e.g.    [{ namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: traefik } } }] |
| persistence.accessModes | list | No | `["ReadWriteMany"]` | Access modes. ReadWriteMany is required to share across replicas/nodes. |
| persistence.annotations | object | No | `{}` | Extra annotations on the created PVC. |
| persistence.enabled | bool | No | `false` | Create + mount a shared PVC for app file storage (uploads + avatars). |
| persistence.existingClaim | string | No | `""` | Use an existing PVC instead of creating one. When set, the create-time    fields below (storageClass/accessModes/size) are ignored. |
| persistence.mountPath | string | No | `"/var/www/html/storage/app"` | Mount path inside the container. Defaults to the Laravel storage/app dir, which    is the parent of both the `local` (storage/app) and `public` (storage/app/public)    disks, so a single volume covers all uploads. Set to .../storage/app/public to    share only avatars. Must match the image's storage layout. |
| persistence.size | string | No | `"5Gi"` | Requested volume size. |
| persistence.storageClass | string | No | `""` | StorageClass for the created PVC. When empty, Kubernetes uses the cluster default. |
| podAnnotations | object | No | `{}` | Pod annotations applied to all roles. |
| podLabels | object | No | `{}` | Pod labels applied to all roles. |
| podSecurityContext | object | No | `{"fsGroup":33,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod-level security context (fsGroup matches www-data uid/gid 33). |
| probes | object | No | `{"appPath":"/up","path":"/php-fpm-ping","port":8080}` | HTTP probe targets. `path` is the PHP-FPM liveness ping. `appPath` is the Laravel    health route used by the readiness probe and `helm test`, so both verify the app. |
| scheduler.affinity | object | No | `{}` |  |
| scheduler.args | list | No | `["php","artisan","schedule:work"]` | Args override = the foreground schedule worker (a single PHP process that    receives SIGTERM directly and shuts down gracefully, unlike a `sh -c` loop). |
| scheduler.enabled | bool | No | `true` | Enable the scheduler Deployment. |
| scheduler.extraEnv | object | No | `{}` | Extra env for the scheduler role only. |
| scheduler.livenessProbe | object | No | `{"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":30,"timeoutSeconds":5}` | Liveness probe timing; the probe itself is `pgrep -f "artisan schedule:work"`. |
| scheduler.nodeSelector | object | No | `{}` |  |
| scheduler.resources.limits.cpu | string | No | `"250m"` |  |
| scheduler.resources.limits.memory | string | No | `"256Mi"` |  |
| scheduler.resources.requests.cpu | string | No | `"50m"` |  |
| scheduler.resources.requests.memory | string | No | `"128Mi"` |  |
| scheduler.terminationGracePeriodSeconds | int | No | `30` | Grace period for the running scheduled task to finish on shutdown/rollout. |
| scheduler.tolerations | list | No | `[]` |  |
| secrets.appKey | string | No | `""` | Laravel APP_KEY when the chart creates the Secret. Generate with `php artisan key:generate`.    When existingSecret is set, put APP_KEY in that Secret instead. |
| secrets.db.password | string | No | `""` | Primary DB password (provide here, or via existingSecret). |
| secrets.existingSecret | string | No | `""` | Use a pre-existing Secret (sealed-secrets/SOPS/Vault). When set, the    keys below are ignored and the chart renders no Secret of its own. |
| secrets.extraSecretEnv | object | No | `{}` | Arbitrary extra SECRET env (key/value). |
| secrets.mail.password | string | No | `""` | SMTP password. |
| secrets.mail.username | string | No | `""` | SMTP username. |
| secrets.s3.accessKeyId | string | No | `""` | S3 access key id (MinIO/Ceph access key, or AWS key). Empty on AWS+IRSA. |
| secrets.s3.secretAccessKey | string | No | `""` | S3 secret access key. Empty on AWS+IRSA. |
| secrets.serviceDb.password | string | No | `""` | Service DB password. When empty, Laravel uses db.password,    but the image requires an explicit value when serviceDb.host differs from db.host. |
| securityContext | object | No | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":33,"runAsNonRoot":true,"runAsUser":33}` | Container-level security context (runs non-root as www-data). |
| serviceAccount.annotations | object | No | `{}` | Annotations for the ServiceAccount. |
| serviceAccount.automountServiceAccountToken | bool | No | `false` | Mount a projected ServiceAccount token. Leave disabled unless the application needs one. |
| serviceAccount.create | bool | No | `true` | Create a ServiceAccount. |
| serviceAccount.name | string | No | `""` | ServiceAccount name (defaults to the fullname). |
| web.affinity | object | No | `{}` |  |
| web.args | list | No | `[]` | Override container args/CMD (empty keeps the image CMD = supervisord web stack).    The image ENTRYPOINT (env validation, config:cache) is always preserved. |
| web.autoscaling.enabled | bool | No | `false` | Enable HPA for the web role. |
| web.autoscaling.maxReplicas | int | No | `6` |  |
| web.autoscaling.minReplicas | int | No | `2` |  |
| web.autoscaling.targetCPUUtilizationPercentage | int | No | `70` |  |
| web.enabled | bool | No | `true` | Enable the web Deployment + Service. |
| web.extraEnv | object | No | `{}` | Extra env for the web role only. |
| web.livenessProbe | object | No | `{"failureThreshold":3,"initialDelaySeconds":30,"periodSeconds":15,"timeoutSeconds":3}` | Probe timing overrides (path/port come from .Values.probes). |
| web.nodeSelector | object | No | `{}` |  |
| web.podDisruptionBudget.enabled | bool | No | `false` | Enable a PodDisruptionBudget for the web role. |
| web.podDisruptionBudget.minAvailable | int | No | `1` | Minimum available web pods. Ignored when maxUnavailable is set. |
| web.readinessProbe.failureThreshold | int | No | `3` |  |
| web.readinessProbe.initialDelaySeconds | int | No | `10` |  |
| web.readinessProbe.periodSeconds | int | No | `10` |  |
| web.readinessProbe.timeoutSeconds | int | No | `3` |  |
| web.replicaCount | int | No | `1` | Web replicas (raise only after sessions+storage are externalized). |
| web.resources.limits.cpu | string | No | `"1"` |  |
| web.resources.limits.memory | string | No | `"1Gi"` |  |
| web.resources.requests.cpu | string | No | `"250m"` |  |
| web.resources.requests.memory | string | No | `"512Mi"` |  |
| web.service.port | int | No | `80` | Service port (forwards to the container HTTP port). |
| web.service.type | string | No | `"ClusterIP"` | Service type. |
| web.startupProbe.failureThreshold | int | No | `40` |  |
| web.startupProbe.periodSeconds | int | No | `5` |  |
| web.startupProbe.timeoutSeconds | int | No | `3` |  |
| web.strategy | object | No | `{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0},"type":"RollingUpdate"}` | Rolling update strategy (surge a new pod before removing old; zero downtime). |
| web.tolerations | list | No | `[]` |  |
| worker.affinity | object | No | `{}` |  |
| worker.args | list | No | `["php","artisan","queue:work","--queue=default","--verbose","--sleep=3","--tries=3","--max-time=3600"]` | Args override = the CMD the entrypoint execs (same command as the Compose/Swarm stacks). |
| worker.enabled | bool | No | `true` | Enable the worker Deployment. |
| worker.extraEnv | object | No | `{}` | Extra env for the worker role only. |
| worker.livenessProbe | object | No | `{"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":30,"timeoutSeconds":5}` | Liveness probe timing; the probe itself is `pgrep -f "artisan queue:work"`. |
| worker.nodeSelector | object | No | `{}` |  |
| worker.replicaCount | int | No | `1` | Worker replicas. |
| worker.resources.limits.cpu | string | No | `"500m"` |  |
| worker.resources.limits.memory | string | No | `"512Mi"` |  |
| worker.resources.requests.cpu | string | No | `"100m"` |  |
| worker.resources.requests.memory | string | No | `"256Mi"` |  |
| worker.terminationGracePeriodSeconds | int | No | `300` | Graceful shutdown window: queue:work finishes the job in hand on SIGTERM. |
| worker.tolerations | list | No | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
