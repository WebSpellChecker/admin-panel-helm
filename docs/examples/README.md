# Example values

Use these files with the [quick start](../QUICKSTART.md). Copy one base example, replace
its endpoints, and add the required overlays.

| File | Scenario |
|------|----------|
| [`values-minimal.yaml`](./values-minimal.yaml) | External MySQL, an existing Secret, log-only mail, and no routing. Start here. |
| [`values-gateway-tls.yaml`](./values-gateway-tls.yaml) | Gateway API on Traefik with cert-manager TLS and same-origin WProofreader routing. See the [routing guide](../ROUTING.md). |
| [`values-ingress.yaml`](./values-ingress.yaml) | Traefik Ingress with cert-manager TLS. |
| [`values-storage.yaml`](./values-storage.yaml) | S3 storage by default, with a commented ReadWriteMany alternative. Use it as an overlay: `-f docs/examples/values-minimal.yaml -f docs/examples/values-storage.yaml`. |

## Secret and ConfigMap

| File | Purpose |
|------|---------|
| [`secret.yaml`](./secret.yaml) | Example `admin-panel-secrets` object for `secrets.existingSecret`. |
| [`configmap.yaml`](./configmap.yaml) | Reference for the non-secret environment generated from `config.*`. Do not create this object. |

All base examples use `secrets.existingSecret: admin-panel-secrets`. Create the Secret
before you install the chart. Add S3 credentials to the same Secret when required. Omit
them when workload identity supplies the credentials.

## Local development

| File | Purpose |
|------|---------|
| [`mailpit-dev.yaml`](./mailpit-dev.yaml) | Mailpit Deployment and Service for testing outbound mail in a local cluster. |

Do not combine the Gateway and Ingress examples. Select one routing method.
