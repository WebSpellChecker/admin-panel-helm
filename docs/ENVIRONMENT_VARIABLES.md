# Environment variables on Kubernetes

This page maps Helm values to the environment variables consumed by Admin-panel `3.0.0` or newer.
The chart stores non-secret variables in a ConfigMap and reads secrets from a Kubernetes Secret.
It does not use a Laravel `.env` file.

## How values become environment variables

Each role receives the same base environment:

1. The chart-managed ConfigMap for non-secret values.
2. The chart-managed Secret, or `secrets.existingSecret`.
3. Role-specific variables from `web.extraEnv`, `worker.extraEnv`,
   or `scheduler.extraEnv` where applicable.

The web Pods and migration Job run the image entrypoint scripts.
The worker and scheduler Pods set `SKIP_ENTRYPOINT_CONFIG=true` and start Artisan directly. nginx,
PHP-FPM, and entrypoint tuning does not apply to the worker or scheduler.

Use `config.extraEnv` for an application or container variable that every role needs.
Use `secrets.extraSecretEnv` for a secret variable that every role needs.
Do not put passwords, tokens, private keys, webhook secrets,
or OAuth client secrets in `config.extraEnv`.

Do not repeat a chart-managed variable in an `extraEnv` map.
Set its documented Helm value.
Duplicate environment keys can produce inconsistent results.

## Chart-managed non-secret variables

