# Routing: Gateway API and Ingress

The chart can render either Gateway API resources or an Ingress. It does not install
Gateway API CRDs, routing controllers, cert-manager, or certificate issuers. Install and
operate those components separately.

## Prerequisites

Before enabling routing, provide:

- A Gateway API or Ingress controller.
- Gateway API CRDs when using `gateway.enabled`.
- A DNS name that points to the controller.
- A TLS Secret, or cert-manager and an Issuer when the chart must request one.

Set `config.appUrl` to the public Admin-panel URL. Enable exactly one routing method.
The chart rejects configurations that enable both.

| Method | Enable with | Example |
| --- | --- | --- |
| Gateway API | `gateway.enabled: true` | [`values-gateway-tls.yaml`](examples/values-gateway-tls.yaml) |
| Ingress | `ingress.enabled: true` | [`values-ingress.yaml`](examples/values-ingress.yaml) |

Each routing example is a complete values file. Copy one example and replace its hosts,
database settings, and issuer name:

```bash
cp docs/examples/values-gateway-tls.yaml values.local.yaml
```

Then follow the quick-start steps to [render](QUICKSTART.md#5-render-before-changing-the-cluster),
[install](QUICKSTART.md#6-install-admin-panel), and
[verify](QUICKSTART.md#7-verify-application-health) the release.

## Gateway API

Set `gateway.create: true` to create a Gateway and its HTTPRoutes. Supply the
GatewayClass name and listener ports used by the controller. Common defaults are:

| Controller | HTTP listener | HTTPS listener |
| --- | ---: | ---: |
| Traefik | `8000` | `8443` |
| Envoy Gateway | `80` | `443` |

Confirm the ports in the controller configuration. The external Service can expose
different ports from the Gateway listeners.

Install the Gateway API CRD version that your controller supports. Confirm that your
Kubernetes version accepts it. Gateway API `v1.6.1` does not install on Kubernetes 1.27.
On Kubernetes 1.27, this chart works with Gateway API `v1.2.1` and Traefik `v3.3`
(chart `34.5.0`).

Set `gateway.create: false` to attach the HTTPRoute to an existing Gateway through
`gateway.parentRefs`. The Gateway owner is then responsible for listeners, TLS, and HTTP
to HTTPS redirects.

When `gateway.tls.certManager.enabled` is true, this chart creates a cert-manager
Certificate in the release namespace. The referenced Issuer or ClusterIssuer must
already exist. For an existing Gateway in another namespace, manage its certificate
with that Gateway instead.

## Ingress

Set the IngressClass, hosts, annotations, and TLS Secret under `ingress`. Redirects are
controller-specific and must be configured through the controller or Ingress
annotations. Ingress backends cannot reference a Service in another namespace.

## Co-hosting WProofreader

Enable `gateway.wproofreader` or `ingress.wproofreader` to route `/wscservice` to the
WProofreader Service before the Admin-panel catch-all route. Then use the same public
origin for the browser-facing URL:

```yaml
config:
  appUrl: https://admin-panel.example.com
  appServerUrl: https://admin-panel.example.com/wscservice/api
```

When both charts run in `wsc`, keep `gateway.wproofreader.namespace` empty. For Gateway
API across namespaces, set it to the WProofreader namespace. The chart creates the
required ReferenceGrant. Ingress requires both charts in the same namespace.

Set `config.appServerInternalUrl` to the WProofreader Service URL when Admin-panel's
server-side calls should remain inside the cluster. See
[WProofreader Server URLs](ENVIRONMENT_VARIABLES.md#wproofreader-server-urls).

## Verify

For Gateway API:

```bash
kubectl -n wsc get gateway,httproute
kubectl -n wsc get httproute admin-panel \
  -o jsonpath='{range .status.parents[*]}{.parentRef.sectionName}: {range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
```

The Gateway must report `Programmed=True`. The HTTPRoute must report
`Accepted=True` and `ResolvedRefs=True`.

For Ingress:

```bash
kubectl -n wsc get ingress
```

If the chart uses cert-manager, verify the Certificate too:

```bash
kubectl -n wsc get certificate
```

After DNS and TLS are ready, verify the application endpoint:

```bash
curl --fail --show-error --silent https://admin-panel.example.com/up
```

Before DNS exists, send the same request to the controller address. Replace
`CONTROLLER_ADDRESS` with the controller's LoadBalancer address, or run
`kubectl port-forward` to the controller Service and use `127.0.0.1` with the local port.
Add `--insecure` while the certificate is self-signed:

```bash
curl --fail --show-error --silent \
  --connect-to admin-panel.example.com:443:CONTROLLER_ADDRESS:443 \
  https://admin-panel.example.com/up
```

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Chart rejects the values | Enable only one of `gateway.enabled` and `ingress.enabled`. |
| Gateway does not become programmed | Check the GatewayClass, controller status, and listener ports. |
| HTTPRoute reports `BackendNotFound` | Check Service names and `gateway.wproofreader.namespace`. |
| WProofreader requests return Admin-panel 404 responses | Enable the WProofreader route and check `ResolvedRefs`. |
| Certificate stays pending | Check the Issuer, DNS or ACME challenge, and Certificate events. |
| Ingress does not redirect HTTP | Configure the redirect in the Ingress controller. |
