# Quick start: deploy Admin-panel

This guide installs the Admin-panel Helm release and verifies the application through
its health endpoint. It covers this chart only. If you still need MySQL or WProofreader,
read [Prepare the dependencies](#2-prepare-the-dependencies) first.

The commands assume the repository is your current directory and use:

- Helm release: `admin-panel`
- Kubernetes namespace: `admin-panel`
- local values file: `values.local.yaml` (ignored by Git)
- Kubernetes Secret: `admin-panel-secrets`

## 1. Check your workstation and cluster

You need Kubernetes 1.27 or newer, Helm 3.12 or newer, `kubectl`, and `openssl`.

```bash
kubectl cluster-info
kubectl version --client
helm version --short
openssl version
```

Confirm that `kubectl` points at the cluster you intend to change:

```bash
kubectl config current-context
```

Create the namespace and confirm that you can deploy into it:

```bash
kubectl create namespace admin-panel
kubectl auth can-i create deployments.apps --namespace admin-panel
kubectl auth can-i create jobs.batch --namespace admin-panel
kubectl auth can-i create secrets --namespace admin-panel
```

`AlreadyExists` from the first command is harmless. Each authorization check must print
`yes`.

## 2. Prepare the dependencies

Admin-panel needs three things before Helm can start it:

1. A MySQL database for Admin-panel. The application user needs permission to create
   and alter tables because the migration hook runs on install and upgrade.
2. A WProofreader service database. Provision its schema and the Admin-panel database
   user with the `db-manager` job from `wproofreader-helm`; do not run Admin-panel
   migrations against this database.
3. A running WProofreader Server with its On-Prem license installed. When using
   `wproofreader-helm`, provide the license through its `licenseTicketID` value.

For the WProofreader chart's current defaults, the service database is `cloud_service`
and the provisioned Admin-panel user is `app_service`. If your deployment overrides
those names, use the overridden values here too.

### Prepare MySQL

The chart does not install MySQL. Use a MySQL 8.4 server that you operate, or a managed
service such as Amazon RDS or Cloud SQL. Admin-panel and WProofreader can share one
server or use separate ones. The server must be reachable from the `admin-panel`
namespace.

Create the Admin-panel database and its user as a MySQL administrator:

```sql
CREATE DATABASE admin_panel_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'admin_panel'@'%' IDENTIFIED BY 'REPLACE_WITH_APP_DB_PASSWORD';
GRANT ALL PRIVILEGES ON admin_panel_db.* TO 'admin_panel'@'%';
```

The user needs full rights on its own database because the migration hook creates and
alters tables. Its password is the value for `DB_PASSWORD` in the next section. Below,
`APP_DB_HOST` is the host name of this server as seen from the cluster.

The WProofreader service database is created by `wproofreader-helm` in the next step. It
needs only an administrative MySQL account that its provisioning Job can use.

### Install WProofreader Server with wproofreader-helm

Skip this if WProofreader Server already runs with a provisioned service database.
Otherwise install the
[wproofreader-helm](https://github.com/WebSpellChecker/wproofreader-helm) chart with
database provisioning switched on. Its `db-manager` Job creates the `cloud_service`
schema and the `appserver` and `app_service` users. Install it into the Admin-panel
namespace so the routing guide can co-host WProofreader without cross-namespace
references.

```bash
git clone https://github.com/WebSpellChecker/wproofreader-helm.git /tmp/wproofreader-helm
kubectl -n admin-panel create secret generic wproofreader-db-credentials \
  --from-literal=root-password='REPLACE_WITH_MYSQL_ADMIN_PASSWORD' \
  --from-literal=appserver-password='REPLACE_WITH_APPSERVER_PASSWORD' \
  --from-literal=admin-panel-password='REPLACE_WITH_SERVICE_DB_PASSWORD'
helm upgrade --install wproofreader-app /tmp/wproofreader-helm/wproofreader \
  --namespace admin-panel \
  --set licenseTicketID='REPLACE_WITH_LICENSE_TICKET_ID' \
  --set database.enabled=true \
  --set database.host=SERVICE_DB_HOST \
  --set database.existingSecret=wproofreader-db-credentials \
  --set databaseProvisioning.enabled=true \
  --timeout 10m
kubectl -n admin-panel rollout status deployment/wproofreader-app --timeout=10m
```

Notes on the values:

- `SERVICE_DB_HOST` is the MySQL server for the WProofreader database, as seen from the
  cluster.
- `root-password` is the password of the administrative account the provisioning Job
  logs in with, `root` by default; change the account with
  `databaseProvisioning.rootUser`.
- `admin-panel-password` is the value for `SERVICE_DB_PASSWORD` in the next section.
- `licenseTicketID` is your WProofreader On-Prem license ticket. Admin-panel reads the
  resulting license status from WProofreader and never sees the ticket.
- The WProofreader Service is `wproofreader-app` on port 80, so the in-cluster API URL
  is `http://wproofreader-app.admin-panel.svc.cluster.local/wscservice/api`.
- If your WProofreader images are in a private registry, set their repository values and
  `imagePullSecrets` before installing the WProofreader release.

Check each database from inside the cluster. Read each password into a shell variable
first so it never appears in your shell history, then run a temporary MySQL client Pod
that is deleted when the query finishes:

```bash
if [ -n "${ZSH_VERSION:-}" ]; then
  read -r -s 'APP_DB_PASSWORD?Admin-panel DB password: '
else
  read -r -s -p 'Admin-panel DB password: ' APP_DB_PASSWORD
fi
printf '\n'
kubectl -n admin-panel run admin-panel-db-check \
  --rm --attach --restart=Never --image=mysql:8.4 \
  --env="MYSQL_PWD=${APP_DB_PASSWORD}" \
  -- mysql --host=APP_DB_HOST --port=3306 --user=admin_panel \
  --execute='SELECT DATABASE(), CURRENT_USER(), VERSION();' admin_panel_db
unset APP_DB_PASSWORD

if [ -n "${ZSH_VERSION:-}" ]; then
  read -r -s 'SERVICE_DB_PASSWORD?WProofreader DB password: '
else
  read -r -s -p 'WProofreader DB password: ' SERVICE_DB_PASSWORD
fi
printf '\n'
kubectl -n admin-panel run service-db-check \
  --rm --attach --restart=Never --image=mysql:8.4 \
  --env="MYSQL_PWD=${SERVICE_DB_PASSWORD}" \
  -- mysql --host=SERVICE_DB_HOST --port=3306 --user=app_service \
  --execute='SELECT DATABASE(), CURRENT_USER(), VERSION();' cloud_service
unset SERVICE_DB_PASSWORD
```

Replace `APP_DB_HOST` and `SERVICE_DB_HOST`. A successful command prints one row and
exits with status 0. A wrong password prints `ERROR 1045 (28000): Access denied` and
exits with status 1. Do not use an interactive `mysql --password` prompt inside
`kubectl run`; the prompt is lost when kubectl attaches and the Pod hangs waiting for
input. If the database uses a private CA, configure the MySQL client for that CA rather
than disabling certificate verification in production.

Check the WProofreader server version and license from temporary Pods. The URL below
is the in-cluster address of the release installed above; use your own when
WProofreader runs elsewhere:

```bash
kubectl -n admin-panel run wproofreader-version-check \
  --rm --attach --restart=Never --image=curlimages/curl:8.22.0 \
  -- curl --fail --show-error --silent \
  'http://wproofreader-app.admin-panel.svc.cluster.local/wscservice/api?cmd=ver'

kubectl -n admin-panel run wproofreader-license-check \
  --rm --attach --restart=Never --image=curlimages/curl:8.22.0 \
  -- curl --fail --show-error --silent \
  'http://wproofreader-app.admin-panel.svc.cluster.local/wscservice/api?cmd=license_status'
```

The first response must contain `"ProgramVersion"` with the WProofreader version. The
second must be JSON containing `"valid":true`.

## 3. Create the Admin-panel Secret

Generate a Laravel application key once. Keep the same key for the lifetime of this
installation; changing it invalidates encrypted application data and sessions.

```bash
printf 'base64:%s\n' "$(openssl rand -base64 32)"
```

Copy the printed value and create the Secret. Replace all three placeholder values:

```bash
kubectl -n admin-panel create secret generic admin-panel-secrets \
  --from-literal=APP_KEY='base64:REPLACE_WITH_GENERATED_VALUE' \
  --from-literal=DB_PASSWORD='REPLACE_WITH_APP_DB_PASSWORD' \
  --from-literal=SERVICE_DB_PASSWORD='REPLACE_WITH_SERVICE_DB_PASSWORD'
```

This command is suitable for a first non-production install. In production, create the
same three keys through External Secrets, Sealed Secrets, SOPS, Vault, or your platform's
secret manager. Do not commit a filled-in Secret manifest or pass secrets with Helm
`--set`.

Verify names only, without printing Secret values:

```bash
kubectl -n admin-panel describe secret admin-panel-secrets
```

SMTP, OAuth, and object storage need additional keys. The complete list and their Helm
locations are in [Environment variables](ENVIRONMENT_VARIABLES.md).

## 4. Create the values file

```bash
cp docs/examples/values-minimal.yaml values.local.yaml
```

Edit these fields in `values.local.yaml`:

| Value | What to enter |
| --- | --- |
| `config.appUrl` | The URL a person's browser will use. For this port-forward flow, keep `http://127.0.0.1:8080`. |
| `config.appServerUrl` | Public WProofreader server API URL reachable by browsers. |
| `config.appServerInternalUrl` | Optional WProofreader server API URL reachable inside the cluster. |
| `config.db.*` | Admin-panel database host, port, name, and application username. |
| `config.serviceDb.*` | WProofreader database host, port, name, and the user created for Admin-panel. |
| `config.mail.mailer` | Keep `log` for a smoke test; use `smtp` only after adding a reachable SMTP host and credentials. |

Keep `secrets.existingSecret: admin-panel-secrets`. The values file should contain no
passwords.

## 5. Render before changing the cluster

These commands catch missing required values, invalid value types, and malformed
Kubernetes resources:

```bash
helm lint ./admin-panel --values values.local.yaml
helm template admin-panel ./admin-panel \
  --namespace admin-panel \
  --values values.local.yaml \
  > /tmp/admin-panel-rendered.yaml
```

If `kubeconform` is installed, validate the standard Kubernetes resources too:

```bash
kubeconform -strict -summary -kubernetes-version 1.27.0 \
  /tmp/admin-panel-rendered.yaml
```

Finally, ask the target API server to validate the rendered release without installing
it:

```bash
helm install admin-panel ./admin-panel \
  --namespace admin-panel \
  --values values.local.yaml \
  --dry-run=server \
  --hide-secret
```

## 6. Install Admin-panel

Use `upgrade --install` so the same command works for the first install and later
configuration updates:

```bash
helm upgrade --install admin-panel ./admin-panel \
  --namespace admin-panel \
  --values values.local.yaml \
  --atomic \
  --timeout 10m
```

Before the Deployments are created or updated, the `admin-panel-migrate` Helm hook waits
for the primary database and runs its migrations. `--atomic` rolls the Helm release back
if that hook or the rollout fails; it does not roll back database migrations.

## 7. Prove the application is healthy

Wait for every long-running role:

```bash
kubectl -n admin-panel rollout status deployment/admin-panel-web --timeout=5m
kubectl -n admin-panel rollout status deployment/admin-panel-worker --timeout=5m
kubectl -n admin-panel rollout status deployment/admin-panel-scheduler --timeout=5m
kubectl -n admin-panel get pods \
  --selector app.kubernetes.io/instance=admin-panel
```

All Pods should show `Running`, and every readiness column should be complete. Run the
chart's application-level test:

```bash
helm test admin-panel --namespace admin-panel
```

The test calls Laravel's `/up` route through the Kubernetes Service and must finish with
`Phase: Succeeded`. Do not add `--logs`: the chart deletes the test Pod as soon as it
succeeds, so Helm cannot fetch its logs and reports an error even though the test passed.

For the no-routing quick start, keep this command running in one terminal:

```bash
kubectl -n admin-panel port-forward service/admin-panel-web 8080:80
```

Then use another terminal:

```bash
curl --fail --show-error --silent http://127.0.0.1:8080/up
curl --head http://127.0.0.1:8080/
```

The health request must return successfully. The root request normally redirects to the
sign-in page. Open <http://127.0.0.1:8080> in a browser for the final check.

## 8. Create the first administrator

On a new On-Prem installation, generate the one-time setup URL from the web Pod:

```bash
kubectl -n admin-panel exec deployment/admin-panel-web -- \
  php artisan app:setup-token --regenerate --no-ansi
```

Open the printed URL within 24 hours and create the organization and first administrator.
Regenerating the token invalidates any earlier token. If a user already exists, the
command refuses to create another setup token; invite additional users from the Team
page instead.

## 9. If installation fails

Start with the release, failed hook, Pod events, and role logs:

```bash
helm status admin-panel --namespace admin-panel
kubectl -n admin-panel get jobs,pods
kubectl -n admin-panel logs job/admin-panel-migrate --all-containers
kubectl -n admin-panel get events --sort-by=.lastTimestamp
kubectl -n admin-panel logs deployment/admin-panel-web --all-containers --tail=200
kubectl -n admin-panel logs deployment/admin-panel-worker --all-containers --tail=200
kubectl -n admin-panel logs deployment/admin-panel-scheduler --all-containers --tail=200
```

The successful migration Job is deleted by its Helm hook policy, so `NotFound` after a
successful install is expected. A failed Job is retained for inspection.

Common causes are a database hostname that is not resolvable inside the cluster, a
password mismatch, an Admin-panel database user without migration privileges, or a
missing key in `admin-panel-secrets`.

## Next steps

- Add external access with the [Gateway API or Ingress examples](examples/README.md).
- Configure every application setting through the
  [environment-variable contract](ENVIRONMENT_VARIABLES.md).
- Externalize uploads before scaling web Pods; see the
  [storage example](examples/values-storage.yaml).
- Read the [operator guide](README.md) before a production rollout.
