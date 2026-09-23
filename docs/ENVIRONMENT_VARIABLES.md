# Environment variables on Kubernetes

Use this page when translating an Admin-panel `.env` file or Docker Compose deployment
to Helm. In Kubernetes, do not mount a Laravel `.env` file. The chart creates a ConfigMap
for non-secret variables and reads secret variables from a Kubernetes Secret.

This chart delivers the **On-Prem edition** of WProofreader Admin-panel. This page
describes the environment contract of chart `1.0.0` with Admin-panel image `3.0.0`, the
same container layout as the `examples/admin-panel` Docker Compose stack in
[wproofreader-docker](https://github.com/WebSpellChecker/wproofreader-docker).

Two facts about versions matter before anything else:

- **This chart needs Admin-panel `3.0.0` or newer.** The provisioning switches it sets,
  `LARAVEL_PROVISION_ADMIN_PANEL_DB` and `LARAVEL_SEED_ADMIN_PANEL_DB`, exist since
  3.0.0. An older image ignores them: its migrate Job exits successfully without running
  a single migration and the release comes up against an unmigrated database.
- **The chart's `appVersion` is `3.0.0`**, so `image.tag` can stay empty. Never pin
  `image.tag` below `3.0.0`.

If you override `image.tag`, use the environment reference from that exact Admin-panel
tag. A newer application's variables do not automatically become supported by an older
image.

## How values become environment variables

Every web, worker, scheduler, and migration Pod loads:

1. the chart-managed ConfigMap for non-secret values;
2. the chart-managed Secret, or `secrets.existingSecret`;
3. role-specific variables from `web.extraEnv`, `worker.extraEnv`, or
   `scheduler.extraEnv` where applicable.

The worker and scheduler Pods receive the same environment but start with
`SKIP_ENTRYPOINT_CONFIG=true`, so the image entrypoint scripts (environment validation,
nginx setup, migrations, storage link, cache rebuild, setup token) run only in the web
Pods and in the migration Job. Laravel reads the variables directly in those two roles.
Container-tuning variables for nginx, PHP-FPM, and the entrypoint have no effect there.

Use `config.extraEnv` for an application or container variable that every role needs.
Use `secrets.extraSecretEnv` for a secret variable that every role needs. Do not put
passwords, tokens, private keys, webhook secrets, or OAuth client secrets in
`config.extraEnv`.

Do not repeat a chart-managed variable in either `extraEnv` map. Set the documented Helm
value instead; duplicate environment keys are difficult to reason about and may not be
handled consistently by YAML tooling.

## On-Prem edition

This chart delivers Admin-panel On-Prem only. It always renders `APP_EDITION=onprem` and
does not expose a Helm value that can change the edition. Attempts to define the same
variable through an `extraEnv` map are rejected by the values schema. Since image
`3.0.0` the application itself falls back to `onprem` when the variable is unset; the
chart still sets it so the rendered ConfigMap states the edition.

| Environment variable | Helm value | Required | Behavior |
| --- | --- | --- | --- |
| `APP_EDITION` | Fixed by chart | No | Always `onprem`; not configurable |
| `ONPREM_PRODUCT_TYPE` | `config.extraEnv.ONPREM_PRODUCT_TYPE` | No | `sdk` or `scayt`. Product type used before a team activates a product. Keep the default `sdk` unless told otherwise. |

`APP_EDITION` is independent of `APP_ENV`. Keep `config.appEnv: production` for a real
On-Prem installation.

Verify after install that the rendered ConfigMap carries the switch:

```bash
kubectl -n admin-panel get configmap admin-panel-env -o jsonpath='{.data.APP_EDITION}'
```

It must print `onprem`.

## Chart-managed non-secret variables

| Environment variable | Helm value | Default or behavior |
| --- | --- | --- |
| `APP_NAME` | `config.appName` | `Admin-panel` |
| `APP_ENV` | `config.appEnv` | `production` |
| `APP_EDITION` | Fixed by chart | `onprem`; this chart does not expose an edition override |
| `APP_URL` | `config.appUrl` | Required; browser-facing base URL. On-Prem signs invitation links and the setup URL with it, so it must be the address people really use. |
| `APP_SERVER_URL` | `config.appServerUrl` | Required; browser-facing WProofreader Server API URL |
| `APP_SERVER_INTERNAL_URL` | `config.appServerInternalUrl` | Omitted when empty; falls back to `APP_SERVER_URL`. On-Prem reads the license from this address, so set it to the in-cluster Service URL. |
| `LOG_OUTPUT_LEVEL` | `config.logOutputLevel` | `info`; controls container/nginx/PHP-FPM output |
| `SSL_MODE` | `config.sslMode` | `off`; terminate TLS at the Gateway or Ingress |
| `PROXY_TYPE` | `config.proxyType` | `generic`; also supports `aws`, `cloudflare`, and image-supported `direct` |
| `SESSION_DRIVER` | `config.sessionDriver` | `database`. Keep it: On-Prem admin password resets revoke the target user's sessions only with this driver, and it is required for more than one web Pod. |
| `CACHE_STORE` | `config.cacheStore` | `database`. The license answer cache lives here, so every Pod shares one license state. |
| `QUEUE_CONNECTION` | `config.queueConnection` | `database` |
| `FILESYSTEM_DISK` | `config.filesystemDisk` | `local` |
| `JETSTREAM_PROFILE_PHOTO_DISK` | `config.profilePhotoDisk` | `public` |
| `DB_CONNECTION` | Fixed by chart | `mysql` |
| `DB_HOST` | `config.db.host` | Required |
| `DB_PORT` | `config.db.port` | `3306` |
| `DB_DATABASE` | `config.db.database` | `admin_panel_db` |
| `DB_USERNAME` | `config.db.username` | `admin_panel` |
| `SERVICE_DB_HOST` | `config.serviceDb.host` | Omitted when empty; application falls back to `DB_HOST` |
| `SERVICE_DB_PORT` | `config.serviceDb.port` | `3306` |
| `SERVICE_DB_DATABASE` | `config.serviceDb.database` | Chart default `app_service_db`; set it to `cloud_service`, the name WProofreader `db-manager` provisions. The examples already do. |
| `SERVICE_DB_USERNAME` | `config.serviceDb.username` | Application fallback is `DB_USERNAME`; set it explicitly when the service DB host differs because image validation requires it. Use the Admin-panel user that `db-manager` creates, `app_service` by default. |
| `MAIL_MAILER` | `config.mail.mailer` | Chart default `smtp`. On-Prem treats `log` as a supported state, not a failure; see [Mail is optional](#mail-is-optional). |
| `MAIL_HOST` | `config.mail.host` | Omitted when empty. With `smtp`, a non-empty host is what marks mail as configured. |
| `MAIL_PORT` | `config.mail.port` | `587` |
| `MAIL_ENCRYPTION` | `config.mail.encryption` | `tls`; use an empty string for plain SMTP such as Mailpit |
| `MAIL_FROM_ADDRESS` | `config.mail.fromAddress` | `hello@example.com` |
| `MAIL_FROM_NAME` | `config.mail.fromName` | `Admin-panel` |
| `AWS_DEFAULT_REGION` | `config.objectStorage.region` | Omitted when empty |
| `AWS_BUCKET` | `config.objectStorage.bucket` | Omitted when empty |
| `AWS_ENDPOINT` | `config.objectStorage.endpoint` | Omitted for AWS S3; set for MinIO/Ceph |
| `AWS_USE_PATH_STYLE_ENDPOINT` | `config.objectStorage.usePathStyleEndpoint` | Rendered only when `endpoint` is set |
| `LARAVEL_ENVIRONMENT_VALIDATION` | Fixed by chart | `true` |
| `LARAVEL_PROVISION_ADMIN_PANEL_DB` | Fixed for runtime Pods | `false`; migration Pod overrides it to `true` |
| `LARAVEL_SEED_ADMIN_PANEL_DB` | Fixed for runtime Pods | `false`; migration Pod uses `migrations.runSeed` |
| `LARAVEL_MIGRATION_WAIT_DB_TIMEOUT` | `migrations.waitDbTimeout` | Migration Pod only; `120` seconds |
| `SKIP_ENTRYPOINT_CONFIG` | Fixed for worker and scheduler Pods | `true`; those Pods bypass the entrypoint scripts. Web and migration Pods do not set it |

`LOG_OUTPUT_LEVEL` is not Laravel's minimum application log level. The image defaults
`LOG_CHANNEL` to `stdout`, which writes JSON to the container log. Set `LOG_LEVEL` in
`config.extraEnv` when you need to change Laravel logging:

```yaml
config:
  logOutputLevel: info
  extraEnv:
    LOG_LEVEL: info
```

## Chart-managed secret variables

When `secrets.existingSecret` is empty, the chart renders these keys from Helm values.
When it is set, the chart renders no Secret: create the keys you need in that existing
Secret instead.

| Environment variable | Helm value | When needed |
| --- | --- | --- |
| `APP_KEY` | `secrets.appKey` | Always. Keep it stable: invitation links and the setup URL are signed with it. |
| `DB_PASSWORD` | `secrets.db.password` | Always for password-authenticated MySQL |
| `SERVICE_DB_PASSWORD` | `secrets.serviceDb.password` | Application fallback is `DB_PASSWORD`; set it explicitly when the service DB host differs because image validation requires it |
| `MAIL_USERNAME` | `secrets.mail.username` | Authenticated SMTP |
| `MAIL_PASSWORD` | `secrets.mail.password` | Authenticated SMTP |
| `AWS_ACCESS_KEY_ID` | `secrets.s3.accessKeyId` | S3 unless workload identity/IRSA supplies credentials |
| `AWS_SECRET_ACCESS_KEY` | `secrets.s3.secretAccessKey` | S3 unless workload identity/IRSA supplies credentials |

Admin-panel has no root database credentials: migrations connect as `DB_USERNAME`, which
therefore needs the privileges to create and alter tables.

With an existing Secret, start with the three keys in
[`examples/secret.yaml`](examples/secret.yaml). Add optional keys only when the matching
feature is enabled. Empty keys are unnecessary.

## License

On-Prem access is governed by the WProofreader Server license. Admin-panel reads the
license status and never writes it. Any status other than `active` blocks protected
operations and shows a banner.

The license itself is installed in WProofreader Server through the
`wproofreader-helm` value `licenseTicketID`. That chart maps the value to its own
WProofreader configuration. Admin-panel never receives the ticket and has no variable
for it.

Admin-panel fetches `GET <APP_SERVER_INTERNAL_URL>?cmd=license_status`. Nothing has to
be set for that to work; the variables below only tune it. Put any of them in
`config.extraEnv`.

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `LICENSE_DRIVER` | `appserver` | Leave unset. `fake` exists only for automated tests and must never reach a customer cluster. |
| `LICENSE_STATUS_URL` | unset | Overrides the license endpoint base. Set it only when the license endpoint lives at a different address than `APP_SERVER_INTERNAL_URL`. |
| `LICENSE_VERIFY_TLS` | `false` | Verify the WProofreader Server TLS certificate. The default is `false` because in-cluster WProofreader commonly uses a self-signed certificate. Set `true` when the internal URL has a trusted certificate. |
| `LICENSE_CONNECT_TIMEOUT` | `3` | Seconds to connect |
| `LICENSE_TIMEOUT` | `5` | Seconds for the whole request |
| `LICENSE_CACHE_TTL` | `60` | Seconds a fetched answer stays fresh. A license change on WProofreader Server takes at most this long to show. |
| `LICENSE_GRACE_SECONDS` | `900` | Seconds the last known answer is still served after WProofreader Server becomes unreachable. Raise it to survive longer WProofreader outages or slow rollouts. |
| `LICENSE_FAILURE_COOLDOWN` | `15` | Seconds WProofreader Server is left alone after a failed license request |
| `LICENSE_LOCK_SECONDS` | `10` | Lock held while one worker refreshes the answer. Keep it above connect plus total timeout. |

Verify the endpoint from a running Pod before blaming the license configuration:

```bash
kubectl -n admin-panel exec deployment/admin-panel-web -- \
  curl --silent --show-error --fail \
  "http://wproofreader-app.admin-panel.svc.cluster.local/wscservice/api?cmd=license_status"
```

Replace the host with your WProofreader Service when it runs in another namespace. A
healthy answer is JSON with `"valid":true`.

## First administrator on Kubernetes

On-Prem has no self-registration. The first administrator is created on the `/setup`
page with a one-time token that is valid for 24 hours. Every unauthenticated request is
redirected to `/setup` until that happens.

The image entrypoint generates the token on the first container start after migrations
and prints a `Setup URL` line in that container's log. **In this chart, the first
container to run is the migration hook Job, and Helm deletes that Job when it succeeds.**
The web Pods then only log that a token is already outstanding, because the plaintext
exists only where it was generated. The worker and the scheduler skip the entrypoint and
never touch the token.

The reliable way to obtain the setup URL is to regenerate the token in the web Pod
after the install finishes:

```bash
kubectl -n admin-panel exec deployment/admin-panel-web -- \
  php artisan app:setup-token --regenerate --no-ansi
```

The command prints the token and a ready-to-open URL of the form
`<APP_URL>/setup?token=...`. Open it within 24 hours and create the organization and the
first administrator. Regenerating invalidates any earlier token. Once a user exists, the
command refuses to run with "Setup is already complete", `/setup` answers 404, and the
root URL redirects signed-in users to `/home`.

The plaintext token is also kept in `storage/app/onprem-setup-token` of the Pod that
generated it until it is used. With Pod-local storage that file disappears with the
Pod, so regenerate the token rather than searching for the file.

If the browser flow is unavailable, create the administrator directly. Without options
the command asks for the values interactively:

```bash
kubectl -n admin-panel exec --stdin --tty deployment/admin-panel-web -- \
  php artisan admin:create
```

For a non-interactive run pass `--name`, `--email`, and `--password`; omit
`--password` to have a strong one generated and printed once. Later,
`php artisan user:reset-password <email>` prints a new one-time password for any user.

Later users join by invitation from the Team page. Invitations expire after 7 days.

## Mail is optional

Many On-Prem installations have no outbound mail. The application detects this from
`MAIL_MAILER` and `MAIL_HOST` and degrades on purpose rather than failing:

- with `MAIL_MAILER=log`, or `smtp` without a host, mail is treated as not configured;
- invitations still work: the Team page shows a copyable link to share out of band;
- administrators reset passwords with `php artisan user:reset-password` or from the
  member page, without email;
- self-service password reset and email-change confirmation are switched off, and their
  routes answer 404 until SMTP is configured.

Set `config.mail.mailer: log` for an installation without SMTP. When a relay is
available, set `smtp`, `config.mail.host`, and the SMTP credentials in the Secret.

## OAuth sign-in

Google, Microsoft, and LinkedIn sign-in are off until both the client ID and the client
secret of a provider are set. There is no separate enable flag, and half a configuration
is logged as a warning and ignored.

| Provider | `config.extraEnv` | Secret key |
| --- | --- | --- |
| Google | `GOOGLE_CLIENT_ID`, optional `GOOGLE_REDIRECT_URI` | `GOOGLE_CLIENT_SECRET` |
| Microsoft | `MICROSOFT_CLIENT_ID`, optional `MICROSOFT_REDIRECT_URI` | `MICROSOFT_CLIENT_SECRET` |
| LinkedIn | `LINKEDIN_CLIENT_ID`, optional `LINKEDIN_REDIRECT_URI` | `LINKEDIN_CLIENT_SECRET` |

The redirect URI defaults to `APP_URL` plus `/oauth/<provider>/callback`, where the
provider segment is `google`, `microsoft`, or `linkedin-openid`. Set the variable only
when the provider must call back a different address. On-Prem sign-in through a provider
never creates an account: the person must already have been invited.

## Other optional application variables

These are not edition-gated. Leave them unset unless you need the feature.

| Feature | `config.extraEnv` (non-secret) | Secret key |
| --- | --- | --- |
| Application | `APP_DEBUG`, `APP_TIMEZONE`, `APP_LOCALE`, `APP_FALLBACK_LOCALE`, `FORCE_HTTPS`, `BCRYPT_ROUNDS` | None |
| Laravel logs | `LOG_CHANNEL`, `LOG_STACK`, `LOG_LEVEL`, `LOG_DEPRECATIONS_CHANNEL`, `LOG_STDERR_FORMATTER` | None |
| Sessions | `SESSION_LIFETIME`, `SESSION_ENCRYPT`, `SESSION_PATH`, `SESSION_DOMAIN`, `SESSION_SECURE_COOKIE`, `SESSION_SAME_SITE`, `SANCTUM_STATEFUL_DOMAINS` | None |
| Cache | `DB_CACHE_CONNECTION`, `DB_CACHE_TABLE`, `CACHE_PREFIX` | None |
| Maintenance | `APP_MAINTENANCE_DRIVER`, `APP_MAINTENANCE_STORE` | None |
| Read-only service DB | `SERVICE_DB_READONLY_HOST`, `SERVICE_DB_READONLY_PORT`, `SERVICE_DB_DATABASE_READONLY`, `SERVICE_DB_READONLY_USERNAME` | `SERVICE_DB_READONLY_PASSWORD` |
| Administrators | `ADMIN_EMAILS` | None |
| WProofreader Server limits API | `APP_SERVER_LIMITS_API_ENABLED`, `APP_SERVER_LIMITS_CACHE_TTL`, `APP_SERVER_LIMITS_BREAKER_TTL` | None |
| Browser extension store links | `EXTENSION_STORE_CHROME`, `EXTENSION_STORE_EDGE`, `EXTENSION_STORE_FIREFOX` | None |
| Product analytics | `POSTHOG_ENABLED`, `POSTHOG_HOST`, `POSTHOG_PROXY_HOST`, `POSTHOG_UI_HOST`, `GOOGLE_TAG_MANAGER_ENABLED`, `GOOGLE_TAG_MANAGER_ID` | `POSTHOG_KEY` |
| S3 public URL | `AWS_URL` | None |

Analytics are off by default and send nothing while their keys are unset. An On-Prem
customer who does not want telemetry leaves them unset.

Example:

```yaml
config:
  extraEnv:
    APP_TIMEZONE: Europe/Madrid
    SESSION_SECURE_COOKIE: "true"
    GOOGLE_CLIENT_ID: example.apps.googleusercontent.com

secrets:
  extraSecretEnv:
    GOOGLE_CLIENT_SECRET: replace-through-your-secret-manager
```

If `secrets.existingSecret` is set, place `GOOGLE_CLIENT_SECRET` directly in that
Kubernetes Secret. The `secrets.extraSecretEnv` map is ignored because the chart-managed
Secret is not rendered.

## Container tuning variables

The production image has defaults for nginx, PHP, PHP-FPM, OPcache, and its Laravel
entrypoint. Override these only after measuring a real workload. Put a shared override in
`config.extraEnv`; put a web-only override in `web.extraEnv`.

Supported groups are:

- nginx: `NGINX_HTTP_PORT`, `NGINX_HTTPS_PORT`, `NGINX_SERVER_NAME`, `NGINX_WEBROOT`,
  `NGINX_SERVER_TOKENS`, `NGINX_KEEPALIVE_TIMEOUT`, `NGINX_CLIENT_HEADER_TIMEOUT`,
  `NGINX_CLIENT_MAX_BODY_SIZE`, `NGINX_CLIENT_BODY_BUFFER_SIZE`,
  `NGINX_FASTCGI_BUFFERS`, `NGINX_FASTCGI_BUFFER_SIZE`, and
  `NGINX_FASTCGI_BUSY_BUFFER_SIZE`;
- PHP: `PHP_MEMORY_LIMIT`, `PHP_MAX_EXECUTION_TIME`, `PHP_MAX_INPUT_TIME`,
  `PHP_UPLOAD_MAX_FILE_SIZE`, `PHP_POST_MAX_SIZE`, `PHP_VARIABLES_ORDER`,
  `PHP_DISPLAY_ERRORS`, `PHP_DISPLAY_STARTUP_ERRORS`, `PHP_ERROR_REPORTING`,
  `PHP_LOG_ERRORS`, `PHP_ERROR_LOG`, `PHP_OPEN_BASEDIR`, `PHP_DATE_TIMEZONE`, and
  `PHP_SESSION_COOKIE_SECURE`;
- PHP-FPM: `PHP_FPM_LOG_LEVEL`, `PHP_FPM_ERROR_LOG`, `PHP_FPM_LOG_LIMIT`,
  `PHP_FPM_DAEMONIZE`, `PHP_FPM_RLIMIT_FILES`, `PHP_FPM_EMERGENCY_RESTART_THRESHOLD`,
  `PHP_FPM_EMERGENCY_RESTART_INTERVAL`, `PHP_FPM_PROCESS_CONTROL_TIMEOUT`,
  `PHP_FPM_POOL_NAME`, `PHP_FPM_PM_CONTROL`, `PHP_FPM_PM_MAX_CHILDREN`,
  `PHP_FPM_PM_START_SERVERS`, `PHP_FPM_PM_MIN_SPARE_SERVERS`,
  `PHP_FPM_PM_MAX_SPARE_SERVERS`, `PHP_FPM_PM_MAX_REQUESTS`,
  `PHP_FPM_CATCH_WORKERS_OUTPUT`, `PHP_FPM_CLEAR_ENV`,
  `PHP_FPM_DECORATE_WORKERS_OUTPUT`, and `PHP_FPM_ACCESS_LOG`;
- OPcache: `PHP_OPCACHE_ENABLE`, `PHP_OPCACHE_MEMORY_CONSUMPTION`,
  `PHP_OPCACHE_MAX_ACCELERATED_FILES`, `PHP_OPCACHE_INTERNED_STRINGS_BUFFER`,
  `PHP_OPCACHE_VALIDATE_TIMESTAMPS`, `PHP_OPCACHE_REVALIDATE_FREQ`,
  `PHP_OPCACHE_JIT_BUFFER_SIZE`, and `PHP_OPCACHE_JIT`;
- proxy/TLS: `CUSTOM_PROXY_NETWORKS`, `HTTP2_ENABLED`, `HTTP2_MAX_STREAMS`,
  `HTTP2_CHUNK_SIZE`, and `HTTP2_PUSH_PRELOAD`;
- entrypoint: `SHOW_WELCOME_MESSAGE`, `SHELL_DEBUG`, `APP_BASE_DIR`, `PHP_PING_PATH`,
  `SKIP_LARAVEL_CONFIGURATION`, `LARAVEL_MIGRATION_ISOLATION`,
  `LARAVEL_SETUP_STORAGE_LINK`, and `LARAVEL_CACHE_ENABLED`.

Do not override `NGINX_HTTP_PORT`, `PHP_PING_PATH`, `SKIP_ENTRYPOINT_CONFIG`,
`SKIP_WEBSERVER_CONFIGURATION`, or the `LARAVEL_PROVISION_*` and `LARAVEL_SEED_*`
variables unless you also update the chart's ports, probes, and role behavior. The chart
owns those parts of the container contract. Do not set
`SKIP_LARAVEL_CONFIGURATION=true` in On-Prem: it also skips the setup-token step.
Entrypoint variables reach the web Pods and the migration Job only; the worker and the
scheduler bypass the entrypoint.

Development-only Docker Compose variables such as `FWD_*`, `USER_ID`, `GROUP_ID`,
`LARAVEL_SAIL`, `XDEBUG_*`, `PHP_VERSION`, `NODE_VERSION`, `SERVICE_DB_CONTEXTS`,
`SERVICE_DB_APPSERVER_USER`, `SERVICE_DB_APPSERVER_PASSWORD`, and `LICENSE_TICKET_ID`
do not belong in an Admin-panel Kubernetes release. The last three belong to the
WProofreader side of the stack.

## What the On-Prem edition expects from the rest of the stack

- **Service database from `db-manager` 6.17.0.0 or newer.** That release grants the
  Admin-panel user `INSERT` and `UPDATE` on `subscription_bool_settings`, which product
  activation uses to remove WProofreader branding. On an older schema activation still
  succeeds and the log carries "could not enable branding removal".
- **The scheduler role must run.** On-Prem schedules `onprem:reconcile-services` hourly
  as the repair path for half-finished activations. The chart deploys the scheduler by
  default; do not set `scheduler.enabled: false` in On-Prem.
- **A reachable WProofreader Server** at `APP_SERVER_INTERNAL_URL`, with its license
  installed. Without it the license status becomes `unavailable` after
  `LICENSE_GRACE_SECONDS` and users are locked out.

## Environment profiles

`APP_ENV` controls Laravel's runtime environment. It is not a Kubernetes namespace and it
is independent from `APP_EDITION`.

| Deployment | Recommended settings |
| --- | --- |
| Local smoke test | `config.appEnv: local`, `APP_DEBUG: "true"`, mailer `log`, one web Pod, port-forward, throwaway databases |
| Staging | `config.appEnv: staging`, `APP_DEBUG: "false"`, real TLS, isolated databases and bucket, non-production integration credentials |
| Production | `config.appEnv: production`, `APP_DEBUG: "false"`, real TLS, external Secret management, backups, durable uploads, resource sizing, and monitoring |

Never reuse database credentials, OAuth applications, buckets, or `APP_KEY` values
across local, staging, and production environments.

## Inspect the effective environment safely

Inspect the generated non-secret ConfigMap:

```bash
kubectl -n admin-panel get configmap admin-panel-env -o yaml
```

List Secret key names without decoding values:

```bash
kubectl -n admin-panel describe secret admin-panel-secrets
```

After changing a chart-managed Secret, `helm upgrade` rolls the Pods because the chart
adds a checksum annotation. If you use `secrets.existingSecret`, restart the roles after
rotating that external Secret:

```bash
kubectl -n admin-panel rollout restart deployment/admin-panel-web
kubectl -n admin-panel rollout restart deployment/admin-panel-worker
kubectl -n admin-panel rollout restart deployment/admin-panel-scheduler
```
