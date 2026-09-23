# Admin-panel Helm chart

This chart deploys WProofreader Admin-panel on Kubernetes. It is intended for
operators who already have WProofreader Server and the required MySQL databases.

For a first installation, follow the [quick start](docs/QUICKSTART.md). It covers the
required values, Secret creation, validation, installation, and health checks.

## What the chart deploys

The Admin-panel image runs in three roles. A separate Helm hook handles database
migrations before an install or upgrade.

| Component | Command | Default replicas |
| --- | --- | ---: |
| Web | Image default: nginx and PHP-FPM | 1 |
| Worker | `php artisan queue:work` | 1 |
| Scheduler | `php artisan schedule:work` | 1, fixed |
| Migration | Image entrypoint runs `php artisan migrate --force` | One hook Job |

The chart requires Admin-panel `3.0.0` or newer.

## Requirements

These services must be reachable from the namespace where you install the chart:

| Dependency | Purpose | Where to get it |
| --- | --- | --- |
| Admin-panel MySQL database | Stores users, teams, sessions, cache, and queues | Any MySQL 8.4 server you operate, or a managed MySQL service |
| WProofreader service database | Stores WProofreader services and usage data | Provision it with the database job in [wproofreader-helm](https://github.com/WebSpellChecker/wproofreader-helm) |
| WProofreader Server | Provides proofreading services | [wproofreader-helm](https://github.com/WebSpellChecker/wproofreader-helm) |

This chart does not install MySQL, provision the WProofreader database, or install
WProofreader Server. It migrates only the Admin-panel database.

## Install

From this repository:

```bash
kubectl create namespace admin-panel
cp docs/examples/values-minimal.yaml values.local.yaml
```

Edit `values.local.yaml` and set the public URLs and database connection details. The
chart always sets `APP_EDITION=onprem`.

Create the required Secret. Keep passwords out of the values file:

```bash
kubectl -n admin-panel create secret generic admin-panel-secrets \
  --from-literal=APP_KEY='base64:REPLACE_WITH_A_32_BYTE_BASE64_KEY' \
  --from-literal=DB_PASSWORD='REPLACE_WITH_APP_DB_PASSWORD' \
  --from-literal=SERVICE_DB_PASSWORD='REPLACE_WITH_SERVICE_DB_PASSWORD'
```

Generate an application key with:

```bash
printf 'base64:%s\n' "$(openssl rand -base64 32)"
```

Use your normal secret-management system for production.

Validate and install the chart:

```bash
helm lint ./admin-panel --values values.local.yaml
helm upgrade --install admin-panel ./admin-panel \
  --namespace admin-panel \
  --values values.local.yaml \
  --atomic \
  --timeout 10m

kubectl -n admin-panel rollout status deployment/admin-panel-web --timeout=5m
helm test admin-panel --namespace admin-panel
```

For a local smoke test without external routing, run:

```bash
kubectl -n admin-panel port-forward service/admin-panel-web 8080:80
```

Then request <http://127.0.0.1:8080/up> from another terminal.

## Documentation

- [Quick start](docs/QUICKSTART.md): first deployment and verification
- [Environment variables](docs/ENVIRONMENT_VARIABLES.md): Helm values, generated
  environment variables, secrets, and overrides
- [Routing](docs/ROUTING.md): Gateway API, Ingress, and TLS
- [Operator guide](docs/README.md): storage, scaling, upgrades, and troubleshooting
- [Examples](docs/examples/README.md): minimal, routing, and storage values
- [Chart values](admin-panel/README.md): generated value reference
- [Changelog](CHANGELOG.md)

