# Admin-panel Helm chart

[![Chart validation](https://github.com/WebSpellChecker/admin-panel-helm/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/WebSpellChecker/admin-panel-helm/actions/workflows/lint.yml)
[![Secret scan](https://github.com/WebSpellChecker/admin-panel-helm/actions/workflows/secret-scan.yml/badge.svg?branch=main)](https://github.com/WebSpellChecker/admin-panel-helm/actions/workflows/secret-scan.yml)

This chart deploys WProofreader Admin-panel on Kubernetes.
It is intended for operators who already have WProofreader Server and access to MySQL 8.4.
Admin-panel `3.0.0` or newer is required.

For a first installation, follow the [quick start](docs/QUICKSTART.md).

## Install a published chart

After the first release, the chart is available from the WebSpellChecker Helm repository.
Prepare the dependencies and the Secret as described in the [quick start](docs/QUICKSTART.md).

Download the minimal example as your values file, then set your URLs and database settings in it,
as described in [step 4 of the quick start](docs/QUICKSTART.md#4-create-the-values-file):

```bash
curl -fsSL -o values.local.yaml \
  https://raw.githubusercontent.com/WebSpellChecker/admin-panel-helm/main/docs/examples/values-minimal.yaml
```

To match a pinned chart version, replace `main` with its release tag, for example `v1.0.0`.

Install the chart:

```bash
helm repo add webspellchecker https://webspellchecker.github.io/admin-panel-helm
helm repo update webspellchecker
helm upgrade --install admin-panel webspellchecker/admin-panel \
  --namespace wsc \
  --values values.local.yaml \
  --atomic \
  --timeout 10m
```

Add `--version <chart version>` to pin a release.
Until the first release, install from a source checkout with `./admin-panel`,
as the quick start shows.

## Requirements

These services must be reachable from the namespace where you install the chart:

| Dependency | Purpose | Where to get it |
| --- | --- | --- |
| Admin-panel MySQL database | Stores users, teams, sessions, cache, and queues | Any MySQL 8.4 server you operate, or a managed MySQL service |
| WProofreader service database | Stores WProofreader service and usage data | Follow [Connect to and provision a database](https://github.com/WebSpellChecker/wproofreader-helm/blob/main/README.md#connect-to-and-provision-a-database) in `wproofreader-helm` |
| WProofreader Server | Provides proofreading services | [wproofreader-helm](https://github.com/WebSpellChecker/wproofreader-helm) |

The Admin-panel and WProofreader databases are separate logical databases,
but they can use the same MySQL 8.4 instance.
Use separate database names, users, and permissions.

This chart does not install MySQL, provision the WProofreader database,
or install WProofreader Server.
It migrates only the Admin-panel database.

## Documentation

- [Quick start](docs/QUICKSTART.md): first deployment and verification
- [Environment variables](docs/ENVIRONMENT_VARIABLES.md): Helm values,
  generated environment variables, secrets, and overrides
- [Routing](docs/ROUTING.md): Gateway API, Ingress, and TLS
- [Operator guide](docs/README.md): storage, scaling, upgrades, and troubleshooting
- [Examples](docs/examples/README.md): minimal, routing, and storage values
- [Chart values](admin-panel/README.md): generated value reference
- [Changelog](admin-panel/CHANGELOG.md)

## Related repositories

| Repository | What it contains |
| --- | --- |
| [wproofreader-helm](https://github.com/WebSpellChecker/wproofreader-helm) | The Helm chart for WProofreader Server. It also creates the WProofreader service database with db-manager. |
| [mysql-server-helm](https://github.com/WebSpellChecker/mysql-server-helm) | A Helm chart that runs MySQL in the cluster. |
| [wproofreader-gitops](https://github.com/WebSpellChecker/wproofreader-gitops) | Argo CD and Flux configurations that deploy the full stack from Git: MySQL, WProofreader Server, Admin-panel, cert-manager, and a Gateway API controller. |
| [wproofreader-docker](https://github.com/WebSpellChecker/wproofreader-docker) | Docker build files for WProofreader Server, and a Docker Compose example of the full stack on one host. |

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you send a pull request.
Use GitHub issues for reproducible chart defects and
[WebSpellChecker support](https://webspellchecker.com/contact-us/) for product support.
Report suspected vulnerabilities through the [security policy](SECURITY.md).
