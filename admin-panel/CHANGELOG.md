# Changelog

## [1.1.0](https://github.com/WebSpellChecker/admin-panel-helm/compare/v1.0.0...v1.1.0) - 2026-10-07

### Features

* update Admin-panel to 3.1.0 (#13) ([c9a7c9c](https://github.com/WebSpellChecker/admin-panel-helm/commit/c9a7c9c0f9d206c4e70154fa455ba13d38a854dd))

## [1.0.0](https://github.com/WebSpellChecker/admin-panel-helm/releases/tag/v1.0.0) - 2026-10-05

### Features

* first release of the chart for WProofreader Admin-panel 3.0.0
* web, queue worker, and scheduler workloads from one application image
* `pre-install,pre-upgrade` hook Job for database migrations
* Gateway API and Ingress routing, optional cert-manager certificates, and same-origin routes to WProofreader Server
* chart-managed Secret or an existing Secret
* S3-compatible object storage and an optional ReadWriteMany volume for uploads
* health probes, a Helm test, web autoscaling, a PodDisruptionBudget, per-role scheduling, and an optional NetworkPolicy
* strict values validation, including rejection of unknown options and managed environment-variable overrides
* non-root security contexts, runtime seccomp profiles, dropped capabilities, and no automatic service-account token mounts
* installation, configuration, routing, and operations guides