| Environment variable | Helm value | Default or behavior |
| --- | --- | --- |
| `APP_NAME` | `config.appName` | `Admin-panel` |
| `APP_ENV` | `config.appEnv` | `production` |
| `APP_URL` | `config.appUrl` | Required. Browser-facing base URL. Invitation links and the setup URL are signed with it, so it must be the address people use. |
| `APP_SERVER_URL` | `config.appServerUrl` | Required. Browser-facing WProofreader Server API URL. |
| `APP_SERVER_INTERNAL_URL` | `config.appServerInternalUrl` | Optional. When empty, the application uses `APP_SERVER_URL`. See [WProofreader Server URLs](#wproofreader-server-urls). |
| `LOG_OUTPUT_LEVEL` | `config.logOutputLevel` | `info`. Controls container, nginx, and PHP-FPM output. |
| `SSL_MODE` | `config.sslMode` | `off`. Terminate TLS at the Gateway or Ingress. |
| `PROXY_TYPE` | `config.proxyType` | `generic`. Also supports `aws`, `cloudflare`, and image-supported `direct`. |
| `SESSION_DRIVER` | `config.sessionDriver` | `database`. Keep it: admin password resets revoke the target user's sessions only with this driver, and it is required for more than one web Pod. |
| `CACHE_STORE` | `config.cacheStore` | `database`. The license answer cache lives here, so every Pod shares one license state. |
| `QUEUE_CONNECTION` | `config.queueConnection` | `database` |
| `FILESYSTEM_DISK` | `config.filesystemDisk` | `local` |
| `JETSTREAM_PROFILE_PHOTO_DISK` | `config.profilePhotoDisk` | `public` |
| `DB_HOST` | `config.db.host` | Required |
| `DB_PORT` | `config.db.port` | `3306` |
| `DB_DATABASE` | `config.db.database` | `admin_panel_db` |
| `DB_USERNAME` | `config.db.username` | `admin_panel` |
| `SERVICE_DB_HOST` | `config.serviceDb.host` | Omitted when empty. The application uses `DB_HOST`. |
| `SERVICE_DB_PORT` | `config.serviceDb.port` | `3306` |
| `SERVICE_DB_DATABASE` | `config.serviceDb.database` | Chart default `app_service_db`. Set it to `cloud_service`, the name WProofreader `db-manager` provisions. The examples already do. |
| `SERVICE_DB_USERNAME` | `config.serviceDb.username` | The application uses `DB_USERNAME` when empty. Set this value when the service DB host differs. Use the Admin-panel user that `db-manager` creates, `app_service` by default. |
| `MAIL_MAILER` | `config.mail.mailer` | Chart default `smtp`. The application also supports `log`. See [Mail is optional](#mail-is-optional). |
| `MAIL_HOST` | `config.mail.host` | Omitted when empty. With `smtp`, a non-empty host is what marks mail as configured. |
| `MAIL_PORT` | `config.mail.port` | `587` |
| `MAIL_ENCRYPTION` | `config.mail.encryption` | `tls`. The Laravel version in the image does not use this value. The port sets the TLS mode: port `465` uses implicit TLS, and any other port uses STARTTLS when the server offers it. |
| `MAIL_FROM_ADDRESS` | `config.mail.fromAddress` | `hello@example.com` |
| `MAIL_FROM_NAME` | `config.mail.fromName` | `Admin-panel` |
| `AWS_DEFAULT_REGION` | `config.objectStorage.region` | Omitted when empty |
| `AWS_BUCKET` | `config.objectStorage.bucket` | Omitted when empty |
| `AWS_ENDPOINT` | `config.objectStorage.endpoint` | Omitted when empty. The S3 client then uses the AWS regional endpoint. Set it for other S3-compatible stores, such as MinIO or Ceph RGW. |
| `AWS_USE_PATH_STYLE_ENDPOINT` | `config.objectStorage.usePathStyleEndpoint` | Rendered only when `endpoint` is set |
| `LARAVEL_MIGRATION_WAIT_DB_TIMEOUT` | `migrations.waitDbTimeout` | Migration Pod only. The chart default is `120` seconds. The image default is `10`. |

The chart also sets internal variables for each role.
Do not set these variables.
See [Other application and container variables](#other-application-and-container-variables).

Laravel uses the `AWS_*` names for Amazon S3 and other S3-compatible stores.

### WProofreader Server URLs

Admin-panel uses two addresses for WProofreader Server:

- `APP_SERVER_URL` is required.
  The browser, the in-app widget, and the browser extension send their requests to this address,
  so it must be reachable from the users' network.
- `APP_SERVER_INTERNAL_URL` is optional.
  Admin-panel uses it for its own server-side calls, such as the license check
  and service management.
  When it is not set, Admin-panel sends these calls to `APP_SERVER_URL`.

Leave `APP_SERVER_INTERNAL_URL` empty when the Admin-panel Pods can reach `APP_SERVER_URL`.
Set it when they cannot, for example when the public DNS name does not resolve inside the cluster,
or when you want these calls to stay inside the cluster.
Use the WProofreader Service address:

```yaml
config:
  appServerUrl: https://wproofreader.example.com/wscservice/api
  appServerInternalUrl: http://wproofreader-app.wsc.svc.cluster.local/wscservice/api
```

### Logging

`LOG_OUTPUT_LEVEL` is not Laravel's minimum application log level.
The image defaults `LOG_CHANNEL` to `stdout`, which writes JSON to the container log.
Set `LOG_LEVEL` in `config.extraEnv` when you need to change Laravel logging:

```yaml
config:
  logOutputLevel: info
  extraEnv:
    LOG_LEVEL: info
```

## Chart-managed secret variables

When `secrets.existingSecret` is empty, the chart renders these keys from Helm values.
When it is set, the chart renders no Secret: create the keys you need in
that existing Secret instead.

| Environment variable | Helm value | Requirement | When needed |
| --- | --- | --- | --- |
| `APP_KEY` | `secrets.appKey` | Required | Every installation. Keep it stable: invitation links and the setup URL are signed with it. |
| `DB_PASSWORD` | `secrets.db.password` | Required | Every installation. The password of the Admin-panel database user. |
| `SERVICE_DB_PASSWORD` | `secrets.serviceDb.password` | Conditional | Required when the service database uses a separate account. If omitted, the application uses `DB_PASSWORD`. |
| `MAIL_USERNAME` | `secrets.mail.username` | Conditional | SMTP authentication when the mail server requires a username. |
| `MAIL_PASSWORD` | `secrets.mail.password` | Conditional | SMTP authentication when the mail server requires a password. |
| `AWS_ACCESS_KEY_ID` | `secrets.s3.accessKeyId` | Conditional | Static credentials for S3-compatible storage. Omit when workload identity supplies credentials. |
| `AWS_SECRET_ACCESS_KEY` | `secrets.s3.secretAccessKey` | Conditional | Static credentials for S3-compatible storage. Omit when workload identity supplies credentials. |

`Required` means that the Secret must contain the key.
`Conditional` means that the requirement depends on the selected feature or database configuration.

Admin-panel has no root database credentials: migrations connect as `DB_USERNAME`,
which therefore needs the privileges to create and alter tables.

With an existing Secret, start with the three keys in
[`examples/secret.yaml`](examples/secret.yaml).
Add optional keys only when the matching feature is enabled.
Empty keys are unnecessary.

## License

Configure the license in WProofreader Server through the `wproofreader-helm`
`licenseTicketID` value.
Admin-panel reads only the license status.
It uses `APP_SERVER_INTERNAL_URL`, or `APP_SERVER_URL` when the internal URL is empty.
Optional `LICENSE_*` variables control caching, timeouts, and TLS verification.
The [WProofreader documentation](https://docs.wproofreader.com/) describes them.
Set them in `config.extraEnv`.

## Mail is optional

The application continues to work without outbound mail.
It uses `MAIL_MAILER` and `MAIL_HOST` to detect this configuration:

- `MAIL_MAILER=log`, or `smtp` without a host, disables outbound mail.
- The Team page provides an invitation link that you can copy.
- Administrators can reset passwords from the member page or with `php artisan user:reset-password`.
- The application disables self-service password reset and email-change confirmation.
  Their routes return 404 until SMTP is configured.

Set `config.mail.mailer: log` for an installation without SMTP.
When a relay is available, set `smtp`, `config.mail.host`, and the SMTP credentials in the Secret.

## OAuth sign-in

Google, Microsoft, and LinkedIn sign-in need both a client ID and a client secret.
There is no separate enable flag.
If one value is missing, the application logs a warning and disables that provider.

| Provider | `config.extraEnv` | Secret key |
| --- | --- | --- |
| Google | `GOOGLE_CLIENT_ID`, optional `GOOGLE_REDIRECT_URI` | `GOOGLE_CLIENT_SECRET` |
| Microsoft | `MICROSOFT_CLIENT_ID`, optional `MICROSOFT_REDIRECT_URI` | `MICROSOFT_CLIENT_SECRET` |
| LinkedIn | `LINKEDIN_CLIENT_ID`, optional `LINKEDIN_REDIRECT_URI` | `LINKEDIN_CLIENT_SECRET` |

The redirect URI defaults to `APP_URL` plus `/oauth/<provider>/callback`,
where the provider segment is `google`, `microsoft`, or `linkedin-openid`.
Set the variable only when the provider must call back a different address.
Provider sign-in never creates an account: the person must already have been invited.

## Other application and container variables

The Admin-panel image supports more application and container variables.
These include session, logging, analytics, nginx, PHP, PHP-FPM, and OPcache settings.
The [WProofreader documentation](https://docs.wproofreader.com/) describes them.
Leave them unset unless you need the related feature.
Change container settings only after you measure a representative workload.

Pass them to the chart this way:

| Variable type | Helm value |
| --- | --- |
| Non-secret, every role | `config.extraEnv` |
| Secret, every role | `secrets.extraSecretEnv`, or the existing Secret |
| Web role only, such as nginx and PHP-FPM tuning | `web.extraEnv` |

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

If `secrets.existingSecret` is set, the chart ignores `secrets.extraSecretEnv`.
Put secret keys such as `GOOGLE_CLIENT_SECRET` directly in that Kubernetes Secret.

The chart sets variables that control ports, probes, and role behavior.
Do not override `DB_CONNECTION`, `NGINX_HTTP_PORT`, `PHP_PING_PATH`, `SKIP_ENTRYPOINT_CONFIG`,
`SKIP_WEBSERVER_CONFIGURATION`, `LARAVEL_ENVIRONMENT_VALIDATION`,
or the `LARAVEL_PROVISION_*` and `LARAVEL_SEED_*` variables.
Do not set `SKIP_LARAVEL_CONFIGURATION=true`.
It also skips the setup-token step.

The worker and scheduler bypass the entrypoint.
Entrypoint variables affect only the web Pods and migration Job. nginx
and PHP-FPM variables affect only the web Pods.

## Inspect the effective environment safely

Inspect the generated non-secret ConfigMap:

```bash
kubectl -n wsc get configmap admin-panel-env -o yaml
```

List Secret key names without decoding values:

```bash
kubectl -n wsc get secret admin-panel-secrets \
  -o go-template='{{range $key, $_ := .data}}{{printf "%s\n" $key}}{{end}}'
```

After changing a chart-managed Secret, `helm upgrade` rolls the Pods because the chart adds
a checksum annotation.
An existing Secret needs a manual restart.
See [Secret rotation](README.md#secret-rotation).
