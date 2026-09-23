# Routing: Gateway API and Ingress

This guide exposes Admin-panel on a hostname with TLS. Pick one of the three supported
setups. Every command below was run against a cluster with the pinned versions in the
table.

| Setup | Controller | Status | Use when |
| --- | --- | --- | --- |
| A. Gateway API with Traefik | Traefik chart `41.5.0` (Traefik `v3.7.13`), Gateway API CRDs `v1.6.1` | Recommended | New clusters, or clusters that already run Traefik |
| B. Gateway API with Envoy Gateway | Envoy Gateway `v1.9.1` | Supported alternative | Clusters standardized on Envoy |
| C. Ingress with Traefik | Traefik chart `41.5.0` | Compatibility option | Clusters that must stay on classic Ingress |

All three use cert-manager `v1.21.1` for certificates. Enable exactly one of
`gateway.enabled` or `ingress.enabled`; the chart refuses to render both.

## Before you start

1. A DNS name for Admin-panel, `admin-panel.example.com` below, pointing at the controller's
   LoadBalancer address once it exists.
2. An Admin-panel release, or the values file from the [quick start](QUICKSTART.md).
   Set `config.appUrl` to `https://admin-panel.example.com`.
3. cert-manager and an issuer. Install cert-manager once per cluster:

   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
   helm upgrade --install cert-manager jetstack/cert-manager \
     --version v1.21.1 --namespace cert-manager --create-namespace \
     --set crds.enabled=true
   ```

   The chart creates a cert-manager `Certificate` directly, so cert-manager's optional
   Gateway API integration does not need to be enabled.

   Then create a ClusterIssuer. For a first test use a self-signed one:

   ```bash
   kubectl apply -f - <<'YAML'
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: selfsigned
   spec:
     selfSigned: {}
   YAML
   ```

   For production replace it with an ACME issuer such as `letsencrypt-prod` and use
   that name in the values below.

## A. Gateway API with Traefik

**1. Install the Gateway API CRDs** (standard channel; the chart uses only Gateway and
HTTPRoute):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
```

**2. Install Traefik with the Gateway provider and without its own default Gateway.**
The Admin-panel chart creates the Gateway.

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik --version 41.5.0 \
  --namespace traefik --create-namespace \
  --set providers.kubernetesGateway.enabled=true \
  --set gateway.enabled=false
kubectl wait --for=condition=Accepted gatewayclass/traefik --timeout=120s
kubectl get gatewayclass traefik
```

The GatewayClass shows `ACCEPTED Unknown` for the first seconds and `True` once Traefik
has reconciled it; the `kubectl wait` line covers that. The chart also prints a
deprecation warning that it still ships Gateway API CRDs. Helm never overwrites CRDs
that already exist, so the `v1.6.1` set from step 1 stays in place; check with
`kubectl get crd httproutes.gateway.networking.k8s.io -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}'`.
Do not add `--wait` on a cluster without a LoadBalancer provider: the Traefik Service
stays `<pending>` and the install times out even though Traefik is running.

**3. Add the routing values.** Traefik binds Gateway listeners to its entrypoints by
port, and those are `8000` for `web` and `8443` for `websecure`, not 80 and 443. The
Traefik Service still exposes 80 and 443 externally.

```yaml
gateway:
  enabled: true
  create: true
  gatewayClassName: traefik
  listenerPort: 8000
  hostnames: ["admin-panel.example.com"]
  tls:
    enabled: true
    listenerPort: 8443
    secretName: admin-panel-gw-tls
    certManager:
      enabled: true
      issuerRef:
        name: selfsigned          # letsencrypt-prod in production
        kind: ClusterIssuer
```

Apply with the usual `helm upgrade --install ... --atomic`.

**4. Verify.** The Gateway must be `PROGRAMMED True`, each HTTPRoute parent
`Accepted=True ResolvedRefs=True`, and the Certificate `READY True`:

```bash
kubectl -n admin-panel get gateway,httproute,certificate
kubectl -n admin-panel get httproute admin-panel \
  -o jsonpath='{range .status.parents[*]}{.parentRef.sectionName}: {range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
```

