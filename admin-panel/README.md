# admin-panel

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.0.0](https://img.shields.io/badge/AppVersion-3.0.0-informational?style=flat-square)

A Helm chart for deploying WProofreader Admin-panel on Kubernetes

> Documentation and examples: [`docs/`](https://github.com/WebSpellChecker/admin-panel-helm/tree/master/docs)

## Install

Use the [quick start](https://github.com/WebSpellChecker/admin-panel-helm/blob/master/docs/QUICKSTART.md)
to prepare the dependencies, create the Secret, install the chart, and verify the application.
Start with [`values-minimal.yaml`](https://github.com/WebSpellChecker/admin-panel-helm/blob/master/docs/examples/values-minimal.yaml).
The [`docs/examples/`](https://github.com/WebSpellChecker/admin-panel-helm/tree/master/docs/examples)
directory also contains routing and storage configurations.

## Architecture

The chart runs one image as a web server, queue worker, and scheduler.
A Helm hook Job runs database migrations.
See the [operator guide](https://github.com/WebSpellChecker/admin-panel-helm/blob/master/docs/README.md)
for details.

## Requirements

Kubernetes: `>=1.27.0-0`

## Values

The **Required** column identifies empty defaults that you must set.
The descriptions state all feature-specific requirements.

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| config.appEnv | string | No | `"production"` | Laravel environment (production|staging|local). |
| config.appName | string | No | `"Admin-panel"` | Application display name. |
| config.appServerInternalUrl | string | No | `""` | Optional in-cluster WProofreader AppServer URL. When empty, the application uses appServerUrl. |
| config.appServerUrl | string | **Yes** | `""` | Public WProofreader AppServer API URL. |
| config.appUrl | string | **Yes** | `""` | Public application URL. It must match the hostname served by the Ingress or Gateway. |
| config.cacheStore | string | No | `"database"` | Cache store. The database option needs no additional service. |
| config.db.database | string | No | `"admin_panel_db"` | Primary DB name. |
| config.db.host | string | **Yes** | `""` | Primary DB host or Kubernetes Service name. |
| config.db.port | int | No | `3306` | Primary DB port. |
| config.db.username | string | No | `"admin_panel"` | Primary DB username. |
| config.extraEnv | object | No | `{}` | Additional non-secret environment variables. For example, { FOO: "bar" }. |
| config.filesystemDisk | string | No | `"local"` | Default filesystem disk (local|s3). Use s3 for shared storage across replicas. |
| config.logOutputLevel | string | No | `"info"` | Container log verbosity (debug|info|warn|error). |
| config.mail.encryption | string | No | `"tls"` | Compatibility value for SMTP encryption. The port controls the TLS mode. |
| config.mail.fromAddress | string | No | `"hello@example.com"` | From address. |
| config.mail.fromName | string | No | `"Admin-panel"` | From name. |
| config.mail.host | string | No | `""` | SMTP host. |
| config.mail.mailer | string | No | `"smtp"` | Mailer transport. |
| config.mail.port | int | No | `587` | SMTP port. |
| config.objectStorage.bucket | string | No | `""` | Bucket name. |
| config.objectStorage.endpoint | string | No | `""` | S3 API endpoint. When empty, the S3 client uses the Amazon S3 regional endpoint. |
| config.objectStorage.region | string | No | `""` | AWS_DEFAULT_REGION. |
| config.objectStorage.usePathStyleEndpoint | bool | No | `true` | Use path-style addressing when endpoint is set. Enable it for MinIO or Ceph. |
| config.profilePhotoDisk | string | No | `"public"` | Jetstream profile-photo disk (public|s3). Use s3 for persistent, shared files. |
| config.proxyType | string | No | `"generic"` | Real-IP/proxy profile (generic|aws|cloudflare). |
| config.queueConnection | string | No | `"database"` | Queue connection. The database option needs no additional service. |
| config.serviceDb.database | string | No | `"app_service_db"` | Service DB name. |
| config.serviceDb.host | string | No | `""` | Service DB host. When empty, the application uses config.db.host. |
| config.serviceDb.port | int | No | `3306` | Service DB port. |
| config.serviceDb.username | string | No | `""` | Service DB username. Set it when serviceDb.host differs from db.host. |
| config.sessionDriver | string | No | `"database"` | Session driver. Use database when you run more than one web replica. |
| config.sslMode | string | No | `"off"` | nginx SSL mode. Keep "off" when TLS terminates at the Ingress or Gateway. |
| fullnameOverride | string | No | `""` | Override the fully-qualified release name used for resource names. |
| gateway.annotations | object | No | `{}` | Extra annotations on the HTTPRoute. |
| gateway.create | bool | No | `false` | Create a Gateway. When false, parentRefs must identify an existing Gateway. |
| gateway.enabled | bool | No | `false` | Enable the Gateway API HTTPRoute. |
| gateway.gatewayClassName | string | No | `""` | GatewayClass name. Used only when create is true. |
| gateway.hostnames | list | No | `["admin-panel.example.com"]` | Hostnames for the route. |
| gateway.listenerPort | int | No | `80` | HTTP listener port for a chart-managed Gateway. |
| gateway.parentRefs | list | No | `[]` | References to an existing Gateway. Used only when create is false. |
| gateway.tls | object | No | `{"certManager":{"enabled":false,"issuerRef":{"kind":"ClusterIssuer","name":""}},"enabled":false,"httpsRedirect":true,"listenerPort":443,"secretName":""}` | HTTPS listener settings for TLS termination at the Gateway. |
| gateway.tls.certManager | object | No | `{"enabled":false,"issuerRef":{"kind":"ClusterIssuer","name":""}}` | Create a cert-manager Certificate in the release namespace. |
| gateway.tls.httpsRedirect | bool | No | `true` | Redirect HTTP to HTTPS with status 301. Used only for a chart-managed Gateway. |
| gateway.wproofreader | object | No | `{"enabled":false,"namespace":"","paths":["/wscservice/api","/wscservice"],"serviceName":"wproofreader-app","servicePort":80}` | Route WProofreader paths on the Admin-panel hostname. |
| gateway.wproofreader.namespace | string | No | `""` | Namespace of the WProofreader Service. Empty uses the release namespace. |
| image.digest | string | No | `""` | Image digest, for example sha256:abc123. When set, this takes precedence over tag. |
| image.pullPolicy | string | No | `"IfNotPresent"` | Image pull policy. |
| image.registry | string | No | `"docker.io"` | Image registry. Empty uses the repository as-is (Docker Hub). |
| image.repository | string | No | `"webspellchecker/admin-panel"` | Application image repository. |
| image.tag | string | No | `""` | Image tag. Defaults to the chart appVersion when empty. |
| imagePullSecrets | list | No | `[]` | Pull secrets for private registries or mirrored images. For example, [{ name: regcred }]. |
| ingress.annotations | object | No | `{}` | Ingress annotations for cert-manager and controller-specific settings. |
| ingress.className | string | No | `""` | IngressClass name (nginx|traefik|alb). |
| ingress.enabled | bool | No | `false` | Enable an Ingress (compatibility option for clusters not on Gateway API). |
| ingress.hosts | list | No | `[{"host":"admin-panel.example.com","paths":[{"path":"/","pathType":"Prefix"}]}]` | Hosts and paths (admin-panel backend). |
| ingress.tls | list | No | `[]` | Ingress TLS settings. |
| ingress.wproofreader | object | No | `{"enabled":false,"pathType":"Prefix","paths":["/wscservice/api","/wscservice"],"serviceName":"wproofreader-app","servicePort":80}` | Route WProofreader paths on each Admin-panel host. |
| migrations.affinity | object | No | `{}` | Affinity rules for the migration Job. |
| migrations.backoffLimit | int | No | `3` | Job backoffLimit (retries). |
| migrations.enabled | bool | No | `true` | Run the migration hook Job. |
| migrations.hooks | string | No | `"pre-install,pre-upgrade"` | Helm hook phases for the migration Job. Keep pre-install and pre-upgrade. |
| migrations.nodeSelector | object | No | `{}` | Node selector for the migration Job. |
| migrations.resources | object | No | `{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"256Mi"}}` | Resource requests and limits for the migration container. |
| migrations.runSeed | bool | No | `false` | Run db:seed whenever the migration hook runs. |
| migrations.tolerations | list | No | `[]` | Tolerations for the migration Job. |
| migrations.waitDbTimeout | int | No | `120` | Seconds the entrypoint waits for the DB before failing. |
| nameOverride | string | No | `""` | Override the chart name used for resource names and the app.kubernetes.io/name label. |
| networkPolicy.enabled | bool | No | `false` | Create a NetworkPolicy for inbound web traffic. Egress remains open. |
| networkPolicy.ingressFrom | list | No | `[]` | Sources that can reach the web port. An empty list allows all cluster Pods. |
| persistence.accessModes | list | No | `["ReadWriteMany"]` | Access modes. ReadWriteMany is required to share across replicas/nodes. |
| persistence.annotations | object | No | `{}` | Extra annotations on the created PVC. |
| persistence.enabled | bool | No | `false` | Create and mount a shared PVC for uploads and profile photos. |
| persistence.existingClaim | string | No | `""` | Use an existing PVC. When set, the chart ignores storageClass, accessModes, and size. |
| persistence.mountPath | string | No | `"/var/www/html/storage/app"` | Container mount path. The default covers the local and public Laravel disks. |
| persistence.size | string | No | `"5Gi"` | Requested volume size. |
| persistence.storageClass | string | No | `""` | StorageClass for the created PVC. When empty, Kubernetes uses the cluster default. |
| podAnnotations | object | No | `{}` | Pod annotations applied to all roles. |
| podLabels | object | No | `{}` | Pod labels applied to all roles. |
| podSecurityContext | object | No | `{"fsGroup":33,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod-level security context (fsGroup matches www-data uid/gid 33). |
| probes | object | No | `{"appPath":"/up","path":"/php-fpm-ping","port":8080}` | HTTP probe targets for PHP-FPM and the Laravel application. |
| scheduler.affinity | object | No | `{}` | Affinity rules for scheduler Pods. |
| scheduler.args | list | No | `["php","artisan","schedule:work"]` | Override the scheduler CMD. |
| scheduler.enabled | bool | No | `true` | Enable the scheduler Deployment. |
| scheduler.extraEnv | object | No | `{}` | Extra env for the scheduler role only. |
| scheduler.livenessProbe | object | No | `{"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":30,"timeoutSeconds":5}` | Liveness-probe timing. The probe runs `pgrep -f "artisan schedule:work"`. |
| scheduler.nodeSelector | object | No | `{}` | Node selector for scheduler Pods. |
| scheduler.resources | object | No | `{"limits":{"cpu":"250m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"128Mi"}}` | Resource requests and limits for the scheduler container. |
| scheduler.terminationGracePeriodSeconds | int | No | `30` | Grace period for the running scheduled task to finish on shutdown/rollout. |
| scheduler.tolerations | list | No | `[]` | Tolerations for scheduler Pods. |
| secrets.appKey | string | No | `""` | Laravel APP_KEY for a chart-managed Secret. Put APP_KEY in existingSecret when you use one. |
| secrets.db.password | string | No | `""` | Primary DB password (provide here, or via existingSecret). |
| secrets.existingSecret | string | No | `""` | Use an existing Secret. When set, the chart ignores the secret values below. |
| secrets.extraSecretEnv | object | No | `{}` | Additional secret environment variables. |
| secrets.mail.password | string | No | `""` | SMTP password. |
| secrets.mail.username | string | No | `""` | SMTP username. |
| secrets.s3.accessKeyId | string | No | `""` | S3 access key id. Empty when workload identity supplies credentials. |
| secrets.s3.secretAccessKey | string | No | `""` | S3 secret access key. Empty when workload identity supplies credentials. |
| secrets.serviceDb.password | string | No | `""` | Service DB password. Set it when serviceDb.host differs from db.host. |
| securityContext | object | No | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":33,"runAsNonRoot":true,"runAsUser":33}` | Container-level security context (runs non-root as www-data). |
| serviceAccount.annotations | object | No | `{}` | Annotations for the ServiceAccount. |
| serviceAccount.automountServiceAccountToken | bool | No | `false` | Mount a projected ServiceAccount token. Leave disabled unless the application needs one. |
| serviceAccount.create | bool | No | `true` | Create a ServiceAccount. |
| serviceAccount.name | string | No | `""` | ServiceAccount name (defaults to the fullname). |
| web.affinity | object | No | `{}` | Affinity rules for web Pods. |
| web.args | list | No | `[]` | Override the image CMD. An empty list uses the default web stack. |
| web.autoscaling.enabled | bool | No | `false` | Enable HPA for the web role. |
| web.autoscaling.maxReplicas | int | No | `6` | Maximum number of web replicas. |
| web.autoscaling.minReplicas | int | No | `2` | Minimum number of web replicas. |
| web.autoscaling.targetCPUUtilizationPercentage | int | No | `70` | Target average CPU use as a percentage of the resource request. |
| web.enabled | bool | No | `true` | Enable the web Deployment and Service. |
| web.extraEnv | object | No | `{}` | Extra env for the web role only. |
| web.livenessProbe | object | No | `{"failureThreshold":3,"initialDelaySeconds":30,"periodSeconds":15,"timeoutSeconds":3}` | Probe timing overrides (path/port come from .Values.probes). |
| web.nodeSelector | object | No | `{}` | Node selector for web Pods. |
| web.podDisruptionBudget.enabled | bool | No | `false` | Enable a PodDisruptionBudget for the web role. |
| web.podDisruptionBudget.minAvailable | int | No | `1` | Minimum number of available web Pods. Ignored when maxUnavailable is set. |
| web.readinessProbe | object | No | `{"failureThreshold":3,"initialDelaySeconds":10,"periodSeconds":10,"timeoutSeconds":3}` | Readiness-probe timing. |
| web.replicaCount | int | No | `1` | Number of web replicas. Increase this only after you externalize sessions and storage. |
| web.resources | object | No | `{"limits":{"cpu":"1","memory":"1Gi"},"requests":{"cpu":"250m","memory":"512Mi"}}` | Resource requests and limits for the web container. |
| web.service.port | int | No | `80` | Service port (forwards to the container HTTP port). |
| web.service.type | string | No | `"ClusterIP"` | Service type. |
| web.startupProbe | object | No | `{"failureThreshold":40,"periodSeconds":5,"timeoutSeconds":3}` | Startup-probe timing. |
| web.strategy | object | No | `{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0},"type":"RollingUpdate"}` | Rolling-update strategy for the web Deployment. |
| web.tolerations | list | No | `[]` | Tolerations for web Pods. |
| worker.affinity | object | No | `{}` | Affinity rules for worker Pods. |
| worker.args | list | No | `["php","artisan","queue:work","--queue=default","--verbose","--sleep=3","--tries=3","--max-time=3600"]` | Override the worker CMD. |
| worker.enabled | bool | No | `true` | Enable the worker Deployment. |
| worker.extraEnv | object | No | `{}` | Extra env for the worker role only. |
| worker.livenessProbe | object | No | `{"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":30,"timeoutSeconds":5}` | Liveness-probe timing. The probe runs `pgrep -f "artisan queue:work"`. |
| worker.nodeSelector | object | No | `{}` | Node selector for worker Pods. |
| worker.replicaCount | int | No | `1` | Worker replicas. |
| worker.resources | object | No | `{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"256Mi"}}` | Resource requests and limits for the worker container. |
| worker.terminationGracePeriodSeconds | int | No | `300` | Graceful shutdown window: queue:work finishes the job in hand on SIGTERM. |
| worker.tolerations | list | No | `[]` | Tolerations for worker Pods. |

