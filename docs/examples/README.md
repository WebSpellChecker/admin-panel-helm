# Example values

Ready-to-adapt values files for common deployment shapes. Start with the
[quick start](../QUICKSTART.md), copy the minimal file, replace its example endpoints,
and pass it with `--values`:

```bash
cp docs/examples/values-minimal.yaml values.local.yaml
helm upgrade --install admin-panel ./admin-panel \
  --namespace admin-panel \
  --values values.local.yaml \
  --atomic \
  --timeout 10m
```

| File | Scenario |
|------|----------|
| [`values-minimal.yaml`](./values-minimal.yaml) | Smallest external-MySQL install; existing Secret, mail-to-log, and no routing. Start here. |
| [`values-gateway-tls.yaml`](./values-gateway-tls.yaml) | Gateway API on Traefik + cert-manager TLS, co-hosting WProofreader (recommended routing). Controller install steps: [routing guide](../ROUTING.md). |
| [`values-ingress.yaml`](./values-ingress.yaml) | Classic Ingress on Traefik + cert-manager TLS (compatibility option). |
| [`values-storage.yaml`](./values-storage.yaml) | Durable avatar and upload storage with an S3-compatible object store or an RWX volume. Pass this overlay with a base file: `-f values-minimal.yaml -f values-storage.yaml`. |

## Secret & ConfigMap

| File | Purpose |
|------|---------|
| [`secret.yaml`](./secret.yaml) | Example `admin-panel-secrets` object for `secrets.existingSecret`. Create this before installing the chart. |
| [`configmap.yaml`](./configmap.yaml) | Reference for the non-secret environment generated from `config.*`. Do not create this object. |

## Local dev

| File | Purpose |
|------|---------|
| [`mailpit-dev.yaml`](./mailpit-dev.yaml) | Mailpit Deployment + Service for catching outbound mail in a local cluster (point `config.mail.host` at it). |

Every base example uses `secrets.existingSecret: admin-panel-secrets`. Create it before
installing. The storage overlay expects its optional AWS credential keys in the same
Secret; on AWS with workload identity/IRSA, omit them.

Do not combine the Gateway and Ingress examples. Choose exactly one routing method.
