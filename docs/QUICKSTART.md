# Quick start: deploy Admin-panel

Use this guide to install Admin-panel and verify its health endpoint.
If MySQL or WProofreader is not ready, start with
[Prepare the dependencies](#2-prepare-the-dependencies).

The commands assume the repository is your current directory and use:

- Helm release: `admin-panel`
- Kubernetes namespace: `wsc`
- local values file: `values.local.yaml` (ignored by Git)
- Kubernetes Secret: `admin-panel-secrets`

## 1. Check your workstation and cluster

You need Kubernetes 1.27 or newer, Helm 3.15 or newer, `kubectl`, and `openssl`.

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

Create or update the namespace.
Then confirm that you can deploy into it:

```bash
kubectl create namespace wsc --dry-run=client -o yaml | kubectl apply --server-side -f -
kubectl auth can-i create deployments.apps --namespace wsc
kubectl auth can-i create jobs.batch --namespace wsc
kubectl auth can-i create secrets --namespace wsc
```

Each authorization check must print `yes`.

## 2. Prepare the dependencies

If you do not have the dependencies yet, the [Kubernetes installation guide](https://docs.wproofreader.com/deployment/installation/kubernetes)
installs MySQL, WProofreader Server, and Admin-panel step by step.

Admin-panel needs three external components:

1. A MySQL database for Admin-panel.
   The application user needs permission to create and alter tables because the migration hook runs
   on install and upgrade.
2. A WProofreader service database.
   Provision its schema and the Admin-panel database user with the `db-manager` job
   from `wproofreader-helm`.
   Do not run Admin-panel migrations against this database.
3. A running WProofreader Server with its license installed.
   When using `wproofreader-helm`, provide the license through its `licenseTicketID` value.

The examples use the WProofreader defaults: database `cloud_service`
and Admin-panel user `app_service`.
Use your configured names if they differ.

### Prepare MySQL

The chart does not install MySQL.
Use a MySQL 8.4 server that you operate, a managed service such as Amazon RDS or Cloud SQL,
or the [MySQL Operator for Kubernetes](https://dev.mysql.com/doc/mysql-operator/en/).
Admin-panel and WProofreader can share one server or use separate ones.
The server can run in any namespace or outside the cluster,
as long as the Admin-panel Pods can reach it.

Create the Admin-panel database and its user as a MySQL administrator:

```sql
CREATE DATABASE admin_panel_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'admin_panel'@'%' IDENTIFIED BY 'REPLACE_WITH_APP_DB_PASSWORD';
GRANT ALL PRIVILEGES ON admin_panel_db.* TO 'admin_panel'@'%';
```

The user needs full rights on its database because the migration hook creates and alters tables.
Its password becomes `DB_PASSWORD` in the next section.

Provision the WProofreader service database with `wproofreader-helm`.
Do not create an empty database in its place.
Admin-panel needs the schema and seed data from `db-manager`.

### Prepare WProofreader Server

Skip this step when WProofreader Server already runs with a provisioned service database.
Otherwise follow [Connect to and provision a database](https://github.com/WebSpellChecker/wproofreader-helm/blob/main/README.md#connect-to-and-provision-a-database)
in `wproofreader-helm`.
Install both charts in the `wsc` namespace unless your cluster requires separate namespaces.

This guide uses the WProofreader defaults: release and Service name `wproofreader-app`,
database `cloud_service`, and Admin-panel database user `app_service`.
Keep the password for that user.
It becomes `SERVICE_DB_PASSWORD` in the Admin-panel Secret.

Configure the WProofreader license in its chart, then check it from a temporary Pod:

```bash
kubectl -n wsc run wproofreader-license-check \
  --rm --attach --restart=Never --image=curlimages/curl:8.22.0 \
  -- curl --fail --show-error --silent \
  'http://wproofreader-app.wsc.svc.cluster.local/wscservice/api?cmd=license_status'
```

> [!IMPORTANT]
> The response must contain `"valid":true`. Do not continue until it does.

## 3. Create the Admin-panel Secret

Generate a Laravel application key once.

> [!WARNING]
> Keep the same key for the lifetime of this installation. Changing it invalidates
> encrypted application data and sessions.

```bash
printf 'base64:%s\n' "$(openssl rand -base64 32)"
```

Copy the printed value and create the Secret.
Replace all three placeholder values:

```bash
kubectl -n wsc create secret generic admin-panel-secrets \
  --from-literal=APP_KEY='base64:REPLACE_WITH_GENERATED_VALUE' \
  --from-literal=DB_PASSWORD='REPLACE_WITH_APP_DB_PASSWORD' \
  --from-literal=SERVICE_DB_PASSWORD='REPLACE_WITH_SERVICE_DB_PASSWORD'
```

This command is suitable for a non-production installation.
In production, create the same keys with your secret-management system.
Do not commit populated Secret manifests or pass secrets with Helm `--set`.

Verify names only, without printing Secret values:

```bash
kubectl -n wsc describe secret admin-panel-secrets
```

You need additional keys for SMTP, OAuth, and object storage.
See [Environment variables](ENVIRONMENT_VARIABLES.md).

## 4. Create the values file

Copy the minimal example as your values file:

```bash
cp docs/examples/values-minimal.yaml values.local.yaml
```

Without a clone of this repository, download the example instead:

```bash
curl -fsSL -o values.local.yaml \
  https://raw.githubusercontent.com/WebSpellChecker/admin-panel-helm/main/docs/examples/values-minimal.yaml
```

The file holds only non-secret settings.
Git ignores it in this repository.
For a long-lived installation, keep it in your own configuration repository.
Edit these fields in `values.local.yaml`:

| Value | What to enter |
| --- | --- |
| `config.appUrl` | The URL a person's browser will use. For this port-forward flow, keep `http://127.0.0.1:8080`. |
| `config.appServerUrl` | Public WProofreader server API URL reachable by browsers. |
| `config.appServerInternalUrl` | Optional in-cluster URL for Admin-panel calls. If empty, Admin-panel uses `config.appServerUrl`. See [WProofreader Server URLs](ENVIRONMENT_VARIABLES.md#wproofreader-server-urls). |
| `config.db.*` | Admin-panel database host, port, name, and application username. |
| `config.serviceDb.*` | WProofreader database host, port, name, and the user created for Admin-panel. |
| `config.mail.mailer` | Keep `log` for a smoke test. Use `smtp` after you add a reachable SMTP host and credentials. |

Keep `secrets.existingSecret: admin-panel-secrets` and leave passwords out of the values file.

## 5. Render before changing the cluster

These commands catch missing required values, invalid value types,
and malformed Kubernetes resources:

```bash
helm lint ./admin-panel --values values.local.yaml
helm template admin-panel ./admin-panel \
  --namespace wsc \
  --values values.local.yaml \
  > /tmp/admin-panel-rendered.yaml
```

If `kubeconform` is installed, validate the rendered resources too.
The second schema location adds the Gateway API and cert-manager resources that routing creates:

```bash
kubeconform -strict -summary -kubernetes-version 1.27.0 \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  /tmp/admin-panel-rendered.yaml
```

Validate the rendered release against the target API server without installing it:

```bash
helm install admin-panel ./admin-panel \
  --namespace wsc \
  --values values.local.yaml \
  --dry-run=server \
  --hide-secret
```

## 6. Install Admin-panel

Use `upgrade --install` so the same command works for the first install
and later configuration updates:

```bash
helm upgrade --install admin-panel ./admin-panel \
  --namespace wsc \
  --values values.local.yaml \
  --atomic \
  --timeout 10m
```

Before the Deployments are created or updated, the `admin-panel-migrate` Helm hook waits for
the primary database and runs its migrations.
`--atomic` rolls the Helm release back if that hook or the rollout fails.

> [!WARNING]
> `--atomic` does not roll back database migrations.

## 7. Verify application health

Wait for every long-running role:

```bash
kubectl -n wsc rollout status deployment/admin-panel-web --timeout=5m
kubectl -n wsc rollout status deployment/admin-panel-worker --timeout=5m
kubectl -n wsc rollout status deployment/admin-panel-scheduler --timeout=5m
kubectl -n wsc get pods --selector app.kubernetes.io/instance=admin-panel
```

All Pods must show `Running`, and all containers must be ready.
Run the chart test:

```bash
helm test admin-panel --namespace wsc
```

The test calls Laravel's `/up` route through the Kubernetes Service.
It must finish with `Phase: Succeeded`.
Do not add `--logs`.
The chart deletes the test Pod when it succeeds, so Helm cannot fetch its logs.

For the no-routing quick start, keep this command running in one terminal:

```bash
kubectl -n wsc port-forward service/admin-panel-web 8080:80
```

Then use another terminal:

```bash
curl --fail --show-error --silent http://127.0.0.1:8080/up
curl --head http://127.0.0.1:8080/
```

The health request must succeed.
On a new installation, the root request redirects to `/setup`.
After you create the first administrator, it redirects to the sign-in page.
Open <http://127.0.0.1:8080> in a browser for the final check.

## 8. Create the first administrator

Admin-panel has no self-registration.
You create the first administrator on the `/setup` page with a one-time token.

Do not look for the setup URL in the Pod logs.
The migration Job creates the first token, and Helm deletes the Job after success.
The token recovery file is deleted with its Pod.
The web Pods cannot recover that URL.

Generate a new setup URL from the web Pod:

```bash
kubectl -n wsc exec deployment/admin-panel-web -- \
  php artisan app:setup-token --regenerate --no-ansi
```

The command prints a URL of the form `<APP_URL>/setup?token=...`.
Open it within 24 hours.
Then create the organization and first administrator.
A new token invalidates all earlier tokens.
After the first user exists, invite other users from the Team page.

If the browser cannot open the setup page, create the administrator from the command line.
The command asks for the name, email, and password:

```bash
kubectl -n wsc exec --stdin --tty deployment/admin-panel-web -- \
  php artisan admin:create
```

To run it without prompts, pass `--name` and `--email`.
You can also pass `--password`.
If you omit it, the command generates a strong password and prints it once.
This command works only before the first user exists.
To reset a password later, run `php artisan user:reset-password <email>` in the web Pod.

## 9. If installation fails

The chart retains a failed migration Job for inspection and deletes a successful one.
Use the operator guide's [failure guide](README.md#failure-guide)
for diagnostic commands and common causes.

## Next steps

- Add external access with the [Gateway API or Ingress examples](examples/README.md).
- Configure every application setting through the
  [environment-variable contract](ENVIRONMENT_VARIABLES.md).
- Externalize uploads before scaling web Pods.
  See the [storage example](examples/values-storage.yaml).
- Read the [operator guide](README.md) before a production rollout.