Then test through the controller. The HTTP request must answer `301` to the HTTPS URL
and the HTTPS request must answer `200`:

```bash
CONTROLLER_ADDRESS="$(kubectl -n traefik get svc traefik \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
if [ -z "${CONTROLLER_ADDRESS}" ]; then
  CONTROLLER_ADDRESS="$(kubectl -n traefik get svc traefik \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
fi
if [ -z "${CONTROLLER_ADDRESS}" ]; then
  echo 'Traefik has no LoadBalancer address; use the port-forward commands below.' >&2
else
  curl --silent --output /dev/null --write-out '%{http_code} %{redirect_url}\n' \
    --connect-to "admin-panel.example.com:80:${CONTROLLER_ADDRESS}:80" \
    http://admin-panel.example.com/up
  curl --silent --output /dev/null --write-out '%{http_code}\n' --insecure \
    --connect-to "admin-panel.example.com:443:${CONTROLLER_ADDRESS}:443" \
    https://admin-panel.example.com/up
fi
```

Drop `--insecure` once a real issuer signs the certificate. Without a LoadBalancer
address, keep this command running in one terminal:

```bash
kubectl -n traefik port-forward service/traefik 8080:80 8443:443
```

Then run the equivalent checks in another terminal:

```bash
curl --silent --output /dev/null --write-out '%{http_code} %{redirect_url}\n' \
  --connect-to admin-panel.example.com:80:127.0.0.1:8080 \
  http://admin-panel.example.com/up
curl --silent --output /dev/null --write-out '%{http_code}\n' --insecure \
  --connect-to admin-panel.example.com:443:127.0.0.1:8443 \
  https://admin-panel.example.com/up
```

## B. Gateway API with Envoy Gateway

Same as A with three differences.

**1. Install Envoy Gateway.** Its chart bundles the Gateway API `v1.6.1` CRDs, so skip
the separate CRD step, and create the GatewayClass yourself:

```bash
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version v1.9.1 \
  --namespace envoy-gateway-system --create-namespace
kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
YAML
kubectl get gatewayclass eg
```

**2. Use the class `eg` and the real ports** in the values from step A.3:

```yaml
gateway:
  gatewayClassName: eg
  listenerPort: 80
  tls:
    listenerPort: 443
```

**3. Verify through the data-plane Service.** Envoy Gateway creates one Service per
Gateway in its own namespace. Find that Service and accept either an IP address or a
DNS hostname from its LoadBalancer status:

```bash
ENVOY_SERVICE="$(kubectl -n envoy-gateway-system get service \
  -l gateway.envoyproxy.io/owning-gateway-name=admin-panel,gateway.envoyproxy.io/owning-gateway-namespace=admin-panel \
  -o jsonpath='{.items[*].metadata.name}')"
if [ -z "${ENVOY_SERVICE}" ]; then
  echo 'Envoy Gateway has not created the Admin-panel data-plane Service.' >&2
else
  CONTROLLER_ADDRESS="$(kubectl -n envoy-gateway-system get service "${ENVOY_SERVICE}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
  if [ -z "${CONTROLLER_ADDRESS}" ]; then
    CONTROLLER_ADDRESS="$(kubectl -n envoy-gateway-system get service "${ENVOY_SERVICE}" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
  fi
  if [ -z "${CONTROLLER_ADDRESS}" ]; then
    echo 'Envoy Gateway has no LoadBalancer address; use the port-forward commands below.' >&2
  else
    curl --silent --output /dev/null --write-out '%{http_code} %{redirect_url}\n' \
      --connect-to "admin-panel.example.com:80:${CONTROLLER_ADDRESS}:80" \
      http://admin-panel.example.com/up
    curl --silent --output /dev/null --write-out '%{http_code}\n' --insecure \
      --connect-to "admin-panel.example.com:443:${CONTROLLER_ADDRESS}:443" \
      https://admin-panel.example.com/up
  fi
fi
```

Until that Service has an external address the Gateway reports
`PROGRAMMED False` with reason `AddressNotAssigned`, while both listeners already show
`Programmed=True`. That is expected on a cluster without a LoadBalancer provider. In
that case, keep this command running in the terminal where you discovered
`ENVOY_SERVICE`:

```bash
kubectl -n envoy-gateway-system port-forward \
  "service/${ENVOY_SERVICE}" 8080:80 8443:443
```

Use the two local `curl --connect-to` commands from A.4 in another terminal.

## C. Ingress with Traefik

Traefik installed as in A.2 also serves Ingress; the Gateway provider flags are
harmless if unused. One difference: Ingress has no portable HTTP to HTTPS redirect, so
configure it on the Traefik entrypoint:

```bash
helm upgrade --install traefik traefik/traefik --version 41.5.0 \
  --namespace traefik --create-namespace \
  --set providers.kubernetesGateway.enabled=false \
  --set gateway.enabled=false \
  --set ports.web.http.redirections.entryPoint.to=websecure \
  --set ports.web.http.redirections.entryPoint.scheme=https \
  --set ports.web.http.redirections.entryPoint.permanent=true
kubectl get ingressclass traefik
```

Routing values:

```yaml
gateway:
  enabled: false
ingress:
  enabled: true
  className: traefik
  annotations:
    cert-manager.io/cluster-issuer: selfsigned   # letsencrypt-prod in production
  hosts:
    - host: admin-panel.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: admin-panel-tls
      hosts: ["admin-panel.example.com"]
```

Verify with the same two `curl` commands as A.4, after checking:

```bash
kubectl -n admin-panel get ingress,certificate
```

## Co-hosting WProofreader on the same hostname

Both routing methods can send `/wscservice` to the WProofreader Service so the browser
widget calls it same-origin. Set `gateway.wproofreader.enabled` or
`ingress.wproofreader.enabled` to `true`, name the WProofreader Service, and point
`config.appServerUrl` at `https://admin-panel.example.com/wscservice/api`.

With Gateway API, WProofreader may live in another namespace: set
`gateway.wproofreader.namespace`, and the chart renders the `ReferenceGrant` that
Gateway API requires into that namespace next to the backend reference. Verified with
Admin-panel in `admin-panel` and WProofreader in `am`:

```yaml
gateway:
  wproofreader:
    enabled: true
    serviceName: wproofreader-app
    servicePort: 80
    namespace: am
```

Without the namespace value, the HTTPRoute for a WProofreader in another namespace
shows `ResolvedRefs=False` with reason `BackendNotFound`. Ingress has no
cross-namespace backends at all, so with Ingress both charts must share a namespace, or
the WProofreader paths silently answer 404.

Whichever method you use, the browser extension and the in-app widget send their
requests to `APP_SERVER_URL`. If that is the same-origin path and the route is missing,
those requests reach Admin-panel's web server and fail with 404.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| Chart fails to render: "Enable only one of gateway.enabled or ingress.enabled" | Both routing methods are on. Disable one. |
| `helm install traefik --wait` times out; Pod is `Running` | No LoadBalancer provider, Service address stays `<pending>`. Re-run without `--wait`, or use `service.type=NodePort`. |
| Gateway `PROGRAMMED False`, reason `AddressNotAssigned` | Same cause. Listeners are usable through port-forward; assign a LoadBalancer address for real traffic. |
| HTTPRoute `ResolvedRefs=False`, `BackendNotFound` | A backend Service name is wrong, or the WProofreader Service is in another namespace and `gateway.wproofreader.namespace` is unset. See the section above. |
| Extension or widget requests to `/wscservice/api` answer 404 | Co-routing is off or unresolved, so the requests hit Admin-panel instead of WProofreader. Enable `gateway.wproofreader` and check `ResolvedRefs`. |
| HTTPRoute `Accepted=False` | The Gateway listener port does not match the controller. Traefik needs `8000`/`8443`, Envoy `80`/`443`. |
| Certificate not `READY` | `kubectl -n admin-panel describe certificate` and check the issuer exists and, for ACME, that DNS points at the controller. |
| HTTP does not redirect on Ingress | The redirect lives on the Traefik entrypoint, not in the chart. Apply the values from C. |
