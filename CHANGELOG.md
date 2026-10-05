# Changelog

This file records changes to the Admin-panel Helm chart.
The chart follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html):
`version` tracks the chart, while `appVersion` tracks the Admin-panel image.

## [1.0.0] (2026-10-05)

Initial release for WProofreader Admin-panel 3.0.0.

### Added

- Web, queue worker, and scheduler workloads from one application image.
- A `pre-install,pre-upgrade` hook Job for database migrations.
- Gateway API and Ingress routing, optional cert-manager certificates,
  and same-origin routes to WProofreader Server.
- Support for a chart-managed Secret or an existing Secret.
- S3-compatible object storage and an optional ReadWriteMany volume for uploads.
- Health probes, a Helm test, web autoscaling, a PodDisruptionBudget, per-role scheduling,
  and an optional NetworkPolicy.
- Strict values validation, including rejection of unknown options
  and managed environment-variable overrides.
- Non-root security contexts, runtime seccomp profiles, dropped capabilities,
  and no automatic service-account token mounts.
- Installation, configuration, routing, and operations guides.
